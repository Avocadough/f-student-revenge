extends SceneTree
## Checks imported resources and instantiated materials, not visual appearance or FPS.

const Stage = preload("res://Scripts/campus_stage.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var textures: Array[Dictionary] = []
var materials: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"case": label, "passed": value})
	if not value: failures.append(label)

func _run() -> void:
	check(int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level")) == 2, "Anisotropic filtering is bounded at 4x")
	for stem in ["concrete_floor", "painted_plaster_wall"]:
		for suffix in ["diff", "normal", "rough"]:
			var path := "res://Assets/Textures/%s_%s.jpg" % [stem, suffix]
			var texture := load(path) as Texture2D
			var pixels := texture.get_image() if texture else null
			check(pixels != null and not pixels.is_empty() and pixels.has_mipmaps() and pixels.get_mipmap_count() > 0, "%s has actual imported mip levels" % path.get_file())
			if pixels:
				textures.append({"path": path, "source_sha256": FileAccess.get_sha256(path), "size": str(texture.get_size()), "has_mipmaps": pixels.has_mipmaps(), "mipmap_count": pixels.get_mipmap_count(), "image_bytes": pixels.get_data_size(), "image_format": pixels.get_format()})
			if suffix == "normal":
				var config := ConfigFile.new()
				var loaded := config.load(path + ".import") == OK
				check(loaded and int(config.get_value("params", "compress/normal_map", 0)) == 1, "%s explicitly renormalizes normal-map mip levels" % path.get_file())
	var stage := Stage.new()
	stage.stage_index = 1
	root.add_child(stage)
	await process_frame
	for quality in [0, 1]:
		stage.apply_render_quality(quality)
		for key in ["floor", "wall", "concrete"]:
			var material: StandardMaterial3D = stage.materials[key]
			var maps_ready := true
			for texture: Texture2D in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
				maps_ready = maps_ready and texture != null and texture.get_image().has_mipmaps()
			check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC and maps_ready, "Quality%d %s material samples mipmapped textures with anisotropic filtering" % [quality, key])
			materials.append({"quality": quality, "material": key, "filter": material.texture_filter, "normal_enabled": material.normal_enabled, "normal_scale": material.normal_scale, "uv_scale": str(material.uv1_scale)})
	var result := {"scope": "Godot imported texture mip levels and actual stage materials at both quality profiles. This does not establish visual improvement, Web compatibility or FPS.", "engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "passed": failures.is_empty(), "textures": textures, "materials": materials}
	var output := FileAccess.open("res://evidence/surface_filtering_checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("SURFACE_FILTERING ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
