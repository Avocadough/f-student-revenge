extends SceneTree

# Native rendered benchmark fixture, not a gameplay completion test.
# No fixed-fps: samples actual frame intervals at 1920x1080.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await create_timer(0.5).timeout
	game.start_level(1, 1)
	game.player.invulnerability = 100.0 # Keep identical enemy workload alive for this fixture.
	await create_timer(2.0).timeout
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	var start := last
	var pauses := 0
	while Time.get_ticks_usec() - start < 12000000:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
		if paused: pauses += 1
	var total := float(last - start) / 1000000.0
	samples.sort()
	var result := {
		"engine": Engine.get_version_info().string,
		"renderer": "Native GL Compatibility; not a Web/browser benchmark",
		"gpu": RenderingServer.get_video_adapter_name(),
		"resolution": str(root.size), "sample_seconds": total,
		"frames": samples.size(), "mean_fps": samples.size() / total,
		"p95_frame_ms": samples[int(samples.size() * 0.95)],
		"p99_frame_ms": samples[int(samples.size() * 0.99)],
		"paused_frames": pauses, "alive_enemies": game.level._alive_count(),
		"fixture": "Stage 2, room 2, stationary player, normal enemy AI, player invulnerable only for repeatable performance sampling; not a manual-play or minimum-spec claim."
	}
	var file := FileAccess.open("res://evidence/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("PERFORMANCE ", JSON.stringify(result))
	game._show_main_menu()
	await process_frame
	quit()
