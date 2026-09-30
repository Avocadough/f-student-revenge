extends Node

## Isolated Web QA: normal controls for traversal; invulnerability only in declared stress fixture.
const GameScene = preload("res://Scenes/main.tscn")
var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var frame := 0
var pressed_keys: Dictionary = {}
var traversal_started_frame := 0
var traversal_finished := false
var traversal_retries := 0
var reached: Array[String] = []
var web_shield_seen := false
var web_core_destroyed := false
var final_seal_seen := false
var traversal_note := ""
var phase := "ready"
var overlay: CanvasLayer
var result_label: Label
var buckets: Dictionary = {}
var active_sample_key := ""
var previous_render_usec := 0
var room_warmup_usec := 0
var sample_run := -1
var hidden_frames_excluded := 0
var inactive_frames_excluded := 0
var status_elapsed := 0.0
var document_ref: JavaScriptObject
var started_usec := 0
var traversal_wall_seconds := 0.0
var traversal_sim_seconds := 0.0
var stress_wall_seconds := 0.0
var route_right := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"): document_ref = JavaScriptBridge.get_interface("document")
	RenderingServer.frame_post_draw.connect(_sample_render_frame)
	overlay = CanvasLayer.new()
	add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color("12212d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)
	var panel := VBoxContainer.new()
	panel.position = Vector2(230, 230)
	panel.size = Vector2(820, 270)
	panel.add_theme_constant_override("separation", 20)
	overlay.add_child(panel)
	var title := Label.new()
	title.text = "ISOLATED WEB QA • CAMPUS DEMON CAMPAIGN"
	title.add_theme_font_size_override("font_size", 27)
	panel.add_child(title)
	var body := Label.new()
	body.text = "Normal controls across all 9 rooms, then a separate 30-second stress fixture.\nKeep this tab visible. Do not press movement keys while the bot runs.\nThe stress fixture alone uses an invulnerable player with four normal enemies.\nNo progress is saved. Actual Godot rendered frames are timed after warm-up."
	body.add_theme_font_size_override("font_size", 18)
	panel.add_child(body)
	var button := Button.new()
	button.text = "Start QA (normal traversal + 30s performance fixture)"
	button.custom_minimum_size = Vector2(800, 60)
	button.pressed.connect(_start_qa)
	panel.add_child(button)
	button.grab_focus()
	result_label = Label.new()
	result_label.position = Vector2(30, 650)
	result_label.add_theme_font_size_override("font_size", 18)
	overlay.add_child(result_label)

func _start_qa() -> void:
	if phase != "ready": return
	overlay.hide()
	game = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	add_child(game)
	phase = "traversal"
	started_usec = Time.get_ticks_usec()
	await wait_frames(3)
	await run_traversal()
	traversal_wall_seconds = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	traversal_sim_seconds = float(frame - traversal_started_frame) / 60.0
	phase = "stress_setup"
	_publish_status("Normal traversal finished. Preparing the disclosed four-enemy performance fixture...")
	await _run_stress()
	phase = "complete"
	release_all()
	game._show_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_publish_result()

func _run_stress() -> void:
	release_all()
	game.start_level(1, 1)
	# The sole combat-state override in this harness: preserve a constant enemy workload.
	game.player.invulnerability = 1000.0
	for tick in range(360):
		if game.level._alive_count() == 4: break
		await wait_frames(1)
	check(game.level._alive_count() == 4, "Stress fixture starts with four live normal enemies")
	phase = "stress"
	active_sample_key = ""
	var stress_start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - stress_start < 32000000:
		var p: Node = game.player
		if p.global_position.x > 4.0: route_right = false
		if p.global_position.x < -4.0: route_right = true
		var toward := Vector3(1.0 if route_right else -1.0, 0.0, -0.6 if p.global_position.z > -23.0 else 0.0)
		set_move(toward)
		await wait_frames(1)
	stress_wall_seconds = float(Time.get_ticks_usec() - stress_start) / 1000000.0
	check(game.level._alive_count() == 4 and not game.player.dead, "Stress fixture retains four live enemies for the full observation")
	release_all()

func _process(delta: float) -> void:
	status_elapsed += delta
	if status_elapsed < 1.0 or not is_instance_valid(game): return
	status_elapsed = 0.0
	if phase in ["traversal", "stress"]:
		_publish_status("%s | Room %d:%d | %d rooms reached | keep this tab visible" % [phase.to_upper(), game.stage_index + 1, game.checkpoint_index + 1, reached.size()])

func _sample_render_frame() -> void:
	var now := Time.get_ticks_usec()
	if phase not in ["traversal", "stress"] or not is_instance_valid(game) or not is_instance_valid(game.player):
		previous_render_usec = now
		return
	if OS.has_feature("web") and document_ref != null and document_ref.hidden:
		hidden_frames_excluded += 1
		previous_render_usec = now
		room_warmup_usec = now
		return
	if not game.running or game.paused or get_tree().paused or not game.player.active or game.player.dead:
		inactive_frames_excluded += 1
		previous_render_usec = now
		return
	var key_value: String = "stress_4_enemy" if phase == "stress" else "%d:%d" % [game.stage_index + 1, game.checkpoint_index + 1]
	if key_value != active_sample_key or sample_run != game._run_id:
		active_sample_key = key_value
		sample_run = game._run_id
		room_warmup_usec = now
		previous_render_usec = now
		if not buckets.has(key_value): buckets[key_value] = {"frame_ms": [], "min_alive": 999, "max_alive": 0, "max_draw_calls": 0.0}
		return
	if now - room_warmup_usec < 2000000:
		previous_render_usec = now
		return
	if previous_render_usec > 0:
		var data: Dictionary = buckets[key_value]
		data.frame_ms.append(float(now - previous_render_usec) / 1000.0)
		data.min_alive = mini(int(data.min_alive), game.level._alive_count())
		data.max_alive = maxi(int(data.max_alive), game.level._alive_count())
		data.max_draw_calls = maxf(float(data.max_draw_calls), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	previous_render_usec = now

func _summarize(samples: Array) -> Dictionary:
	if samples.is_empty(): return {"frames": 0, "sample_seconds": 0.0, "avg_fps": null, "p95_frame_ms": null}
	var sorted: Array = samples.duplicate()
	sorted.sort()
	var total_ms := 0.0
	for sample in samples: total_ms += float(sample)
	return {"frames": samples.size(), "sample_seconds": total_ms / 1000.0, "avg_fps": samples.size() * 1000.0 / maxf(total_ms, 0.001), "p95_frame_ms": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95) - 1)], "max_frame_ms": sorted.back()}

func _publish_result() -> void:
	var per_room: Dictionary = {}
	var all_traversal_samples: Array = []
	var stress_result: Dictionary = {}
	for key_value: String in buckets:
		var bucket: Dictionary = buckets[key_value]
		var summary := _summarize(bucket.frame_ms)
		summary["min_alive_enemies"] = bucket.min_alive if not bucket.frame_ms.is_empty() else null
		summary["max_alive_enemies"] = bucket.max_alive
		summary["max_draw_calls"] = bucket.max_draw_calls
		if key_value == "stress_4_enemy": stress_result = summary
		else:
			per_room[key_value] = summary
			all_traversal_samples.append_array(bucket.frame_ms)
	var result := {
		"schema": 1, "scope": "Isolated browser-rendered QA; automated controls, not human usability or low-spec certification",
		"engine": Engine.get_version_info().string, "web": OS.has_feature("web"),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"video_adapter": RenderingServer.get_video_adapter_name(), "viewport": {"width": get_viewport().get_visible_rect().size.x, "height": get_viewport().get_visible_rect().size.y},
		"user_agent": str(JavaScriptBridge.eval("navigator.userAgent")) if OS.has_feature("web") else "native validation only",
		"engine_fps_cap": Engine.max_fps, "checks": checks, "failures": failures,
		"traversal": {"complete": traversal_finished, "reached_rooms": reached, "retries": traversal_retries, "simulated_seconds": traversal_sim_seconds, "wall_seconds": traversal_wall_seconds, "shield_seen": web_shield_seen, "curse_pylon_destroyed": web_core_destroyed, "final_E_seal_seen": final_seal_seen, "events": events, "note": traversal_note},
		"performance": {"per_room": per_room, "traversal_sampled_active": _summarize(all_traversal_samples), "stress_4_enemy": stress_result, "stress_total_wall_seconds_including_2s_warmup": stress_wall_seconds, "hidden_frames_excluded": hidden_frames_excluded, "inactive_frames_excluded": inactive_frames_excluded, "measurement": "Actual RenderingServer.frame_post_draw timestamps from Time.get_ticks_usec; active unpaused gameplay only; 2-second warm-up per room or restarted scene. Average FPS = sampled frames / summed sampled frame intervals. p95 is frame milliseconds. Browser display/VSync limits remain active; no RAF proxy."},
		"traversal_disclosure": "Same normal input bot as test_gameplay_v03: J/K/Shift/Space/Q/E/T and real movement; menu signals only route normal menus. No direct damage, teleport, health edit, invulnerability edit or disabled enemies during traversal; qa_no_save avoids user progress writes.",
		"stress_disclosure": "Separate stage 2 room 2 fixture, four live normal enemy AIs and two pending. Only player invulnerability is overridden to 1000 seconds. No attacks during 30 sampled seconds after 2 seconds warm-up; ordinary action inputs walk left/right. Not a normal difficulty result."
	}
	print("FSTUDENT_WEB_QA_RESULT ", JSON.stringify(result))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.finishFStudentQA(" + JSON.stringify(result) + ");")
	else:
		print("NATIVE_VALIDATION_ONLY: browser results must be captured separately")

func _publish_status(message: String) -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.fStudentQAStatus(" + JSON.stringify(message) + ");")

func check(condition: bool, description: String, detail: Variant = null) -> void:
	checks.append({"pass": condition, "description": description, "detail": detail})
	if not condition:
		failures.append(description)
		print("CHECK FAILED: ", description, " ", detail)

func wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		frame += 1

func key(code: int, down: bool) -> void:
	if bool(pressed_keys.get(code, false)) == down:
		return
	pressed_keys[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code, true)
	await wait_frames(1)
	key(code, false)

func release_all() -> void:
	for code in pressed_keys.keys(): key(code, false)
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)

func set_move(direction: Vector3) -> void:
	var d := direction.normalized() if direction.length() > 0.01 else Vector3.ZERO
	var strengths := {"move_left": maxf(0, -d.x), "move_right": maxf(0, d.x), "move_forward": maxf(0, -d.z), "move_back": maxf(0, d.z)}
	for action: String in strengths:
		if float(strengths[action]) > 0.12:
			Input.action_press(action, strengths[action])
		else:
			Input.action_release(action)

func press_button_with(text_fragment: String, container: Node) -> bool:
	for child in container.get_children():
		if child is Button and text_fragment in child.text:
			child.pressed.emit()
			return true
	return false

func run_traversal() -> void:
	release_all()
	game._show_main_menu()
	game.save_data.clear()
	game.elapsed = 0
	game.deaths = 0
	press_button_with("เริ่มล้างแค้น", game.menu_stack)
	await wait_frames(1)
	press_button_with("ถึงเวลาเข้าเรียน", game.modal_stack)
	await wait_frames(3)
	traversal_started_frame = frame
	var key_to_release := 0
	var previous_guard := false
	var dodge_pending := false
	var last_room := ""
	var snapshot_tick := 0
	for tick in range(60 * 720):
		if key_to_release != 0:
			key(key_to_release, false)
			key_to_release = 0
		var p: Node = game.player
		var level: Node = game.level
		var room_id := "%d:%d" % [game.stage_index + 1, game.checkpoint_index + 1]
		if tick % 3600 == 0:
			print("STATE ", JSON.stringify({"tick": tick, "running": game.running, "paused": game.paused, "tree_paused": get_tree().paused, "room": room_id, "spawn": level.encounter_started, "pending": level.pending_enemies.size(), "alive": level._alive_count(), "stage_processing": level.is_physics_processing(), "health": p.health, "position": str(p.global_position), "modal": game.modal.visible}))
		if room_id != last_room:
			last_room = room_id
			if room_id not in reached: reached.append(room_id)
			var event := {"room": room_id, "sim_seconds": float(frame - traversal_started_frame) / 60.0, "health": p.health}
			events.append(event)
			print("TRAVERSAL ", JSON.stringify(event))
		if not game.running and game.stage_index == 2 and level.completed:
			traversal_finished = true
			traversal_note = "Reached final ending by real player attacks and movement; no direct enemy damage, teleport, health override or invulnerability cheat."
			break
		if p.dead:
			release_all()
			if game.modal.visible:
				traversal_retries += 1
				events.append({"retry": traversal_retries, "room": room_id, "sim_seconds": float(frame - traversal_started_frame) / 60.0})
				if traversal_retries > 8:
					traversal_note = "Bot exhausted bounded retry budget; not a completed traversal."
					break
				press_button_with("กลับไปแก้มือ", game.modal_stack)
			await wait_frames(1)
			continue
		if not game.running and game.modal.visible:
			release_all()
			press_button_with("ไปช่วยพื้นที่ถัดไป", game.modal_stack)
			await wait_frames(1)
			continue
		if game.paused:
			release_all()
			press_button_with("เล่นต่อ", game.modal_stack)
			await wait_frames(1)
			continue
		var boss: Node = level.get_boss()
		if is_instance_valid(boss) and boss.kind == "web":
			if boss.shielded: web_shield_seen = true
			if boss.shield_triggered and not boss.shielded: web_core_destroyed = true
		if level.final_core_created: final_seal_seen = true
		if level.room_clear[game.checkpoint_index]:
			key(KEY_SHIFT, false)
			var exit_direction: Vector3 = (level.exit_markers[game.checkpoint_index] - level.room_centers[game.checkpoint_index]).normalized()
			var goal: Vector3 = level.to_global(level.exit_markers[game.checkpoint_index] + exit_direction * 3.0)
			goal.y = p.global_position.y
			set_move(goal - p.global_position)
			await wait_frames(1)
			continue
		if level.combat_cleared:
			key(KEY_SHIFT, false)
			var goal: Vector3 = level.objective_node.global_position
			var toward_device: Vector3 = goal - p.global_position
			toward_device.y = 0
			set_move(toward_device if toward_device.length() > 1.6 else Vector3.ZERO)
			if toward_device.length() <= 2.0 and p.attack_id.is_empty() and p.dodge_timer <= 0:
				key(KEY_E, true); key_to_release = KEY_E
			await wait_frames(1)
			continue
		if level.teacher_rescued and level.support_cooldown <= 0.0 and tick % 30 == 0:
			key(KEY_T, true); key_to_release = KEY_T
		var target: Node3D = null
		var closest := INF
		for candidate in level.active_enemies:
			if not is_instance_valid(candidate) or candidate.dead or candidate.shielded: continue
			var distance: float = p.global_position.distance_to(candidate.global_position)
			if candidate.is_core: distance *= 0.25
			if distance < closest:
				closest = distance
				target = candidate
		if target == null:
			set_move(Vector3.ZERO)
			await wait_frames(1)
			continue
		var toward: Vector3 = target.global_position - p.global_position
		toward.y = 0
		var distance := toward.length()
		var danger: Node = null
		var parry_needed := false
		for candidate in level.active_enemies:
			if not is_instance_valid(candidate) or candidate.dead: continue
			var d: float = p.global_position.distance_to(candidate.global_position)
			if candidate.mode == "telegraph" and candidate.attack_id in ["spin", "ai_zone", "web_error", "layout"]:
				if d < 4.2 or p.global_position.distance_to(candidate.attack_target) < 3.5:
					danger = candidate
			if candidate.mode == "telegraph" and candidate.state_time < 0.1 and d < 2.4 and candidate.attack_id not in ["spin", "ai_zone", "web_error", "layout"]:
				parry_needed = true
		if danger != null:
			key(KEY_SHIFT, false)
			var away: Vector3 = p.global_position - (danger.attack_target if danger.attack_id in ["ai_zone", "web_error", "layout"] else danger.global_position)
			away.y = 0
			if away.length() < 0.1: away = Vector3.RIGHT
			set_move(away)
			if dodge_pending and p.dodge_cooldown <= 0:
				key(KEY_SPACE, true); key_to_release = KEY_SPACE
			dodge_pending = true
		elif parry_needed and p.attack_id.is_empty():
			set_move(Vector3.ZERO)
			key(KEY_SHIFT, true)
			previous_guard = true
		elif p.parry_timer > 0 and previous_guard:
			set_move(Vector3.ZERO)
		else:
			key(KEY_SHIFT, false)
			previous_guard = false
			dodge_pending = false
			set_move(toward if distance > 1.75 else Vector3.ZERO)
			if distance < 2.3 and p.attack_id.is_empty() and p.stagger_timer <= 0 and p.dodge_timer <= 0:
				if target.can_finish():
					key(KEY_E, true); key_to_release = KEY_E
				elif p.counter_timer > 0:
					key(KEY_J, true); key_to_release = KEY_J
				elif p.focus >= 50 and not target.is_core:
					key(KEY_Q, true); key_to_release = KEY_Q
				else:
					key(KEY_K, true); key_to_release = KEY_K
		if tick - snapshot_tick >= 900:
			snapshot_tick = tick
			print("BOT ", JSON.stringify({"room": room_id, "health": p.health, "remaining": level.get_remaining(), "position": str(p.global_position), "target": target.kind, "target_hp": target.health, "attacks": p.attack_count}))
		await wait_frames(1)
	if traversal_note.is_empty(): traversal_note = "Bot reached simulation time limit; not a completed traversal."
	release_all()
	check(traversal_finished, "Automated real-player traversal reaches all three stages and final ending", traversal_note)
	if traversal_finished:
		check(web_shield_seen and web_core_destroyed and final_seal_seen, "Traversal passed demon shield, curse pylon and final E portal seal", {"shield_seen": web_shield_seen, "server_destroyed": web_core_destroyed, "final_seal_seen": final_seal_seen})
