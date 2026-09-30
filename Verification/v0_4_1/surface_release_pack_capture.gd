extends SceneTree
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    seed(410844)
    var game = load("res://Scenes/main.tscn").instantiate()
    game.set_meta("qa_no_save", true)
    root.add_child(game)
    game.settings.quality = 1
    game.start_level(1, 1)
    game.set_process_unhandled_key_input(false)
    game.player.camera_rig.set_process_input(false)
    game.player.camera_rig.set_process_unhandled_input(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    for frame in range(150): await physics_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    var saved := image.save_png("C:/Users/Admin/Desktop/การล้างแค้นของนักศึกษาติด F/evidence/surface_release_pack_stage2.png")
    var record := {"pack": {"pack": "C:\\Users\\Admin\\Desktop\\การล้างแค้นของนักศึกษาติด F\\docs\\index.pck", "bytes": 20801464, "sha256": "70ae587d04a708e1c030d631c593a3a00e445330b46f6793fefe15961872a823", "external_directory": "C:\\Users\\Admin\\AppData\\Local\\Temp\\FStudentSurfacePackQA_20261001_050627", "source": "Actual shipping Web PCK mounted using --main-pack from an otherwise empty external directory; no copied project or resources"}, "engine": Engine.get_version_info().string, "renderer": "Native GL Compatibility", "gpu": RenderingServer.get_video_adapter_name(), "quality": game.settings.quality, "viewport_image": str(image.get_size()), "physical_texture": str(root.get_texture().get_size()), "render_scale": root.scaling_3d_scale, "msaa": root.msaa_3d, "stage": game.stage_index, "room": game.checkpoint_index, "alive_enemies": game.level._alive_count(), "save_error": saved, "scope": "Deterministic native screenshot from actual shipping PCK: seed410844, fixed60Hz150ticks, stage2room2 standard, camera mouse input disabled only for screenshot fixture. Not Web/browser/FPS evidence."}
    var output := FileAccess.open("C:/Users/Admin/Desktop/การล้างแค้นของนักศึกษาติด F/evidence/surface_release_pack_capture.json", FileAccess.WRITE)
    output.store_string(JSON.stringify(record, "\t"))
    print("SURFACE_RELEASE_CAPTURE ", JSON.stringify(record))
    _stop_audio(game)
    game._show_main_menu()
    game.queue_free()
    for frame in range(12): await process_frame
    quit(0 if saved == OK else 1)
func _stop_audio(node: Node) -> void:
    if node is AudioStreamPlayer: node.stop()
    for child in node.get_children(): _stop_audio(child)
