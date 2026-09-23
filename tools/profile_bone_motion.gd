extends SceneTree

# Native render-frame diagnostic. Run with a display, not --headless:
# godot --path . --script tools/profile_bone_motion.gd --resolution 1280x720
# Compares PHYSICS and IDLE animation clocks on identical current assets.
# This is not a game-version comparison; v0.1 already used IDLE.
# The fixture sets qa_no_save and does not write player progress.
var game: Node
var player: Node
var skel: Skeleton3D
var output := {}
func _initialize() -> void: _run.call_deferred()
func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found: return found
	return null
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	game.start_level(0)
	game.level.set_physics_process(false)
	for enemy in game.level.active_enemies: enemy.set_physics_process(false)
	player = game.player
	player.set_physics_process(false)
	skel = find_skeleton(player.visual)
	output["engine"] = Engine.get_version_info()
	output["bone_names"] = []
	for i in range(skel.get_bone_count()): output.bone_names.append(skel.get_bone_name(i))
	var track_audit := {}
	for clip in player.animation_player.get_animation_list():
		var anim: Animation = player.animation_player.get_animation(clip)
		var outside_bones := []
		for i in range(anim.get_track_count()):
			var path := str(anim.track_get_path(i))
			if not path.contains("Skeleton3D:"): outside_bones.append({"path": path, "type": anim.track_get_type(i), "keys": anim.track_get_key_count(i)})
		track_audit[clip] = {"tracks": anim.get_track_count(), "outside_bones": outside_bones}
	output["track_audit"] = track_audit
	for mode in [AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE]:
		player.animation_player.callback_mode_process = mode
		player._play_animation("run", 0, true)
		await create_timer(0.3).timeout
		var previous := poses()
		var same := 0
		var count := 0
		var previous_time: float = player.animation_player.current_animation_position
		var repeated_clock := 0
		var max_step := 0.0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 2500000:
			await RenderingServer.frame_post_draw
			var current := poses()
			var diff := 0.0
			for i in range(current.size()): diff = maxf(diff, previous[i].origin.distance_to(current[i].origin) + previous[i].basis.x.distance_to(current[i].basis.x) + previous[i].basis.y.distance_to(current[i].basis.y) + previous[i].basis.z.distance_to(current[i].basis.z))
			if diff < 0.000001: same += 1
			max_step = maxf(max_step, diff)
			if is_equal_approx(previous_time, player.animation_player.current_animation_position): repeated_clock += 1
			previous_time = player.animation_player.current_animation_position
			previous = current
			count += 1
		output["physics" if mode == 0 else "idle"] = {"frames":count,"seconds":float(Time.get_ticks_usec()-start)/1000000.0,"repeated_entire_pose":same,"repeated_fraction":float(same)/count,"repeated_animation_clock":repeated_clock,"max_pose_step_metric":max_step}
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	player.set_physics_process(true)
	await physics_frame
	player._start_attack("hook")
	var expected_duration: float = player.ATTACKS.hook.startup + player.ATTACKS.hook.active + player.ATTACKS.hook.recovery
	var hook_length: float = player.animation_player.get_animation(player.animation_map.hook).length
	var max_clock_error := 0.0
	var hold_checks := []
	var injected_pause := false
	var paused_samples := 0
	var previous_time := -1.0
	var first_contact := {}
	while not player.attack_id.is_empty():
		await RenderingServer.frame_post_draw
		var timeline: float = player.animation_player.current_animation_position * expected_duration / hook_length
		max_clock_error = maxf(max_clock_error, absf(timeline - player.attack_elapsed))
		if player.attack_elapsed >= player.ATTACKS.hook.startup and first_contact.is_empty(): first_contact = {"attack_elapsed":player.attack_elapsed,"animation_game_time":timeline,"source_time":player.animation_player.current_animation_position}
		if player.attack_elapsed > 0.24 and not injected_pause:
			player.hit_pause = 0.05
			injected_pause = true
		if player.animation_player.speed_scale == 0:
			if previous_time >= 0: hold_checks.append(is_equal_approx(previous_time, timeline))
			previous_time = timeline
			paused_samples += 1
	output["idle_hook"] = {"max_visual_vs_physics_game_seconds":max_clock_error,"expected_duration":expected_duration,"source_length":hook_length,"first_active_render":first_contact,"pause_samples":paused_samples,"pause_clock_stable":not hold_checks.has(false),"finished_attack":player.attack_id.is_empty()}
	output["comparison"] = "PHYSICS versus IDLE animation clocks on current assets; not v0.1 versus v0.2."
	output["fixture"] = "Native GL Compatibility, 120 FPS cap, 60 physics ticks, stationary Run pose sampled after rendering, 2.5 seconds per clock. Hook uses real player attack timing with an injected 50 ms hit pause. qa_no_save is enabled."
	output["limitations"] = "Frame counts include the first sample; frame pacing can vary between runs. Bone repetition is distinct from root-position interpolation and overall FPS. Visual-versus-physics clock skew around one 60 Hz tick is expected."
	output["model_track_audit"] = audit_model_tracks()
	var file := FileAccess.open("res://evidence/bone_clock_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("BONE_CLOCK ",JSON.stringify({"physics":output.physics,"idle":output.idle,"idle_hook":output.idle_hook}))
	game._show_main_menu()
	await process_frame
	quit()
func poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in range(skel.get_bone_count()): result.append(skel.get_bone_pose(i))
	return result


func find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_animator(child)
		if found: return found
	return null

func audit_model_tracks() -> Dictionary:
	var summary := {}
	for model_name in ["teacher_programming", "teacher_ai", "teacher_web", "phone", "tablet", "computer"]:
		var model = load("res://Assets/Models/%s.glb" % model_name).instantiate()
		var animator := find_animator(model)
		var non_bones := []
		var tracks := 0
		for clip in animator.get_animation_list():
			var anim: Animation = animator.get_animation(clip)
			tracks += anim.get_track_count()
			for index in range(anim.get_track_count()):
				var path := str(anim.track_get_path(index))
				if not path.contains("Skeleton3D:") and not non_bones.has(path): non_bones.append(path)
		summary[model_name] = {"clips": animator.get_animation_list().size(), "tracks": tracks, "non_bone_paths": non_bones}
		model.free()
	return summary
