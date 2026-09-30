extends Control
## Static vector ornament. Redrawn only on resize; no per-frame shader or animation.

const BONE := Color("e8dfcc")
const BRASS := Color("b79a66")
const BLOOD := Color("9d343d")
const ASH := Color("a39a91")
const TEAL := Color("81aaa7")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var c := Color(BRASS, 0.65)
	for p: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		var d := Vector2(1 if p.x == 0 else -1, 1 if p.y == 0 else -1)
		draw_line(p, p + Vector2(22 * d.x, 0), c, 1)
		draw_line(p, p + Vector2(0, 22 * d.y), c, 1)
	var x := size.x / 2
	draw_colored_polygon(PackedVector2Array([Vector2(x, -3), Vector2(x + 4, 1), Vector2(x, 5), Vector2(x - 4, 1)]), BLOOD)

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
		theme.set_stylebox("normal", type, flat(Color("1d191b"), Color("403437")))
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
