extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _run() -> void:
	var old_dir := ProjectSettings.globalize_path("user://")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "FStudentRevenge_QA_Migration_" + str(OS.get_process_id()))
	var test_dir := ProjectSettings.globalize_path("user://")
	assert(test_dir != old_dir and "QA_Migration_" in test_dir)
	DirAccess.make_dir_recursive_absolute(test_dir)
	var original := JSON.stringify({"version":1,"progress":{"stage":2,"checkpoint":2,"complete":true},"settings":{"volume":0.4,"sfx":0.3,"god_mode":true,"quality":0}})
	var legacy := FileAccess.open("user://progress.json", FileAccess.WRITE)
	legacy.store_string(original)
	legacy.close()
	var game: Node = load("res://Scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	check(game.legacy_progress_found, "Old campaign detected")
	check(game.save_data.is_empty(), "Old checkpoint cannot skip new plot")
	check(is_equal_approx(game.settings.volume,0.4) and game.settings.god_mode == true and game.settings.quality == 0, "Legacy typed settings preserved")
	game.start_level(1, 1)
	check(FileAccess.file_exists("user://progress_v2.json"), "Active campaign writes separate v2 save")
	check(FileAccess.get_file_as_string("user://progress.json") == original, "Legacy file stays byte-identical")
	game._show_main_menu()
	game.save_data.clear()
	game._load_save()
	check(not game.legacy_progress_found and game.save_data.stage == 1 and game.save_data.checkpoint == 1, "V2 restart restores new campaign checkpoint")
	game._continue_game()
	check(game.player.active and game.level.checkpoint_index == 1 and game.level.get_remaining() > 0, "Checkpoint deterministically reconstructs encounter")
	check(game.level.get_support_status().contains("T"), "Checkpoint reconstructs ally support")
	game._show_main_menu()
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	var result := {"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Isolated on-disk migration and checkpoint reconstruction. Original user directory untouched."}
	var output := FileAccess.open("res://evidence/save_migration_v03.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
