extends TextureRect
## A piece of text drawn once into a small image, then shown as that image. Drawing letters
## one by one every frame is by far the most expensive thing the display did; this draws
## them only when the words change.

var _vp: SubViewport
var _label: Label
var _sig := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(8, 8)
	add_child(_vp)
	_label = Label.new()
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_vp.add_child(_label)
	texture = _vp.get_texture()

## width 0 means one line. align: 0 left, 1 centre, 2 right.
func show_text(t: String, font_size := 16, color := Color.WHITE, width := 0, align := 0, outline := 4) -> void:
	var sig := "%s|%d|%s|%d|%d|%d" % [t, font_size, color.to_html(), width, align, outline]
	if sig == _sig:
		return
	_sig = sig
	if t == "":
		_vp.size = Vector2i(8, 8)
		custom_minimum_size = Vector2.ZERO
		size = Vector2.ZERO
		_label.text = ""
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var f: Font = ThemeDB.fallback_font
	var sz: Vector2 = f.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, float(width) if width > 0 else -1.0, font_size)
	var pad := outline + 3
	var px := Vector2i(int(ceil(float(width) if width > 0 else sz.x)) + pad * 2, int(ceil(sz.y)) + pad * 2)
	_vp.size = px
	_label.text = t
	_label.position = Vector2(pad, pad)
	_label.size = Vector2(px.x - pad * 2, px.y - pad * 2)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > 0 else TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][align]
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_constant_override("outline_size", outline)
	custom_minimum_size = Vector2(px)
	size = Vector2(px)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
