extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await create_timer(0.8).timeout
	await _capture("menu")
	for stage in range(3):
		game.start_level(stage, 0 if stage < 2 else 2)
		game.player.invulnerability = 100.0
		await create_timer(2.0).timeout
		await _capture("stage_%d" % (stage + 1))
	game._show_main_menu()
	await process_frame
	print("CAPTURE_COMPLETE")
	quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s.png" % filename)
