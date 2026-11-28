extends CanvasLayer
## Conversation panel: what the person says on the left, topics and actions on the right.

const UI = preload("res://scripts/ui.gd")

var npc: Node = null
var _root: Control
var _name: Label
var _sub: Label
var _text: RichTextLabel
var _list: VBoxContainer

func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 70)
	m.add_theme_constant_override("margin_top", 250)
	m.add_theme_constant_override("margin_bottom", 40)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	h.add_child(left)
	_name = UI.text(left, "", 28, UI.GOLD)
	_sub = UI.text(left, "", 16, Color(0.7, 0.68, 0.6))
	_text = UI.rich(left, 20)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	_root.visible = false

func active() -> bool:
	return _root.visible

func open(n: Node) -> void:
	npc = n
	_name.text = n.npc_name
	_text.clear()
	_text.append_text(n.greeting() + "\n")
	_root.visible = true
	UI.open_modal()
	_rebuild()

func close() -> void:
	if not active():
		return
	_root.visible = false
	UI.close_modal()

func _unhandled_input(ev: InputEvent) -> void:
	if active() and ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _rebuild() -> void:
	_sub.text = npc.role
	UI.clear(_list)
	for t in npc.topics():
		UI.button(_list, t, _ask.bind(t), 17)
	for a in npc.actions():
		var b := UI.button(_list, "›  " + a[0], _act.bind(a[1]), 17)
		if String(a[0]).begins_with("Attack"):
			b.add_theme_color_override("font_color", Color(0.85, 0.4, 0.35))
	UI.button(_list, "Goodbye", close, 17)

func _ask(t: String) -> void:
	_text.append_text("\n[color=#edc259]%s[/color]\n%s\n" % [t, npc.topic_text(t)])
	if active():
		_rebuild()

func _act(cb: Callable) -> void:
	var reply: String = cb.call()
	if not active():
		return
	if reply != "":
		_text.append_text("\n[i]%s[/i]\n" % reply)
	_rebuild()
