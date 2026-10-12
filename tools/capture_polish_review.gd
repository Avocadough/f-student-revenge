extends SceneTree
## Real rendered UI review; fixed framing only, not completion/performance evidence.
var game: Node
var output := "res://evidence/2026-10-12-polish/before"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	_run.call_deferred()

func settle(seconds := 0.5) -> void:
	await create_timer(seconds).timeout

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	print("POLISH_CAPTURE ", label)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await settle()
	await capture("menu")
	game._show_stage_select()
	await settle()
	await capture("stages")
	game.modal.hide()
	game._show_settings()
	await settle()
	await capture("settings")
	game.modal.hide()
	game._show_intro()
	await settle()
	await capture("intro")
	game.start_level(1, 0)
	game.player.god_mode = true
	await settle(2.0)
	game._resume()
	await settle(0.3)
	await capture("combat")
	game._show_pause()
	await settle()
	await capture("pause")
	game._show_main_menu()
	game.queue_free()
	await process_frame
	quit()
