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
var settings: Dictionary = {"volume": 0.75, "sfx": 0.8, "sensitivity": 1.0, "shake": true, "quality": 1}
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
			InputMap.action_add_event(action, event)
	for pair: Array in [["light_attack", MOUSE_BUTTON_LEFT], ["heavy_attack", MOUSE_BUTTON_RIGHT]]:
		var event := InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

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
	add_child(menu_world)
	_menu_box(Vector3(0, -0.16, 0), Vector3(30, 0.3, 25), Color("465059"))
	_menu_box(Vector3(0, 2.3, -5), Vector3(22, 4.6, 0.3), Color("bdc2b8"))
	_menu_box(Vector3(1, 2.15, -4.78), Vector3(8, 2.5, 0.08), Color("273d39"))
	_menu_box(Vector3(1.0, 0.95, -1.0), Vector3(3.0, 0.14, 1.2), Color("b57a4b"))
	for x in [-0.2, 2.2]:
		_menu_box(Vector3(x, 0.45, -1.0), Vector3(0.10, 0.95, 0.85), Color("28323c"))
	for x in [-5.0, -2.0, 5.0]:
		_menu_box(Vector3(x, 4.2, -1.2), Vector3(1.8, 0.035, 0.45), Color("fff2cb"))
	var board := Label3D.new()
	board.font = FONT
	board.text = "F"
	board.font_size = 190
	board.pixel_size = 0.008
	board.modulate = ORANGE
	board.outline_size = 0
	board.position = Vector3(2.4, 2.5, -4.65)
	menu_world.add_child(board)
	var note := Label3D.new()
	note.font = FONT
	note.text = "FINAL GRADE\nเข้าเรียน 0 / 15"
	note.font_size = 40
	note.pixel_size = 0.005
	note.position = Vector3(2.4, 1.45, -4.6)
	menu_world.add_child(note)
	for item: Array in [["student", Vector3(3.3, 0, 0.4), 0.55], ["phone", Vector3(0.7, 1.05, -0.8), 0.0], ["book", Vector3(1.5, 1.05, -1.2), 0.1]]:
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
	menu_camera.position = Vector3(6, 2.5, 6.2)
	menu_camera.look_at(Vector3(1.6, 1.35, -1.4))
	menu_camera.fov = 55
	menu_camera.current = true

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
	button.custom_minimum_size.y = 44
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", panel_style(ORANGE if primary else Color("252e3be8"), Color("4a5360"), 10))
	button.add_theme_stylebox_override("hover", panel_style(CREAM, CREAM, 10))
	button.add_theme_stylebox_override("focus", panel_style(MINT, MINT, 10))
	button.pressed.connect(func() -> void:
		if audio: audio.play_effect("ui")
		callback.call())
	return button

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
	main_menu = PanelContainer.new()
	ui.add_child(main_menu)
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	main_menu.offset_left = 46
	main_menu.offset_right = 573
	main_menu.offset_top = -320
	main_menu.offset_bottom = 320
	main_menu.add_theme_stylebox_override("panel", panel_style(Color("151b24ef"), Color("727466"), 30))
	menu_stack = VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 8)
	main_menu.add_child(menu_stack)
	menu_stack.add_child(_label("CP410844  /  GROUP 03  /  PLAYABLE DEMO", 13, MINT))
	menu_stack.add_child(_label("การล้างแค้น\nของนักศึกษาติด F", 40))
	var subtitle := _label("เกรดไม่ผ่าน แต่หมัดผ่านทุกวิชา\nสามด่าน · สามอาจารย์ · หนึ่งวันล้างแค้น", 17, Color("b8c0c7"))
	menu_stack.add_child(subtitle)
	menu_stack.add_child(_button("01   เริ่มล้างแค้น", _new_game, true))
	menu_stack.add_child(_button("02   เล่นต่อจากจุดล่าสุด", _continue_game))
	menu_stack.add_child(_button("03   เลือกด่านสำหรับเดโม", _show_stage_select))
	menu_stack.add_child(_button("04   วิธีเล่นและคอมโบ", _show_help))
	menu_stack.add_child(_button("05   ตั้งค่า", _show_settings))
	menu_stack.add_child(_button("06   เครดิตและที่มา", _show_credits))
	menu_stack.add_child(_label("คีย์บอร์ด + เมาส์  /  แนะนำเปิดเต็มหน้าจอ", 13, Color("a4abae")))
	modal = PanelContainer.new()
	ui.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -335
	modal.offset_right = 335
	modal.offset_top = -285
	modal.offset_bottom = 285
	modal.add_theme_stylebox_override("panel", panel_style(Color("141c27fc"), Color("758580"), 32))
	modal_stack = VBoxContainer.new()
	modal_stack.add_theme_constant_override("separation", 12)
	modal.add_child(modal_stack)
	modal.hide()
	_build_hud()

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_root)
	ui.move_child(modal, ui.get_child_count() - 1)
	var stats := PanelContainer.new()
	hud_root.add_child(stats)
	stats.position = Vector2(24, 22)
	stats.custom_minimum_size = Vector2(285, 122)
	stats.add_theme_stylebox_override("panel", panel_style(Color("121a23da"), Color("56625d"), 16))
	var stack := VBoxContainer.new()
	stats.add_child(stack)
	health_label = _label("นักศึกษา  /  100", 19)
	stack.add_child(health_label)
	health_bar = _bar(stack, ORANGE, 12)
	var posture_text := _label("เสียสมดุล", 11, Color("bbc2c7"))
	stack.add_child(posture_text)
	posture_bar = _bar(stack, Color("e4b75f"), 5)
	stack.add_child(_label("สมาธิ  /  Q ใช้ 50", 11, MINT))
	focus_bar = _bar(stack, MINT, 5)
	objective_label = _label("", 17)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	control_hint = _label("WASD เดิน   •   คลิกซ้าย / ขวา โจมตี   •   Shift การ์ด   •   Space หลบ   •   Q ท่าพิเศษ   •   Esc พัก", 14)
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
	for child in modal_stack.get_children():
		modal_stack.remove_child(child)
		child.queue_free()
	modal_stack.add_child(_label(title, 30, ORANGE))
	var body := _label(copy, 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_stack.add_child(body)
	for action: Dictionary in actions:
		modal_stack.add_child(_button(action.text, action.callback, action.get("primary", false)))
	modal.show()
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
	menu_camera.current = true
	main_menu.show()
	modal.hide()
	hud_root.hide()
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
	show_modal("วิธีเล่น", "WASD เดิน · เมาส์หมุนกล้อง · R หันกล้องกลับ\nคลิกซ้าย (L) / J = หมัดเบา\nคลิกขวา (H) / K = โจมตีหนัก\n\nL L L   แย็บ → หมัดตรง → ฮุก\nL L H   จบด้วยถีบ ผลักชนฉาก\nL H L   เตะกวาด แล้วต่อหมัด\n\nShift ค้าง = การ์ด · กดก่อนโดน = ปัดป้อง\nSpace + ทิศทาง = หลบ · Q = ท่าพิเศษ\nE = ปิดฉากศัตรูเสียหลัก / ขว้างสิ่งของ\n\nสัญลักษณ์ ! สีแดง = ท่าที่ต้องหลบ", [{"text": "เข้าใจแล้ว", "callback": func() -> void: modal.hide(), "primary": true}])

func _show_settings() -> void:
	show_modal("ตั้งค่า", "ปรับให้เหมาะกับเครื่องและการควบคุมของคุณ")
	for row: Array in [["เสียงหลัก", "volume", 0.0, 1.0], ["เสียงเอฟเฟกต์", "sfx", 0.0, 1.0], ["ความไวเมาส์", "sensitivity", 0.3, 2.0]]:
		modal_stack.add_child(_label(row[0], 17))
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = 0.05
		slider.value = float(settings[row[1]])
		var key: String = row[1]
		slider.value_changed.connect(func(value: float) -> void:
			settings[key] = value
			_apply_settings())
		modal_stack.add_child(slider)
	var shake := CheckButton.new()
	shake.text = "กล้องสั่นเมื่อปะทะ"
	shake.button_pressed = settings.shake
	shake.toggled.connect(func(value: bool) -> void:
		settings.shake = value
		_apply_settings())
	modal_stack.add_child(shake)
	var quality := OptionButton.new()
	quality.add_item("ภาพต่ำ / ลดเงา")
	quality.add_item("ภาพปกติ")
	quality.select(int(settings.quality))
	quality.item_selected.connect(func(index: int) -> void:
		settings.quality = index
		_apply_settings())
	modal_stack.add_child(quality)
	modal_stack.add_child(_button("บันทึกและกลับ", func() -> void:
		_write_save()
		if paused: _show_pause()
		else: modal.hide(), true))

func _show_credits() -> void:
	show_modal("สร้างจากของจริง แล้วปรับให้เป็นเรา", "โครงการรายวิชา CP410844 · กลุ่ม 3\n\nGodot 4.7.2 / Blender 5.2\nเมนูและลำดับเกม: 3D-lab1 / SD Studios (MIT)\nการเคลื่อนที่และกล้อง: Jeh3no (MIT)\nตัวละครและแอนิเมชัน: Quaternius (CC0)\nเฟอร์นิเจอร์และเสียง: Kenney (CC0)\nโมเดลประกอบ: ดู ASSET_CREDITS ใน repository\nฟอนต์ Noto Sans Thai (SIL OFL)\n\nตัวละครและมหาวิทยาลัยเป็นเรื่องสมมติ\nหน้าจอคลิปและบทพูดสร้างเพื่อเกมนี้\nรายละเอียดการดัดแปลงอยู่ใน source และไฟล์ Blender", [{"text": "กลับ", "callback": func() -> void: modal.hide(), "primary": true}])

func start_level(index: int, checkpoint: int = 0) -> void:
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
	main_menu.hide()
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
	player.stage_ref = level
	player.focus = 50.0 if checkpoint_index == 2 else 0.0
	player.camera_rig.global_position = player.global_position + Vector3.UP * 1.55
	player.message.connect(notify)
	player.defeated.connect(_on_defeated)
	level.encounter_changed.connect(_on_encounter_changed)
	level.stage_completed.connect(_on_stage_completed)
	level.start(player)
	_apply_settings()
	hud_root.show()
	_last_health = 100.0
	_mouse_loss_time = 0.0
	_capture_stable_time = 0.0
	_capture_was_active = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio.set_combat(true)
	_write_save()
	notify(STAGE_NAMES[stage_index], 3.5)
	if stage_index == 0 and checkpoint_index == 0:
		get_tree().create_timer(3.5).timeout.connect(func() -> void:
			if running and stage_index == 0: notify("คลิกซ้ายสามจังหวะเพื่อต่อคอมโบ · Space หลบ", 5.0))

func _on_encounter_changed(checkpoint: int, title: String) -> void:
	checkpoint_index = checkpoint
	if checkpoint == 2 and is_instance_valid(player):
		player.health = 100.0
		player.focus = maxf(player.focus, 50.0)
	_write_save()
	notify(title, 4.0)

func _on_defeated() -> void:
	deaths += 1
	get_tree().create_timer(1.25).timeout.connect(func() -> void:
		if not running or not is_instance_valid(player) or not player.dead: return
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
	health_label.text = "นักศึกษา  /  %03d" % ceili(player.health)
	health_bar.value = player.health
	posture_bar.value = player.posture
	focus_bar.value = player.focus
	objective_label.text = "%s\n%s" % [STAGE_SUBTITLES[stage_index], level.get_objective()]
	combo_label.text = "%02d HITS" % player.combo_hits if player.combo_hits > 1 else ""
	timer_label.text = "%s   /   แก้มือ %d ครั้ง" % [_format_time(), deaths]
	var boss: Node = level.get_boss()
	boss_panel.visible = is_instance_valid(boss) and not boss.dead
	if boss_panel.visible:
		boss_label.text = boss.display_name
		boss_bar.max_value = boss.max_health
		boss_bar.value = boss.health
		boss_structure.max_value = boss.max_posture
		boss_structure.value = boss.posture
	var target: Node3D = player.nearest_enemy(2.4, false, true)
	prompt_label.text = "[ E ]  ปิดฉาก" if target else ""

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
	if progress is Dictionary and typeof(progress.get("stage")) in [TYPE_INT, TYPE_FLOAT] and typeof(progress.get("checkpoint")) in [TYPE_INT, TYPE_FLOAT]:
		save_data = {"stage": clampi(int(progress.stage), 0, 2), "checkpoint": clampi(int(progress.checkpoint), 0, 2), "complete": progress.get("complete", false) == true}
	var stored = data.get("settings", {})
	if not stored is Dictionary: return
	for key: String in ["volume", "sfx", "sensitivity", "quality"]:
		if typeof(stored.get(key)) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(stored[key])):
			settings[key] = clampf(float(stored[key]), 0.3 if key == "sensitivity" else 0.0, 2.0 if key == "sensitivity" else 1.0)
	if typeof(stored.get("shake")) == TYPE_BOOL:
		settings.shake = stored.shake

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
	if sun: sun.shadow_enabled = int(settings.quality) > 0
	if audio: audio.effects_volume = float(settings.sfx)
	if is_instance_valid(player) and player.camera_rig:
		player.camera_rig.sensitivity = float(settings.sensitivity) * 0.0025
		player.camera_rig.shake_enabled = bool(settings.shake)
