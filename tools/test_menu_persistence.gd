extends SceneTree
## Bounded regression fixtures. Uses an isolated engine user directory, never a real save.

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var game: Node
var original_user_dir := ""
var fixture_user_dir := ""
const DEFAULT_SETTINGS := {"volume": 0.75, "sfx": 0.8, "sensitivity": 1.0, "shake": true, "quality": 1, "god_mode": false}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func press_modal(fragment: String) -> bool:
	for child in game.modal_stack.get_children():
		if child is Button and fragment in child.text:
			child.pressed.emit()
			return true
	return false

func press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_key_input(event)

func load_fixture(raw: String) -> void:
	assert(ProjectSettings.globalize_path("user://") == fixture_user_dir)
	game.settings = DEFAULT_SETTINGS.duplicate(true)
	game.save_data = {}
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(raw)
	file.close()
	game._load_save()
	game._apply_settings()

func run() -> void:
	original_user_dir = ProjectSettings.globalize_path("user://")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "FStudentRevenge_QA_Menu_" + str(OS.get_process_id()))
	fixture_user_dir = ProjectSettings.globalize_path("user://")
	assert(fixture_user_dir != original_user_dir and "FStudentRevenge_QA_Menu_" in fixture_user_dir, "Could not isolate the QA save directory")
	DirAccess.make_dir_recursive_absolute(fixture_user_dir)
	game = load("res://Scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	check(game.main_menu.visible and not paused, "Starts on menu")
	game._show_intro()
	press_escape()
	check(game.main_menu.visible and not game.modal.visible and not paused, "Escape from intro restores menu")
	game._show_help()
	press_escape()
	check(game.main_menu.visible and not game.modal.visible, "Escape from help restores menu")
	game.start_level(0, 2)
	game._on_stage_completed()
	check(game.save_data.get("stage") == 1 and game.save_data.get("checkpoint") == 0, "Stage completion records next stage checkpoint")
	press_escape()
	check(game.main_menu.visible and not game.running and not paused, "Escape from stage clear restores unpaused menu")
	game._continue_game()
	check(game.stage_index == 1 and game.checkpoint_index == 0, "Continue after stage clear enters next stage")
	game._show_pause()
	press_escape()
	check(game.running and not game.paused and not paused and not game.modal.visible, "Escape resumes normal pause")
	game.player.dead = true
	game._on_defeated()
	await create_timer(1.3).timeout
	press_escape()
	game._resume()
	check(game.modal.visible and game.paused and paused and game.player.dead, "Escape and resume cannot close death retry dialog")
	check(press_modal("กลับไปแก้มือ"), "Death retry button exists")
	check(not game.player.dead and not paused and is_equal_approx(game.player.health,100.0), "Death retry creates healthy playable player")
	game.start_level(2, 2)
	game._on_stage_completed()
	check(game.save_data.get("complete") == true, "Victory records completion")
	press_escape()
	check(game.main_menu.visible and not paused and not game.running, "Escape from victory restores menu")
	game._show_intro()
	check(press_modal("ถึงเวลาเข้าเรียน"), "New game start button exists")
	check(game.stage_index == 0 and game.checkpoint_index == 0 and not game.save_data.get("complete",false), "New game clears old completion")
	game._show_main_menu()
	load_fixture("{invalid json")
	check(game.save_data.is_empty() and game.settings == DEFAULT_SETTINGS, "Broken JSON falls back to defaults")
	load_fixture('[1,2,3]')
	check(game.save_data.is_empty() and game.settings == DEFAULT_SETTINGS, "Wrong root schema falls back to defaults")
	load_fixture('{"version":99,"progress":{"stage":2,"checkpoint":2},"settings":{"volume":0}}')
	check(game.save_data.is_empty() and game.settings == DEFAULT_SETTINGS, "Unknown save version ignored")
	load_fixture('{"version":1,"progress":"bad","settings":42}')
	check(game.save_data.is_empty() and game.settings == DEFAULT_SETTINGS, "Wrong progress and settings types ignored")
	load_fixture('{"version":1,"progress":{"stage":"2","checkpoint":null},"settings":{"volume":"loud","sfx":[],"sensitivity":false,"quality":{},"shake":1}}')
	check(game.save_data.is_empty() and game.settings == DEFAULT_SETTINGS, "Invalid individual field types ignored")
	load_fixture('{"version":1,"progress":{"stage":99,"checkpoint":-1,"complete":true},"settings":{"volume":-10,"sfx":22,"sensitivity":50,"quality":99,"shake":false}}')
	check(game.save_data == {"stage":2,"checkpoint":0,"complete":true}, "Progress bounds clamped")
	check(game.settings == {"volume":0.0,"sfx":1.0,"sensitivity":2.0,"quality":1.0,"shake":false,"god_mode":false}, "Settings bounds clamped")
	load_fixture('{"version":1,"progress":{"stage":1,"checkpoint":2,"complete":false},"settings":{"volume":0.4,"sfx":0.2,"sensitivity":0.7,"quality":0,"shake":false}}')
	check(game.save_data == {"stage":1,"checkpoint":2,"complete":false}, "Valid progress retained")
	check(is_equal_approx(game.settings.volume,0.4) and is_equal_approx(game.settings.sfx,0.2) and is_equal_approx(game.settings.sensitivity,0.7) and game.settings.quality == 0 and game.settings.shake == false, "Valid settings retained")
	game._write_save()
	game.save_data = {}
	game.settings = DEFAULT_SETTINGS.duplicate(true)
	game._load_save()
	check(game.save_data.get("stage") == 1 and game.save_data.get("checkpoint") == 2 and is_equal_approx(game.settings.sfx,0.2), "Valid save write/read round trip")
	check(game.main_menu.visible and not paused, "Malformed fixtures leave menu usable")
	var result := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"test_scope":"Synthetic menu callbacks and isolated real persistence fixtures; no player save modified","fixture_user_dir":fixture_user_dir,"original_user_dir_untouched":original_user_dir != fixture_user_dir}
	var out := FileAccess.open("res://evidence/menu_persistence_checks.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify({"passed":failures.is_empty(),"checks":checks.size(),"failures":failures,"isolated_save":fixture_user_dir}))
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if failures.is_empty() else 1)
