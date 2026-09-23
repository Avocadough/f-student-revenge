extends SceneTree

# Rendered before/after fixture: identical input route and workload; no fixed-fps.
var game: Node
var route_right := true
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await create_timer(0.5).timeout
	game.start_level(1, 1)
	game.player.invulnerability = 1000.0
	physics_frame.connect(_route)
	await create_timer(2.0).timeout
	var frames: Array[float] = []
	var process_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var stationary_render_steps := 0
	var moving_frames := 0
	var pauses := 0
	var previous_point: Vector3 = _render_point()
	var started := Time.get_ticks_usec()
	var previous := started
	while Time.get_ticks_usec() - started < 12000000:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var point := _render_point()
		if Vector2(game.player.velocity.x, game.player.velocity.z).length() > 3:
			moving_frames += 1
			if point.distance_to(previous_point) < 0.00001: stationary_render_steps += 1
		previous_point = point
		if paused: pauses += 1
	var seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	frames.sort(); process_ms.sort(); draw_calls.sort()
	var tag := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "current"
	var result := {"tag": tag, "engine": Engine.get_version_info().string,
		"gpu": RenderingServer.get_video_adapter_name(), "viewport": str(root.size),
		"fps_cap": 120, "seconds": seconds, "frames": frames.size(), "mean_fps": frames.size() / seconds,
		"p95_frame_ms": frames[int(frames.size() * 0.95)], "p99_frame_ms": frames[int(frames.size() * 0.99)],
		"median_process_ms": process_ms[int(process_ms.size() * 0.5)],
		"median_draw_calls": draw_calls[int(draw_calls.size() * 0.5)],
		"moving_frames": moving_frames, "stationary_render_steps": stationary_render_steps,
		"stationary_render_fraction": float(stationary_render_steps) / maxi(1, moving_frames),
		"paused_frames": pauses, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"fixture": "Native 1280x720 requested, 120fps cap, stage2room2 normal4enemyAI, invulnerable player walks left/right via real action input. Rendered root position uses engine interpolation when enabled; stationary fraction measures physics stair-stepping, not bone motion. Not browser/minimum-spec benchmark."}
	var file := FileAccess.open("res://evidence/motion_%s.json" % tag, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("MOTION_PROFILE ", JSON.stringify(result))
	physics_frame.disconnect(_route)
	Input.action_release("move_left"); Input.action_release("move_right")
	game._show_main_menu()
	await process_frame
	quit()

func _render_point() -> Vector3:
	return game.player.get_global_transform_interpolated().origin if bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)) else game.player.global_position

func _route() -> void:
	if not is_instance_valid(game.player): return
	if game.player.global_position.x > 4.0: route_right = false
	if game.player.global_position.x < -4.0: route_right = true
	Input.action_release("move_left" if route_right else "move_right")
	Input.action_press("move_right" if route_right else "move_left")
