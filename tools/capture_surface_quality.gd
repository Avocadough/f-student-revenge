extends SceneTree
## Deterministic rendered stills, not a combat or performance benchmark.
## Usage: --script res://tools/capture_surface_quality.gd -- before (or after).
## Physics/AI and animation are held; portal TIME is fixed only in this fixture.

const SAMPLES := [[0, 0], [1, 1], [2, 2]]
var game: Node
var camera: Camera3D
var images: Array[Dictionary] = []
var tag := "capture"
var output_dir := "res://evidence/surface_quality"
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func settle(count: int = 5) -> void:
	for frame in range(count): await process_frame

func freeze_visuals(node: Node) -> void:
	if node is AnimationPlayer:
		if not node.current_animation.is_empty(): node.seek(0.25, true)
		node.pause()
	if node is GeometryInstance3D:
		var material = node.get("material_override")
		if material is ShaderMaterial and material.shader and "TIME" in material.shader.code:
			var fixed: ShaderMaterial = material.duplicate(true)
			fixed.shader.code = fixed.shader.code.replace("TIME", "1.25")
			node.set("material_override", fixed)
	for child in node.get_children(): freeze_visuals(child)

func surface_info(material: StandardMaterial3D) -> Dictionary:
	var result := {"filter": material.texture_filter, "normal_scale": material.normal_scale, "normal_enabled": material.normal_enabled, "uv_scale": str(material.uv1_scale), "roughness": material.roughness}
	for kind in ["albedo", "normal", "roughness"]:
		var texture: Texture2D = material.get(kind + "_texture")
		if texture:
			var pixels := texture.get_image()
			result[kind] = {"path": texture.resource_path, "size": str(texture.get_size()), "mipmaps": pixels.has_mipmaps() if pixels else false}
	return result

func shot(stage: int, quality: int, detail: bool = false) -> void:
	game.settings.quality = quality
	game._apply_settings()
	AudioServer.set_bus_mute(0, true)
	game.paused = true
	game.modal.hide()
	game.toast.hide()
	game._update_hud()
	var center: Vector3 = game.level.room_centers[game.checkpoint_index]
	# The first courtyard has a solid rear boundary at local z=10.2. Unlike
	# gameplay's SpringArm, this fixed camera must be placed inside it explicitly.
	var entrance_shift := Vector3(0, 0, -2.6) if stage == 0 else Vector3.ZERO
	camera.position = center + entrance_shift + (Vector3(2.0, 0.95, 9.0) if detail else Vector3(0, 2.8, 11.35))
	camera.look_at(center + entrance_shift + (Vector3(2.0, 0.05, 1.5) if detail else Vector3(0, 1.55, 6.0)), Vector3.UP)
	camera.make_current()
	await settle()
	await RenderingServer.frame_post_draw
	var suffix := "standard" if quality == 1 else "low"
	var path := "%s/%s/stage_%d_%s%s.png" % [output_dir, tag, stage + 1, suffix, "_floor" if detail else ""]
	var pixels := root.get_texture().get_image()
	if pixels.save_png(path) != OK: failed = true
	images.append({"path": path, "stage": stage, "checkpoint": game.checkpoint_index, "quality": quality, "detail": detail, "window_pixels": str(root.get_texture().get_size()), "render_scale": root.scaling_3d_scale, "effective_3d_pixels": str(Vector2(root.get_texture().get_size()) * root.scaling_3d_scale), "msaa": root.msaa_3d, "camera_position": str(camera.position), "camera_rotation": str(camera.rotation), "player_position": str(game.player.position), "floor": surface_info(game.level.materials["floor"]), "wall": surface_info(game.level.materials["wall"])})
	print("SURFACE_CAPTURE ", path)

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): stop_audio(child)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): tag = args[0].validate_filename()
	if args.size() > 1: output_dir = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir + "/" + tag))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	Engine.max_fps = 60
	seed(46130)
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.settings.shake = false
	for sample: Array in SAMPLES:
		game.start_level(sample[0], sample[1])
		game.paused = true
		game.level.process_mode = Node.PROCESS_MODE_DISABLED
		game.player.process_mode = Node.PROCESS_MODE_DISABLED
		game.player.active = false
		game.player.velocity = Vector3.ZERO
		game.player.visual.rotation.y = PI
		game.player.global_position = game.level.room_centers[sample[1]] + Vector3(0, 0.03, 3.4 if sample[0] == 0 else 6.0)
		game.player.reset_physics_interpolation()
		var enemies: Array = game.level.pending_enemies.duplicate()
		game.level.pending_enemies.clear()
		for kind in enemies.slice(0, 4): game.level._spawn_enemy(kind)
		freeze_visuals(game.level)
		freeze_visuals(game.player)
		camera = Camera3D.new()
		camera.fov = 66.0
		camera.near = 0.12
		camera.far = 130.0
		game.level.add_child(camera)
		game.elapsed = 0.0
		game.deaths = 0
		game.toast_timer = 0.0
		for quality in [1, 0]: await shot(sample[0], quality)
		if sample[0] == 1:
			for quality in [1, 0]: await shot(sample[0], quality, true)
		game._show_main_menu()
		await settle(3)
	var source_hashes := {}
	for path in ["res://Scripts/campus_environment.gd", "res://Scripts/game.gd", "res://project.godot", "res://tools/capture_surface_quality.gd"]:
		source_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "not included in resource pack"
	for stem in ["concrete_floor", "painted_plaster_wall"]:
		for channel in ["diff", "normal", "rough"]:
			var path := "res://Assets/Textures/%s_%s.jpg.import" % [stem, channel]
			source_hashes[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "not included in resource pack"
	var report := {"tag": tag, "scope": "Rendered native 1280x720 still comparison, same camera and held pose. AI/physics/animations disabled after spawning up to four real enemies; portal TIME fixed to 1.25 in duplicated runtime shader. No assets or production materials edited by fixture; no save I/O. Not gameplay/performance evidence.", "engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "source_hashes": source_hashes, "images": images, "passed": not failed}
	var output := FileAccess.open("%s/%s/capture.json" % [output_dir, tag], FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	stop_audio(game)
	game.queue_free()
	await settle(3)
	print("SURFACE_CAPTURE_DONE ", tag, " images=", images.size())
	quit(1 if failed else 0)
