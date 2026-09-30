extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await process_frame
	game.start_level(0, 0)
	for frame in range(8): await process_frame
	game.level.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.process_mode = Node.PROCESS_MODE_DISABLED
	game.paused = true
	game.toast_timer = 0
	game.toast.hide()
	var origin: Vector3 = game.player.global_position
	var count := 0
	while game.level.active_enemies.size() < 2: game.level._spawn_enemy("demon_imp")
	for enemy in game.level.active_enemies:
		if count >= 2: enemy.hide(); continue
		enemy.global_position = origin + Vector3(-0.65 if count == 0 else 0.65, 0, -1.8)
		enemy.reset_physics_interpolation()
		enemy._begin_attack((origin - enemy.global_position).normalized())
		count += 1
	game._update_hud()
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/v05/melee_captions.png")
	print("MELEE_CAPTION_CAPTURE count=", count, " source=", FileAccess.get_sha256("res://Scripts/school_enemy.gd"))
	AudioServer.set_bus_mute(0, true)
	game._show_main_menu()
	await process_frame
	quit()
