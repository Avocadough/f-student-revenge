extends Node3D

const POOL_SIZE := 12
const FONT = preload("res://Assets/Fonts/NotoSansThai.ttf")

static func prepare(parent: Node) -> Node3D:
	var existing := parent.get_node_or_null("CombatFXPool") as Node3D
	if existing: return existing
	var pool := Node3D.new()
	pool.name = "CombatFXPool"
	pool.process_mode = Node.PROCESS_MODE_PAUSABLE
	pool.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pool.set_meta("next", 0)
	parent.add_child(pool)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.028, 0.028, 0.16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.55, 0.7))
	shrink.add_point(Vector2(1, 0))
	for index in range(POOL_SIZE):
		var particles := CPUParticles3D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 7
		particles.lifetime = 0.24
		particles.explosiveness = 1.0
		particles.mesh = mesh
		particles.direction = Vector3.UP
		particles.spread = 180.0
		particles.gravity = Vector3(0, -1, 0)
		particles.initial_velocity_min = 1.2
		particles.initial_velocity_max = 2.8
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.0
		particles.scale_amount_curve = shrink
		particles.angular_velocity_min = -180.0
		particles.angular_velocity_max = 180.0
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pool.add_child(particles)
	return pool

static func burst(parent: Node, point: Vector3, color: Color, large: bool = false) -> void:
	var pool := prepare(parent)
	var index: int = pool.get_meta("next", 0)
	var particles := pool.get_child(index) as CPUParticles3D
	pool.set_meta("next", (index + 1) % POOL_SIZE)
	particles.global_position = point
	particles.color = color
	particles.initial_velocity_max = 3.0 if large else 1.6
	particles.scale_amount_max = 1.15 if large else 0.8
	particles.restart()

static func popup(parent: Node, point: Vector3, text: String, color: Color = Color.WHITE) -> void:
	var label := Label3D.new()
	# This decoration moves with a render-frame tween, not physics ticks.
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	label.text = text
	label.font = FONT
	label.font_size = 38
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = point
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3.UP * 0.5, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
