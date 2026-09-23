extends SceneTree

const StageScript = preload("res://Scripts/campus_stage.gd")
var failures: Array[String] = []
var checks: Array[String] = []

class PlayerStub extends Node3D:
	var health := 100.0
	var focus := 50.0
	var hit_calls := 0
	var response := "hit"
	func receive_hit(_damage: float, _structure: float, _from: Vector3, _unblockable: bool = false) -> String:
		hit_calls += 1
		return response
	func heal(amount: float) -> void:
		health = minf(100, health + amount)

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks.append(label)
	if not condition:
		failures.append(label)
		push_error(label)

func _make_stage(index: int, checkpoint: int) -> Node3D:
	var stage := StageScript.new()
	stage.stage_index = index
	stage.checkpoint_index = checkpoint
	root.add_child(stage)
	stage.set_physics_process(false)
	return stage

func run() -> void:
	var player := PlayerStub.new()
	player.add_to_group("player")
	root.add_child(player)
	var stage := _make_stage(0, 0)
	player.global_position = stage.get_spawn_position()
	stage.start(player)
	for i in range(3): stage._physics_process(0.7)
	check(stage.get_remaining() == 3, "Stage 1 first encounter spawns exactly three enemies")
	for enemy in stage.active_enemies:
		enemy.set_physics_process(false)
	check(stage.gates.size() == 3, "Three connected rooms have three exit gates")
	for enemy in stage.active_enemies:
		enemy.take_hit(9999, 9999, player.global_position, 0, true)
	check(stage.room_clear[0], "Defeat events clear first encounter")
	check(stage.checkpoint_index == 0, "Clearing room does not teleport or advance checkpoint")
	player.global_position.z = -17
	stage._physics_process(0.1)
	check(stage.checkpoint_index == 1, "Walking through doorway advances checkpoint")
	for i in range(8): stage._physics_process(0.7)
	check(stage._alive_count() == 4 and stage.pending_enemies.size() == 1, "Maximum four active enemies with pending fifth")
	var active: Array = stage.active_enemies
	for enemy in active: enemy.set_physics_process(false)
	active[0].is_attacking = true
	active[1].is_attacking = true
	check(not stage.request_attack(active[2], false), "Maximum two simultaneous attackers")
	active[0].is_attacking = false
	active[1].ranged = true
	check(not stage.request_attack(active[2], true), "Only one ranged attacker at a time")
	active[1].is_attacking = false
	active[0].take_hit(9999, 9999, player.global_position, 0, true)
	stage._physics_process(0.7)
	check(stage._alive_count() == 4 and stage.pending_enemies.is_empty(), "Pending enemy spawns after a slot becomes available")
	stage.restart_encounter()
	check(stage.checkpoint_index == 1 and stage.get_remaining() == 5 and not stage.room_clear[1], "Restart restores whole encounter at current checkpoint")
	stage.queue_free()
	await process_frame
	stage = _make_stage(0, 2)
	stage.start(player)
	stage._physics_process(0.7)
	var professor: Node = stage.get_boss()
	player.response = "hit"
	player.global_position = professor.global_position + Vector3.FORWARD * 1.5
	var hits_before: int = player.hit_calls
	var completed_attacks := 0
	var prior_mode: String = professor.mode
	for frame_index in range(300):
		# Reduced damage/posture fixture isolates the old ordinary-hit stun lock;
		# no posture resets, timing edits or interruption bypasses are used.
		if frame_index % 20 == 0:
			professor.take_hit(1, 2, player.global_position, 0, true)
		await physics_frame
		if prior_mode == "attack" and professor.mode == "recover": completed_attacks += 1
		prior_mode = professor.mode
	check(completed_attacks >= 1 and player.hit_calls > hits_before, "Professor completes damaging attacks despite repeated heavy hits")
	check(professor.health < professor.max_health, "Boss heavy-hit resistance still accepts health damage")
	professor.set_physics_process(false)
	professor._begin_attack(Vector3.FORWARD)
	var telegraph_remaining: float = professor.state_time
	professor.take_hit(1, 2, player.global_position, 0, true)
	check(professor.mode == "telegraph" and professor.state_time == telegraph_remaining, "Heavy hit cannot cancel or reset an active professor telegraph")
	professor.on_parried()
	check(professor.mode == "recover" and professor.stun_time > 0, "Real parry still interrupts a professor after heavy-hit resistance fix")
	professor.take_hit(1, 1000, player.global_position, 0, true)
	check(professor.broken and professor.can_finish(), "Heavy hits still cause a true boss posture break and finisher opening")
	stage.queue_free()
	await process_frame

	stage = _make_stage(1, 2)
	player.global_position = stage.get_spawn_position()
	stage.start(player)
	stage._physics_process(0.7)
	var ai: Node = stage.get_boss()
	ai.set_physics_process(false)
	ai.notify_combo("LLL")
	ai.notify_combo("LLL")
	check(not ai.adapting, "AI does not adapt before three repeated completed combos")
	ai.notify_combo("LLL")
	check(ai.adapting, "AI adapts after three identical completed combos")
	ai.take_hit(1, 1, ai.global_position + Vector3.FORWARD, 0, true)
	check(not ai.adapting, "Heavy hit clears AI adaptation")
	ai.posture = 0
	ai.player = player
	player.response = "parried"
	player.global_position = ai.global_position + Vector3.FORWARD
	ai.attack_direction = Vector3.FORWARD
	ai._melee_hit(10, 20, 2.5, false)
	check(ai.posture == 42 and not ai.is_attacking, "A player parry damages boss posture and interrupts attack")
	ai.take_hit(1, 1000, player.global_position, 0, true)
	check(ai.can_finish(), "Full posture opens finisher")
	var before: float = ai.health
	ai.finish()
	check(ai.health == before - 60 and not ai.broken, "Boss finisher does bounded damage and clears posture break")
	stage.queue_free()
	await process_frame

	stage = _make_stage(2, 2)
	player.global_position = stage.get_spawn_position()
	stage.start(player)
	stage._physics_process(0.7)
	var web: Node = stage.get_boss()
	web.set_physics_process(false)
	web.take_hit(200, 10, player.global_position, 0, true)
	check(web.shielded and web.backend and web.shield_triggered, "Web boss activates shield once at 60 percent")
	var core: Node = web.phase_core
	check(is_instance_valid(core) and core.kind == "server_core", "Shield creates a visible destructible server core")
	before = web.health
	web.take_hit(9999, 1, player.global_position, 0, true)
	check(web.health == before, "Shield rejects boss damage before core destruction")
	core.take_hit(9999, 1000, player.global_position, 0, true)
	check(not web.shielded, "Core defeat disables boss shield")
	web.take_hit(20, 0, player.global_position, 0, true)
	check(not web.shielded, "Later damage does not recreate shield")
	web.take_hit(9999, 1000, player.global_position, 0, true)
	check(stage.final_core_created and not stage.completed, "Boss defeat stops attacks and creates final F core before ending")
	var final_core: Node
	for enemy in stage.active_enemies:
		if is_instance_valid(enemy) and enemy.kind == "final_core": final_core = enemy
	check(is_instance_valid(final_core), "Final core exists and can be targeted")
	final_core.take_hit(9999, 1000, player.global_position, 0, true)
	check(stage.completed, "Destroying final F core completes stage")
	stage.queue_free()
	await process_frame

	stage = _make_stage(2, 2)
	stage.start(player)
	stage._physics_process(0.7)
	web = stage.get_boss()
	web.take_hit(9999, 1000, player.global_position, 0, true)
	check(web.dead and stage.final_core_created, "Lethal hit crossing phase threshold cannot make boss immortal")
	stage.queue_free()
	await process_frame
	stage = _make_stage(1, 0)
	stage.start(player)
	stage.pending_enemies.clear()
	player.response = "hit"
	for enemy_kind in ["paper", "book", "pencil", "pen", "phone", "tablet", "computer", "programming", "ai", "web"]:
		var enemy: Node = stage._spawn_enemy(enemy_kind, Vector3.ZERO)
		enemy.set_physics_process(false)
		player.global_position = Vector3(0, 0.08, -1.0)
		for attack in range(3):
			enemy._begin_attack(Vector3.FORWARD)
			enemy.mode = "attack"
			enemy.attack_clock = 0
			enemy.attack_step = 0
			for tick in range(18):
				if enemy.mode == "attack": enemy._process_attack(0.1)
			check(not enemy.is_attacking, "%s attack %d terminates and releases attack slot" % [enemy_kind, attack + 1])
		enemy.queue_free()
		stage.active_enemies.erase(enemy)
		stage._clear_projectiles()
		await process_frame
	check(player.hit_calls > 10, "Enemy attack callbacks actually reach player damage interface")
	stage.queue_free()
	player.queue_free()
	await process_frame
	var result := {"scope": "stage subsystem API and lifecycle tests; not a human gameplay completion", "engine": Engine.get_version_info().string, "checks": checks.size(), "failures": failures, "passed": failures.is_empty(), "labels": checks}
	var file := FileAccess.open("res://evidence/stage_subsystem_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
