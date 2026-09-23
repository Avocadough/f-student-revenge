extends SceneTree

const Stage = preload("res://Scripts/campus_stage.gd")
const Projectile = preload("res://Scripts/projectile.gd")
const Prop = preload("res://Scripts/interactable_prop.gd")
var results: Array[Dictionary] = []
var failures: Array[String] = []

class DamageDummy extends Node3D:
	var health := 100.0
	var dead := false
	var hit_calls := 0
	func receive_hit(damage: float, _structure: float, _from: Vector3, _unblockable: bool = false) -> String:
		health -= damage
		hit_calls += 1
		return "hit"
	func take_hit(damage: float, _structure: float, _from: Vector3, _force: float = 0, _heavy: bool = false) -> String:
		health -= damage
		hit_calls += 1
		return "hit"

class FixtureWorld extends Node3D:
	var active_enemies: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	results.append({"passed": value, "case": label})
	if not value:
		failures.append(label)
		push_error(label)

func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func make_wall(parent: Node, at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	return wall

func make_prop(parent: Node, dummy: Node3D) -> Node:
	var prop := Prop.new()
	prop.stage = parent
	parent.add_child(prop)
	prop.set_physics_process(false)
	prop.throw_at(dummy, Vector3.FORWARD)
	return prop

func run() -> void:
	var arena := FixtureWorld.new()
	root.add_child(arena)
	var dummy := DamageDummy.new()
	arena.add_child(dummy)
	arena.active_enemies.append(dummy)
	var wall := make_wall(arena, Vector3(0, 2, -5))
	dummy.position = Vector3(0, 0, -3)
	await ticks(2)
	var bullet := Projectile.new()
	bullet.target = dummy
	bullet.direction = Vector3.FORWARD
	arena.add_child(bullet)
	bullet.global_position = Vector3(0, 0.9, 0)
	bullet.set_physics_process(false)
	bullet._physics_process(1.0)
	check(dummy.hit_calls == 1, "Swept projectile hits player before a wall later on the same frame segment")
	await ticks(1)
	dummy.health = 100
	dummy.hit_calls = 0
	dummy.position.z = -7
	bullet = Projectile.new()
	bullet.target = dummy
	bullet.direction = Vector3.FORWARD
	arena.add_child(bullet)
	bullet.global_position = Vector3(0, 0.9, 0)
	bullet.set_physics_process(false)
	bullet._physics_process(1.0)
	check(dummy.hit_calls == 0, "Swept projectile does not hit a player behind an earlier wall")
	wall.position.x = 100
	dummy.position = Vector3(0, 0, -5)
	await ticks(2)
	var prop := make_prop(arena, dummy)
	dummy.position.x = 8
	for i in range(30): prop._physics_process(1.0 / 60.0)
	check(dummy.hit_calls == 0, "Thrown prop misses a target that moves away from the flight path")
	await ticks(1)
	dummy.position = Vector3(0, 0, -5)
	prop = make_prop(arena, dummy)
	for i in range(30): prop._physics_process(1.0 / 60.0)
	check(dummy.hit_calls == 1 and dummy.health == 76, "Thrown prop hits a stationary target once when its path reaches the target")
	await ticks(1)
	dummy.health = 100
	dummy.hit_calls = 0
	wall.position = Vector3(0, 2, -2.5)
	await ticks(2)
	prop = make_prop(arena, dummy)
	for i in range(30): prop._physics_process(1.0 / 60.0)
	check(dummy.hit_calls == 0, "Solid wall stops thrown prop damage through the wall")
	arena.queue_free()
	await ticks(2)

	var stage := Stage.new()
	root.add_child(stage)
	stage.set_physics_process(false)
	var player := DamageDummy.new()
	player.add_to_group("player")
	root.add_child(player)
	stage.start(player)
	stage.pending_enemies.clear()
	var enemy: Node = stage._spawn_enemy("paper", Vector3(0, 0.08, 0))
	enemy.set_physics_process(false)
	player.position = Vector3(0, 0.08, -1.8)
	var melee_wall := make_wall(stage, Vector3(0, 2, -0.9))
	await ticks(2)
	enemy.attack_direction = Vector3.FORWARD
	enemy._melee_hit(7, 13, 2.15, false)
	check(player.hit_calls == 0, "Enemy melee cannot pass through an environment wall")
	melee_wall.queue_free()
	await ticks(2)
	enemy._melee_hit(7, 13, 2.15, false)
	check(player.hit_calls == 1, "Unobstructed enemy melee still damages the player")
	enemy.take_hit(1, 999, player.global_position, 0, true)
	check(enemy.broken and enemy.telegraph.visible, "Broken enemy displays its finisher ring")
	enemy._physics_process(3.7)
	check(not enemy.broken and not enemy.telegraph.visible, "Expired posture break removes the misleading green finisher ring")
	stage._open_gate(0)
	await ticks(8)
	stage.restart_encounter()
	stage.set_physics_process(false)
	await ticks(70)
	check(is_zero_approx(stage.gates[0].position.y) and not stage.gate_colliders[0].disabled, "Restart cancels an in-progress gate-opening tween and keeps the gate shut")
	check(stage.static_instance_count > stage.static_batch_count * 4, "Static room architecture and furniture are materially batched")
	check(stage._visual_regions[0].visible and stage._visual_regions[1].visible and not stage._visual_regions[2].visible, "Only current and adjacent room visuals are enabled")
	var stat := {"source_instances": stage.static_instance_count, "static_batches": stage.static_batch_count}
	stage.queue_free()
	player.queue_free()
	await ticks(3)
	var report := {"scope": "Synthetic collision, lifecycle and static batching regressions; not an exhaustive bug guarantee or browser performance benchmark", "engine": Engine.get_version_info().string, "passed": failures.is_empty(), "checks": results, "failures": failures, "batching": stat}
	var out := FileAccess.open("res://evidence/stage_collision_checks.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t"))
	print("STAGE_COLLISION_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
