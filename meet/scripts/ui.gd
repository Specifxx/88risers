extends RefCounted
## Small helpers shared by the on-screen panels.

const GOLD := Color(0.93, 0.76, 0.35)
const INK := Color(0.06, 0.05, 0.05, 0.93)
const PAPER := Color(0.93, 0.9, 0.82)

static func panel(parent: Node, color := INK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p

static func text(parent: Node, t: String, size := 20, color := PAPER) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

static func rich(parent: Node, size := 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_following = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", PAPER)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(r)
	return r

static func button(parent: Node, t: String, cb: Callable, size := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # so a list of these can still be dragged by touch
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.16, 0.13, 0.11)
	n.set_corner_radius_all(4)
	n.set_content_margin_all(9)
	var h: StyleBoxFlat = n.duplicate()
	h.bg_color = Color(0.3, 0.23, 0.12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func open_modal() -> void:
	Meet.modal = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

static func close_modal() -> void:
	Meet.modal = false
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
