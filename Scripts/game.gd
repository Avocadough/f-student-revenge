# Menu/modal, pause/restart and scene lifecycle adapted from the user's 3D-lab1
# Scripts/game.gd (SD Studios starter lineage). See ThirdParty and CREDITS.md.
extends Node3D

const Player = preload("res://Scripts/student_player.gd")
const Stage = preload("res://Scripts/campus_stage.gd")
const HorrorUI = preload("res://Scripts/horror_ui.gd")
const FX = preload("res://Scripts/combat_fx.gd")
const GameAudio = preload("res://Scripts/game_audio.gd")
const Campaign = preload("res://Scripts/campaign_data.gd")
const FONT = preload("res://Assets/Fonts/NotoSansThai.ttf")
const STAGE_NAMES := Campaign.STAGE_NAMES
const SAVE_PATH := "user://progress_v2.json"
const LEGACY_SAVE_PATH := "user://progress.json"
const STAGE_SUBTITLES := ["01 / คิวที่ 666", "02 / CAPTCHA จับโป๊ะ", "03 / ยกเลิกวันสิ้นภาค"]
const INK := Color("100e12")
const CREAM := HorrorUI.BONE
const ORANGE := HorrorUI.BLOOD
const MINT := HorrorUI.TEAL

var player: CharacterBody3D
var level: Node3D
var running: bool = false
var paused: bool = false
var stage_index: int = 0
var checkpoint_index: int = 0
var elapsed: float = 0.0
var deaths: int = 0
var save_data: Dictionary = {}
var settings: Dictionary = {"volume": 0.75, "sfx": 0.8, "sensitivity": 1.0, "shake": true, "quality": 1, "god_mode": false}
var ui: Control
var main_menu: PanelContainer
var menu_stack: VBoxContainer
var modal: PanelContainer
var modal_stack: VBoxContainer
var hud_root: Control
var health_bar: ProgressBar
var posture_bar: ProgressBar
var focus_bar: ProgressBar
var health_label: Label
var objective_label: Label
var boss_panel: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar
var boss_structure: ProgressBar
var combo_label: Label
var control_hint: Label
var toast: Label
var toast_timer: float = 0.0
var prompt_label: Label
var timer_label: Label
var environment: WorldEnvironment
var sun: DirectionalLight3D
var menu_world: Node3D
var menu_camera: Camera3D
var audio: Node
var _last_health: float = 100.0
var _mouse_loss_time: float = 0.0
var _capture_stable_time: float = 0.0
var _capture_was_active: bool = false
var _capture_fallback_notified: bool = false
var _intro_seen: bool = false
var menu_backdrop: ColorRect
var menu_dossier: PanelContainer
var menu_title: Label
var continue_button: Button
var menu_scroll: ScrollContainer
var modal_scrim: ColorRect
var modal_scroll: ScrollContainer
var stats_panel: PanelContainer
var _hud_tick: float = 0.0
var _modal_return_focus: Control
var _run_id: int = 0
var menu_cover: TextureRect
var support_label: Label
var menu_frame: Control
var modal_frame: Control
var modal_kicker: Label
var legacy_progress_found := false
var story_revision_changed := false
var story_beat_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_setup_inputs()
	_load_save()
	_build_world()
	_build_ui()
	get_viewport().size_changed.connect(func() -> void: _apply_render_settings.call_deferred())
	audio = GameAudio.new()
	add_child(audio)
	_apply_settings()
	_show_main_menu()
	if legacy_progress_found:
		notify("พบเซฟเรื่องเดิม • เก็บไฟล์เดิมไว้และย้ายค่าตั้งค่าแล้ว เริ่มเรื่องใหม่เพื่อกู้มหาลัย", 8.0)
	elif story_revision_changed:
		notify("เดโมเรื่องใหม่: ยมทะเบียนบุก! เล่นต่อได้ หรือเริ่มใหม่เพื่อดูมุกตั้งแต่ต้น", 8.0)

func _setup_inputs() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"light_attack": [KEY_J], "heavy_attack": [KEY_K], "guard": [KEY_SHIFT],
		"dodge": [KEY_SPACE], "focus_attack": [KEY_Q], "interact": [KEY_E], "recenter": [KEY_R], "teacher_support": [KEY_T]
	}
	for action: String in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	for pair: Array in [["light_attack", MOUSE_BUTTON_LEFT], ["heavy_attack", MOUSE_BUTTON_RIGHT]]:
		var event := InputEventMouseButton.new()
		event.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], event): InputMap.action_add_event(pair[0], event)

func _build_world() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("172129")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("859da3")
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_light_color = Color("253340")
	env.fog_density = 0.004
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_color = Color("b6cbd7")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	menu_world = Node3D.new()
	# The opaque cover needs no hidden models, materials, lights or animation.
	add_child(menu_world)
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(6.3, 2.9, 7.4)
	menu_camera.look_at(Vector3(2.0, 1.75, -1.5))
	menu_camera.fov = 49
	menu_camera.current = true

func panel_style(color: Color, border: Color = Color.TRANSPARENT, padding: float = 24.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.set_content_margin_all(padding)
	style.border_color = border
	style.set_border_width_all(1)
	return style

func _label(text: String, size: int = 20, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("79716c"))
	button.add_theme_stylebox_override("normal", panel_style(Color("772932") if primary else Color("221a1dcc"), Color("bc5c58") if primary else Color("4b373c"), 11))
	button.add_theme_stylebox_override("hover", panel_style(Color("48282e"), HorrorUI.BRASS, 11))
	button.add_theme_stylebox_override("pressed", panel_style(Color("682d36"), CREAM, 11))
	var focus_style := panel_style(Color.TRANSPARENT, HorrorUI.BRASS, 11)
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_focus_color", CREAM)
	button.add_theme_stylebox_override("disabled", panel_style(Color("191519"), Color("30282d"), 11))
	button.mouse_entered.connect(func() -> void: _button_hover(button, true))
	button.mouse_exited.connect(func() -> void: _button_hover(button, false))
	button.pressed.connect(func() -> void:
		if audio: audio.play_effect("ui")
		callback.call())
	return button

func _button_hover(button: Button, active: bool) -> void:
	if button.disabled: return
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		if old and old.is_valid(): old.kill()
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "modulate", Color.WHITE if active else Color("e5dcda"), 0.12)
	button.set_meta("hover_tween", tween)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	HorrorUI.apply(theme)
	ui.theme = theme
	canvas.add_child(ui)
	menu_cover = TextureRect.new()
	menu_cover.texture = load("res://Assets/Images/hell_registrar_cover.png")
	menu_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_cover)
	menu_backdrop = ColorRect.new()
	menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float shade = mix(0.96, 0.08, smoothstep(0.1,0.8,UV.x)); shade += 0.2 * pow(abs(UV.y-0.5)*2.0, 2.0); COLOR=vec4(0.038,0.023,0.033,min(shade,0.98)); }"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	menu_backdrop.material = shader_material
	ui.add_child(menu_backdrop)
	main_menu = PanelContainer.new()
	ui.add_child(main_menu)
	main_menu.add_theme_stylebox_override("panel", panel_style(Color("100d12cf"), Color("513c3c"), 26))
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	main_menu.add_child(menu_scroll)
	menu_stack = VBoxContainer.new()
	menu_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_stack.add_theme_constant_override("separation", 8)
	menu_scroll.add_child(menu_stack)
	menu_stack.add_child(_label("คำร้องด่วน 666   /   DEMO 0.5", 13, HorrorUI.BRASS))
	menu_title = _label("การล้างแค้น\nของนักศึกษาติด F", 39)
	menu_title.add_theme_color_override("font_shadow_color", Color("5f1c27"))
	menu_title.add_theme_constant_override("shadow_offset_y", 3)
	menu_title.add_theme_constant_override("line_spacing", -2)
	menu_stack.add_child(menu_title)
	var subtitle := _label("ยมทะเบียนจะลบนักศึกษาทั้งมหาลัย\nคนที่โดดทุกคาบ ดันเป็นคนเดียวที่ระบบหาไม่เจอ", 16, HorrorUI.ASH)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_stack.add_child(subtitle)
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 10)
	menu_stack.add_child(divider)
	menu_stack.add_child(_button("01    เริ่มภารกิจสอบซ่อม", _new_game, true))
	continue_button = _button("02   เล่นต่อจากจุดล่าสุด", _continue_game)
	menu_stack.add_child(continue_button)
	menu_stack.add_child(_button("03   เลือกด่านสำหรับเดโม", _show_stage_select))
	menu_stack.add_child(_button("04   วิธีเล่นและคอมโบ", _show_help))
	menu_stack.add_child(_button("05   ตั้งค่า", _show_settings))
	menu_stack.add_child(_button("06   เครดิตและที่มา", _show_credits))
	menu_stack.add_child(_label("CP410844  ·  กลุ่ม 3   /   WASD + เมาส์", 12, HorrorUI.ASH))
	menu_frame = HorrorUI.new()
	ui.add_child(menu_frame)
	menu_dossier = PanelContainer.new()
	menu_dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_dossier.add_theme_stylebox_override("panel", panel_style(Color("110e13e8"), Color("745445"), 18))
	ui.add_child(menu_dossier)
	var dossier_row := HBoxContainer.new()
	dossier_row.add_theme_constant_override("separation", 18)
	menu_dossier.add_child(dossier_row)
	var grade := _label("F", 74, Color("c95759"))
	dossier_row.add_child(grade)
	var dossier_stack := VBoxContainer.new()
	dossier_stack.add_theme_constant_override("separation", 2)
	dossier_row.add_child(dossier_stack)
	dossier_stack.add_child(_label("ACADEMIC RECORD / 000-F", 10, HorrorUI.BRASS))
	dossier_stack.add_child(_label("ขาดเรียน 15 ครั้ง", 20))
	dossier_stack.add_child(_label("สถานะ: ไม่พบหน้าในระบบ", 15, HorrorUI.ASH))
	dossier_stack.add_child(_label("ยื่นคำร้องด้วยเอกสาร… และหมัด", 12, Color("c95759")))
	_build_hud()
	modal_scrim = ColorRect.new()
	modal_scrim.color = Color("08060bdc")
	modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal_scrim)
	modal_scrim.hide()
	modal = PanelContainer.new()
	ui.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.add_theme_stylebox_override("panel", panel_style(Color("171218fa"), Color("755249"), 30))
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.follow_focus = true
	modal.add_child(modal_scroll)
	modal_stack = VBoxContainer.new()
	modal_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_stack.add_theme_constant_override("separation", 12)
	modal_frame = HorrorUI.new()
	ui.add_child(modal_frame)
	modal_frame.hide()
	modal_kicker = _label("บันทึกจากมหาวิทยาลัย  /  RESTRICTED", 12, HorrorUI.BRASS)
	modal_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(modal_kicker)
	modal_kicker.hide()
	modal_scroll.add_child(modal_stack)
	modal_stack.minimum_size_changed.connect(func() -> void: _layout_modal.call_deferred())
	modal.visibility_changed.connect(_modal_visibility_changed)
	modal.hide()
	ui.resized.connect(_layout_ui)
	_layout_ui.call_deferred()

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_root)
	stats_panel = PanelContainer.new()
	hud_root.add_child(stats_panel)
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_theme_stylebox_override("panel", panel_style(Color("100e14e0"), Color("64504a"), 12))
	var stack := VBoxContainer.new()
	stats_panel.add_child(stack)
	health_label = _label("นักศึกษา  /  100", 17)
	stack.add_child(health_label)
	health_bar = _bar(stack, Color("c65358"), 9)
	var posture_text := _label("สมดุล  /  SHIFT ปัดป้อง", 12, HorrorUI.ASH)
	stack.add_child(posture_text)
	posture_bar = _bar(stack, HorrorUI.BRASS, 5)
	stack.add_child(_label("สมาธิ  /  Q ใช้ 50", 12, MINT))
	focus_bar = _bar(stack, MINT, 5)
	support_label = _label("", 12, HorrorUI.BRASS)
	support_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(support_label)
	objective_label = _label("", 15)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_stylebox_override("normal", panel_style(Color("100e14dc"), Color("54413c"), 12))
	hud_root.add_child(objective_label)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective_label.offset_left = -370
	objective_label.offset_right = -26
	objective_label.offset_top = 25
	objective_label.offset_bottom = 110
	boss_panel = VBoxContainer.new()
	hud_root.add_child(boss_panel)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -245
	boss_panel.offset_right = 245
	boss_panel.offset_top = 22
	boss_panel.offset_bottom = 95
	boss_label = _label("", 22, CREAM)
	boss_label.add_theme_color_override("font_shadow_color", INK)
	boss_label.add_theme_constant_override("shadow_offset_y", 2)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_label)
	boss_bar = _bar(boss_panel, Color("b4414e"), 8)
	boss_structure = _bar(boss_panel, HorrorUI.BRASS, 4)
	combo_label = _label("", 27, HorrorUI.BRASS)
	hud_root.add_child(combo_label)
	combo_label.position = Vector2(28, 164)
	timer_label = _label("", 14, HorrorUI.ASH)
	hud_root.add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	timer_label.position = Vector2(28, -92)
	control_hint = _label("WASD เดิน   ·   J / K โจมตี   ·   Shift การ์ด   ·   Space หลบ   ·   Q พิเศษ   ·   E ใช้   ·   T อาจารย์   ·   Esc พัก", 12, HorrorUI.ASH)
	control_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_hint.add_theme_stylebox_override("normal", panel_style(Color("100e14d9"), Color("3d3036"), 8))
	hud_root.add_child(control_hint)
	control_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	control_hint.offset_top = -34
	control_hint.offset_bottom = -8
	control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_hint.add_theme_color_override("font_shadow_color", INK)
	control_hint.add_theme_constant_override("shadow_offset_x", 1)
	control_hint.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label = _label("", 19, CREAM)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.add_theme_constant_override("outline_size", 5)
	prompt_label.add_theme_color_override("font_outline_color", Color("160f16"))
	hud_root.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -350
	prompt_label.offset_right = 350
	prompt_label.offset_top = -102
	prompt_label.offset_bottom = -68
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _label("", 18, CREAM)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_stylebox_override("normal", panel_style(Color("190f18ec"), Color("845450"), 10))
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -460
	toast.offset_right = 460
	toast.offset_top = -156
	toast.offset_bottom = -115
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color", INK)
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	hud_root.hide()
	toast.hide()

func _layout_ui() -> void:
	if not is_instance_valid(ui): return
	var viewport_size := ui.size
	var margin := 28.0 if viewport_size.x >= 1000 else 16.0
	var menu_width := minf(490.0, viewport_size.x - margin * 2.0)
	main_menu.position = Vector2(margin, margin)
	main_menu.size = Vector2(menu_width, viewport_size.y - margin * 2.0)
	menu_frame.position = main_menu.position + Vector2(6, 6)
	menu_frame.size = main_menu.size - Vector2(12, 12)
	menu_frame.visible = main_menu.visible
	menu_title.add_theme_font_size_override("font_size", 39 if menu_width >= 460 else 30)
	menu_dossier.position = Vector2(viewport_size.x - 374.0, viewport_size.y - 164.0)
	menu_dossier.size = Vector2(346, 136)
	menu_dossier.visible = main_menu.visible and viewport_size.x >= 1050 and viewport_size.y >= 600
	stats_panel.position = Vector2(margin, margin)
	stats_panel.size = Vector2(238, 162)
	objective_label.offset_left = -minf(284, viewport_size.x * 0.32) - margin
	objective_label.offset_right = -margin
	objective_label.offset_top = margin
	objective_label.offset_bottom = margin + 100
	var boss_width := minf(390, viewport_size.x - 2 * margin)
	boss_panel.offset_left = -boss_width / 2
	boss_panel.offset_right = boss_width / 2
	boss_panel.offset_top = margin if viewport_size.x >= 1120 else 183.0
	boss_panel.offset_bottom = boss_panel.offset_top + 90
	combo_label.position = Vector2(margin + 4, 216)
	timer_label.offset_left = margin
	timer_label.offset_top = -79
	control_hint.offset_left = margin
	control_hint.offset_right = -margin
	control_hint.offset_top = -48
	control_hint.offset_bottom = -12
	toast.offset_left = -minf(420, viewport_size.x / 2 - margin)
	toast.offset_right = minf(420, viewport_size.x / 2 - margin)
	toast.offset_top = -155
	toast.offset_bottom = -110
	prompt_label.offset_left = -minf(300, viewport_size.x / 2 - margin)
	prompt_label.offset_right = minf(300, viewport_size.x / 2 - margin)
	_layout_modal()
	_apply_render_settings()

func _layout_modal() -> void:
	if not is_instance_valid(modal) or not is_instance_valid(ui): return
	var width := minf(660, ui.size.x - 32)
	var height := clampf(modal_stack.get_combined_minimum_size().y + 60, 220, maxf(220, ui.size.y - 84))
	modal.offset_left = -width / 2
	modal.offset_right = width / 2
	modal.offset_top = -height / 2
	modal.offset_bottom = height / 2
	if is_instance_valid(modal_frame):
		modal_frame.position = modal.position + Vector2(7, 7)
		modal_frame.size = modal.size - Vector2(14, 14)
		modal_kicker.position = modal.position + Vector2(0, -27)
		modal_kicker.size.x = width

func _modal_visibility_changed() -> void:
	if not modal or not modal_scrim: return
	modal_scrim.visible = modal.visible
	if is_instance_valid(modal_frame):
		modal_frame.visible = modal.visible
		modal_kicker.visible = modal.visible
	for child in menu_stack.get_children():
		if child is BaseButton:
			child.focus_mode = Control.FOCUS_NONE if modal.visible else Control.FOCUS_ALL
	if not modal.visible and is_instance_valid(_modal_return_focus) and _modal_return_focus.is_visible_in_tree():
		_modal_return_focus.grab_focus()

func _set_label(label: Label, copy: String) -> void:
	# Godot reshapes Thai glyphs on text changes; do not invalidate unchanged text.
	if label.text != copy: label.text = copy

func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("background", panel_style(Color("35272d"), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", panel_style(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	return bar

func show_modal(title: String, copy: String, actions: Array = []) -> void:
	toast_timer = 0.0
	if toast: toast.hide()
	if not modal.visible:
		_modal_return_focus = get_viewport().gui_get_focus_owner()
	for child in modal_stack.get_children():
		modal_stack.remove_child(child)
		child.queue_free()
	modal_stack.add_theme_constant_override("separation", 12)
	var heading := _label(title, 28, CREAM)
	heading.focus_mode = Control.FOCUS_ALL
	heading.add_theme_stylebox_override("normal", _heading_style())
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_stack.add_child(heading)
	var body := _label(copy, 17, Color("c5b9ad"))
	body.add_theme_constant_override("line_spacing", 3)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_stack.add_child(body)
	body.visible = not copy.is_empty()
	for action: Dictionary in actions:
		modal_stack.add_child(_button(action.text, action.callback, action.get("primary", false)))
	modal.show()
	modal_scroll.scroll_vertical = 0
	_layout_modal.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if modal_stack.get_child_count() > 2:
		_focus_initial_modal.call_deferred(heading, modal_stack.get_child(2))

func _focus_initial_modal(heading: Label, action: Control) -> void:
	# Containers need a layout pass before follow_focus can reveal an action.
	# Long pages open at their heading; Tab reaches the action and scrolls to it.
	await get_tree().process_frame
	if not is_instance_valid(heading) or not is_instance_valid(action) or not modal.visible: return
	if heading.get_parent() != modal_stack: return
	if modal_stack.size.y > modal_scroll.size.y + 1:
		heading.grab_focus()
		modal_scroll.scroll_vertical = 0
	else:
		action.grab_focus()

func _show_main_menu() -> void:
	story_beat_open = false
	toast_timer = 0.0
	if toast: toast.hide()
	running = false
	paused = false
	get_tree().paused = false
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = null
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = null
	menu_world.show()
	menu_world.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_camera.current = true
	main_menu.show()
	menu_frame.show()
	menu_backdrop.show()
	menu_cover.show()
	continue_button.disabled = save_data.is_empty()
	continue_button.text = "02   ยังไม่มีจุดบันทึก" if save_data.is_empty() else "02   เล่นต่อจากจุดล่าสุด"
	modal.hide()
	hud_root.hide()
	_layout_ui()
	for child in menu_stack.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if audio: audio.set_combat(false)

func _new_game() -> void:
	if not save_data.is_empty():
		show_modal("เริ่มเรื่องใหม่", "เริ่มต้นที่ด่านแรก ความคืบหน้าล่าสุดจะถูกแทนที่\nการตั้งค่าเดิมยังอยู่", [
			{"text": "เริ่มใหม่", "callback": _show_intro, "primary": true},
			{"text": "กลับ", "callback": func() -> void: modal.hide()}])
	else:
		_show_intro()

func _show_intro() -> void:
	main_menu.hide()
	menu_frame.hide()
	menu_dossier.hide()
	show_modal("นักศึกษาตกค้างต้องเป็นศูนย์", Campaign.INTRO_TEXT, [{"text": "ถึงเวลาเข้าเรียน…ภาคสนาม", "callback": func() -> void:
		save_data.clear()
		elapsed = 0.0
		deaths = 0
		start_level(0, 0), "primary": true}])

func _continue_game() -> void:
	if save_data.is_empty():
		notify("ยังไม่มีจุดบันทึก เลือกเริ่มภารกิจสอบซ่อมได้เลย", 3)
		return
	start_level(int(save_data.get("stage", 0)), int(save_data.get("checkpoint", 0)))

func _show_stage_select() -> void:
	var actions: Array = []
	for index in range(3):
		var selected := index
		actions.append({"text": "%02d   %s" % [index + 1, STAGE_NAMES[index]], "callback": func() -> void: start_level(selected, 0), "primary": index == 0})
	actions.append({"text": "กลับ", "callback": func() -> void: modal.hide()})
	show_modal("เลือกด่านสำหรับเดโม", "เปิดให้ลองครบสามด่าน · คอมโบใช้ได้ทั้งหมด\nเล่นตามลำดับเพื่อดูมุกและเรื่องครบ", actions)

func _show_help() -> void:
	show_modal("วิธีเล่น", "WASD เดิน · เมาส์หมุนกล้อง · R หันกล้องกลับ\nคลิกซ้าย (L) / J = หมัดเบา\nคลิกขวา (H) / K = โจมตีหนัก\n\nL L L   แย็บ / หมัดตรง / ฮุก\nL L H   จบด้วยถีบ ผลักชนฉาก\nL H L   เตะกวาด แล้วต่อหมัด\n\nShift ค้าง = การ์ด · กดก่อนโดน = ปัดป้อง\nSpace + ทิศทาง = หลบ · Q = ท่าพิเศษ\nE = ใช้อุปกรณ์ภารกิจ / ปิดฉาก / ขว้างสิ่งของ\nT = เรียกอาจารย์ช่วย (รอ 15 วินาที)\n\nสัญลักษณ์ ! สีแดง = ท่าที่ต้องหลบ", [{"text": "เข้าใจแล้ว", "callback": func() -> void: modal.hide(), "primary": true}])

func _show_settings() -> void:
	show_modal("ตั้งค่า", "")
	modal_stack.add_theme_constant_override("separation", 8)
	for row: Array in [["เสียงหลัก", "volume", 0.0, 1.0], ["เสียงเอฟเฟกต์", "sfx", 0.0, 1.0], ["ความไวเมาส์", "sensitivity", 0.3, 2.0]]:
		var title := _label("", 17)
		modal_stack.add_child(title)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = 0.05
		slider.custom_minimum_size.y = 26
		slider.value = float(settings[row[1]])
		var key: String = row[1]
		var caption: String = row[0]
		title.text = "%s   %s" % [caption, ("%.2f×" % slider.value) if key == "sensitivity" else ("%d%%" % roundi(slider.value * 100))]
		slider.value_changed.connect(func(value: float) -> void:
			settings[key] = value
			title.text = "%s   %s" % [caption, ("%.2f×" % value) if key == "sensitivity" else ("%d%%" % roundi(value * 100))]
			_apply_settings())
		modal_stack.add_child(slider)
	var shake := CheckButton.new()
	shake.text = "กล้องสั่นเมื่อปะทะ"
	shake.button_pressed = settings.shake
	shake.toggled.connect(func(value: bool) -> void:
		settings.shake = value
		_apply_settings())
	modal_stack.add_child(shake)
	var god_toggle := CheckButton.new()
	god_toggle.text = "God Mode: อมตะ / โจมตีครั้งเดียว"
	god_toggle.button_pressed = bool(settings.get("god_mode", false))
	god_toggle.toggled.connect(func(value: bool) -> void:
		settings.god_mode = value
		_apply_settings())
	modal_stack.add_child(god_toggle)
	var quality := OptionButton.new()
	quality.add_item("ประหยัด  /  720p · ขอบเรียบ 2×")
	quality.add_item("คมชัด  /  1080p · ขอบเรียบ 4×")
	quality.custom_minimum_size.y = 40
	quality.select(int(settings.quality))
	quality.item_selected.connect(func(index: int) -> void:
		settings.quality = index
		_apply_settings())
	modal_stack.add_child(quality)
	var quality_note := _label("ความละเอียดสูงสุดตามขนาดจอ · จำกัด 60 FPS ทั้งสองโหมด
ถ้าการต่อสู้ไม่ลื่น ให้เลือกประหยัดก่อนเริ่มเล่น", 12, HorrorUI.ASH)
	quality_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_stack.add_child(quality_note)
	modal_stack.add_child(_button("บันทึกและกลับ", func() -> void:
		_write_save()
		if paused: _show_pause()
		else: modal.hide(), true))
	modal_stack.get_child(3).grab_focus()
	_layout_modal.call_deferred()

func _show_credits() -> void:
	show_modal("สร้างจากของจริง แล้วปรับให้เป็นเรา", "โครงการรายวิชา CP410844 · กลุ่ม 3\n\nGodot 4.7.2 / Blender 5.2\nเมนูและลำดับเกม: 3D-lab1 / SD Studios (MIT)\nการเคลื่อนที่และกล้อง: Jeh3no (MIT)\nตัวละครและแอนิเมชัน: Quaternius (CC0)\nเฟอร์นิเจอร์และเสียง: Kenney (CC0)\nพื้นผิว: Poly Haven (CC0)\nบรรยากาศ: congusbongus (CC0)\nภาพหน้าปก: สร้างด้วย OpenAI imagegen\nโมเดลและเสียงเพิ่มเติม: ทีมพัฒนา\nฟอนต์ Noto Sans Thai (SIL OFL)\n\nตัวละครและมหาวิทยาลัยเป็นเรื่องสมมติ\nหน้าจอคลิปและบทพูดสร้างเพื่อเกมนี้\nรายละเอียดการดัดแปลงอยู่ใน source และไฟล์ Blender", [{"text": "กลับ", "callback": func() -> void: modal.hide(), "primary": true}])

func start_level(index: int, checkpoint: int = 0) -> void:
	story_beat_open = false
	menu_cover.hide()
	_run_id += 1
	get_tree().paused = false
	paused = false
	running = true
	stage_index = clampi(index, 0, 2)
	checkpoint_index = clampi(checkpoint, 0, 2)
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	level = null
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player = null
	menu_world.hide()
	menu_world.process_mode = Node.PROCESS_MODE_DISABLED
	main_menu.hide()
	menu_frame.hide()
	menu_backdrop.hide()
	menu_dossier.hide()
	modal.hide()
	level = Stage.new()
	level.stage_index = stage_index
	level.checkpoint_index = checkpoint_index
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = level.get_spawn_position()
	player.reset_physics_interpolation()
	player.stage_ref = level
	player.focus = 50.0 if checkpoint_index == 2 else 0.0
	if player.camera_rig.has_method("snap_to_target"):
		player.camera_rig.snap_to_target()
	else:
		player.camera_rig.global_position = player.global_position + Vector3.UP * 1.55
	player.message.connect(notify)
	player.defeated.connect(_on_defeated)
	level.encounter_changed.connect(_on_encounter_changed)
	level.stage_completed.connect(_on_stage_completed)
	level.start(player)
	_apply_settings()
	hud_root.show()
	_hud_tick = 0.0
	_update_hud()
	_last_health = 100.0
	_mouse_loss_time = 0.0
	_capture_stable_time = 0.0
	_capture_was_active = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio.set_combat(true)
	_write_save()
	# CampusStage owns the entry line; do not overwrite its story/tutorial toast.

func _on_encounter_changed(checkpoint: int, title: String) -> void:
	checkpoint_index = checkpoint
	if checkpoint == 2 and is_instance_valid(player):
		player.health = 100.0
		player.focus = maxf(player.focus, 50.0)
	_write_save()
	# The stage follows this signal with the authored room-entry line.

func show_story_beat(title: String, body: String) -> void:
	# Short, skippable payoffs happen only after a room has become safe.
	if not running or not is_instance_valid(player) or player.dead or story_beat_open: return
	story_beat_open = true
	paused = true
	get_tree().paused = true
	show_modal(title, body, [{"text": "เล่นต่อ  →", "callback": _resume, "primary": true}])

func _on_defeated() -> void:
	deaths += 1
	var defeated_run := _run_id
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if defeated_run != _run_id or not running or not is_instance_valid(player) or not player.dead: return
		paused = true
		get_tree().paused = true
		show_modal("ยังไม่พ้น F", "ลองอีกครั้งจากช่วงล่าสุด\nอ่านท่าเตือน ใช้ Space หลบ และอย่าลืม Shift ปัดป้อง", [
			{"text": "กลับไปแก้มือ", "callback": func() -> void: start_level(stage_index, checkpoint_index), "primary": true},
			{"text": "กลับเมนู", "callback": _show_main_menu}]))

func _on_stage_completed() -> void:
	if not running: return
	running = false
	player.active = false
	get_tree().paused = true
	if stage_index < 2:
		save_data["stage"] = stage_index + 1
		save_data["checkpoint"] = 0
		_write_save()
		show_modal("คำร้องคืบหน้า  /  %d จาก 3" % (stage_index + 1), "%s\n\n%s" % [STAGE_NAMES[stage_index], Campaign.STAGE_ENDINGS[stage_index]], [
			{"text": "ไปช่วยพื้นที่ถัดไป", "callback": func() -> void: start_level(stage_index + 1, 0), "primary": true},
			{"text": "กลับเมนู", "callback": _show_main_menu}])
	else:
		save_data["complete"] = true
		_write_save()
		audio.set_combat(false)
		show_modal("ยกเลิกวันสิ้นภาคสำเร็จ", "%s\n\nเวลา %s    แก้มือ %d ครั้ง\nขอบคุณที่เล่นเดโมของกลุ่ม 3" % [Campaign.ENDING_TEXT, _format_time(), deaths], [
			{"text": "กลับหน้าเมนู", "callback": _show_main_menu, "primary": true}])

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		if running:
			if is_instance_valid(player) and player.dead:
				return
			if paused: _resume()
			else: _show_pause()
		elif modal.visible:
			_show_main_menu()

func _show_pause() -> void:
	if not running: return
	paused = true
	get_tree().paused = true
	show_modal("พักก่อน เดี๋ยวค่อยล้างแค้น", "L L L หมัดต่อเนื่อง · L L H ถีบ · L H L กวาด\nShift ปัดป้อง · Space หลบ · Q ท่าพิเศษ · E ใช้ / ปิดฉาก · T อาจารย์ช่วย", [
		{"text": "เล่นต่อ", "callback": _resume, "primary": true},
		{"text": "เริ่มช่วงนี้ใหม่", "callback": func() -> void: start_level(stage_index, checkpoint_index)},
		{"text": "ตั้งค่า", "callback": _show_settings},
		{"text": "กลับเมนู", "callback": _show_main_menu}])

func _resume() -> void:
	if not running or not is_instance_valid(player) or player.dead:
		return
	paused = false
	story_beat_open = false
	get_tree().paused = false
	modal.hide()
	_mouse_loss_time = -0.3
	_capture_stable_time = 0.0
	_capture_was_active = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused:
		_show_pause()

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast.visible = true
		if toast_timer <= 0.0: toast.hide()
	if running and not paused and is_instance_valid(player):
		elapsed += delta
		health_bar.value = player.health
		posture_bar.value = player.posture
		focus_bar.value = player.focus
		_hud_tick -= delta
		if _hud_tick <= 0.0:
			_hud_tick = 0.1
			_update_hud()
		if OS.has_feature("web"):
			_update_mouse_capture(delta, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func _update_mouse_capture(delta: float, captured: bool) -> void:
	if captured:
		_capture_stable_time += delta
		if _capture_stable_time >= 0.2:
			_capture_was_active = true
		_mouse_loss_time = 0.0
	else:
		_capture_stable_time = 0.0
		_mouse_loss_time += delta
		if _mouse_loss_time > 0.35 and _capture_was_active:
			_show_pause()
		elif _mouse_loss_time > 0.6 and not _capture_fallback_notified:
			_capture_fallback_notified = true
			notify("ลากปุ่มเมาส์กลางเพื่อหมุนกล้อง · R หันกล้องกลับ", 6.0)

func _update_hud() -> void:
	_set_label(health_label, "GOD MODE / อมตะ" if bool(settings.get("god_mode", false)) else "นักศึกษา  /  %03d" % ceili(player.health))
	health_bar.value = player.health
	posture_bar.value = player.posture
	focus_bar.value = player.focus
	_set_label(support_label, level.get_support_status() if level.has_method("get_support_status") else "")
	_set_label(objective_label, "%s\n%s" % [STAGE_SUBTITLES[stage_index], level.get_objective()])
	_set_label(combo_label, "%02d HITS" % player.combo_hits if player.combo_hits > 1 else "")
	_set_label(timer_label, "%s   /   แก้มือ %d ครั้ง   /   เอกสาร %d จาก 3" % [_format_time(), deaths, stage_index])
	var boss: Node = level.get_boss()
	boss_panel.visible = is_instance_valid(boss) and not boss.dead
	if boss_panel.visible:
		_set_label(boss_label, "—  %s  —" % boss.display_name)
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
		boss_structure.max_value = boss.max_posture
		boss_structure.value = boss.posture
	var target: Node3D = player.nearest_enemy(2.4, false, true)
	_set_label(prompt_label, "[ E ]  ปิดฉาก" if target else "[ E ]  ใช้อุปกรณ์ภารกิจ" if level.combat_cleared and not level.objective_completed and not level.completed else "")

func notify(text: String, duration: float = 2.5) -> void:
	if not toast or (modal and modal.visible): return
	if audio and audio.has_method("duck"): audio.duck(duration)
	toast.text = text
	toast_timer = duration
	toast.show()

func _format_time() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

func _load_save() -> void:
	if has_meta("qa_no_save"): return
	legacy_progress_found = false
	story_revision_changed = false
	var path := SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else LEGACY_SAVE_PATH
	if not FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	var data = parser.data
	if not data is Dictionary or data.get("version") != (Campaign.VERSION if path == SAVE_PATH else 1):
		return
	var progress = data.get("progress", {})
	story_revision_changed = path == SAVE_PATH and data.get("story_id", "") != Campaign.STORY_ID and progress is Dictionary and not progress.is_empty()
	legacy_progress_found = path == LEGACY_SAVE_PATH and progress is Dictionary and not progress.is_empty()
	if path == SAVE_PATH and progress is Dictionary and typeof(progress.get("stage")) in [TYPE_INT, TYPE_FLOAT] and typeof(progress.get("checkpoint")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(progress.stage)) and is_finite(float(progress.checkpoint)):
		save_data = {"stage": clampi(int(progress.stage), 0, 2), "checkpoint": clampi(int(progress.checkpoint), 0, 2), "complete": progress.get("complete", false) == true}
	var stored = data.get("settings", {})
	if not stored is Dictionary: return
	for key: String in ["volume", "sfx", "sensitivity", "quality"]:
		if typeof(stored.get(key)) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(stored[key])):
			settings[key] = clampf(float(stored[key]), 0.3 if key == "sensitivity" else 0.0, 2.0 if key == "sensitivity" else 1.0)
	if typeof(stored.get("shake")) == TYPE_BOOL:
		settings.shake = stored.shake
	if typeof(stored.get("god_mode")) == TYPE_BOOL:
		settings.god_mode = stored.god_mode

func _write_save() -> void:
	if has_meta("qa_no_save"): return
	if running:
		save_data["stage"] = stage_index
		save_data["checkpoint"] = checkpoint_index
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": Campaign.VERSION, "story_id": Campaign.STORY_ID, "progress": save_data, "settings": settings}))
	else:
		notify("เล่นต่อได้ แต่เบราว์เซอร์นี้บันทึกข้ามรอบไม่ได้", 4.0)

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(settings.volume))))
	AudioServer.set_bus_mute(0, float(settings.volume) <= 0.0)
	_apply_render_settings()
	if audio: audio.effects_volume = float(settings.sfx)
	if is_instance_valid(player):
		player.god_mode = bool(settings.get("god_mode", false))
		if player.god_mode and not player.dead:
			player.health = 100.0
			player.posture = 0.0
			player.stagger_timer = 0.0
		_update_hud()
	if is_instance_valid(player) and player.camera_rig:
		player.camera_rig.sensitivity = float(settings.sensitivity) * 0.0025
		player.camera_rig.shake_enabled = bool(settings.shake)

func _heading_style() -> StyleBoxFlat:
	var style := panel_style(Color.TRANSPARENT, ORANGE, 0)
	style.set_border_width_all(0)
	style.border_width_bottom = 2
	style.content_margin_bottom = 13
	return style

func _apply_render_settings() -> void:
	# Render pixel budget is independent from crisp native-resolution UI.
	# Physics remains 60 Hz; this cap avoids burning GPU power on surplus frames.
	Engine.max_fps = 60
	var quality := int(settings.quality)
	if sun: sun.shadow_enabled = quality > 0
	var viewport := get_viewport()
	var pixels := Vector2(viewport.get_texture().get_size())
	var budget := Vector2(1920, 1080) if quality > 0 else Vector2(1280, 720)
	viewport.scaling_3d_scale = clampf(minf(budget.x / maxf(1, pixels.x), budget.y / maxf(1, pixels.y)), 0.25, 1.0)
	viewport.msaa_3d = Viewport.MSAA_4X if quality > 0 else Viewport.MSAA_2X
	if is_instance_valid(level): level.apply_render_quality(quality)
	if is_instance_valid(player): FX.apply_quality(self, quality)
