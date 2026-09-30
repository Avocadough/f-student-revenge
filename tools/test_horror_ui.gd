extends SceneTree
## Rendered UI fixtures only, not gameplay completion or a performance benchmark.
## Run without --headless after the render slot is free. Uses qa_no_save throughout.

const OUTPUT_DIR := "res://evidence/v05/ui"
const SIZES := [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 720)]

var game: Node
var checks: Array[Dictionary] = []
var screens: Array[Dictionary] = []
var failures: Array[String] = []
var context := ""
var resolution := ""
var started_usec := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	var description := "%s: %s" % [context, label]
	checks.append({"pass": condition, "label": description})
	if not condition:
		failures.append(description)
		print("HORROR_UI_FAIL ", description)

func settle(frames: int = 5) -> void:
	for frame in range(frames):
		await process_frame

func rect_data(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}

func contains_rect(outer: Rect2, inner: Rect2, tolerance: float = 1.5) -> bool:
	return outer.grow(tolerance).encloses(inner)

func viewport_bounds(control: Control) -> bool:
	return contains_rect(Rect2(Vector2.ZERO, game.ui.size), control.get_global_rect())

func enabled_focus_inside(parent: Control) -> bool:
	var focus := root.gui_get_focus_owner()
	return is_instance_valid(focus) and parent.is_ancestor_of(focus) and focus.is_visible_in_tree() and focus.focus_mode != Control.FOCUS_NONE and not (focus is BaseButton and focus.disabled)

func collect_controls(parent: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in parent.get_children():
		if child is Control:
			found.append(child)
		found.append_array(collect_controls(child))
	return found

func audit_text(container: Control, horizontal_bounds: Rect2, minimum_font: int) -> void:
	var text_count := 0
	for control in collect_controls(container):
		if not control.is_visible_in_tree(): continue
		var copy := ""
		if control is Label or control is Button:
			copy = control.text
		if copy.is_empty(): continue
		text_count += 1
		var rect := control.get_global_rect()
		var short_copy := copy.replace("\n", " ").left(50)
		check(rect.size.x > 0 and rect.size.y > 0, "Text has a nonzero layout: " + short_copy)
		check(rect.position.x >= horizontal_bounds.position.x - 2 and rect.end.x <= horizontal_bounds.end.x + 2, "Text fits available width: " + short_copy)
		check(control.get_theme_font_size("font_size") >= minimum_font, "Text meets %d px fixture minimum: %s" % [minimum_font, short_copy])
		if control is Label:
			check(control.size.y + 2 >= control.get_minimum_size().y, "Label has room for its wrapped lines: " + short_copy)
	check(text_count > 0, "Screen contains readable text controls")

func text_inventory(parent: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for control in collect_controls(parent):
		if not control.is_visible_in_tree(): continue
		if control is Label or control is Button:
			if control.text.is_empty(): continue
			result.append({"text": control.text, "font_px": control.get_theme_font_size("font_size"), "bounds": rect_data(control.get_global_rect()), "type": control.get_class()})
	return result

func capture(state: String, owner: Control) -> void:
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var path := "%s/%s/%s.png" % [OUTPUT_DIR, resolution, state]
	var save_error := shot.save_png(path)
	check(save_error == OK, "PNG captured: " + state)
	check(shot.get_size() == root.size, "Capture uses requested pixel size")
	var focus := root.gui_get_focus_owner()
	screens.append({"state": state, "resolution": resolution, "path": path, "pixels": [shot.get_width(), shot.get_height()], "bounds": rect_data(owner.get_global_rect()), "focus_type": focus.get_class() if is_instance_valid(focus) else "none", "focus_text": focus.text if focus is Button else "", "modal_scroll": game.modal_scroll.scroll_vertical if game.modal.visible else null, "text": text_inventory(owner)})
	print("HORROR_UI_CAPTURE ", resolution, " ", state)

func last_enabled_focus(parent: Control) -> Control:
	var controls := collect_controls(parent)
	controls.reverse()
	for control in controls:
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and control.disabled):
			return control
	return null

func press_tab() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func inspect_modal(state: String) -> void:
	context = resolution + "/" + state
	await settle()
	check(game.modal.visible and viewport_bounds(game.modal), "Modal panel remains within viewport")
	check(game.modal_scrim.visible and game.modal_scrim.mouse_filter == Control.MOUSE_FILTER_STOP, "Scrim blocks background pointer input")
	check(enabled_focus_inside(game.modal), "Initial keyboard focus belongs to the modal")
	for control in collect_controls(game.menu_stack):
		if control is BaseButton:
			check(control.focus_mode == Control.FOCUS_NONE, "Background button excluded from focus: " + control.text)
	audit_text(game.modal_stack, game.modal_scroll.get_global_rect(), 12)
	await capture(state, game.modal)
	await press_tab()
	check(enabled_focus_inside(game.modal), "Tab keeps keyboard focus inside modal")
	var final_action := last_enabled_focus(game.modal_stack)
	check(is_instance_valid(final_action), "Modal exposes an enabled keyboard action")
	if is_instance_valid(final_action):
		final_action.grab_focus()
		await settle()
		check(contains_rect(game.modal_scroll.get_global_rect(), final_action.get_global_rect()), "Keyboard can reveal the final action without clipping")
	var scroll_bar: VScrollBar = game.modal_scroll.get_v_scroll_bar()
	if scroll_bar.max_value > scroll_bar.page + 2:
		await capture(state + "_bottom", game.modal)
		game.modal_scroll.scroll_vertical = 0
		await settle()
		await capture(state + "_top", game.modal)

func inspect_menu() -> void:
	context = resolution + "/menu"
	game.save_data.clear()
	game._show_main_menu()
	await settle()
	check(game.continue_button.disabled, "Continue disabled without a checkpoint")
	check(viewport_bounds(game.main_menu), "Main menu fits viewport")
	check(enabled_focus_inside(game.main_menu), "Menu opens with an enabled keyboard action focused")
	check(not game.modal.visible and not game.modal_scrim.visible, "Main menu has no stale modal overlay")
	audit_text(game.menu_stack, game.menu_scroll.get_global_rect(), 11)
	await capture("menu", game.main_menu)
	var final_action := last_enabled_focus(game.menu_stack)
	if is_instance_valid(final_action):
		final_action.grab_focus()
		await settle()
		check(contains_rect(game.menu_scroll.get_global_rect(), final_action.get_global_rect()), "Menu keyboard navigation reveals the last action")
		if game.menu_scroll.scroll_vertical > 0:
			await capture("menu_bottom", game.main_menu)

func begin_game_fixture(stage: int, checkpoint: int) -> void:
	game._show_main_menu()
	game.settings.god_mode = false
	game.start_level(stage, checkpoint)
	game.player.invulnerability = 100.0
	AudioServer.set_bus_mute(0, true)
	# Let the real stage spawn its boss and settle interpolation, then hold a stable
	# visual fixture. These state calls do not claim a human or bot won the campaign.
	for frame in range(24):
		paused = false
		game.paused = false
		game.modal.hide()
		await process_frame
	paused = true
	game.paused = true
	game.modal.hide()
	game.toast_timer = 0.0
	game.toast.hide()
	game._update_hud()
	await settle()

func inspect_hud() -> void:
	context = resolution + "/game_hud"
	check(game.hud_root.visible and not game.modal.visible, "Gameplay HUD visible without modal")
	check(game.boss_panel.visible, "Boss HUD fixture includes the final boss")
	for control: Control in [game.stats_panel, game.objective_label, game.boss_panel, game.control_hint, game.timer_label, game.prompt_label]:
		if control.is_visible_in_tree():
			check(viewport_bounds(control), "HUD control fits viewport: " + str(control.get_path()))
	check(not game.stats_panel.get_global_rect().intersects(game.objective_label.get_global_rect()), "Status and objective panels do not overlap")
	check(not game.stats_panel.get_global_rect().intersects(game.boss_panel.get_global_rect()), "Status and boss panels do not overlap")
	check(not game.objective_label.get_global_rect().intersects(game.boss_panel.get_global_rect()), "Objective and boss panels do not overlap")
	audit_text(game.hud_root, Rect2(Vector2.ZERO, game.ui.size), 12)
	await capture("game_hud", game.hud_root)
	# Include the longer teacher notice, combo, and interaction prompt together.
	game.player.combo_hits = 12
	game._update_hud()
	game.prompt_label.text = "[ E ]  ใช้อุปกรณ์ภารกิจ"
	game.notify("อาจารย์ฟูลสแตก: กำแพงป้องกันพร้อมแล้ว • T ขอแรงอาจารย์", 30.0)
	await settle()
	check(viewport_bounds(game.toast), "Long teacher notice fits viewport")
	check(viewport_bounds(game.combo_label), "Combo counter fits viewport")
	check(viewport_bounds(game.prompt_label), "Interaction prompt fits viewport")
	check(not game.toast.get_global_rect().intersects(game.prompt_label.get_global_rect()), "Teacher notice and E prompt do not overlap")
	check(not game.toast.get_global_rect().intersects(game.control_hint.get_global_rect()), "Teacher notice and controls do not overlap")
	await capture("game_hud_notices", game.ui)

func run_resolution(size: Vector2i) -> void:
	resolution = "%dx%d" % [size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + resolution))
	game._show_main_menu()
	root.size = size
	root.content_scale_size = size
	await settle(8)
	await inspect_menu()
	for state in ["help", "settings", "stage_select", "intro", "credits"]:
		game._show_main_menu()
		game.call("_show_" + state)
		await inspect_modal(state)
		if state == "settings":
			# This is a settings UI assertion, not a GPU-performance assertion.
			var has_quality := false
			for control in collect_controls(game.modal_stack):
				if control is OptionButton and control.item_count >= 2: has_quality = true
			check(has_quality, "Settings includes at least two graphics choices")
	await begin_game_fixture(2, 2)
	await inspect_hud()
	game.show_story_beat("สำเนาถูกต้อง... แต่ต้นฉบับเหนื่อยแล้ว", "นักศึกษา: ผมต้องยื่นคำร้องเพื่อยกเลิกคำร้องอีกทีเหรอครับ?\nอาจารย์: คราวนี้ไม่ต้อง เธอเพิ่งต่อยฝ่ายอนุมัติไปแล้ว")
	await inspect_modal("story_payoff")
	check(paused and game.paused and game.story_beat_open, "Safe story payoff pauses simulation")
	check(not game.level.request_teacher_support(), "Teacher action is blocked during story payoff")
	game._resume()
	check(not paused and not game.story_beat_open, "Story payoff resumes without leaving a stale pause")
	game._show_pause()
	await inspect_modal("pause")
	check(paused and game.paused, "Pause screen pauses simulation")
	game._resume()
	game.level.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.invulnerability = 0.0
	game.player.health = 1.0
	game.player.receive_hit(999.0, 0.0, game.player.global_position + Vector3.BACK, true)
	await create_timer(1.4, true, false, true).timeout
	await inspect_modal("death")
	check(game.player.dead and paused, "Death screen represents a defeated, paused player")
	await begin_game_fixture(0, 2)
	game._on_stage_completed()
	await inspect_modal("clear")
	check(not game.running and paused, "Stage clear pauses gameplay")
	await begin_game_fixture(2, 2)
	var portal = game.level.get_meta("final_portal_visual", null)
	if portal is Node3D: portal.hide()
	game._on_stage_completed()
	await inspect_modal("ending")
	check(not game.running and paused, "Ending pauses gameplay")
	var ending_has_grade := false
	for item in text_inventory(game.modal):
		if "F → D" in item.text: ending_has_grade = true
	check(ending_has_grade, "Ending shows the cooperative F to D resolution")

func stop_audio(parent: Node) -> void:
	if parent is AudioStreamPlayer or parent is AudioStreamPlayer3D or parent is AudioStreamPlayer2D:
		parent.stop()
	for child in parent.get_children(): stop_audio(child)

func _run() -> void:
	started_usec = Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless":
		push_error("This harness needs a rendered native window; --headless is suitable only for --check-only.")
		quit(2)
		return
	# Bound the capture helper's load and give physics/animations a predictable
	# settling interval. This cap is not used as evidence of game performance.
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game = load("res://Scenes/main.tscn").instantiate()
	game.set_meta("qa_no_save", true)
	root.add_child(game)
	await settle(8)
	for size: Vector2i in SIZES:
		await run_resolution(size)
	context = "cleanup"
	check(game.has_meta("qa_no_save"), "Player save reads/writes remained disabled")
	var report := {"passed": failures.is_empty(), "engine": Engine.get_version_info().string, "scope": "Native synthetic UI/layout fixtures at three window sizes; direct handlers dispatch death/clear/ending for presentation QA. No player saves, gameplay completion, browser behavior or performance are certified.", "manual_review_required": "Inspect captured PNGs for Thai legibility, contrast, composition and the horror art direction; geometry and font-size assertions do not certify visual readability.", "resolutions": ["1280x720", "960x540", "800x720"], "checks": checks, "failures": failures, "screens": screens, "wall_seconds": (Time.get_ticks_usec() - started_usec) / 1000000.0}
	var output := FileAccess.open(OUTPUT_DIR + "/checks.json", FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	else:
		failures.append("Could not write UI report")
	print("HORROR_UI_RESULT ", JSON.stringify({"passed": failures.is_empty(), "checks": checks.size(), "screens": screens.size(), "failures": failures}))
	paused = false
	stop_audio(game)
	game.queue_free()
	await settle(3)
	quit(0 if failures.is_empty() else 1)
