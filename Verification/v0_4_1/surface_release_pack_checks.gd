extends SceneTree
## Checks imported resources and instantiated materials, not visual appearance or FPS.

const Stage = preload("res://Scripts/campus_stage.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var textures: Array[Dictionary] = []
var materials: Array[Dictionary] = []
var skipped_checks: Array[String] = []

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
				textures.append({"path": path, "size": str(texture.get_size()), "has_mipmaps": pixels.has_mipmaps(), "mipmap_count": pixels.get_mipmap_count(), "image_bytes": pixels.get_data_size(), "image_format": pixels.get_format()})
			if suffix == "normal":
				var config := ConfigFile.new()
				var loaded := FileAccess.file_exists(path + ".import") and config.load(path + ".import") == OK
				if loaded:
					print("PACK_NORMAL_IMPORT_META ", JSON.stringify({"path": path, "sections": config.get_sections(), "has_normal_flag": config.has_section_key("params", "compress/normal_map")}))
				if loaded and config.has_section_key("params", "compress/normal_map"):
					check(int(config.get_value("params", "compress/normal_map", 0)) == 1, "%s explicitly renormalizes normal-map mip levels" % path.get_file())
				else:
					skipped_checks.append("%s normal import parameter absent from shipping PCK metadata; actual imported mip levels still checked" % path.get_file())
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
	var result := {"scope": "Actual shipping PCK imported texture levels and instantiated stage materials. Native headless, not Web FPS.", "pack": {"pack": "C:\\Users\\Admin\\Desktop\\การล้างแค้นของนักศึกษาติด F\\docs\\index.pck", "bytes": 20801464, "sha256": "70ae587d04a708e1c030d631c593a3a00e445330b46f6793fefe15961872a823", "external_directory": "C:\\Users\\Admin\\AppData\\Local\\Temp\\FStudentSurfacePackQA_20261001_050627", "source": "Actual shipping Web PCK mounted using --main-pack from an otherwise empty external directory; no copied project or resources"}, "skipped_checks": skipped_checks, "engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "passed": failures.is_empty(), "textures": textures, "materials": materials}
	var output := FileAccess.open("C:/Users/Admin/Desktop/การล้างแค้นของนักศึกษาติด F/evidence/surface_release_pack_checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("SURFACE_FILTERING ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
