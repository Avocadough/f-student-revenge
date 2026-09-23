extends Node3D
class_name CampusProp

var available := true
var prop_kind := "chair"
var target: Node3D
var origin := Vector3.ZERO
var destination := Vector3.ZERO
var flying := false
var flight_time := 0.0
var model: Node3D
var prompt: Label3D

func _ready() -> void:
	add_to_group("campus_props")
	var path := "res://Assets/Models/%s.glb" % prop_kind
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
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
	add_child(prompt)

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

func _process(delta: float) -> void:
	if not flying:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		prompt.visible = available and is_instance_valid(player) and player.global_position.distance_to(global_position) < 3.2
		return
	flight_time += delta
	var ratio := minf(flight_time / 0.42, 1.0)
	global_position = origin.lerp(destination, ratio) + Vector3.UP * sin(ratio * PI) * 1.4
	model.rotate_x(delta * 10)
	model.rotate_z(delta * 5)
	if ratio >= 1.0:
		if is_instance_valid(target) and target.has_method("take_hit"):
			target.take_hit(24.0, 42.0, origin, 2.8, true)
		flying = false
		queue_free()
