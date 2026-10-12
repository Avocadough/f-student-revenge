extends SceneTree
## Isolated behavioral fixtures: actual world collision and animation contact timing.
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var room: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await physics_frame
func box(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var mesh := BoxShape3D.new()
	mesh.size = dimensions
	shape.shape = mesh
	body.add_child(shape)
	room.add_child(body)
	body.position = at
func _run() -> void:
	Engine.max_fps = 60
	for action in ["move_forward", "move_back", "move_left", "move_right", "guard"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	room = Node3D.new()
	root.add_child(room)
	box(Vector3(0, -0.2, 0), Vector3(30, 0.4, 30))
	box(Vector3(0, 1, -1.1), Vector3(5, 2, 0.2))
	player = load("res://Scripts/student_player.gd").new()
	room.add_child(player)
	player.position = Vector3(0, 0.05, 0)
	player.reset_physics_interpolation()
	Input.action_press("move_forward")
	await frames(100)
	check(absf(player.get_real_velocity().z) < 0.05, "Fixture player is stopped by solid cover")
	check(player.current_animation == player.animation_map.idle, "Pushing a wall stops the walking animation", player.current_animation)
	Input.action_release("move_forward")
	player.set_physics_process(false)
	player._play_animation("walk", 0.0, true)
	player.animation_player.seek(0.61, true)
	var phase: float = player.animation_player.current_animation_position / player.animation_player.current_animation_length
	player._play_animation("run")
	player.animation_player.advance(0)
	var next_phase: float = player.animation_player.current_animation_position / player.animation_player.current_animation_length
	check(absf(next_phase - phase) < 0.02, "Walk to run preserves the planted-foot cycle phase", [phase, next_phase])
	player.position = Vector3(7, 0.02, 0)
	player.health = 100
	player.invulnerability = 0
	player.god_mode = false
	player.reset_physics_interpolation()
	var enemy = load("res://Scripts/school_enemy.gd").new()
	enemy.kind = "demon_imp"
	enemy.player = player
	room.add_child(enemy)
	enemy.position = Vector3(7, 0.02, -1.65)
	enemy.arena_center = Vector3(7, 0, 0)
	enemy.reset_physics_interpolation()
	enemy._begin_attack(Vector3.BACK)
	var contact_phase := -1.0
	for frame in 90:
		await physics_frame
		if player.health < 100:
			contact_phase = enemy.animator.current_animation_position / enemy.animator.current_animation_length
			break
	check(player.health < 100, "Normal enemy strike still deals damage")
	check(contact_phase >= 0.16 and contact_phase <= 0.48, "Damage lands during the visible punch instead of its starting pose", contact_phase)
	enemy.queue_free()
	room.queue_free()
	await frames(3)
	var output := "res://evidence/2026-10-12-polish"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var f := FileAccess.open(output.path_join("motion_checks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Isolated behavioral fixtures, not a frame-time benchmark or full playthrough."}, "\t"))
	print("MOTION_POLISH ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
