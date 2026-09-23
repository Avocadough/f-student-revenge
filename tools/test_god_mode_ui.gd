extends SceneTree
## UI/save integration only. Combat effects are covered by separate player/enemy tests.

var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var fixture_user_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func read_save() -> Dictionary:
	var file := FileAccess.open("user://progress.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else {}

func write_fixture(god_value: Variant) -> void:
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "progress": {"stage": 1, "checkpoint": 1, "complete": false}, "settings": {"god_mode": god_value}}))
	file.close()

func press_modal(fragment: String) -> bool:
	for child in game.modal_stack.get_children():
		if child is Button and fragment in child.text:
			child.pressed.emit()
			return true
	return false

func _run() -> void:
	var original_user_dir := ProjectSettings.globalize_path("user://")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "FStudentRevenge_QA_GodUI_" + str(OS.get_process_id()))
	fixture_user_dir = ProjectSettings.globalize_path("user://")
	assert(fixture_user_dir != original_user_dir and "FStudentRevenge_QA_GodUI_" in fixture_user_dir)
	DirAccess.make_dir_recursive_absolute(fixture_user_dir)
	game = load("res://Scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.settings.god_mode == false, "God Mode defaults off with no save")
	for value in ["true", 1, null]:
		write_fixture(value)
		game.settings.god_mode = false
		game._load_save()
		check(game.settings.god_mode == false, "Non-boolean God Mode save value ignored: %s" % str(value))
	write_fixture(false)
	game._load_save()
	game._continue_game()
	await process_frame
	var normal_memory: Dictionary = game.save_data.duplicate(true)
	var normal_disk: Dictionary = read_save().progress.duplicate(true)
	check(not game.player.god_mode, "Normal player starts with God Mode disabled")
	game._show_pause()
	game._show_settings()
	var toggle: CheckButton
	for child in game.modal_stack.get_children():
		if child is CheckButton and "God Mode" in child.text: toggle = child
	check(is_instance_valid(toggle), "Settings exposes a clearly named God Mode toggle")
	game.player.health = 35.0
	game.player.posture = 70.0
	game.player.stagger_timer = 0.2
	toggle.button_pressed = true
	check(game.settings.god_mode and game.player.god_mode, "Enabling UI toggle applies God Mode to current player")
	check(game.player.health == 100.0 and game.player.posture == 0.0 and game.player.stagger_timer == 0.0, "Enabling God Mode restores a living player's health and balance")
	check(game.health_label.text == "GOD MODE / อมตะ", "HUD clearly marks active God Mode")
	check(press_modal("บันทึกและกลับ"), "God Mode settings can be saved and return to pause")
	check(game.paused and paused and game.modal.visible, "Saving settings preserves the pause state")
	check(read_save().settings.god_mode == true, "God Mode enabled value persists as a boolean")
	check(game.save_data == normal_memory and read_save().progress == normal_disk, "God Mode toggle does not alter normal progress")
	game._show_main_menu()
	game.settings.god_mode = false
	game._load_save()
	check(game.settings.god_mode == true, "Reload restores the explicitly enabled God Mode setting")
	game._continue_game()
	check(game.player.god_mode and game.health_label.text == "GOD MODE / อมตะ", "Loaded God Mode remains visible on the next player")
	game.settings.god_mode = false
	game._apply_settings()
	game._write_save()
	check(not game.player.god_mode and not read_save().settings.god_mode, "Disabling God Mode restores and persists the normal mode")
	check("GOD MODE" not in game.health_label.text, "Disabled mode removes the active HUD marker")
	game.player.dead = true
	game.player.health = 0.0
	game.settings.god_mode = true
	game._apply_settings()
	check(game.player.dead and game.player.health == 0.0, "Settings do not revive or bypass a dead-player state")
	var out := FileAccess.open("res://evidence/god_mode_ui_checks.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures,
		"scope": "Isolated God Mode UI/save integration fixtures; combat behavior tested separately", "fixture_user_dir": fixture_user_dir, "original_user_dir_untouched": true}, "\t"))
	print(JSON.stringify({"checks": checks.size(), "passed": failures.is_empty(), "failures": failures}))
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)
