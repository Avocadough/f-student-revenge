extends SceneTree

# Synthetic, isolated combat fixtures using the production player, stages and input
# routing. Explicit placement/state setup is not a human campaign playthrough.
const GameScene = preload("res://Scenes/main.tscn")
const PropScript = preload("res://Scripts/interactable_prop.gd")
var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var pressed_keys: Dictionary = {}
var successful_hits := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok:
		failures.append(label)
		print("FAIL: ", label, " ", detail)

func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func key(code: int, down: bool) -> void:
	pressed_keys[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: int) -> void:
	key(code, true)
	await ticks(1)
	key(code, false)

func attack() -> void:
	await tap(KEY_J)
	await ticks(32)

func mode(enabled: bool) -> void:
	game.settings.god_mode = enabled
	game._apply_settings()

func fixture(kind: String = "programming", index: int = 0, checkpoint: int = 0, distance: float = 1.35) -> Node:
	for code in pressed_keys.keys():
		if pressed_keys[code]: key(code, false)
	paused = false
	game.settings.god_mode = false
	game.start_level(index, checkpoint)
	game.level.set_physics_process(false)
	game.level.pending_enemies.clear()
	for enemy in game.level.active_enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	game.level.active_enemies.clear()
	await ticks(2)
	var enemy: Node = game.level._spawn_enemy(kind, game.player.global_position + Vector3.FORWARD * distance)
	enemy.set_physics_process(false)
	enemy.mode = "recover"
	enemy.state_time = 10.0
	await ticks(2)
	return enemy

func make_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.2)
	collider.shape = shape
	wall.add_child(collider)
	game.level.add_child(wall)
	return wall

func run() -> void:
	game = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await ticks(3)
	check(game.settings.god_mode == false, "God Mode defaults off without changing the normal campaign")
	var enemy := await fixture()
	check(enemy.max_health == 340, "Programming boss retains original 340 health")
	mode(true)
	# Deliberately non-full fixture health tests immunity separately from UI healing.
	game.player.health = 72.0
	game.player.posture = 32.0
	var result: String = game.player.receive_hit(99, 100, enemy.global_position, false)
	check(result == "invulnerable" and game.player.health == 72 and game.player.posture == 32 and not game.player.dead, "Ordinary hit cannot damage health or posture in God Mode")
	result = game.player.receive_hit(1000, 1000, enemy.global_position, true)
	check(result == "invulnerable" and game.player.health == 72 and game.player.posture == 32 and not game.player.dead, "Lethal unblockable hit cannot damage health or posture in God Mode")
	check(game.player.invulnerability == 0 and game.player.stagger_timer == 0 and game.player.damage_taken == 0, "God immunity leaves no damage, stagger or invulnerability timer residue")
	mode(false)
	result = game.player.receive_hit(7, 12, enemy.global_position, false)
	check(result == "hit" and game.player.health == 65 and game.player.damage_taken == 7, "Disabling God Mode immediately restores ordinary damage without a lingering grace period")

	enemy = await fixture()
	await attack()
	check(not enemy.dead and enemy.health == 327, "Normal-mode actual J still deals exactly 13 damage instead of an instant kill")
	enemy = await fixture("web", 2, 2)
	check(enemy.max_health == 480, "Web boss retains original 480 health")
	enemy.take_hit(200, 0, game.player.global_position, 0, true)
	var normal_shield_health: float = enemy.health
	await attack()
	check(enemy.shielded and not enemy.dead and enemy.health == normal_shield_health, "Normal-mode actual J cannot bypass the Web boss shield")

	for kind in ["paper", "book", "pencil", "pen", "phone", "tablet", "computer", "programming", "ai", "web", "server_core", "final_core"]:
		enemy = await fixture(kind)
		if kind == "book":
			enemy.mode = "approach"
			enemy.rotation.y = PI
		if kind == "ai":
			check(enemy.max_health == 410, "AI boss retains original 410 health")
			for i in range(3): enemy.notify_combo("LLL")
		mode(true)
		var defeated_events: Array = []
		enemy.defeated.connect(func(_target: Node) -> void: defeated_events.append(true))
		await attack()
		check(defeated_events.size() == 1 and (not is_instance_valid(enemy) or enemy.dead), "One actual J kills %s once in God Mode" % kind, {"defeat_events": defeated_events.size()})
		if defeated_events.size() == 1: successful_hits += 1

	# The shield is genuinely entered in normal mode, then the setting changes.
	enemy = await fixture("web", 2, 2)
	enemy.take_hit(200, 0, game.player.global_position, 0, true)
	var server: Node = enemy.phase_core
	check(enemy.shielded and is_instance_valid(server), "Shielded Web fixture has a real live server core before toggling")
	mode(true)
	await attack()
	check(enemy.dead and not enemy.shielded and game.level.final_core_created and not game.level.completed, "God jab kills a shielded Web boss and creates the final F core")
	check(not is_instance_valid(server) or server.dead, "God Web defeat removes the old phase core instead of leaving a shield softlock")
	var final_core: Node
	for target in game.level.active_enemies:
		if is_instance_valid(target) and target.kind == "final_core": final_core = target
	check(is_instance_valid(final_core), "Final core remains required and targetable after a God Web defeat")
	if is_instance_valid(final_core):
		# Explicit endpoint fixture placement, not a claim of walking the campaign.
		game.player.global_position = final_core.global_position + Vector3.BACK * 1.35
		game.player.reset_physics_interpolation()
		game.player.camera_rig.snap_to_target()
		await ticks(2)
		await attack()
	check(game.level.completed and not game.running and game.modal.visible, "Actual J on the final core reaches the ending with God Mode active")

	enemy = await fixture("programming", 0, 0, 8)
	mode(true)
	await attack()
	check(not enemy.dead and enemy.health == 340, "God jab cannot kill a boss beyond attack range")
	enemy = await fixture("programming", 0, 0, 1.8)
	var wall := make_wall(game.player.global_position + Vector3(0, 2, -0.9))
	mode(true)
	await ticks(2)
	await attack()
	check(not enemy.dead and enemy.health == 340, "God jab cannot kill a boss through a solid wall")
	wall.queue_free()
	await ticks(2)
	await attack()
	check(enemy.dead, "Removing the wall permits the same God attack to kill")

	enemy = await fixture()
	enemy.take_hit(1, 1000, game.player.global_position, 0, true)
	mode(true)
	await tap(KEY_E)
	await ticks(2)
	check(enemy.dead, "Actual E finisher kills a posture-broken boss in God Mode")
	enemy = await fixture("programming", 0, 0, 4)
	mode(true)
	var prop := PropScript.new()
	prop.stage = game.level
	prop.player = game.player
	game.level.add_child(prop)
	prop.global_position = game.player.global_position + Vector3(0.3, 0, -0.4)
	prop.reset_physics_interpolation()
	game.level.props.append(prop)
	await tap(KEY_E)
	await ticks(38)
	check(enemy.dead, "Actual E throws a nearby prop that kills a boss on collision in God Mode")

	enemy = await fixture("paper")
	mode(true)
	enemy.mode = "approach"
	enemy.state_time = 0
	enemy.set_physics_process(true)
	var completed_attacks := 0
	var previous_mode: String = enemy.mode
	for tick in range(180):
		await ticks(1)
		if previous_mode == "attack" and enemy.mode == "recover": completed_attacks += 1
		previous_mode = enemy.mode
	check(completed_attacks > 0 and game.player.health == 100 and game.player.posture == 0 and not game.player.dead, "Live enemy AI attacks leave a God player alive without health or posture loss", {"completed_attacks": completed_attacks})
	enemy.set_physics_process(false)
	game.player.global_position.y = -9
	game.player.velocity = Vector3(0, -50, 0)
	await ticks(1)
	await ticks(1)
	check(game.player.global_position.distance_to(game.level.get_spawn_position()) < 0.2 and game.player.health == 100 and not game.player.dead, "Falling outside the map in God Mode recovers to the checkpoint without losing health")

	var out := FileAccess.open("res://evidence/god_mode_combat_checks.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"engine": Engine.get_version_info().string, "one_j_kill_kinds": successful_hits,
		"scope": "Synthetic isolated production combat fixtures; actual J/E input, live AI, normal-mode comparisons and fall recovery. UI/persistence have their own separate suite. No human-playthrough or exhaustive-bug claim.",
		"fixture_disclosure": "Spawns, stationary-enemy state, guard/adaptation/posture setup and specific player positions/health are explicitly configured only for isolated cases. qa_no_save prevents reading or writing user progress."}, "\t"))
	print("GOD_MODE_COMBAT_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "one_j_kill_kinds": successful_hits, "failures": failures}))
	stop_audio(game)
	OS.delay_msec(120)
	paused = false
	game.queue_free()
	await ticks(12)
	quit(0 if failures.is_empty() else 1)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	for child in node.get_children(): stop_audio(child)
