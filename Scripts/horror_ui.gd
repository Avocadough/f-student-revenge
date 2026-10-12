extends Control
## Static vector ornament. Redrawn only on resize; no per-frame shader or animation.

const BONE := Color("e8dfcc")
const BRASS := Color("b79a66")
const BLOOD := Color("9d343d")
const ASH := Color("b3a99f")
const TEAL := Color("81aaa7")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var c := Color(BRASS, 0.65)
	draw_line(Vector2.ZERO, Vector2(minf(size.x * 0.3, 100), 0), c, 2)
	draw_line(Vector2(size.x - 32, size.y), size, c, 1)
	draw_line(size - Vector2(0, 16), size, c, 1)

static func rule_style(color: Color, edge: Color, padding: float = 12) -> StyleBoxFlat:
	var s := flat(color, edge, padding)
	s.set_border_width_all(0)
	s.border_width_bottom = 1
	return s

static func dossier_style(color: Color, accent: Color, padding: float = 14) -> StyleBoxFlat:
	var s := flat(color, Color.TRANSPARENT, padding)
	s.set_border_width_all(0)
	s.border_color = accent
	s.border_width_left = 3
	return s

static func flat(color: Color, edge: Color, padding: float = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_content_margin_all(padding)
	return s

static func apply(theme: Theme) -> void:
	var focus := flat(Color.TRANSPARENT, BRASS, 3)
	focus.set_border_width_all(2)
	for type in ["CheckButton", "OptionButton"]:
		theme.set_color("font_color", type, BONE)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, BONE)
		theme.set_stylebox("normal", type, rule_style(Color("1d191b"), Color("514349")))
		theme.set_stylebox("hover", type, flat(Color("302125"), BRASS))
		theme.set_stylebox("pressed", type, flat(Color("48262b"), BLOOD))
		theme.set_stylebox("focus", type, focus)
	theme.set_icon("checked", "CheckButton", preload("res://Assets/UI/switch_on.svg"))
	theme.set_icon("unchecked", "CheckButton", preload("res://Assets/UI/switch_off.svg"))
	theme.set_icon("arrow", "OptionButton", preload("res://Assets/UI/arrow.svg"))
	theme.set_constant("h_separation", "OptionButton", 12)
	var slider := flat(Color("342d30"), Color("57464a"), 0)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", flat(BLOOD, BLOOD, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", flat(BRASS, BRASS, 0))
	theme.set_icon("grabber", "HSlider", preload("res://Assets/UI/slider.svg"))
	theme.set_icon("grabber_highlight", "HSlider", preload("res://Assets/UI/slider.svg"))
	theme.set_stylebox("focus", "HSlider", focus)
	theme.set_stylebox("panel", "PopupMenu", flat(Color("171418"), BRASS, 10))
	theme.set_stylebox("hover", "PopupMenu", flat(Color("49272d"), BLOOD, 6))
	theme.set_color("font_color", "PopupMenu", BONE)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_constant("v_separation", "PopupMenu", 12)
	theme.set_stylebox("scroll", "VScrollBar", flat(Color("19161a"), Color.TRANSPARENT, 3))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		theme.set_stylebox(state, "VScrollBar", flat(Color("705150"), Color.TRANSPARENT, 3))
	var line := StyleBoxLine.new()
	line.color = Color("54413c")
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
