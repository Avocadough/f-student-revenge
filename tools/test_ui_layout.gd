extends SceneTree
## Native UI layout and modal isolation regression; never reads or writes player saves.

var game: Node
var checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	if not ok: print("FAIL: ", label)

func settle() -> void:
	for index in range(4): await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s.png" % filename)

func modal_bounds() -> bool:
	var bounds: Rect2 = game.modal.get_global_rect()
	return bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= game.ui.size.x + 1 and bounds.end.y <= game.ui.size.y + 1

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await create_timer(0.3).timeout
	await settle()
	check(game.continue_button.disabled, "Continue disabled without checkpoint")
	check(game.menu_world.process_mode == Node.PROCESS_MODE_ALWAYS, "Menu decoration animates while visible")
	await capture("ui_menu_1280")
	game._show_help()
	await settle()
	check(game.modal_scrim.visible and game.modal_scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Modal scrim blocks background pointer events")
	check(game.continue_button.focus_mode == Control.FOCUS_NONE, "Modal excludes background keyboard focus")
	check(modal_bounds(), "Help fits 1280x720")
	await capture("ui_help_1280")
	game._show_settings()
	await settle()
	check(root.gui_get_focus_owner() is HSlider, "Settings initially focuses first slider")
	check(modal_bounds(), "Settings fits 1280x720")
	await capture("ui_settings_1280")
	game.settings.volume = 0.0
	game._apply_settings()
	check(AudioServer.is_bus_mute(0), "Volume zero fully mutes master bus")
	game.settings.volume = 0.75
	game._apply_settings()
	check(not AudioServer.is_bus_mute(0), "Positive volume unmutes master bus")
	game.modal.hide()
	check(not game.modal_scrim.visible and game.continue_button.focus_mode == Control.FOCUS_ALL, "Closing modal removes scrim and restores menu focusability")
	game.start_level(0, 0)
	game.player.invulnerability = 100.0
	await create_timer(0.6).timeout
	check(game.menu_world.process_mode == Node.PROCESS_MODE_DISABLED, "Hidden menu animation stops during gameplay")
	game.settings.god_mode = true
	game._apply_settings()
	await settle()
	await capture("ui_god_mode_1280")
	game.settings.god_mode = false
	game._apply_settings()
	game._show_pause()
	await settle()
	check(modal_bounds(), "Pause fits 1280x720")
	await capture("ui_pause_1280")
	game._show_main_menu()
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await settle()
	check(game.main_menu.get_global_rect().end.y <= game.ui.size.y, "Menu panel fits short 960x540 viewport")
	await capture("ui_menu_960")
	game._show_settings()
	await settle()
	check(modal_bounds(), "Settings panel fits short 960x540 viewport")
	check(game.modal_scroll.get_v_scroll_bar().max_value > game.modal_scroll.size.y, "Long settings can scroll in short viewport")
	await capture("ui_settings_960")
	game.modal_stack.get_child(game.modal_stack.get_child_count() - 1).grab_focus()
	await settle()
	check(game.modal_scroll.scroll_vertical > 0, "Keyboard navigation scrolls final action into view")
	await capture("ui_settings_960_bottom")
	game._show_main_menu()
	root.size = Vector2i(800, 720)
	root.content_scale_size = Vector2i(800, 720)
	await settle()
	game._show_help()
	await settle()
	check(modal_bounds(), "Help fits narrower 800x720 viewport")
	await capture("ui_help_800")
	var passed := true
	for item in checks:
		if not item.pass: passed = false
	var out := FileAccess.open("res://evidence/ui_layout_checks.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Native synthetic UI state/layout checks at 1280x720, 960x540, 800x720; no player save touched"}, "\t"))
	print(JSON.stringify({"passed": passed, "checks": checks.size()}))
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if passed else 1)
