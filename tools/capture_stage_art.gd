extends SceneTree

# Visual fixture only: brief invulnerability and pause clearing keep screenshots
# comparable while another native/browser QA window may own foreground focus.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await create_timer(0.4).timeout
	for index in range(3):
		game.start_level(index, 0 if index < 2 else 2)
		game.player.invulnerability = 20.0
		await create_timer(0.8).timeout
		paused = false
		game.paused = false
		game.modal.hide()
		game._update_hud()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/stage_art_%d.png" % (index + 1))
	game._show_main_menu()
	await process_frame
	print("STAGE_ART_CAPTURE_COMPLETE")
	quit()
