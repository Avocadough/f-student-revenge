extends Node3D
class_name SchoolProjectile

var target: Node3D
var attacker: Node
var direction := Vector3.FORWARD
var speed := 8.0
var damage := 8.0
var structure := 14.0
var source_position := Vector3.ZERO
var lifetime := 4.0
var tint := Color(1.0, 0.25, 0.3)
var elapsed := 0.0

func _ready() -> void:
	add_to_group("school_projectiles")
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.15
	shape.height = 0.3
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.0
	mesh.material_override = material
	add_child(mesh)
	var trail := MeshInstance3D.new()
	var tail := BoxMesh.new()
	tail.size = Vector3(0.07, 0.07, 0.65)
	trail.mesh = tail
	trail.material_override = material
	trail.position.z = 0.25
	add_child(trail)
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime or not is_instance_valid(target):
		queue_free()
		return
	var prior := global_position
	var next := prior + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(prior, next, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position = next
	var target_center := target.global_position + Vector3.UP * 0.9
	var segment := next - prior
	var progress: float = clampf((target_center - prior).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
	if target_center.distance_to(prior + segment * progress) < 0.61:
		if target.has_method("receive_hit"):
			var outcome: String = target.receive_hit(damage, structure, source_position, false)
			if outcome == "parried" and is_instance_valid(attacker) and not attacker.dead:
				attacker.on_parried()
		queue_free()
