extends SceneTree
var animators: Array[AnimationPlayer] = []
var skeletons: Array[Skeleton3D] = []
var names := ["student", "teacher_programming", "teacher_ai", "teacher_web", "demon_imp", "demon_brute", "demon_caster", "demon_warden", "demon_mirror", "demon_archon"]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.095, 0.105, 0.125)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.68, 0.73, 0.82)
	settings.ambient_light_energy = 0.65
	env.environment = settings
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_energy = 1.65
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 130, 0)
	fill.light_energy = 0.65
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.7
	camera.position = Vector3(2.5, 5.2, -12)
	camera.look_at(Vector3(0, 1.0, 1.55))
	camera.current = true
	for index in range(names.size()):
		var actor: Node3D = load("res://Assets/Models/%s.glb" % names[index]).instantiate()
		world.add_child(actor)
		var row := 0 if index < 4 else 1
		var col := index if row == 0 else index - 4
		var count := 4 if row == 0 else 6
		actor.position = Vector3((col - (count - 1) * 0.5) * 1.55, 0, 3.0 * row)
		var animator: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		animators.append(animator)
		skeletons.append(skeleton)
		var label := Label3D.new()
		label.text = names[index].replace("teacher_", "").replace("demon_", "")
		label.position = actor.position + Vector3(0, -.11, -.1)
		label.font_size = 34
		label.pixel_size = .005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var reports: Array = []
	for clip in ["Idle", "Run", "Hook"]:
		for animator in animators:
			if not animator.has_animation(clip):
				push_error("Missing clip: " + clip)
				quit(1)
				return
			animator.play(clip)
		await create_timer(.06).timeout
		var before: Array[Transform3D] = []
		for skeleton in skeletons:
			before.append(skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")))
		await create_timer(.28).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Art/Previews/godot_final_%s.png" % clip.to_lower())
		for i in range(names.size()):
			var after := skeletons[i].get_bone_global_pose(skeletons[i].find_bone("hand_r"))
			var tip_delta := (after * Vector3(.1, .1, .1)).distance_to(before[i] * Vector3(.1, .1, .1))
			reports.append({"model": names[i], "clip": clip, "time": animators[i].current_animation_position, "hand_tip_motion_m": tip_delta})
	var file := FileAccess.open("res://Art/godot_character_render_qa.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "status": "RENDERED", "scope": "Actual Compatibility rendered viewport, imported final GLBs, animation playback sampled at two wall-clock times; not full game behavior or browser performance.", "samples": reports}, "\t"))
	file.close()
	print("FINAL_CHARACTER_RENDER_COMPLETE")
	quit()
