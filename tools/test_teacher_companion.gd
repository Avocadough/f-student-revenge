extends SceneTree

const GameScene = preload("res://Scenes/main.tscn")
var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks.append({"pass": value, "description": description})
	if not value: failures.append(description)

func frames(count: int) -> void:
	for tick in range(count): await physics_frame

func fixture(stage_index: int = 0, room: int = 1) -> Node:
	game.start_level(stage_index, room)
	game.level.set_physics_process(false)
	game.level.pending_enemies.clear()
	game.player.set_physics_process(false)
	game.player.global_position = game.level.to_global(game.level.room_centers[room])
	game.player.reset_physics_interpolation()
	return game.level

func target_fixture(level: Node, kind: String = "demon_imp") -> Node:
	var center: Vector3 = level.to_global(level.room_centers[level.checkpoint_index])
	game.player.global_position = center + Vector3.RIGHT * 2.0
	level.teacher.global_position = center - Vector3.RIGHT
	level.teacher.reset_physics_interpolation()
	var enemy: Node = level._spawn_enemy(kind, level.to_local(center + Vector3.RIGHT * 0.5))
	enemy.set_physics_process(false)
	return enemy

func wall_fixture(at: Vector3, size: Vector3 = Vector3(0.25, 2.5, 4.0)) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = at + Vector3.UP * 1.25
	return wall

func wait_for_attack(teacher: Node) -> bool:
	for tick in range(100):
		if teacher.combat_state == "attack": return true
		await frames(1)
	return false

func _run() -> void:
	game = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	var level: Node = fixture()
	var teacher: Node3D = level.teacher
	await frames(2)
	var distance_before: float = teacher.global_position.distance_to(game.player.global_position)
	await frames(60)
	check(teacher.global_position.distance_to(game.player.global_position) < distance_before - 1.0, "Rescued teacher actually follows the player through physics")
	check(teacher is CharacterBody3D and teacher.collision_layer == 0 and teacher.collision_mask == 1, "Teacher collides with the world but cannot block actors")
	check(teacher.has_method("get_combat_status"), "Teacher exposes a concise combat status for its HUD card")
	check(not teacher.is_in_group("enemies") and teacher.is_in_group("teacher_allies") and level.get_remaining() == 0, "Companion never counts toward room-clear enemies")
	check(game.player.health == 100.0 and not teacher.has_method("take_hit"), "Following has no friendly-fire or escort-health interface")
	teacher._play("walk", 0.0, true)
	teacher.animator.advance(0.0)
	teacher.animator.seek(teacher.animator.current_animation_length * 0.6, true)
	teacher._play("run")
	teacher.animator.advance(0.0)
	check(absf(teacher.animator.current_animation_position / teacher.animator.current_animation_length - 0.6) < 0.02, "Teacher preserves foot-cycle phase when walk becomes run")
	game.player.global_position = teacher.global_position - Vector3.RIGHT
	check(not game.player.test_move(game.player.global_transform, Vector3.RIGHT * 2.0), "Player collision sweep passes through the companion")
	game.player.global_position = level.to_global(level.room_centers[1])
	game.player.global_position = level.to_global(level.room_centers[1] + Vector3(20, 0, -30))
	await frames(180)
	var offset: Vector3 = teacher.global_position - teacher.arena_center
	check(absf(offset.x) < 6.7 and absf(offset.z) < 8.0, "Follower remains in its current room when player leaves its bounds")

	level = fixture(0, 0)
	teacher = level.teacher
	var waiting_at := teacher.global_position
	await frames(90)
	check(not teacher.rescued and teacher.global_position.is_equal_approx(waiting_at), "Unrescued teacher remains at the rescue marker")
	var rescue_enemy: Node = level._spawn_enemy("demon_imp", Vector3.ZERO)
	rescue_enemy.set_physics_process(false)
	rescue_enemy.take_hit(9999.0, 9999.0, game.player.global_position, 0.0, true)
	await frames(60)
	check(level.teacher_rescued and teacher.rescued and teacher.global_position.distance_to(waiting_at) > 0.5, "First real clear unlocks companion follow as well as T")

	level = fixture()
	teacher = level.teacher
	var enemy: Node = target_fixture(level)
	check(enemy.has_method("take_ally_hit"), "Enemy exposes a separate ally damage entry point")
	if not enemy.has_method("take_ally_hit"):
		await finish()
		return
	check(await wait_for_attack(teacher), "Nearby visible enemy triggers a real companion attack")
	await frames(8)
	check(enemy.health == 30.0, "Companion windup does not deal early damage")
	await frames(15)
	check(enemy.health == 22.0 and teacher.landed_hits == 1, "Companion deals exactly eight damage through the live enemy API")
	await frames(55)
	check(enemy.health == 22.0 and teacher.landed_hits == 1, "Recovery frames and cooldown cannot repeat the same hit")
	check(game.player.health == 100.0 and level.get_remaining() == 1, "Companion attack cannot hurt its student or alter live enemy count")
	await frames(100)
	check(teacher.landed_hits == 2, "Companion can begin a new attack after its bounded cooldown")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	teacher.rotation.y = PI / 2.0 # Enemy is directly behind the teacher's initial facing.
	await frames(14)
	check(enemy.health == 30.0, "Rear target cannot take an early punch while teacher is still turning")
	for tick in range(90):
		if enemy.health < 30.0: break
		await frames(1)
	var contact_direction: Vector3 = enemy.global_position - teacher.global_position
	contact_direction.y = 0.0
	check(enemy.health == 22.0 and (-teacher.global_transform.basis.z).dot(contact_direction.normalized()) >= 0.4, "Rear target is hit only after the teacher naturally turns into the attack arc")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	await wait_for_attack(teacher)
	enemy.global_position = teacher.global_position + teacher.global_transform.basis.z * 1.5
	await frames(30)
	check(enemy.health == 30.0 and teacher.landed_hits == 0, "Target crossing behind during windup cannot be hit outside the fist's impact arc")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	game.player.god_mode = true
	await wait_for_attack(teacher)
	await frames(30)
	check(enemy.health == 22.0 and not enemy.dead, "Player God Mode never makes autonomous ally damage lethal")
	game.player.god_mode = false

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	await wait_for_attack(teacher)
	enemy.queue_free()
	await frames(45)
	check(not is_instance_valid(teacher.target) and teacher.combat_state != "attack", "Freed enemy cancels a pending strike and is skipped by later scans")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	enemy.global_position = teacher.arena_center + Vector3(8.1, 0.0, 8.8)
	game.player.global_position = enemy.global_position - Vector3.RIGHT
	await frames(60)
	check(teacher.target == null, "Companion does not lock onto an unreachable arena-corner target")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	var blocked_at: Vector3 = (teacher.global_position + enemy.global_position) * 0.5
	var wall := wall_fixture(blocked_at, Vector3(0.25, 2.5, 10.0))
	await frames(90)
	if enemy.health != 30.0 or teacher.target != null:
		print("COVER_DIAGNOSTIC ", JSON.stringify({"health": enemy.health, "target": str(teacher.target), "teacher_position": str(teacher.global_position), "wall_position": str(wall.global_position), "clear_sight": teacher._has_line_of_sight(enemy), "state": teacher.combat_state}))
	check(enemy.health == 30.0 and teacher.target == null, "Teacher cannot acquire or hit an enemy behind solid cover")
	check(teacher.global_position.x < blocked_at.x - 0.2, "Follower's world collider cannot cross a wall")
	wall.queue_free()
	await frames(2)
	check(await wait_for_attack(teacher), "Removing cover makes the enemy eligible again")
	wall = wall_fixture((teacher.global_position + enemy.global_position) * 0.5, Vector3(0.2, 2.5, 10.0))
	await frames(30)
	check(enemy.health == 30.0, "Cover inserted during windup is checked again at impact")
	wall.queue_free()
	await frames(2)

	for exclusion in ["shielded", "broken", "is_core", "dead"]:
		level = fixture()
		teacher = level.teacher
		enemy = target_fixture(level)
		enemy.set(exclusion, true)
		await frames(75)
		check(enemy.health == 30.0 and teacher.target == null, "Teacher skips %s targets to preserve player mechanics" % exclusion)

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	await wait_for_attack(teacher)
	check(level.request_teacher_support(), "T remains available while companion begins a basic attack")
	await frames(35)
	check(enemy.health == 30.0 and level.support_cooldown == 15.0 and teacher.animation_time > 0.0, "T cancels basic windup and retains its existing fifteen-second skill cooldown")
	check(not level.request_teacher_support(), "T still cannot be spammed")

	for condition in ["pause", "modal", "inactive", "dead", "clear", "completed"]:
		level = fixture()
		teacher = level.teacher
		enemy = target_fixture(level)
		await wait_for_attack(teacher)
		var before_at := teacher.global_position
		match condition:
			"pause": paused = true
			"modal": game.modal.show()
			"inactive": game.player.active = false
			"dead": game.player.dead = true
			"clear": level.combat_cleared = true
			"completed": level.completed = true
		await frames(36)
		check(enemy.health == 30.0 and teacher.combat_state != "attack", "%s cancels companion damage already winding up" % condition)
		if condition not in ["clear"]: check(teacher.global_position.is_equal_approx(before_at), "%s freezes companion movement" % condition)
		paused = false
		game.modal.hide()
		if condition == "pause":
			await frames(15)
			check(enemy.health == 30.0, "Resuming pause cannot deliver a canceled delayed strike")

	level = fixture()
	teacher = level.teacher
	enemy = target_fixture(level)
	await wait_for_attack(teacher)
	var old_teacher: WeakRef = weakref(teacher)
	level.restart_encounter()
	level.pending_enemies.clear()
	await frames(3)
	check(old_teacher.get_ref() == null and level.teacher.landed_hits == 0, "Restart frees the old companion and its in-flight attack")
	old_teacher = weakref(level.teacher)
	level._start_encounter(2)
	level.pending_enemies.clear()
	await frames(3)
	check(old_teacher.get_ref() == null and level.teacher.arena_center == level.to_global(level.room_centers[2]), "Checkpoint creates one companion bound to the new room")
	check(get_nodes_in_group("teacher_allies").size() == 1, "Checkpoint lifecycle leaves no orphan ally nodes")
	old_teacher = weakref(level.teacher)
	game._show_main_menu()
	await frames(3)
	check(old_teacher.get_ref() == null and get_nodes_in_group("teacher_allies").is_empty(), "Menu return destroys companion and pending attacks")
	await finish()

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): stop_audio(child)

func finish() -> void:
	paused = false
	game._show_main_menu()
	stop_audio(game)
	OS.delay_msec(120)
	game.queue_free()
	await frames(4)
	DirAccess.make_dir_recursive_absolute("res://evidence/2026-10-12-polish")
	var report := {"engine": Engine.get_version_info().string, "scope": "Synthetic companion physics/combat/lifecycle regression; not rendered smoothness, Web FPS or a human playtest", "fixture_disclosure": "Fresh qa_no_save levels, encounter spawning and player physics paused; real companion physics and real enemy damage API run. Explicit positions/cover isolate behavior.", "checks": checks, "failures": failures}
	var file := FileAccess.open("res://evidence/2026-10-12-polish/teacher_companion_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("TEACHER_COMPANION_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
