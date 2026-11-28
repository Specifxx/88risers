extends CanvasLayer
## Arm wrestling at the table. Hold PULL to drive, but your grip tires, so let go and
## recover when they surge. Match their style with the one that beats it:
## a toproll peels open a hook, a hook drags a press inside, a press drives through a toproll.

const UI = preload("res://scripts/ui.gd")
const BEATS := {"Toproll": "Hook", "Hook": "Press", "Press": "Toproll"}
const STYLES := ["Toproll", "Hook", "Press"]

var rival: Node = null
var meter := 0.0            # -1 you are pinned ... +1 you pin them
var grip := 1.0
var pulling := false
var mine := "Toproll"
var theirs := "Hook"
var phase := "off"          # off | ready | go | done
var won := false
var _t := 0.0
var _clock := 0.0
var _switch := 0.0
var _surge := 0.0           # time until they surge
var _surging := 0.0         # time left in the surge
var _fouls := 0
var _angry := 1.0
var _chalk := 1.0

var _root: Control
var _title: Label
var _call: Label
var _bar: ProgressBar
var _grip: ProgressBar
var _theirs: Label
var _mine: Label
var _pull: Button
var _styles := {}
var _card: TextureRect
var _done: Button

func _ready() -> void:
	layer = 22
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0, 0.55)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	var p := UI.panel(c)
	p.custom_minimum_size = Vector2(900, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	_card = TextureRect.new()
	_card.custom_minimum_size = Vector2(210, 315)
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_card)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	h.add_child(v)
	_title = UI.text(v, "", 26, UI.GOLD)
	_call = UI.text(v, "", 30)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.text(v, "They pin you   ←                                →   You pin them", 14, Color(0.7, 0.68, 0.6)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = _make_bar(v, UI.GOLD, 26)
	_bar.min_value = -1.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_theirs = UI.text(v, "", 20, Color(1.0, 0.6, 0.5))
	_mine = UI.text(v, "", 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var i := 1
	for s in STYLES:
		var b := UI.button(row, "%d  %s" % [i, s], set_style.bind(s), 20)
		b.custom_minimum_size = Vector2(150, 54)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_styles[s] = b
		i += 1
	UI.text(v, "Grip", 14, Color(0.7, 0.68, 0.6))
	_grip = _make_bar(v, Color(0.2, 0.55, 0.85), 14)
	_grip.max_value = 1.0
	_grip.step = 0.001
	_pull = UI.button(v, "HOLD TO PULL  (Space)", func(): pass, 26)
	_pull.custom_minimum_size = Vector2(0, 76)
	_pull.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pull.button_down.connect(func(): press(true))
	_pull.button_up.connect(func(): press(false))
	_done = UI.button(v, "Step back from the table", _close, 20)
	_done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.visible = false

func _make_bar(parent: Node, fill: Color, tall: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, tall)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.1, 0.09)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b

func active() -> bool:
	return _root.visible

func start(r: Node) -> void:
	rival = r
	Meet.main.drop_match(r)
	meter = 0.0
	grip = 1.0
	pulling = false
	won = false
	_fouls = 0
	_clock = 0.0
	mine = "Toproll"
	theirs = STYLES[randi() % 3]
	_switch = randf_range(2.5, 4.5)
	_surge = randf_range(2.0, 4.0)
	_surging = 0.0
	phase = "ready"
	_t = randf_range(1.6, 3.0)
	_title.text = "You  vs  %s" % r.riser_name
	_angry = 1.0
	if Meet.straps.has(r.id):
		# Turning up to pull someone with their own strap round your wrist.
		r.caught_with_strap()
		_angry = 1.2
		_title.text = "%s: \"Is that MY strap?\"" % r.first_name
	elif Meet.chalked or not Meet.straps.is_empty():
		_title.text += "   (%s)" % " and ".join((["chalked"] if Meet.chalked else []) + (["strapped"] if not Meet.straps.is_empty() else []))
	_chalk = 0.65 if Meet.chalked else 1.0
	var pic: String = r.portrait()
	_card.visible = pic != ""
	if pic != "":
		_card.texture = load("res://assets/portraits/%s.jpg" % pic)
	_call.text = "Ready..."
	_done.visible = false
	_pull.visible = true
	_root.visible = true
	UI.open_modal()
	_show()

func set_style(s: String) -> void:
	if phase in ["ready", "go"]:
		mine = s
		_show()

func press(down: bool) -> void:
	if phase == "ready" and down:
		_fouls += 1
		_call.text = "Foul! Wait for GO." if _fouls < 2 else "Second foul. That's the match."
		if _fouls >= 2:
			_finish(false)
		return
	pulling = down and phase == "go"

func _unhandled_key_input(ev: InputEvent) -> void:
	if not active():
		return
	if ev.keycode == KEY_SPACE and not ev.echo:
		get_viewport().set_input_as_handled()
		press(ev.pressed)
	elif ev.pressed and not ev.echo and ev.keycode >= KEY_1 and ev.keycode <= KEY_3:
		get_viewport().set_input_as_handled()
		set_style(STYLES[ev.keycode - KEY_1])

func _process(dt: float) -> void:
	if active() and phase in ["ready", "go"]:
		tick(dt)
		_show()

## One step of the match. Separate from the screen so it can be played by a test.
func tick(dt: float) -> void:
	if phase == "ready":
		_t -= dt
		if _t <= 0.0:
			phase = "go"
			_call.text = "GO!"
		return
	_clock += dt
	# Their style changes now and then, and they announce a surge a moment before it comes.
	_switch -= dt
	if _switch <= 0.0:
		_switch = randf_range(2.5, 5.0)
		theirs = STYLES[randi() % 3]
	if _surging > 0.0:
		_surging -= dt
	else:
		_surge -= dt
		if _surge <= 0.0:
			_surging = 1.1
			_surge = randf_range(2.6, 4.6)
	var them: float = 0.5 + (rival.strength - 60.0) / 60.0
	them *= 1.7 if _surging > 0.0 else 1.0
	them *= max(0.6, 1.0 - _clock * 0.012) * _angry
	var edge := 1.0
	if BEATS[mine] == theirs:
		edge = 1.3
	elif BEATS[theirs] == mine:
		edge = 0.75
	var me: float = 0.5 + (Meet.strength() - 60.0) / 60.0
	if pulling and grip > 0.02:
		me *= (0.45 + 0.55 * grip) * edge * 1.55
		grip = max(0.0, grip - dt * 0.3 * _chalk)
	else:
		me *= 0.5 * edge
		grip = min(1.0, grip + dt * 0.42)
	meter = clamp(meter + (me - them) * dt * 0.55, -1.0, 1.0)
	_call.text = "They're surging! Hold on!" if _surging > 0.0 else ("They're loading up..." if _surge < 0.7 else "GO!")
	if meter >= 1.0:
		_finish(true)
	elif meter <= -1.0:
		_finish(false)

func _show() -> void:
	_bar.value = meter
	_grip.value = grip
	_theirs.text = "%s is pulling a %s." % [rival.riser_name.split(" ")[0] if rival.is_riser else rival.riser_name, theirs.to_lower()]
	var note := "even"
	if BEATS[mine] == theirs:
		note = "you have the better of it"
	elif BEATS[theirs] == mine:
		note = "they have the better of it"
	_mine.text = "You are pulling a %s: %s." % [mine.to_lower(), note]
	for s in _styles:
		(_styles[s] as Button).add_theme_color_override("font_color", UI.GOLD if s == mine else UI.PAPER)

func _finish(victory: bool) -> void:
	phase = "done"
	won = victory
	pulling = false
	Meet.chalked = false
	_pull.visible = false
	_done.visible = true
	rival.mind.experience("match", 0.35 if victory else 0.3, 1.0, true, "")
	if rival.passer:
		rival.recruited = true
		Meet.recruits += 1
		_call.text = ("You pin %s." if victory else "%s pins you. Oh.") % rival.riser_name
		_call.text = _call.text.left(1).to_upper() + _call.text.substr(1)
		Meet.results.append(("You beat %s" if victory else "%s beat you, somehow") % rival.first_name)
		rival.say_aloud("That was brilliant. When's the next one?" if rival.strength < 80 else "Still got it. Forty years.", 5.0)
		Meet.say("%s says they'll come to the next meet. That's %d talked into it." % [rival.riser_name, Meet.recruits])
		if Meet.recruits >= 3:
			Meet.grant("clipboard")
	elif victory:
		Meet.wins += 1
		Meet.beaten[rival.id] = true
		Meet.results.append("You beat %s" % rival.first_name)
		_call.text = "PIN! You beat %s." % rival.first_name
		Meet.grant("foam_finger")
		if rival.id == "harry":
			Meet.grant("belt")
		var all := true
		for r in Meet.risers:
			if r.is_riser and not Meet.beaten.has(r.id):
				all = false
		if all:
			Meet.grant("katana_88")
		rival.say_aloud(["Good pull.", "Okay. Okay! Again some time.", "Where did that come from?"][randi() % 3], 4.0)
	else:
		Meet.losses += 1
		Meet.results.append("%s beat you" % rival.first_name)
		if _fouls < 2:
			_call.text = "Pinned. %s takes it." % rival.first_name
		if Meet.losses >= 3:
			Meet.grant("medal")
		rival.say_aloud(["Good effort.", "You'll get there.", "Chalk up and go again."][randi() % 3], 4.0)
	Meet.save()
	Meet.touch_state()

func _close() -> void:
	_root.visible = false
	phase = "off"
	UI.close_modal()
