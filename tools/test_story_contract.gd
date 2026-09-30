extends SceneTree
## Bounded story data, real v2 save load/write, and one real E-payoff UI lifecycle.
## Encounter completion is arranged by this fixture; it is not a combat playthrough.

const Campaign = preload("res://Scripts/campaign_data.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var game: Node
var original_user_dir := ""
var fixture_user_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"case": label, "passed": value})
	if not value:
		failures.append(label)
		print("STORY_CONTRACT_FAIL ", label)

func settle() -> void:
	for index in range(3): await process_frame

func _run() -> void:
	check(Campaign.VERSION == 2 and Campaign.STORY_ID == "registry_midnight_v3" and Campaign.NARRATIVE_REVISION == 3, "Narrative identity stays independent of save schema v2")
	for entry: Array in [["stages", Campaign.STAGE_NAMES], ["teachers", Campaign.TEACHER_NAMES], ["bosses", Campaign.BOSS_NAMES], ["support", Campaign.SUPPORT_NAMES], ["briefs", Campaign.STAGE_BRIEFS], ["trophies", Campaign.STAGE_TROPHIES], ["support quips", Campaign.SUPPORT_QUIPS], ["boss quotes", Campaign.BOSS_QUOTES]]:
		var valid: bool = entry[1].size() == 3
		for value in entry[1]: valid = valid and value is String and not value.strip_edges().is_empty()
		check(valid, "Three nonempty " + str(entry[0]))
	for entry: Array in [["rooms", Campaign.ROOM_TITLES], ["objectives", Campaign.OBJECTIVE_TITLES], ["openings", Campaign.ROOM_OPENING_LINES], ["encounters", Campaign.ENCOUNTERS], ["payoffs", Campaign.OBJECTIVE_PAYOFFS]]:
		var valid: bool = entry[1].size() == 3
		for row in entry[1]: valid = valid and row is Array and row.size() == 3
		check(valid, "Three-by-three " + str(entry[0]) + " preserve checkpoint indexing")
	for stage in range(3):
		for room in range(3):
			var beat: Dictionary = Campaign.OBJECTIVE_PAYOFFS[stage][room]
			check(beat.get("title") is String and not str(beat.title).is_empty() and beat.get("body") is String and not str(beat.body).is_empty(), "Stage%d room%d supplies a complete readable payoff" % [stage, room])
	check(Campaign.STAGE_ENDINGS.size() == 2 and "F → D" in Campaign.ENDING_TEXT and "เดินมาเรียนด้วย" in Campaign.ENDING_TEXT and "กรุณาประเมินความพึงพอใจ" in Campaign.ENDING_TEXT, "Two stage transitions lead to the authored grade and post-credits payoff")

	original_user_dir = ProjectSettings.globalize_path("user://")
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "FStudentRevenge_QA_Story_" + str(OS.get_process_id()))
	fixture_user_dir = ProjectSettings.globalize_path("user://")
	assert(fixture_user_dir != original_user_dir and "QA_Story_" in fixture_user_dir)
	DirAccess.make_dir_recursive_absolute(fixture_user_dir)
	var old_v2 := JSON.stringify({"version": 2, "progress": {"stage": 1, "checkpoint": 1, "complete": false}, "settings": {"volume": 0.4, "sfx": 0.2, "sensitivity": 0.7, "quality": 0, "shake": false, "god_mode": false}})
	var file := FileAccess.open("user://progress_v2.json", FileAccess.WRITE)
	file.store_string(old_v2)
	file.close()
	game = load("res://Scripts/game.gd").new()
	root.add_child(game)
	await settle()
	check(game.story_revision_changed and not game.legacy_progress_found and game.save_data.stage == 1 and game.save_data.checkpoint == 1, "Old v2 without story_id retains progress and advertises the new story")
	check(is_equal_approx(game.settings.volume, 0.4) and is_equal_approx(game.settings.sfx, 0.2) and is_equal_approx(game.settings.sensitivity, 0.7) and game.settings.quality == 0 and not game.settings.shake, "Old v2 settings survive the narrative revision")
	check(FileAccess.get_file_as_string("user://progress_v2.json") == old_v2, "Loading the old v2 file is read-only")
	game._continue_game()
	game.level.set_physics_process(false)
	game.player.set_physics_process(false)
	game.level.pending_enemies.clear()
	game.level.combat_cleared = true
	game.player.global_position = game.level.objective_node.global_position + Vector3.BACK
	game.player.reset_physics_interpolation()
	await physics_frame
	var updated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://progress_v2.json"))
	check(game.stage_index == 1 and game.checkpoint_index == 1 and updated.version == 2 and updated.story_id == Campaign.STORY_ID and updated.progress.stage == 1 and updated.progress.checkpoint == 1, "Continue reconstructs the same checkpoint and upgrades only narrative metadata")
	check(game.level.interact_objective(game.player), "Actual nearby E objective opens the room payoff after an arranged clear")
	await settle()
	check(game.story_beat_open and game.running and game.paused and paused and game.modal.visible, "Story beat pauses the active run with a visible modal")
	check(game.level.objective_completed and game.level.room_clear[1], "Opening the payoff does not undo the completed objective")
	var expected: Dictionary = Campaign.OBJECTIVE_PAYOFFS[1][1]
	check(game.modal_stack.get_child(0).text == expected.title and game.modal_stack.get_child(1).text == expected.body, "The E interaction displays this exact checkpoint's authored payoff")
	var focus := root.gui_get_focus_owner()
	check(is_instance_valid(focus) and game.modal.is_ancestor_of(focus) and focus.is_visible_in_tree(), "Keyboard focus settles inside the story modal")
	game.show_story_beat("duplicate", "must not replace the open beat")
	check(game.modal_stack.get_child(0).text == expected.title, "Duplicate story notifications cannot replace an open beat")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_key_input(event)
	await settle()
	check(game.running and not game.paused and not paused and not game.story_beat_open and not game.modal.visible, "Escape skips the payoff and resumes the same run")
	check(not game.level.interact_objective(game.player), "Repeated E cannot replay the already-completed room payoff")
	game.show_story_beat("menu lifecycle", "fixture")
	game._show_main_menu()
	await settle()
	check(not game.running and not game.paused and not paused and not game.story_beat_open and not game.modal.visible and game.main_menu.visible and game.level == null and game.player == null, "Returning to menu clears story state and old gameplay nodes")
	game.start_level(0, 0)
	game.level.set_physics_process(false)
	game.player.set_physics_process(false)
	await settle()
	check(game.running and not game.paused and not paused and not game.story_beat_open and not game.modal.visible, "Starting again cannot inherit a stale story overlay or pause")
	game.show_story_beat("button lifecycle", "fixture")
	await settle()
	var resume_button := game.modal_stack.get_child(2) as Button
	check(resume_button != null and "เล่นต่อ" in resume_button.text, "Story beat exposes a continue button")
	if resume_button: resume_button.pressed.emit()
	await settle()
	check(game.running and not game.paused and not paused and not game.story_beat_open and not game.modal.visible, "Continue button also resumes and clears the story flag")
	game._show_main_menu()
	var result := {"scope": "Synthetic 3x3 story contract, isolated real old-v2 persistence, and one real E-payoff/modal lifecycle. Arranged combat clear; not a full playthrough or visual audit.", "engine": Engine.get_version_info().string, "story_id": Campaign.STORY_ID, "checks": checks, "failures": failures, "passed": failures.is_empty(), "fixture_user_dir": fixture_user_dir, "original_user_dir_untouched": fixture_user_dir != original_user_dir, "source_hashes": {"campaign_data.gd": FileAccess.get_sha256("res://Scripts/campaign_data.gd"), "game.gd": FileAccess.get_sha256("res://Scripts/game.gd"), "campus_stage.gd": FileAccess.get_sha256("res://Scripts/campus_stage.gd")}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/v05"))
	var output := FileAccess.open("res://evidence/v05/story_contract_checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("STORY_CONTRACT ", JSON.stringify({"checks": checks.size(), "failures": failures, "passed": failures.is_empty()}))
	game.queue_free()
	await settle()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
