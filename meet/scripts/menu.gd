extends CanvasLayer
## What you can do with someone at the meet, and the notes people leave at the lanterns.

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")

var who: Node = null
var _root: Control
var _name: Label
var _sub: Label
var _text: RichTextLabel
var _list: VBoxContainer
var _card: TextureRect
var _dots: HBoxContainer
var _chats := {}
var _photos := {}
var _pick_a := ""

func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	m.add_theme_constant_override("margin_top", 250)
	m.add_theme_constant_override("margin_bottom", 30)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	_card = TextureRect.new()
	_card.custom_minimum_size = Vector2(230, 0)
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_card)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	h.add_child(left)
	_name = UI.text(left, "", 28, UI.GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 3)
	row.add_child(_dots)
	for i in 10:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(11, 11)
		_dots.add_child(d)
	_sub = UI.text(row, "", 15, Color(0.75, 0.72, 0.62))
	_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
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

func _show() -> void:
	if not active():
		_root.visible = true
		UI.open_modal()

func close() -> void:
	if active():
		_root.visible = false
		who = null
		UI.close_modal()

func _unhandled_input(ev: InputEvent) -> void:
	if active() and ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# --- People ------------------------------------------------------------------------

func open(r: Node) -> void:
	who = r
	_name.text = r.riser_name
	var pic: String = r.portrait()
	_card.visible = pic != ""
	if pic != "":
		_card.texture = load("res://assets/portraits/%s.jpg" % pic)
	_dots.visible = true
	_text.clear()
	var lines: Array = People.BARKS[r.bond()]
	var first: String = lines[randi() % lines.size()]
	if r.state == "search":
		first = "Have you seen my strap? It was in my bag."
	elif r.calling > 0.0:
		first = "There you are. Table. Now."
	elif r.passer:
		first = r.def["chat"][0]
	elif r.tonight.get("line", "") != "" and not _chats.has(r.id):
		first = r.tonight["line"]
	_text.append_text("[i]%s[/i]\n\n\"%s\"\n" % [r.role, first])
	_show()
	_options()

func _options() -> void:
	var m = who.mind
	m.feeling()
	for i in _dots.get_child_count():
		var a: float = m.activity[i]
		(_dots.get_child(i) as ColorRect).color = Color(0.25, 0.22, 0.2).lerp(Color(0.95, 0.75, 0.3) if a > 0.0 else Color(0.45, 0.6, 0.95), absf(a))
	_sub.text = "%s  ·  %s" % [who.bond_text().capitalize(), "you've only just met" if m.familiarity < 0.2 else ("you've talked a few times" if m.familiarity < 0.6 else "you go back a while")]
	UI.clear(_list)
	UI.button(_list, "Have a chat", _chat, 18)
	if who.is_riser:
		UI.button(_list, "\"Fancy a pull?\"", _challenge, 18).add_theme_color_override("font_color", UI.GOLD)
	else:
		UI.button(_list, "\"You should have a go.\"", _invite, 18).add_theme_color_override("font_color", UI.GOLD)
	if Meet.straps.has(who.id):
		UI.button(_list, "\"Found this. Yours?\"  (hand back the strap)", _strap, 18)
	UI.button(_list, "Offer a snack  (%d)" % Meet.snacks, _snack, 18)
	UI.button(_list, "Ask who's winning tonight", _results, 18)
	UI.button(_list, "Take a photo together", _photo, 18)
	UI.button(_list, "Heckle", _heckle, 18).add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	UI.button(_list, "See you later", close, 18)

func _line(t: String) -> void:
	_text.append_text("\n%s\n" % t)
	if active() and who != null:
		_options()

func _chat() -> void:
	var lines: Array = who.def["chat"] if who.passer else People.CHAT[who.bond()]
	_chats[who.id] = _chats.get(who.id, 0) + 1
	if _chats[who.id] <= 3 and who.bond() != "gone":
		who.mind.experience("talk", 0.2, 0.3, true, "")
	_line("\"%s\"" % lines[randi() % lines.size()])
	_mates_check()

func _challenge() -> void:
	if who.bond() == "gone":
		_line("\"Not with you. Not tonight.\"")
		return
	if who.tonight.get("id", "") == "sore":
		_line("\"Elbow's gone. Ask me next week.\"")
		return
	if who.state in ["pull", "to_table", "prep"]:
		_line("\"I'm up next on this table. After.\"")
		return
	var r := who
	close()
	Meet.table.start(r)

## Talking a passer-by into their first pull.
func _invite() -> void:
	if who.recruited:
		_line("\"I said I'd come back! Don't push it.\"")
		return
	if who.mind.feeling() + randf() * 0.5 < 0.42:
		who.mind.experience("nagged", -0.1, 0.4)
		_line(["\"Oh, no. No no. I'd snap.\"", "\"Maybe another time.\"", "\"I've got to get on.\""][randi() % 3] + "\n[i]A chat or a snack might soften them up.[/i]")
		return
	var r := who
	close()
	r.say_aloud("Go on then. Once.", 3.0)
	Meet.table.start(r)

func _strap() -> void:
	_line("\"%s\"" % who.strap_returned())

func _snack() -> void:
	if Meet.snacks <= 0:
		_line("[i]You pat your pockets. No snacks. The table's over by the lights.[/i]")
		return
	Meet.snacks -= 1
	Meet.snacks_given += 1
	who.mind.experience("gift", 0.6, 1.0, true, "")
	if Meet.snacks_given >= 5:
		Meet.grant("chef_hat")
	Meet.touch_state()
	_line("[i]You hand it over.[/i] \"%s\"" % ["Oh, cheers.", "You're a legend.", "I was about to go and get one.", "Don't mind if I do."][randi() % 4])
	_mates_check()

func _results() -> void:
	if Meet.results.is_empty():
		_line("\"Nobody's pulled yet. Give it a minute.\"")
		return
	var recent: Array = Meet.results.slice(max(0, Meet.results.size() - 5))
	_line("\"So far? %s.\"" % ". ".join(recent))

func _photo() -> void:
	var r := who
	if not _photos.has(r.id) and r.bond() != "gone":
		_photos[r.id] = true
		r.mind.experience("photo", 0.3, 0.5, true, "")
	close()
	r.say_aloud("Cheese." if r.bond() != "gone" else "Seriously?", 3.0)
	Meet.hud.photo()

func _heckle() -> void:
	var reply: String = who.heckle()
	if reply != "" and active():
		_line("[i]You tell them their toproll looks like someone opening a jar.[/i]\n\"%s\"" % reply)

## Being on good terms with four founders is worth something.
func _mates_check() -> void:
	var n := 0
	for r in Meet.risers:
		if r.is_riser and r.bond() in ["mates", "close"]:
			n += 1
	if n >= 4:
		Meet.grant("lion_mask")

# --- Notes at the lanterns ---------------------------------------------------------------

func notes(spot: int) -> void:
	who = null
	_name.text = "Notes left at this lantern"
	_card.visible = false
	_dots.visible = false
	_sub.text = "Built from set phrases. For now, only you can see the ones you leave."
	_text.clear()
	var any := false
	for n in People.SEEDED + Meet.notes:
		if int(n["spot"]) == spot:
			any = true
			_text.append_text("•  %s %s.\n" % [n["a"], n["b"]])
	if not any:
		_text.append_text("[i]Nobody has left anything here yet.[/i]\n")
	_show()
	UI.clear(_list)
	UI.button(_list, "Leave a note", _note_first.bind(spot), 18).add_theme_color_override("font_color", UI.GOLD)
	UI.button(_list, "Walk on", close, 18)

func _note_first(spot: int) -> void:
	UI.clear(_list)
	for a in People.NOTE_A:
		UI.button(_list, a + " ...", func():
			_pick_a = a
			_note_second(spot), 17)

func _note_second(spot: int) -> void:
	UI.clear(_list)
	for b in People.NOTE_B:
		UI.button(_list, "%s %s" % [_pick_a, b], func():
			Meet.notes.append({"spot": spot, "a": _pick_a, "b": b})
			Meet.save()
			notes(spot), 17)
