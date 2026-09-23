# Menu/modal, pause/restart and scene lifecycle adapted from the user's 3D-lab1
# Scripts/game.gd (SD Studios starter lineage). See ThirdParty and CREDITS.md.
extends Node3D

const Player = preload("res://Scripts/student_player.gd")
const Stage = preload("res://Scripts/campus_stage.gd")
const GameAudio = preload("res://Scripts/game_audio.gd")
const FONT = preload("res://Assets/Fonts/NotoSansThai.ttf")
const STAGE_NAMES := ["เช็คชื่อครั้งสุดท้าย", "ห้องแล็บที่รู้ทันทุกอย่าง", "Final Deployment"]
const STAGE_SUBTITLES := ["01 / PROGRAMMING", "02 / ARTIFICIAL INTELLIGENCE", "03 / WEB APPLICATION"]
const INK := Color("151b24")
const CREAM := Color("f3ecda")
const ORANGE := Color("f2704e")
const MINT := Color("88d5c5")

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_setup_inputs()
	_load_save()
	_build_world()
	_build_ui()
	audio = GameAudio.new()
	add_child(audio)
	_apply_settings()
	_show_main_menu()

func _setup_inputs() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"light_attack": [KEY_J], "heavy_attack": [KEY_K], "guard": [KEY_SHIFT],
		"dodge": [KEY_SPACE], "focus_attack": [KEY_Q], "interact": [KEY_E], "recenter": [KEY_R]
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
	env.background_color = Color("697b88")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8d5df")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -25, 0)
	sun.light_color = Color("ffdfb6")
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	menu_world = Node3D.new()
	# Menu animation is decorative and never mixed with interpolated gameplay.
	menu_world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(menu_world)
	_menu_box(Vector3(0, -0.16, 0), Vector3(30, 0.3, 25), Color("717975"))
	_menu_box(Vector3(0, 2.7, -5), Vector3(22, 5.4, 0.3), Color("cbc6b2"))
	_menu_box(Vector3(0, 0.5, -4.81), Vector3(22, 1.0, 0.08), Color("4a6762"))
	_menu_box(Vector3(2.2, 2.45, -4.77), Vector3(7.4, 2.65, 0.12), Color("ac9971"))
	_menu_box(Vector3(2.2, 2.45, -4.68), Vector3(7.16, 2.41, 0.08), Color("243e36"))
	_menu_box(Vector3(2.2, 1.08, -4.58), Vector3(7.4, 0.09, 0.25), Color("b8ac8d"))
	# Wall rails, floor inlays and actual desks anchor the scene as a campus room.
	for x in [-5.5, -1.0, 7.0]:
		_menu_box(Vector3(x, 2.7, -4.76), Vector3(0.13, 5.4, 0.08), Color("ddd6bd"))
	for z in [-3.0, 1.0, 5.0]:
		_menu_box(Vector3(2, 0.002, z), Vector3(17, 0.008, 0.025), Color("9caa9e"))
	for x in [-2.0, 2.2, 6.5]:
		_menu_box(Vector3(x, 4.85, -1.7), Vector3(2.0, 0.055, 0.4), Color("eee4c3"))
	_menu_box(Vector3(1.0, 0.96, -1.3), Vector3(3.1, 0.13, 1.25), Color("b69262"))
	_menu_box(Vector3(1.0, 0.57, -1.62), Vector3(2.7, 0.64, 0.1), Color("426059"))
	for x in [-0.3, 2.3]:
		_menu_box(Vector3(x, 0.45, -1.3), Vector3(0.12, 0.95, 1.0), Color("283d3c"))
	for pos in [Vector3(5.7, 0, -2.6), Vector3(7.7, 0, -2.6)]:
		_menu_box(pos + Vector3(0, 0.76, 0), Vector3(1.45, 0.09, 0.9), Color("b49c74"))
		for x in [-0.58, 0.58]:
			_menu_box(pos + Vector3(x, 0.37, 0), Vector3(0.07, 0.74, 0.68), Color("42514d"))
	_menu_box(Vector3(6.85, 1.5, -4.74), Vector3(0.95, 1.25, 0.05), CREAM)
	_menu_sign("งดส่งงานย้อนหลัง\nยกเว้นหมัด", Vector3(6.85, 1.53, -4.69), 29, 0.004, INK)
	_menu_sign("DEPARTMENT OF\nSECOND CHANCES", Vector3(-2.7, 2.7, -4.68), 34, 0.006, Color("3c544f"))
	var board := Label3D.new()
	board.font = FONT
	board.text = "F"
	board.font_size = 190
	board.pixel_size = 0.008
	board.modulate = ORANGE
	board.outline_size = 0
	board.position = Vector3(3.4, 2.55, -4.59)
	menu_world.add_child(board)
	var note := Label3D.new()
	note.font = FONT
	note.text = "FINAL GRADE\nเข้าเรียน 0 / 15"
	note.font_size = 40
	note.pixel_size = 0.005
	note.position = Vector3(3.4, 1.5, -4.55)
	menu_world.add_child(note)
	for item: Array in [["student", Vector3(5.4, 0, 1.5), 0.5], ["phone", Vector3(0.6, 1.05, -1.1), 0.0], ["book", Vector3(1.45, 1.05, -1.55), 0.1]]:
		var path: String = "res://Assets/Models/%s.glb" % item[0]
		if ResourceLoader.exists(path):
			var model: Node3D = load(path).instantiate()
			menu_world.add_child(model)
			model.position = item[1]
			model.rotation.y = item[2] + PI
			var animator := _find_animator(model)
			if animator:
				for clip: StringName in animator.get_animation_list():
					if String(clip).to_lower() in ["idle", "screenloop"]:
						animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
						animator.play(clip)
						break
	menu_camera = Camera3D.new()
	add_child(menu_camera)
	menu_camera.position = Vector3(6.3, 2.9, 7.4)
	menu_camera.look_at(Vector3(2.0, 1.75, -1.5))
	menu_camera.fov = 49
	menu_camera.current = true

func _menu_sign(copy: String, pos: Vector3, font_size: int, pixel_size: float, color: Color) -> void:
	var label := Label3D.new()
	label.font = FONT
	label.text = copy
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	menu_world.add_child(label)

func _find_animator(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var animator := _find_animator(child)
		if animator: return animator
	return null

func _menu_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material_override = material
	mesh.position = pos
	menu_world.add_child(mesh)

func panel_style(color: Color, border: Color = Color.TRANSPARENT, padding: float = 24.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
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
	button.custom_minimum_size.y = 46
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("7d898d"))
	button.add_theme_stylebox_override("normal", panel_style(ORANGE if primary else Color("253234"), ORANGE if primary else Color("425350"), 11))
	button.add_theme_stylebox_override("hover", panel_style(CREAM, CREAM, 11))
	button.add_theme_stylebox_override("pressed", panel_style(MINT, MINT, 11))
	var focus_style := panel_style(Color.TRANSPARENT, MINT, 11)
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_color_override("font_focus_color", CREAM if not primary else INK)
	button.add_theme_stylebox_override("disabled", panel_style(Color("1c2729"), Color("303f40"), 11))
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
	tween.tween_property(button, "modulate", Color.WHITE if active else Color("e9eeea"), 0.12)
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
	ui.theme = theme
	canvas.add_child(ui)
	menu_backdrop = ColorRect.new()
	menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float shade = mix(0.86, 0.03, smoothstep(0.1,0.75,UV.x)); COLOR=vec4(0.045,0.075,0.075,shade); }"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	menu_backdrop.material = shader_material
	ui.add_child(menu_backdrop)
	main_menu = PanelContainer.new()
	ui.add_child(main_menu)
	main_menu.add_theme_stylebox_override("panel", panel_style(Color("142325f5"), Color("58736a"), 26))
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	main_menu.add_child(menu_scroll)
	menu_stack = VBoxContainer.new()
	menu_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_stack.add_theme_constant_override("separation", 9)
	menu_scroll.add_child(menu_stack)
	menu_stack.add_child(_label("CP410844   /   GROUP 03", 13, MINT))
	menu_title = _label("การล้างแค้น\nของนักศึกษาติด F", 37)
	menu_title.add_theme_constant_override("line_spacing", -2)
	menu_stack.add_child(menu_title)
	var subtitle := _label("เกรดไม่ผ่าน แต่หมัดผ่านทุกวิชา\nสามด่าน · สามอาจารย์ · หนึ่งวันล้างแค้น", 16, Color("b6c5bd"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_stack.add_child(subtitle)
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 10)
	menu_stack.add_child(divider)
	menu_stack.add_child(_button("01   เริ่มล้างแค้น", _new_game, true))
	continue_button = _button("02   เล่นต่อจากจุดล่าสุด", _continue_game)
	menu_stack.add_child(continue_button)
	menu_stack.add_child(_button("03   เลือกด่านสำหรับเดโม", _show_stage_select))
	menu_stack.add_child(_button("04   วิธีเล่นและคอมโบ", _show_help))
	menu_stack.add_child(_button("05   ตั้งค่า", _show_settings))
	menu_stack.add_child(_button("06   เครดิตและที่มา", _show_credits))
	menu_stack.add_child(_label("WASD + เมาส์    /    เดโม 3 ด่าน", 13, Color("9fb3aa")))
	menu_dossier = PanelContainer.new()
	menu_dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_dossier.add_theme_stylebox_override("panel", panel_style(CREAM, Color("e4d7b6"), 18))
	ui.add_child(menu_dossier)
	var dossier_stack := VBoxContainer.new()
	menu_dossier.add_child(dossier_stack)
	dossier_stack.add_child(_label("ACADEMIC RECORD  /  000-F", 11, Color("5e756b")))
	dossier_stack.add_child(_label("เข้าเรียน 0 / 15   ส่งงาน 0 / 8", 16, INK))
	dossier_stack.add_child(_label("คำร้องขอแก้เกรด: ใช้กำปั้น", 17, Color("93452f")))
	dossier_stack.add_child(_label("สถานะ  •  พร้อมกลับเข้าตึก", 12, Color("5e756b")))
	_build_hud()
	modal_scrim = ColorRect.new()
	modal_scrim.color = Color("061011b3")
	modal_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal_scrim)
	modal_scrim.hide()
	modal = PanelContainer.new()
	ui.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.add_theme_stylebox_override("panel", panel_style(Color("142326"), Color("718b7e"), 26))
	modal_scroll = ScrollContainer.new()
	modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_scroll.follow_focus = true
	modal.add_child(modal_scroll)
	modal_stack = VBoxContainer.new()
	modal_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_stack.add_theme_constant_override("separation", 12)
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
	stats_panel.add_theme_stylebox_override("panel", panel_style(Color("102125e8"), Color("647c70"), 14))
	var stack := VBoxContainer.new()
	stats_panel.add_child(stack)
	health_label = _label("นักศึกษา  /  100", 19)
	stack.add_child(health_label)
	health_bar = _bar(stack, ORANGE, 10)
	var posture_text := _label("สมดุล", 12, Color("c4ccc4"))
	stack.add_child(posture_text)
	posture_bar = _bar(stack, Color("e4b75f"), 5)
	stack.add_child(_label("สมาธิ   /   Q ใช้ 50", 12, MINT))
	focus_bar = _bar(stack, MINT, 5)
	objective_label = _label("", 17)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_stylebox_override("normal", panel_style(Color("102125df"), Color("485e55"), 12))
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
	boss_label = _label("", 23)
	boss_label.add_theme_color_override("font_shadow_color", INK)
	boss_label.add_theme_constant_override("shadow_offset_y", 2)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_label)
	boss_bar = _bar(boss_panel, ORANGE, 10)
	boss_structure = _bar(boss_panel, Color("e5bb65"), 4)
	combo_label = _label("", 35, CREAM)
	hud_root.add_child(combo_label)
	combo_label.position = Vector2(28, 164)
	timer_label = _label("", 14, Color("d0d8d5"))
	hud_root.add_child(timer_label)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	timer_label.position = Vector2(28, -92)
	control_hint = _label("WASD เดิน   /   L · H โจมตี   /   Shift การ์ด   /   Space หลบ   /   Q พิเศษ   /   E ใช้   /   Esc พัก", 14)
	control_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_hint.add_theme_stylebox_override("normal", panel_style(Color("102125cf"), Color.TRANSPARENT, 8))
	hud_root.add_child(control_hint)
	control_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	control_hint.offset_top = -34
	control_hint.offset_bottom = -8
	control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_hint.add_theme_color_override("font_shadow_color", INK)
	control_hint.add_theme_constant_override("shadow_offset_x", 1)
	control_hint.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label = _label("", 20, MINT)
	hud_root.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -350
	prompt_label.offset_right = 350
	prompt_label.offset_top = -102
	prompt_label.offset_bottom = -68
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _label("", 21, CREAM)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_stylebox_override("normal", panel_style(Color("102125ef"), Color("6a8475"), 12))
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
	menu_title.add_theme_font_size_override("font_size", 37 if menu_width >= 460 else 30)
	menu_dossier.position = Vector2(viewport_size.x - 346.0, viewport_size.y - 154.0)
	menu_dossier.size = Vector2(318, 122)
	menu_dossier.visible = main_menu.visible and viewport_size.x >= 1050 and viewport_size.y >= 600
	stats_panel.position = Vector2(margin, margin)
	stats_panel.size = Vector2(254, 138)
	objective_label.offset_left = -minf(300, viewport_size.x * 0.32) - margin
	objective_label.offset_right = -margin
	objective_label.offset_top = margin
	objective_label.offset_bottom = margin + 100
	var boss_width := minf(430, viewport_size.x - 2 * margin)
	boss_panel.offset_left = -boss_width / 2
	boss_panel.offset_right = boss_width / 2
	boss_panel.offset_top = margin if viewport_size.x >= 1120 else 183.0
	boss_panel.offset_bottom = boss_panel.offset_top + 90
	combo_label.position = Vector2(margin + 4, 188)
	timer_label.offset_left = margin
	timer_label.offset_top = -99
	control_hint.offset_left = margin
	control_hint.offset_right = -margin
	control_hint.offset_top = -60
	control_hint.offset_bottom = -16
	toast.offset_left = -minf(420, viewport_size.x / 2 - margin)
	toast.offset_right = minf(420, viewport_size.x / 2 - margin)
	toast.offset_top = -169
	toast.offset_bottom = -109
	prompt_label.offset_left = -minf(300, viewport_size.x / 2 - margin)
	prompt_label.offset_right = minf(300, viewport_size.x / 2 - margin)
	_layout_modal()

func _layout_modal() -> void:
	if not is_instance_valid(modal) or not is_instance_valid(ui): return
	var width := minf(660, ui.size.x - 32)
	var height := clampf(modal_stack.get_combined_minimum_size().y + 52, 220, maxf(220, ui.size.y - 40))
	modal.offset_left = -width / 2
	modal.offset_right = width / 2
	modal.offset_top = -height / 2
	modal.offset_bottom = height / 2

func _modal_visibility_changed() -> void:
	if not modal or not modal_scrim: return
	modal_scrim.visible = modal.visible
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
	bar.add_theme_stylebox_override("background", panel_style(Color("35414b"), Color.TRANSPARENT, 0))
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
	var heading := _label(title, 29, ORANGE)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_stack.add_child(heading)
	var body := _label(copy, 18)
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
		modal_stack.get_child(2).grab_focus()

func _show_main_menu() -> void:
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
	menu_backdrop.show()
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
	menu_dossier.hide()
	show_modal("ผลการเรียนออกแล้ว", "เข้าเรียน 0 / 15     ส่งงาน 0 / 8\nเกรดที่ได้รับ: F\n\nคุณเป็นนักศึกษาที่ชอบโดดเรียน\nแต่วันนี้คุณมีเหตุผลที่จะกลับเข้าตึก\n\nผ่านอาจารย์ทั้งสาม ไปหาอาจารย์ Web App\nและทำลายระบบ F กลางให้ได้", [{"text": "ถึงเวลาเข้าเรียน…ด้วยหมัด", "callback": func() -> void:
		save_data.clear()
		elapsed = 0.0
		deaths = 0
		start_level(0, 0), "primary": true}])

func _continue_game() -> void:
	if save_data.is_empty():
		notify("ยังไม่มีจุดบันทึก เลือกเริ่มล้างแค้นได้เลย", 3)
		return
	start_level(int(save_data.get("stage", 0)), int(save_data.get("checkpoint", 0)))

func _show_stage_select() -> void:
	var actions: Array = []
	for index in range(3):
		var selected := index
		actions.append({"text": "%02d   %s" % [index + 1, STAGE_NAMES[index]], "callback": func() -> void: start_level(selected, 0), "primary": index == 0})
	actions.append({"text": "กลับ", "callback": func() -> void: modal.hide()})
	show_modal("เลือกด่านสำหรับเดโม", "เปิดให้ลองครบทั้งสามด่าน\nคอมโบทั้งหมดใช้ได้ตั้งแต่เริ่ม", actions)

func _show_help() -> void:
	show_modal("วิธีเล่น", "WASD เดิน · เมาส์หมุนกล้อง · R หันกล้องกลับ\nคลิกซ้าย (L) / J = หมัดเบา\nคลิกขวา (H) / K = โจมตีหนัก\n\nL L L   แย็บ / หมัดตรง / ฮุก\nL L H   จบด้วยถีบ ผลักชนฉาก\nL H L   เตะกวาด แล้วต่อหมัด\n\nShift ค้าง = การ์ด · กดก่อนโดน = ปัดป้อง\nSpace + ทิศทาง = หลบ · Q = ท่าพิเศษ\nE = ปิดฉากศัตรูเสียหลัก / ขว้างสิ่งของ\n\nสัญลักษณ์ ! สีแดง = ท่าที่ต้องหลบ", [{"text": "เข้าใจแล้ว", "callback": func() -> void: modal.hide(), "primary": true}])

func _show_settings() -> void:
	show_modal("ตั้งค่า", "ปรับให้เหมาะกับเครื่องและการควบคุมของคุณ")
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
	quality.add_item("ภาพประหยัด  /  ปิดเงา")
	quality.add_item("ภาพปกติ  /  เปิดเงา")
	quality.custom_minimum_size.y = 40
	quality.select(int(settings.quality))
	quality.item_selected.connect(func(index: int) -> void:
		settings.quality = index
		_apply_settings())
	modal_stack.add_child(quality)
	modal_stack.add_child(_button("บันทึกและกลับ", func() -> void:
		_write_save()
		if paused: _show_pause()
		else: modal.hide(), true))
	modal_stack.get_child(3).grab_focus()
	_layout_modal.call_deferred()

func _show_credits() -> void:
	show_modal("สร้างจากของจริง แล้วปรับให้เป็นเรา", "โครงการรายวิชา CP410844 · กลุ่ม 3\n\nGodot 4.7.2 / Blender 5.2\nเมนูและลำดับเกม: 3D-lab1 / SD Studios (MIT)\nการเคลื่อนที่และกล้อง: Jeh3no (MIT)\nตัวละครและแอนิเมชัน: Quaternius (CC0)\nเฟอร์นิเจอร์และเสียง: Kenney (CC0)\nโมเดลประกอบ: ดู ASSET_CREDITS ใน repository\nฟอนต์ Noto Sans Thai (SIL OFL)\n\nตัวละครและมหาวิทยาลัยเป็นเรื่องสมมติ\nหน้าจอคลิปและบทพูดสร้างเพื่อเกมนี้\nรายละเอียดการดัดแปลงอยู่ใน source และไฟล์ Blender", [{"text": "กลับ", "callback": func() -> void: modal.hide(), "primary": true}])

func start_level(index: int, checkpoint: int = 0) -> void:
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
	notify(STAGE_NAMES[stage_index], 3.5)
	if stage_index == 0 and checkpoint_index == 0:
		var tutorial_run := _run_id
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			if running and not paused and tutorial_run == _run_id and stage_index == 0: notify("คลิกซ้ายสามจังหวะเพื่อต่อคอมโบ · Space หลบ", 5.0))

func _on_encounter_changed(checkpoint: int, title: String) -> void:
	checkpoint_index = checkpoint
	if checkpoint == 2 and is_instance_valid(player):
		player.health = 100.0
		player.focus = maxf(player.focus, 50.0)
	_write_save()
	notify(title, 4.0)

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
		show_modal("ผ่านวิชานี้แล้ว", "%s\n\nอาจารย์คนถัดไปรออยู่ชั้นบน" % STAGE_NAMES[stage_index], [
			{"text": "ขึ้นชั้นถัดไป", "callback": func() -> void: start_level(stage_index + 1, 0), "primary": true},
			{"text": "กลับเมนู", "callback": _show_main_menu}])
	else:
		save_data["complete"] = true
		_write_save()
		audio.set_combat(false)
		show_modal("200 OK  /  ล้างแค้นสำเร็จ", "ระบบเกรดปิดปรับปรุง ไม่มีกำหนดเปิดอีกครั้ง\n\nสามวิชา สามอาจารย์ และแกน F ที่พังไปแล้ว\nคุณเดินออกจากตึก…\nเครื่องพิมพ์พยายามพิมพ์ F ใบสุดท้าย แต่กระดาษติด\n\nเวลา %s    แก้มือ %d ครั้ง\n\nขอบคุณที่เล่นเดโมของกลุ่ม 3" % [_format_time(), deaths], [
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
	show_modal("พักก่อน เดี๋ยวค่อยล้างแค้น", "L L L หมัดต่อเนื่อง · L L H ถีบ · L H L กวาด\nShift ปัดป้อง · Space หลบ · Q ท่าพิเศษ · E ปิดฉาก", [
		{"text": "เล่นต่อ", "callback": _resume, "primary": true},
		{"text": "เริ่มช่วงนี้ใหม่", "callback": func() -> void: start_level(stage_index, checkpoint_index)},
		{"text": "ตั้งค่า", "callback": _show_settings},
		{"text": "กลับเมนู", "callback": _show_main_menu}])

func _resume() -> void:
	if not running or not is_instance_valid(player) or player.dead:
		return
	paused = false
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
	_set_label(objective_label, "%s\n%s" % [STAGE_SUBTITLES[stage_index], level.get_objective()])
	_set_label(combo_label, "%02d HITS" % player.combo_hits if player.combo_hits > 1 else "")
	_set_label(timer_label, "%s   /   แก้มือ %d ครั้ง" % [_format_time(), deaths])
	var boss: Node = level.get_boss()
	boss_panel.visible = is_instance_valid(boss) and not boss.dead
	if boss_panel.visible:
		_set_label(boss_label, boss.display_name)
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
		boss_structure.max_value = boss.max_posture
		boss_structure.value = boss.posture
	var target: Node3D = player.nearest_enemy(2.4, false, true)
	_set_label(prompt_label, "[ E ]  ปิดฉาก" if target else "")

func notify(text: String, duration: float = 2.5) -> void:
	if not toast or (modal and modal.visible): return
	toast.text = text
	toast_timer = duration
	toast.show()

func _format_time() -> String:
	return "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]

func _load_save() -> void:
	if has_meta("qa_no_save"): return
	if not FileAccess.file_exists("user://progress.json"): return
	var file := FileAccess.open("user://progress.json", FileAccess.READ)
	if not file: return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return
	var progress = data.get("progress", {})
	if progress is Dictionary and typeof(progress.get("stage")) in [TYPE_INT, TYPE_FLOAT] and typeof(progress.get("checkpoint")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(progress.stage)) and is_finite(float(progress.checkpoint)):
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
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "progress": save_data, "settings": settings}))
	else:
		notify("เล่นต่อได้ แต่เบราว์เซอร์นี้บันทึกข้ามรอบไม่ได้", 4.0)

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(settings.volume))))
	AudioServer.set_bus_mute(0, float(settings.volume) <= 0.0)
	if sun: sun.shadow_enabled = int(settings.quality) > 0
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
