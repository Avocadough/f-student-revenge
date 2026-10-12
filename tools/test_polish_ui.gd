extends SceneTree
## Pause-safe presentation and ally HUD regression. No save access; headless by default.

var game: Node
var checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "label": label})
	if not ok: print("FAIL: ", label)

func settle() -> void:
	await create_timer(0.3, true, false, true).timeout
	for i in range(3): await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await settle()
	check(game.menu_stack.size.y <= game.menu_scroll.size.y + 1, "All menu choices and footer fit at 1280x720 without scrolling")
	var ui_font: Font = game.ui.theme.default_font
	var menu_covered := true
	for child in game.menu_stack.get_children():
		if child is Button and not _has_glyphs(child.text, ui_font): menu_covered = false
	check(menu_covered, "Menu action copy has bundled glyphs without operating-system fallback")
	check(_has_glyphs(game.Campaign.ENDING_TEXT, ui_font), "Ending copy including the changed grade has bundled UI glyphs")
	var environment_source := FileAccess.get_file_as_string("res://Scripts/campus_environment.gd")
	var cabinet_source := environment_source.get_slice("static func _electrical_cabinet(", 1).get_slice("static func ", 0)
	var sign_expression := RegEx.create_from_string('stage\\._sign\\("([^"]+)"')
	var sign_match := sign_expression.search(cabinet_source)
	var world_font: Font = load("res://Assets/Fonts/NotoSansThaiWorld.ttf")
	check(sign_match != null and _has_glyphs(sign_match.get_string(1), world_font), "Electrical cabinet runtime caption has bundled world-font glyphs")
	game._show_help()
	game._show_credits()
	game._show_settings()
	await settle()
	check(game.modal_stack.size.y <= game.modal_scroll.size.y + 1, "Settings save action fits the 720px screen without scrolling")
	check(game.modal.modulate.a > 0.99 and game.modal.scale.is_equal_approx(Vector2.ONE), "Rapid paused modal replacement finishes fully visible without stale motion")
	check(root.gui_get_focus_owner() is HSlider, "Rapid modal replacement preserves final settings keyboard focus")
	check(game.continue_button.focus_mode == Control.FOCUS_NONE, "Background cannot steal focus during modal presentation")
	game.start_level(0, 0)
	game.set_process(false)
	game.level.set_physics_process(false)
	game.player.set_physics_process(false)
	var electrical_label := _electrical_label(game.level)
	check(electrical_label != null and _has_glyphs(electrical_label.text, electrical_label.font) and electrical_label.font.get_string_size(electrical_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, electrical_label.font_size).x * electrical_label.pixel_size <= 0.34, "Instantiated electrical caption uses covered glyphs and fits its 0.38m warning plate with margins")
	game.player.health = 100.0
	game.health_bar.value = 100.0
	game.player.health = 43.0
	game._process(1.0 / 60.0)
	game._update_hud()
	check(game.health_label.text.contains("043"), "Damage number reflects actual HP immediately while the bar animates")
	check(game.health_bar.value > 43.0 and game.health_bar.value < 100.0, "Damage bar eases toward HP rather than snapping or staying frozen")
	for i in range(120): game._process(1.0 / 60.0)
	check(absf(game.health_bar.value - 43.0) < 0.1, "Damage bar settles accurately and does not drift")
	check(game.get("ally_panel") != null, "Combat gives teacher status a dedicated readable HUD region")
	if game.get("ally_panel") != null:
		check(game.ally_panel.size.y <= 132, "Teacher card cannot retain a tall transient autowrap measurement")
	game.level.teacher_rescued = true
	game.level.teacher.rescued = true
	game.level.support_cooldown = 7.2
	game._update_hud()
	if game.get("cooldown_label") != null:
		check(game.cooldown_label.text.contains("8"), "T status shows remaining cooldown rounded up, separate from autonomous combat")
		check(not game.support_label.text.contains("15 วินาที"), "Autonomous teacher status does not duplicate T instructions")
		game.level.teacher.combat_state = "attack"
		game.level.support_cooldown = 0.0
		game._update_hud()
		check(game.support_label.text == "กำลังช่วยโจมตี" and game.cooldown_label.text.contains("พร้อมใช้"), "Autonomous attack and ready T skill are represented independently")
	game.show_story_beat("ทดสอบบทสนทนา", "อาจารย์: พร้อมไปต่อแล้ว")
	check(_has_glyphs(game.modal_stack.get_child(2).text, ui_font), "Actual story resume action has bundled UI glyphs")
	game._resume()
	game._show_pause()
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 720)]:
		root.size = resolution
		root.content_scale_size = resolution
		await settle()
		var bounds: Rect2 = game.modal.get_global_rect()
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(bounds), "Pause stays inside viewport at %s" % resolution)
		if game.get("ally_panel") != null:
			check(not game.ally_panel.get_global_rect().intersects(game.boss_panel.get_global_rect()), "Ally and boss regions stay separate at %s" % resolution)
			check(not game.stats_panel.get_global_rect().intersects(game.ally_panel.get_global_rect()), "Student and teacher regions stay separate at %s" % resolution)
	game._resume()
	check(not paused and not game.modal.visible and not game.modal_scrim.visible, "Resume dismisses modal and restores gameplay immediately")
	var passed := true
	for item in checks:
		if not item.pass: passed = false
	var out := FileAccess.open("res://evidence/2026-10-12-polish/ui_polish_checks.json", FileAccess.WRITE)
	if out: out.store_string(JSON.stringify({"passed": passed, "checks": checks}, "\t"))
	print("POLISH_UI ", "PASS" if passed else "FAIL", " checks=", checks.size())
	_stop_audio(game)
	game.queue_free()
	await settle()
	quit(0 if passed else 1)

func _stop_audio(parent: Node) -> void:
	if parent is AudioStreamPlayer or parent is AudioStreamPlayer3D: parent.stop()
	for child in parent.get_children(): _stop_audio(child)

func _has_glyphs(copy: String, font: Font) -> bool:
	# Inspect the shipped font's own coverage; desktop fallback masks missing glyphs.
	for index in range(copy.length()):
		var codepoint := copy.unicode_at(index)
		if codepoint in [9, 10, 13]: continue
		if not font.has_char(codepoint): return false
	return true

func _electrical_label(parent: Node) -> Label3D:
	for child in parent.get_children():
		if child is Label3D and child.text == "ไฟฟ้า": return child
		var found := _electrical_label(child)
		if found: return found
	return null
