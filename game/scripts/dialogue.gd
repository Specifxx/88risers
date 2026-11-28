extends CanvasLayer
## Conversation panel: what the person says on the left, topics and actions on the right.

const UI = preload("res://scripts/ui.gd")

var npc: Node = null
var _root: Control
var _name: Label
var _sub: Label
var _text: RichTextLabel
var _list: VBoxContainer
var _portrait: TextureRect
var _mind: Label
var _neurons: HBoxContainer

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
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(250, 0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_portrait)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	h.add_child(left)
	_name = UI.text(left, "", 28, UI.GOLD)
	_sub = UI.text(left, "", 16, Color(0.7, 0.68, 0.6))
	var mind_row := HBoxContainer.new()
	mind_row.add_theme_constant_override("separation", 10)
	left.add_child(mind_row)
	_neurons = HBoxContainer.new()
	_neurons.add_theme_constant_override("separation", 3)
	mind_row.add_child(_neurons)
	for i in 10:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		_neurons.add_child(dot)
	_mind = UI.text(mind_row, "", 15, Color(0.75, 0.72, 0.62))
	_mind.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	var pic: String = n.portrait()
	_portrait.visible = pic != ""
	if pic != "":
		_portrait.texture = load("res://assets/portraits/%s.jpg" % pic)
	_text.clear()
	_text.append_text(n.greeting() + "\n")
	_root.visible = true
	UI.open_modal()
	_rebuild()

## A guard has come over about what you owe.
func confront(guard: Node) -> void:
	if active() or Game.modal:
		return
	npc = guard
	_name.text = guard.npc_name
	var pic: String = guard.portrait()
	_portrait.visible = pic != ""
	if pic != "":
		_portrait.texture = load("res://assets/portraits/%s.jpg" % pic)
	var owed: int = Game.bounty[guard.village]
	_text.clear()
	_text.append_text("\"You. Stand where you are. People here have told me what you did.\n\nIt is %d coin to settle it. Pay, or we do this the other way.\"\n" % owed)
	_root.visible = true
	UI.open_modal()
	_sub.text = guard.role
	_show_mind()
	UI.clear(_list)
	UI.button(_list, "Pay the %d coin" % owed, _pay.bind(owed), 17)
	UI.button(_list, "Talk your way down", _plead.bind(owed), 17)
	UI.button(_list, "Refuse", _refuse, 17).add_theme_color_override("font_color", Color(0.85, 0.4, 0.35))

func _settle(text: String) -> void:
	_text.append_text("\n[i]%s[/i]\n" % text)
	UI.clear(_list)
	UI.button(_list, "Goodbye", close, 17)

func _pay(owed: int) -> void:
	if Game.coins < owed:
		_text.append_text("\n[i]You haven't that much. They can see it.[/i]\n")
		return
	Game.coins -= owed
	Game.bounty[npc.village] = 0
	Game.touch()
	_settle("They count it. \"That settles the law. It doesn't settle what people think of you.\"")

func _plead(owed: int) -> void:
	Game.train("speech", 2.0)
	if randf() < 0.25 + Game.skills["speech"] * 0.012 + npc.mind.feeling() * 0.3:
		var less := int(owed / 2.0)
		Game.bounty[npc.village] = less
		_settle("They hear you out. \"%d, then. And I'm watching you.\" They will ask again." % less)
	else:
		_settle("\"Save it.\" The price stands. They will ask again.")

func _refuse() -> void:
	close()
	npc.say_aloud("Then we do it the other way.")
	npc._flee = false
	npc.aggro = true
	for n in Game.villagers(npc.village):
		if n.def.get("guard", false):
			n._flee = false
			n.aggro = true

func close() -> void:
	if not active():
		return
	_root.visible = false
	UI.close_modal()

func _unhandled_input(ev: InputEvent) -> void:
	if active() and ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

## Their mind, as much as you can read of it: how they seem towards you, how well they
## know you, and the units of their network firing as they think about you.
func _show_mind() -> void:
	var m = npc.mind
	m.feeling()
	for i in _neurons.get_child_count():
		var a: float = m.activity[i]
		(_neurons.get_child(i) as ColorRect).color = Color(0.25, 0.22, 0.2).lerp(Color(0.95, 0.75, 0.3) if a > 0.0 else Color(0.45, 0.6, 0.95), absf(a))
	var known := "a stranger to them" if m.familiarity < 0.2 else ("knows you a little" if m.familiarity < 0.6 else "knows you well")
	_mind.text = "Seems %s  ·  %s  ·  remembers %d thing%s about you" % [m.state_word(), known, m.memories.size(), "" if m.memories.size() == 1 else "s"]

func _rebuild() -> void:
	_sub.text = npc.role
	_show_mind()
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
