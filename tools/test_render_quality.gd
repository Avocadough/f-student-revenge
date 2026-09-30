extends SceneTree
## Integrated resource/viewport checks, not a GPU benchmark or minimum-spec claim.

const FX = preload("res://Scripts/combat_fx.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"case": label, "passed": value})
	if not value: failures.append(label)

func settle() -> void:
	for index in range(3): await process_frame

func _run() -> void:
	var game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	game.start_level(1, 1)
	game.player.invulnerability = 100.0 # Isolate display settings from incidental damage.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	for window_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await settle()
		for quality in [0, 1]:
			game.settings.quality = quality
			game._apply_settings()
			await settle()
			var physical: Vector2 = root.get_texture().get_size()
			var budget := Vector2(960, 540) if quality == 0 else Vector2(1280, 720)
			var effective := physical * root.scaling_3d_scale
			var pool := FX.prepare(game)
			var active_slots := 0
			var particle_budget := 0
			for emitter: CPUParticles3D in pool.get_children():
				if emitter.visible and emitter.process_mode != Node.PROCESS_MODE_DISABLED:
					active_slots += 1
					particle_budget += emitter.amount
			var lights := 0
			for room_lights: Array in game.level._room_lights:
				for light: OmniLight3D in room_lights:
					if light.is_visible_in_tree(): lights += 1
			var label := "%s quality%d" % [str(window_size), quality]
			check(physical.x > 0 and physical.y > 0 and effective.x <= budget.x + 1.0 and effective.y <= budget.y + 1.0, label + " respects physical render pixel budget")
			check(game.level.render_quality == quality and active_slots == (6 if quality == 0 else 12) and particle_budget == (24 if quality == 0 else 84) and lights == (3 if quality == 0 else 4), label + " updates stage lights and FX through game settings")
			check(root.msaa_3d == (Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X) and Engine.max_fps == 60 and Engine.physics_ticks_per_second == 60, label + " applies rendering options without changing physics rate")
			measurements.append({"requested_window": str(window_size), "physical_texture": str(physical), "logical_rect": str(root.get_visible_rect().size), "quality": quality, "render_scale": root.scaling_3d_scale, "effective_3d_pixels": str(effective), "active_room_lights": lights, "active_fx_slots": active_slots, "max_impact_particles": particle_budget})
	var pool := FX.prepare(game)
	for index in range(60): FX.burst(game, game.player.global_position, Color.ORANGE)
	game._show_main_menu()
	await create_timer(0.8).timeout
	var settled := true
	for emitter: CPUParticles3D in pool.get_children(): settled = settled and not emitter.emitting
	check(settled and not paused and pool.get_child_count() == 12, "Returning to menu lets one-shot impacts expire without pool growth")
	game.settings.quality = 0
	game.start_level(0, 0)
	await settle()
	check(FX.prepare(game) == pool and pool.get_child_count() == 12 and int(pool.get_meta("budget")) == 6 and game.level.render_quality == 0, "New stage reuses the bounded FX pool and reapplies saved low quality")
	var result := {"scope": "Integrated quality, canvas_items viewport budgets and FX lifecycle. Headless resource assertions are not rendered FPS evidence.", "engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "passed": failures.is_empty(), "measurements": measurements}
	var output := FileAccess.open("res://evidence/render_quality_checks.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("RENDER_QUALITY ", JSON.stringify({"checks": checks.size(), "failures": failures}))
	game._show_main_menu()
	game.queue_free()
	await settle()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
