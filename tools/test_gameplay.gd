extends SceneTree

# Synthetic integration QA. Combat travels through input events, real PlayerController,
# hit windows, physics and enemy AI. Unit fixtures are disclosed separately below.
const GameScene = preload("res://Scenes/main.tscn")
var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var combos: Array[String] = []
var frame := 0
var pressed_keys: Dictionary = {}
var traversal_started_frame := 0
var traversal_finished := false
var traversal_retries := 0
var reached: Array[String] = []
var web_shield_seen := false
var web_core_destroyed := false
var final_core_seen := false
var traversal_note := ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String, detail: Variant = null) -> void:
	checks.append({"pass": condition, "description": description, "detail": detail})
	if not condition:
		failures.append(description)
		print("CHECK FAILED: ", description, " ", detail)

func wait_frames(count: int) -> void:
	for i in range(count):
		await physics_frame
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

func fixture(enemy_kind: String = "programming") -> Node:
	release_all()
	game.start_level(0, 0)
	game.level.set_physics_process(false)
	game.level.pending_enemies.clear()
	for enemy in game.level.active_enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	game.level.active_enemies.clear()
	await wait_frames(2)
	var enemy: Node = game.level._spawn_enemy(enemy_kind, game.player.global_position + Vector3.FORWARD * 1.35)
	enemy.set_physics_process(false)
	enemy.mode = "recover"
	enemy.state_time = 10.0
	game.player.combo_completed.connect(func(id: String) -> void: combos.append(id))
	await wait_frames(2)
	return enemy

func attack_key(code: int) -> void:
	await tap(code)
	var limit := 0
	while not game.player.attack_id.is_empty() and limit < 120:
		await wait_frames(1)
		limit += 1
	await wait_frames(1)

func run() -> void:
	game = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await wait_frames(3)
	check(game.main_menu.visible and not game.running, "Startup renders menu state before gameplay")
	check(press_button_with("เริ่มล้างแค้น", game.menu_stack), "New-game menu button is wired")
	await wait_frames(1)
	check(game.modal.visible and not game.running, "New-game button opens story introduction")
	check(press_button_with("ถึงเวลาเข้าเรียน", game.modal_stack), "Intro button starts playable stage")
	await wait_frames(3)
	check(game.running and game.stage_index == 0 and game.player.active, "Menu to stage 1 reaches active player")

	var enemy := await fixture()
	var before: float = enemy.health
	await attack_key(KEY_J)
	check(is_equal_approx(before - enemy.health, 13.0), "One actual jab damages a target once across all active frames", before - enemy.health)
	for sequence in ["LLL", "LLH", "LHL"]:
		enemy = await fixture()
		before = enemy.health
		var prior_combos := combos.size()
		for letter in sequence:
			await attack_key(KEY_J if letter == "L" else KEY_K)
		var expected: float = {"LLL": 53.0, "LLH": 55.0, "LHL": 49.0}[sequence]
		check(is_equal_approx(before - enemy.health, expected), "%s produces its documented damage through J/K events" % sequence, before - enemy.health)
		check(combos.size() > prior_combos and combos.back() == sequence, "%s emits completed combo from real attack state" % sequence)

	enemy = await fixture("paper")
	enemy.mode = "approach"
	enemy.state_time = 0
	enemy.set_physics_process(true)
	await tap(KEY_SHIFT)
	key(KEY_SHIFT, true)
	await wait_frames(115)
	check(game.player.health == 100 and game.player.posture > 0, "Held guard blocks a real AI attack after parry window expires", {"health": game.player.health, "posture": game.player.posture})

	enemy = await fixture("paper")
	enemy.mode = "approach"
	enemy.state_time = 0
	enemy.set_physics_process(true)
	for tick in range(180):
		if enemy.mode == "telegraph" and enemy.state_time < 0.12:
			key(KEY_SHIFT, true)
			break
		await wait_frames(1)
	await wait_frames(24)
	check(game.player.parry_count == 1 and game.player.health == 100, "Timed Shift parries an actual enemy attack", {"parries": game.player.parry_count, "health": game.player.health})
	check(enemy.posture >= 30, "Actual parry returns posture damage to attacker", enemy.posture)
	key(KEY_SHIFT, false)
	await attack_key(KEY_J)
	check("COUNTER" in combos, "Parry then J routes through counter attack")

	enemy = await fixture("paper")
	enemy.mode = "approach"
	enemy.state_time = 0
	enemy.set_physics_process(true)
	for tick in range(180):
		if enemy.mode == "telegraph" and enemy.state_time < 0.07:
			await tap(KEY_SPACE)
			break
		await wait_frames(1)
	await wait_frames(22)
	check(game.player.dodge_count == 1 and game.player.health == 100, "Space dodge avoids damage during a real enemy attack", {"dodges": game.player.dodge_count, "health": game.player.health})

	release_all()
	game.start_level(0, 0)
	await wait_frames(3)
	await tap(KEY_P)
	check(paused and game.paused and game.modal.visible, "P input opens pause modal and pauses tree")
	var position_before: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	await wait_frames(20)
	check(game.player.global_position == position_before, "Paused player does not move while movement input is held")
	Input.action_release("move_forward")
	check(press_button_with("เล่นต่อ", game.modal_stack), "Resume modal button is wired")
	await wait_frames(3)
	check(not paused and not game.paused and game.running, "Resume restores active simulation")

	# Death is caused by normal enemy attacks; there is no direct receive_hit or health overwrite.
	for tick in range(3600):
		if game.player.dead and game.modal.visible: break
		await wait_frames(1)
	check(game.player.dead and game.player.health == 0, "Normal live enemy AI can deplete player health to zero", {"health": game.player.health, "damage_taken": game.player.damage_taken})
	var death_checkpoint: int = game.checkpoint_index
	check(press_button_with("กลับไปแก้มือ", game.modal_stack), "Death retry modal button is wired")
	await wait_frames(3)
	check(not game.player.dead and game.player.health == 100 and game.checkpoint_index == death_checkpoint, "Retry restores current checkpoint with full health")

	# Explicit in-memory fixture verifies routing only. qa_no_save keeps disk/user progress untouched.
	game._show_main_menu()
	game.save_data = {"stage": 1, "checkpoint": 1}
	check(press_button_with("เล่นต่อจากจุดล่าสุด", game.menu_stack), "Continue button is wired to saved checkpoint route")
	await wait_frames(3)
	check(game.stage_index == 1 and game.checkpoint_index == 1 and absf(game.player.global_position.z + 18.0) < 0.2, "Continue route loads fixture stage 2 checkpoint 2", "In-memory fixture only; persistent storage not exercised")

	await run_traversal()
	write_result()
	stop_audio(game)
	OS.delay_msec(120)
	paused = false
	game.queue_free()
	await wait_frames(12)
	quit(0 if failures.is_empty() and traversal_finished else 1)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.stop()
	for child in node.get_children(): stop_audio(child)

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
			print("STATE ", JSON.stringify({"tick": tick, "running": game.running, "paused": game.paused, "tree_paused": paused, "room": room_id, "spawn": level.encounter_started, "pending": level.pending_enemies.size(), "alive": level._alive_count(), "stage_processing": level.is_physics_processing(), "health": p.health, "position": str(p.global_position), "modal": game.modal.visible}))
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
			press_button_with("ขึ้นชั้นถัดไป", game.modal_stack)
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
		if level.final_core_created: final_core_seen = true
		if level.room_clear[game.checkpoint_index]:
			key(KEY_SHIFT, false)
			var goal := Vector3(0, p.global_position.y, -float(game.checkpoint_index) * 24.0 - 20.0)
			set_move(goal - p.global_position)
			await wait_frames(1)
			continue
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
		check(web_shield_seen and web_core_destroyed and final_core_seen, "Traversal passed Web shield, server core and final F core", {"shield_seen": web_shield_seen, "server_destroyed": web_core_destroyed, "final_core_seen": final_core_seen})

func write_result() -> void:
	var result := {
		"scope": "Synthetic automated gameplay integration, not manual browser verification or a user fun assessment",
		"engine": Engine.get_version_info().string,
		"controls": "Input.parse_input_event for J K Shift Space Q E P; Input.action_press/release for movement; modal Button.pressed.emit for menu navigation",
		"fixture_disclosure": "Isolated combat cases start a fresh level, pause encounter spawning and one stationary enemy AI, and place that enemy within reach. Defense/death cases run real enemy AI. Checkpoint-load uses disclosed in-memory save_data fixture. No user save file is touched.",
		"traversal_disclosure": "Fresh game from menu. No direct take_hit/receive_hit calls, position teleports, health edits, enemy disabling, or invulnerability edits in traversal. Bot may observe enemy states. Production boss checkpoints legitimately heal player.",
		"checks": checks, "failure_count": failures.size(), "failures": failures,
		"traversal": {"complete": traversal_finished, "reached_rooms": reached, "retries": traversal_retries, "simulated_seconds": float(frame - traversal_started_frame) / 60.0, "web_shield_seen": web_shield_seen, "web_core_destroyed": web_core_destroyed, "final_core_seen": final_core_seen, "events": events, "note": traversal_note}
	}
	var file := FileAccess.open("res://evidence/gameplay_integration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("GAMEPLAY_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures, "traversal_complete": traversal_finished, "reached": reached, "retries": traversal_retries}))
