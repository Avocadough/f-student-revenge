extends Node3D
class_name CampusProp

const ProjectileScript = preload("res://Scripts/projectile.gd")
static var _model_scenes: Dictionary = {}

var available := true
var prop_kind := "chair"
var target: Node3D
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var flying := false
var flight_time := 0.0
var model: Node3D
var prompt: Label3D
var player: Node3D
var stage: Node
var prompt_timer := 0.0
var obstacle_query := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	add_to_group("campus_props")
	var path := "res://Assets/Models/%s.glb" % prop_kind
	if ResourceLoader.exists(path):
		if not _model_scenes.has(path):
			_model_scenes[path] = load(path) as PackedScene
		var packed: PackedScene = _model_scenes[path]
		if packed != null:
			model = packed.instantiate() as Node3D
	if model == null:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.48, 0.85, 0.48)
		mesh.mesh = box
		mesh.position.y = 0.43
		model = mesh
	add_child(model)
	model.scale = Vector3.ONE * 0.9
	prompt = Label3D.new()
	prompt.text = "E  •  THROW"
	prompt.position.y = 1.3
	prompt.pixel_size = 0.003
	prompt.font_size = 32
	prompt.modulate = Color(1, 0.8, 0.3)
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.outline_size = 8
	prompt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(prompt)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	obstacle_query.collision_mask = 1

func throw_at(aim: Node3D, direction: Vector3) -> void:
	if not available:
		return
	available = false
	flying = true
	prompt.visible = false
	target = aim
	origin = global_position
	destination = origin + direction.normalized() * 9.0 + Vector3.UP * 0.6
	if is_instance_valid(aim):
		destination = aim.global_position + Vector3.UP * 0.85

func _physics_process(delta: float) -> void:
	if not flying:
		prompt_timer -= delta
		if prompt_timer > 0:
			return
		prompt_timer = 0.12
		prompt.visible = available and is_instance_valid(player) and player.global_position.distance_to(global_position) < 3.2
		return
	var prior := global_position
	flight_time += delta
	var ratio := minf(flight_time / 0.42, 1.0)
	var next := origin.lerp(destination, ratio) + Vector3.UP * sin(ratio * PI) * 1.4
	obstacle_query.from = prior
	obstacle_query.to = next
	var obstacle := get_world_3d().direct_space_state.intersect_ray(obstacle_query)
	var obstacle_fraction: float = INF if obstacle.is_empty() else prior.distance_to(obstacle.position) / maxf(prior.distance_to(next), 0.0001)
	var candidates: Array = stage.active_enemies if is_instance_valid(stage) else [target]
	var struck: Node3D
	var earliest := obstacle_fraction
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var fraction: float = ProjectileScript.segment_hit_fraction(prior, next, candidate.global_position + Vector3.UP * 0.85, 0.75)
		if fraction <= 1.0 and fraction < earliest:
			earliest = fraction
			struck = candidate
	if struck != null:
		struck.take_hit(24.0, 42.0, origin, 2.8, true)
		flying = false
		queue_free()
		return
	if not obstacle.is_empty():
		flying = false
		queue_free()
		return
	global_position = next
	model.rotate_x(delta * 10)
	model.rotate_z(delta * 5)
	if ratio >= 1.0:
		flying = false
		queue_free()
