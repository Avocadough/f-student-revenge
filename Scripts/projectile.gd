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
var obstacle_query := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	add_to_group("school_projectiles")
	var mesh := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.15
	shape.height = 0.3
	shape.radial_segments = 12
	shape.rings = 6
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.0
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	var trail := MeshInstance3D.new()
	var tail := BoxMesh.new()
	tail.size = Vector3(0.07, 0.07, 0.65)
	trail.mesh = tail
	trail.material_override = material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.position.z = 0.25
	add_child(trail)
	obstacle_query.collision_mask = 1
	if direction.length_squared() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime or not is_instance_valid(target):
		queue_free()
		return
	var prior := global_position
	var next := prior + direction * speed * delta
	obstacle_query.from = prior
	obstacle_query.to = next
	var obstacle := get_world_3d().direct_space_state.intersect_ray(obstacle_query)
	var target_center := target.global_position + Vector3.UP * 0.9
	var segment := next - prior
	var target_fraction := segment_hit_fraction(prior, next, target_center, 0.61)
	var obstacle_fraction: float = INF if obstacle.is_empty() else prior.distance_to(obstacle.position) / maxf(segment.length(), 0.0001)
	if target_fraction <= 1.0 and target_fraction < obstacle_fraction:
		if target.has_method("receive_hit"):
			var outcome: String = target.receive_hit(damage, structure, source_position, false)
			if outcome == "parried" and is_instance_valid(attacker) and not attacker.dead:
				attacker.on_parried()
		queue_free()
	elif not obstacle.is_empty():
		queue_free()
	else:
		global_position = next

static func segment_hit_fraction(start: Vector3, end: Vector3, center: Vector3, radius: float) -> float:
	var step := end - start
	var offset := start - center
	var distance_squared := offset.length_squared() - radius * radius
	if distance_squared <= 0:
		return 0.0
	var magnitude := step.length_squared()
	if magnitude < 0.000001:
		return INF
	var approach := offset.dot(step)
	var discriminant := approach * approach - magnitude * distance_squared
	if discriminant < 0:
		return INF
	var fraction := (-approach - sqrt(discriminant)) / magnitude
	return fraction if fraction >= 0.0 and fraction <= 1.0 else INF
