extends SceneTree

const FX = preload("res://Scripts/combat_fx.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, label: String) -> void:
	checks.append({"pass": value, "label": label})
	if not value: failures.append(label)
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func _run() -> void:
	var game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	game.start_level(0)
	game.level.set_physics_process(false)
	for enemy in game.level.active_enemies: enemy.set_physics_process(false)
	var player = game.player
	await frames(3)
	check(physics_interpolation, "Project interpolates rendered physics motion")
	check(player.camera_rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "Camera uses manual render-frame interpolation")
	player.camera_rig.snap_to_target()
	check(player.camera_rig.global_position.is_equal_approx(player.global_position + Vector3.UP * 1.55), "Spawn camera snaps to positioned player without a startup fly-in")
	player.hit_pause = 0.15
	await frames(2)
	var impact_pose_time: float = player.animation_player.current_animation_position
	await frames(3)
	var pose_held := is_equal_approx(impact_pose_time, player.animation_player.current_animation_position)
	await frames(10)
	check(pose_held and player.animation_player.current_animation_position > impact_pose_time + 0.02, "Impact hitstop holds animation time, then resumes it")
	player.guarding = true
	player.parry_timer = 0.22
	Input.action_press("guard")
	var result: String = player.receive_hit(8, 15, player.global_position + Vector3.FORWARD)
	check(result == "parried", "Fixture produces a real parry")
	await frames(2)
	check(player.current_animation == player.animation_map.parry, "Parry pose is not replaced by guard on the next tick")
	Input.action_release("guard")
	player.request_dodge()
	player.focus = 100
	player.request_focus()
	check(player.attack_id.is_empty() and player.focus == 100, "Focus cannot overlap an active dodge or spend focus")
	player.request_interact()
	check(player.dodge_timer > 0 and player.stagger_timer == 0, "Interact cannot overlap dodge with a finisher or throw")
	await frames(45)
	player.request_attack("L")
	player.queued_action = "H"
	player.queue_timer = 0.18
	player.attack_elapsed = 0.4
	player.request_dodge()
	check(player.queued_action.is_empty() and player.queue_timer == 0, "Dodge cancel clears stale buffered attacks")
	var enemy = game.level._spawn_enemy("book", player.global_position + Vector3.FORWARD * 1.6)
	enemy.set_physics_process(false)
	enemy.broken = true
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2.5, 0.2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.global_position = player.global_position + Vector3.FORWARD * 0.8 + Vector3.UP
	await frames(2)
	check(player.nearest_enemy(2.4, false, true) == null, "Finisher target cannot be acquired through solid cover")
	wall.queue_free()
	await frames(2)
	check(player.nearest_enemy(2.4, false, true) == enemy, "Finisher target remains available with clear line of sight")
	var pool := FX.prepare(game)
	check(FX.prepare(game) == pool, "Impact effects reuse the existing pool")
	var node_count := get_node_count()
	for index in range(400): FX.burst(game, player.global_position + Vector3.UP, Color.ORANGE, index % 2 == 0)
	check(pool.get_child_count() == 12 and get_node_count() == node_count, "400 impacts do not allocate more nodes or timers")
	check(pool.process_mode == Node.PROCESS_MODE_PAUSABLE, "Pooled impacts respect pause")
	var file := FileAccess.open("res://evidence/motion_regressions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Isolated locomotion/camera/animation/effect regressions; fixtures alter action state, not a full playthrough."}, "\t"))
	print("MOTION_CHECKS ", JSON.stringify({"count": checks.size(), "failures": failures}))
	game._show_main_menu()
	for voice in game.audio._players: voice.stop()
	OS.delay_msec(120)
	game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
