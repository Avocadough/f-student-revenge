extends Node3D

static func burst(parent: Node, point: Vector3, color: Color, large: bool = false) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = point
	for i in range(7 if large else 4):
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.035, 0.035, 0.24 if large else 0.14)
		mesh.mesh = shape
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		mesh.material_override = material
		root.add_child(mesh)
		var direction := Vector3(sin(i * 2.4), cos(i * 1.7), cos(i * 2.4)).normalized()
		mesh.rotation = Vector3(i * 0.7, i * 1.4, i * 0.4)
		var tween := mesh.create_tween().set_parallel(true)
		tween.tween_property(mesh, "position", direction * (0.65 if large else 0.35), 0.2)
		tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.23)
	root.get_tree().create_timer(0.25).timeout.connect(root.queue_free)

static func popup(parent: Node, point: Vector3, text: String, color: Color = Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://Assets/Fonts/NotoSansThai.ttf")
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
