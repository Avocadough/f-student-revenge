extends RefCounted
## Separate MSDF atlas for world signs; the tested native-resolution UI font stays untouched.
const FONT = preload("res://Assets/Fonts/NotoSansThaiWorld.ttf")

static func apply(label: Label3D, font_size: int = 64, pixel_size: float = 0.005) -> Label3D:
	label.font = FONT
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 2
	label.outline_modulate = Color(0.035, 0.045, 0.055, 0.92)
	label.shaded = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Three aligned doorways must not stack tiny text from several rooms together.
	label.visibility_range_end = 28.0
	return label
