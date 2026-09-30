extends SceneTree

# Bounded synthetic fixtures for authored events. Full normal-input traversal is separate.
const GameScene = preload("res://Scenes/main.tscn")
const Campaign = preload("res://Scripts/campaign_data.gd")
var game: Node
var checks: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks.append({"pass": value, "description": description})
	if not value:
		failures.append(description)
		push_error(description)

func fixture(stage_index: int = 0, checkpoint: int = 2) -> Node:
	game.start_level(stage_index, checkpoint)
	var level: Node = game.level
	level.set_physics_process(false)
	game.player.set_physics_process(false)
	level.pending_enemies.clear()
	game.player.global_position = level.to_global(level.room_centers[checkpoint])
	game.player.reset_physics_interpolation()
	if stage_index == 0 and checkpoint == 2:
		var enemy: Node = level._spawn_enemy("programming", level.room_centers[checkpoint] + Vector3.RIGHT)
		enemy.set_physics_process(false)
	return level

func complete_objective(level: Node) -> bool:
	# Synthetic combat clear isolates E/dialogue lifecycle; no claim of combat skill.
	level.combat_cleared = true
	game.player.global_position = level.objective_node.global_position + Vector3.BACK
	return level.interact_objective(game.player)

func resume_button() -> bool:
	for node in game.modal_stack.get_children():
		if node is Button and "เล่นต่อ" in node.text:
			node.pressed.emit()
			return true
	return false

func has_modal_text(text: String) -> bool:
	for node in game.modal_stack.get_children():
		if node is Label and node.text == text: return true
	return false

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): stop_audio(child)

func run() -> void:
	game = GameScene.instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await process_frame
	var level: Node = fixture()
	var enemy: Node = level.get_boss()
	var enemy_hp: float = enemy.health
	check(level._begin_stamp_warning(), "First boss starts one visible stamp warning")
	check(level._stamp_warning_time >= 1.0 and level._stamp_warning_time == 1.2, "Stamp grants the full 1.2 second warning")
	check(not level._begin_stamp_warning(), "A second stamp cannot overlap the first")
	var locked_target: Vector3 = level._stamp_target
	level._tick_stamp_hazard(1.19)
	check(game.player.health == 100.0 and enemy.health == enemy_hp, "Warning never damages player or demon before its deadline")
	level._tick_stamp_hazard(0.02)
	check(game.player.health == 86.0 and enemy.health == enemy_hp - 28.0, "Stamp hits both stationary player and demon at impact")
	check(enemy.posture == 32.0, "Stamp uses bounded posture damage through the existing combat interface")
	level._resolve_stamp_impact()
	check(game.player.health == 86.0 and enemy.health == enemy_hp - 28.0, "Repeated impact dispatch cannot deal damage twice")
	level._tick_stamp_hazard(0.3)
	check(not is_instance_valid(level._stamp_visual), "Impact visual frees after its brief hold")
	level._tick_stamp_hazard(6.48)
	check(not is_instance_valid(level._stamp_visual), "Stamp cannot restart before the eight second cooldown")
	level._tick_stamp_hazard(0.02)
	check(is_instance_valid(level._stamp_visual), "Stamp restarts once the full cooldown expires")

	level = fixture()
	enemy = level.get_boss()
	enemy_hp = enemy.health
	level._begin_stamp_warning()
	locked_target = level._stamp_target
	game.player.global_position += Vector3.RIGHT * 3.0
	level._tick_stamp_hazard(1.21)
	check(level._stamp_target == locked_target, "Warning target remains fixed when the player moves")
	check(game.player.health == 100.0 and enemy.health == enemy_hp - 28.0, "Moving clear safely baits the stamp onto a demon")

	level = fixture()
	level._begin_stamp_warning()
	level._tick_stamp_hazard(1.1)
	game.player.request_dodge()
	level._tick_stamp_hazard(0.11)
	check(game.player.dodge_count == 1 and game.player.health == 100.0, "Real dodge invulnerability avoids a stamp at impact")

	level = fixture()
	level._begin_stamp_warning()
	paused = true
	check(not is_instance_valid(level._stamp_visual) and level._stamp_warning_time == 0.0, "Tree pause immediately cancels an armed stamp")
	paused = false
	check(level._stamp_cooldown == 8.0 and not is_instance_valid(level._stamp_visual), "Resuming cannot deliver a stale delayed impact")
	level._begin_stamp_warning()
	game.player.active = false
	level._tick_stamp_hazard(2.0)
	check(not is_instance_valid(level._stamp_visual) and game.player.health == 100.0, "Inactive player cancels the hazard without damage")
	game.player.active = true
	level._begin_stamp_warning()
	game.player.dead = true
	level._tick_stamp_hazard(2.0)
	check(not is_instance_valid(level._stamp_visual), "Dead player cannot retain or start an armed stamp")
	game.player.dead = false
	level._begin_stamp_warning()
	game.modal.show()
	level._tick_stamp_hazard(2.0)
	check(not is_instance_valid(level._stamp_visual) and game.player.health == 100.0, "A visible modal cancels hazard even without tree pause")
	game.modal.hide()
	level._begin_stamp_warning()
	level.restart_encounter()
	check(not is_instance_valid(level._stamp_visual) and level._stamp_cooldown == 8.0, "Restart removes the old hazard and restores its whole cooldown")
	level.pending_enemies.clear()
	enemy = level._spawn_enemy("programming", level.room_centers[2] + Vector3.RIGHT)
	enemy.set_physics_process(false)
	level._begin_stamp_warning()
	enemy.take_hit(9999.0, 9999.0, game.player.global_position, 0.0, true)
	check(level.combat_cleared and not is_instance_valid(level._stamp_visual), "Killing the last demon clears an armed stamp before objective work")

	for pair in [[0, 0], [1, 2], [2, 2]]:
		level = fixture(pair[0], pair[1])
		check(not level._begin_stamp_warning(), "Stamp stays out of stage %d checkpoint %d" % [pair[0] + 1, pair[1] + 1])

	for stage_index in range(3):
		for checkpoint in range(2):
			level = fixture(stage_index, checkpoint)
			check(complete_objective(level), "Stage %d room %d accepts nearby E after clear" % [stage_index + 1, checkpoint + 1])
			var payoff: Dictionary = Campaign.OBJECTIVE_PAYOFFS[stage_index][checkpoint]
			check(game.story_beat_open and game.paused and paused and has_modal_text(str(payoff.title)), "Stage %d room %d shows its authored safe payoff" % [stage_index + 1, checkpoint + 1])
			check(level.room_clear[checkpoint] and level.objective_completed and not level.interact_objective(game.player), "Story objective is already complete and duplicate E is harmless")
			check(resume_button() and not game.story_beat_open and not game.paused and not paused, "Continue resumes immediately without another confirmation")

	level = fixture()
	check(complete_objective(level) and not game.story_beat_open and not paused, "First boss objective does not stack a story modal over stage completion")
	level = fixture(2, 2)
	check(complete_objective(level) and not game.story_beat_open and not game.running and paused, "Final stamp goes straight to the earned-grade ending once")
	check(not level.interact_objective(game.player), "Final ending rejects repeated objective interaction")

	level = fixture()
	level._begin_stamp_warning()
	var hazard_ref: WeakRef = weakref(level._stamp_visual)
	game._show_main_menu()
	await process_frame
	await process_frame
	check(hazard_ref.get_ref() == null, "Returning to menu destroys the hazard with its stage")
	stop_audio(game)
	OS.delay_msec(120)
	game.queue_free()
	paused = false
	for tick in range(3): await process_frame
	DirAccess.make_dir_recursive_absolute("res://evidence/v05")
	var source_hashes := {}
	for path in ["Scripts/campus_stage.gd", "Scripts/school_enemy.gd", "Scripts/campaign_data.gd", "Scripts/game.gd", "tools/test_registry_story.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	var result := {"engine": Engine.get_version_info().string, "scope": "Synthetic authored-event regressions, not browser, FPS or a human fun assessment", "fixture_disclosure": "Fresh levels, disabled player/enemy/stage physics for deterministic clock tests, direct position setup, synthetic combat clears for E lifecycle. Real hit/dodge/E/modal code is used. User saves untouched. Full ordinary-input traversal is separate.", "checks": checks, "failures": failures, "passed": failures.is_empty(), "source_sha256": source_hashes}
	var file := FileAccess.open("res://evidence/v05/registry_story_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("REGISTRY_STORY_RESULT ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
