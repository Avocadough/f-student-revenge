# Camera rotation / SpringArm approach adapted from Jeh3no CameraHolder (MIT).
# Upstream: 502805705c3a57580a3cc3919ad0dce25328ab22. See ThirdParty.
extends Node3D

var sensitivity: float = 0.0025
var shake_enabled: bool = true
var shake: float = 0.0
var spring: SpringArm3D
var camera: Camera3D
var target: Node3D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 100
	target = get_parent() as Node3D
	position.y = 1.55
	rotation.x = -0.23
	spring = SpringArm3D.new()
	spring.spring_length = 5.5
	spring.margin = 0.25
	spring.collision_mask = 1
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	spring.shape = sphere
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.12
	camera.far = 130.0
	spring.add_child(camera)
	camera.current = true
	set_as_top_level(true)
	snap_to_target()
	# One accumulated mouse event per render frame avoids redundant work on high-Hz mice.
	Input.set_use_accumulated_input(true)

func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * 1.55
		reset_physics_interpolation()

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			rotate_from_vector(event.relative * sensitivity)

func rotate_from_vector(motion: Vector2) -> void:
	rotation.y -= motion.x
	rotation.x = clampf(rotation.x - motion.y, -0.85, 0.22)

func _process(delta: float) -> void:
	if not is_instance_valid(target): return
	var rendered_target := target.get_global_transform_interpolated().origin + Vector3.UP * 1.55
	global_position = global_position.lerp(rendered_target, 1.0 - exp(-18.0 * delta))
	shake = maxf(0.0, shake - delta * 1.2)
	if camera:
		camera.h_offset = sin(Time.get_ticks_msec() * 0.1) * shake * 0.1 if shake_enabled else 0.0
		camera.v_offset = cos(Time.get_ticks_msec() * 0.13) * shake * 0.055 if shake_enabled else 0.0

func recenter(angle: float) -> void:
	rotation.y = angle
	rotation.x = -0.23
