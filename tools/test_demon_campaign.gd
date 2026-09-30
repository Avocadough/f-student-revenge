extends SceneTree

const Stage = preload("res://Scripts/campus_stage.gd")
const Player = preload("res://Scripts/student_player.gd")
const Enemy = preload("res://Scripts/school_enemy.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var completion_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks.append(label)
	if not value:
		failures.append(label)
		push_error(label)

func make_stage(index: int, checkpoint: int = 0) -> Node:
	var stage := Stage.new()
	stage.stage_index = index
	stage.checkpoint_index = checkpoint
	root.add_child(stage)
	stage.set_physics_process(false)
	var player := Player.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.global_position = stage.get_spawn_position()
	player.stage_ref = stage
	stage.start(player)
	stage.stage_completed.connect(func() -> void: completion_count += 1)
	return stage

func spawn_pending(stage: Node) -> void:
	for tick in range(12):
		stage._physics_process(0.7)
		for enemy in stage.active_enemies:
			if is_instance_valid(enemy): enemy.set_physics_process(false)

func clear_combat(stage: Node) -> void:
	# Synthetic lifecycle fixture deliberately kills targets; this is not a skill or fun test.
	stage.player.god_mode = true
	for pass_index in range(12):
		spawn_pending(stage)
		for enemy in stage.active_enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead:
				enemy.take_hit(9999.0, 9999.0, stage.player.global_position, 0.0, true)
		if stage.combat_cleared: break
	stage.player.god_mode = false

func free_stage(stage: Node) -> void:
	stage.queue_free()
	await process_frame
	await physics_frame

func run() -> void:
	var stage := make_stage(0)
	check(stage.get_spawn_position() == stage.to_global(stage.spawn_markers[0]), "Spawn is supplied by the environment marker")
	check(not stage.request_teacher_support(), "First teacher support stays locked until rescue")
	check(not stage.teacher.is_in_group("enemies") and stage.teacher.is_in_group("teacher_allies"), "Teachers are allied and excluded from enemy targeting")
	check(not stage.teacher is CollisionObject3D and not stage.teacher.has_method("take_hit"), "Event teacher is invulnerable and cannot physically block combat")
	stage.player.global_position = stage.teacher.global_position
	check(stage.player.nearest_enemy(2.4) == null, "Player targeting never acquires the teacher")
	check(not stage.interact_objective(stage.player), "A live encounter cannot be bypassed by E")
	clear_combat(stage)
	check(stage.teacher_rescued and stage.teacher.rescued, "First clear rescues the teacher and unlocks support")
	check(stage.combat_cleared and not stage.room_clear[0], "Combat clear alone does not skip the mission device")
	stage.player.global_position = stage.to_global(stage.spawn_markers[0])
	check(not stage.interact_objective(stage.player), "E mission requires proximity")
	stage.player.global_position = stage.objective_node.global_position + Vector3.BACK
	check(stage.interact_objective(stage.player), "Nearby E completes a cleared objective")
	check(not stage.interact_objective(stage.player), "Mission interaction is idempotent")
	check(stage.room_clear[0], "Completed mission opens progression")
	var before: int = stage.total_defeated
	var prior: Node = stage.active_enemies[0]
	stage._on_enemy_defeated(prior)
	check(stage.total_defeated == before, "Repeated defeated callback is ignored")
	var direction: Vector3 = (stage.exit_markers[0] - stage.room_centers[0]).normalized()
	stage.player.global_position = stage.to_global(stage.exit_markers[0] + direction * 2.0)
	stage._physics_process(0.1)
	check(stage.checkpoint_index == 1 and stage.teacher_rescued, "Crossing the marked exit advances and reconstructs the ally")
	stage.restart_encounter()
	check(not stage.combat_cleared and not stage.objective_completed and stage.support_time == 0.0, "Restart resets mission, effects and objective lifecycle")
	await free_stage(stage)

	stage = make_stage(0, 1)
	stage.pending_enemies.clear()
	var demon: Node = stage._spawn_enemy("demon_imp", stage.to_local(stage.player.global_position) + Vector3.FORWARD * 2.0)
	demon.set_physics_process(false)
	var health_before: float = demon.health
	check(stage.request_teacher_support(), "Direct checkpoint select has support immediately ready")
	check(demon.posture == 35.0 and demon.stun_time == 1.6 and demon.health == health_before, "Programming support gives bounded posture/stun without changing hit damage")
	check(stage.support_cooldown == 15.0 and not stage.request_teacher_support(), "Teacher support has a 15 second cooldown and cannot spam")
	stage._physics_process(14.9)
	check(not stage.request_teacher_support(), "Support is unavailable just before cooldown expires")
	stage._physics_process(0.11)
	check(stage.request_teacher_support(), "Support is available after the whole cooldown")
	stage.support_cooldown = 0.0
	stage.player.active = false
	check(not stage.request_teacher_support(), "Inactive player cannot call support")
	stage.player.active = true
	stage.player.dead = true
	check(not stage.request_teacher_support(), "Dead player cannot call support")
	stage.player.dead = false
	paused = true
	check(not stage.request_teacher_support(), "Paused game cannot call support")
	paused = false
	await free_stage(stage)

	stage = make_stage(1, 2)
	spawn_pending(stage)
	demon = stage.get_boss()
	demon.notify_combo("LLL")
	demon.notify_combo("LLL")
	demon.notify_combo("LLL")
	check(demon.adapting, "Demon mirror retains the existing repeated-combo defense")
	stage.player.global_position = demon.global_position + Vector3.BACK * 2.0
	check(stage.request_teacher_support() and not demon.adapting and demon.exposed_time == 6.0, "AI support exposes the mirror and clears adaptation")
	for count in range(4): demon.notify_combo("LLL")
	check(not demon.adapting, "Analyzed enemy cannot rebuild adaptation during the support window")
	await free_stage(stage)

	stage = make_stage(2, 1)
	stage.player.god_mode = true
	for batch in range(3):
		spawn_pending(stage)
		for enemy in stage.active_enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead: enemy.take_hit(9999, 9999, Vector3.ZERO, 0, true)
		if stage.wave_index == 2: break
	check(stage.wave_index == 2 and stage.pending_enemies.size() == 3 and not stage.combat_cleared, "Web auditorium defense has a second finite wave before objective unlock")
	clear_combat(stage)
	check(stage.wave_index == 2 and stage.combat_cleared and stage.get_remaining() == 0, "Web auditorium defense terminates after exactly two waves")
	stage.restart_encounter()
	check(stage.wave_index == 1 and not stage.combat_cleared, "Restart rewinds a two-wave mission completely")
	check(stage.request_teacher_support(), "Web support activates a stationary firewall")
	var center: Vector3 = stage.support_center
	check(stage.support_block_projectile(center + Vector3.UP), "Web bubble intercepts projectiles inside its radius")
	check(not stage.support_block_projectile(center + Vector3.RIGHT * 4.0), "Web bubble does not intercept outside its radius")
	stage.player.global_position += Vector3.RIGHT * 4.0
	check(not stage.support_block_projectile(stage.player.global_position + Vector3.UP), "Web bubble stays anchored when player leaves it")
	stage._physics_process(6.01)
	check(not stage.support_block_projectile(center), "Web bubble expires after six seconds")
	await free_stage(stage)

	stage = make_stage(2, 2)
	spawn_pending(stage)
	demon = stage.get_boss()
	check(demon.display_name.find("อาจารย์") < 0 and demon.model_kind == "demon_archon", "Final boss uses a demon identity and model")
	demon.take_hit(200.0, 10.0, stage.player.global_position, 0.0, true)
	check(demon.shielded and is_instance_valid(demon.phase_core), "Final boss preserves the shield/core phase")
	demon.phase_core.take_hit(9999.0, 1000.0, stage.player.global_position, 0.0, true)
	check(not demon.shielded, "Destroying the curse pylon disables the shield")
	demon.take_hit(9999.0, 1000.0, stage.player.global_position, 0.0, true)
	check(stage.final_core_created and stage.combat_cleared and not stage.completed, "Final boss defeat unlocks E seal and does not prematurely finish")
	var attackable_end := false
	for enemy in stage.active_enemies:
		if is_instance_valid(enemy) and enemy.kind == "final_core": attackable_end = true
	check(not attackable_end, "The ending never spawns an attackable grade-system core")
	var portal = stage.get_meta("final_portal_visual", null)
	check(is_instance_valid(portal), "Final portal provides sealable runtime geometry")
	var count_before := completion_count
	stage.player.global_position = stage.objective_node.global_position + Vector3.BACK
	check(stage.interact_objective(stage.player), "Nearby E seals the final portal")
	stage.interact_objective(stage.player)
	stage._complete_stage()
	check(stage.completed and completion_count == count_before + 1, "Final completion signal is emitted exactly once")
	check(is_instance_valid(portal) and not portal.visible, "Successful E seal closes visible portal geometry")
	await free_stage(stage)

	# Every mission checkpoint must be independently resumable and finishable.
	for stage_index in range(3):
		for checkpoint in range(3):
			stage = make_stage(stage_index, checkpoint)
			clear_combat(stage)
			stage.player.global_position = stage.objective_node.global_position + Vector3.BACK
			check(stage.interact_objective(stage.player), "Stage %d room %d can finish its unique objective" % [stage_index + 1, checkpoint + 1])
			await free_stage(stage)
	var result := {"scope": "Synthetic campaign/support/lifecycle tests; not a human playthrough or balance result", "engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "passed": failures.is_empty()}
	var file := FileAccess.open("res://evidence/demon_campaign_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("DEMON_CAMPAIGN_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
