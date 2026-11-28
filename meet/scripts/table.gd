extends CanvasLayer
## A pull, played as the grip fight from Pin Run on 88risers.com. A needle sweeps the bar:
## tap when it is inside the gold zone to take the grip. Miss and they take it. First to three.
## Every founder has the signature move they have in Pin Run, and it bends the bar their way.

const UI = preload("res://scripts/ui.gd")
const NEED := 3
const MOVES := {
	"toproll": ["Toproll", "the gold zone rolls along the bar", Color(1.0, 0.7, 0.28)],
	"hook": ["Hook", "the needle snaps back without warning", Color(1.0, 0.35, 0.37)],
	"hydraulic": ["Hydraulic Press", "the needle pumps slow, then surges", Color(0.5, 0.78, 1.0)],
	"press": ["Press", "the gold zone gets crushed smaller", Color(1.0, 0.48, 0.24)],
	"side": ["Side Pressure", "the needle drags slow, then whips through", Color(0.78, 0.6, 1.0)],
	"kings": ["King's Move", "the gold zone flickers out of sight", Color(0.95, 0.76, 0.3)],
	"fake": ["Fake-Out", "the gold zone jumps when you get close", Color(0.49, 1.0, 0.69)],
}
const WHO := {"harry": "toproll", "george": "hook", "phillip": "hydraulic", "bhavya": "press", "kelvin": "side", "tommy": "kings", "luie": "fake", "erick": "chain", "p_old": "chain", "kaiju": "chain"}
const CHAIN := ["toproll", "hook", "press"]

var rival: Node = null
var phase := "off"          # off | ready | go | between | done
var won := false
var mine := 0
var theirs := 0
var move := ""
var pos := 0.5
var zone := 0.5
var width := 0.2
var speed := 4.0
var _ph := 0.0
var _dir := 1.0
var _t := 0.0
var _z0 := 0.5
var _w0 := 0.2
var _flip := 1.0
var _used := false
var _wait := 0.0
var _angry := 1.0
var _table := -1
var _lefts := false

var _root: Control
var _title: Label
var _call: Label
var _score: Label
var _pips_me: Pips
var _pips_them: Pips
var _move: Label
var _track: Control
var _zone: ColorRect
var _needle: ColorRect
var _card: TextureRect
var _grip: Button
var _done: Button

func _ready() -> void:
	layer = 22
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 120)
	m.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	_card = TextureRect.new()
	_card.custom_minimum_size = Vector2(130, 195)
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_card)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = UI.text(top, "", 24, UI.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score = UI.text(top, "You", 24)
	_score.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pips_me = Pips.new()
	_pips_me.px = 22.0
	_pips_me.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pips_me)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	top.add_child(gap)
	_pips_them = Pips.new()
	_pips_them.px = 22.0
	_pips_them.from_right = true
	_pips_them.color = Color(1.0, 0.45, 0.4)
	_pips_them.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pips_them)
	UI.text(top, "Them", 24).autowrap_mode = TextServer.AUTOWRAP_OFF
	_call = UI.text(v, "", 30)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 46)
	v.add_child(_track)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track.add_child(bg)
	_zone = ColorRect.new()
	_zone.color = UI.GOLD
	_track.add_child(_zone)
	_needle = ColorRect.new()
	_needle.color = Color(1, 1, 1)
	_track.add_child(_needle)
	_move = UI.text(v, "", 18)
	_grip = UI.button(v, "GRIP!   (Space, click or tap)", tap, 26)
	_grip.custom_minimum_size = Vector2(0, 66)
	_grip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_done = UI.button(v, "Step back from the table", _close, 20)
	_done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.visible = false

func active() -> bool:
	return _root.visible

func start(r: Node) -> void:
	rival = r
	Meet.main.drop_match(r)
	mine = 0
	theirs = 0
	won = false
	_angry = 1.0
	_title.text = "You  vs  %s" % r.riser_name
	if r.pull_angry:
		_angry = 1.15
	if r.lefts:
		r.lefts = false
		_lefts = true
		_title.text += "   (left arms)"
	else:
		_lefts = false
	if r.stake > 0:
		_title.text += "   ($%d on it)" % r.stake
	if Meet.straps.has(r.id):
		# Turning up to pull someone with their own strap round your wrist.
		r.caught_with_strap()
		_angry = 1.2
		_title.text = "%s: \"Is that MY strap?\"" % r.riser_name
	var extras: Array = []
	if Meet.chalked:
		extras.append("chalked: wider zone")
	if not Meet.straps.is_empty():
		extras.append("strapped: slower needle")
	if Meet.tips > 0:
		extras.append("coached")
	if Meet.pump > 0:
		extras.append("pumped x%d" % Meet.pump)
	if not extras.is_empty():
		_title.text += "   (%s)" % ", ".join(extras)
	var pic: String = r.portrait()
	_card.visible = pic != ""
	if pic != "":
		_card.texture = load("res://assets/portraits/%s.jpg" % pic)
	_done.visible = false
	_grip.visible = true
	_root.visible = true
	UI.open_modal()
	_table = Meet.main.seat_player(r) if r.id != "kaiju" else -1
	phase = "ready"
	_wait = 1.6
	_call.text = "Hands in... ready..."
	_round()
	_show()

## Set up the bar for the next grip.
func _round() -> void:
	var kind: String = WHO.get(rival.id, "chain" if rival.legend != "" else "")
	move = CHAIN[(mine + theirs) % 3] if kind == "chain" else kind
	width = clamp(0.2 + (Meet.strength() - rival.strength) * 0.003 - mine * 0.015, 0.1, 0.3)
	speed = (4.2 + (rival.strength - 50.0) * 0.05 + (mine + theirs) * 0.35) * _angry
	if _lefts:
		# Nobody is as good left-handed: the zone is smaller, but the needle is slower and there are no tricks.
		move = ""
		width *= 0.8
		speed *= 0.8
	if Meet.chalked:
		width *= 1.2
	if not Meet.straps.is_empty():
		speed *= 0.9
	width += min(Meet.tips, 4) * 0.01 + Meet.pump * 0.012
	if Meet.stamina < 30.0:
		width *= 0.85
	if move in ["press", "hook"]:
		width *= 1.3
	elif move == "hydraulic":
		width *= 1.25
	elif move in ["toproll", "kings"]:
		width *= 1.1
	zone = randf_range(0.55, 0.8) if move == "side" else randf_range(0.25, 0.75)
	_z0 = zone
	_w0 = width
	_t = 0.0
	_ph = 0.0
	_dir = 1.0
	pos = 0.5
	_flip = randf_range(1.0, 1.5)
	_used = false
	_move.text = "%s's %s: %s." % [rival.riser_name.split(" ")[0] if rival.is_riser else rival.riser_name, MOVES[move][0], MOVES[move][1]] if move != "" else "No tricks. Just time it."
	_zone.color = MOVES[move][2] if move != "" else UI.GOLD

func _unhandled_input(ev: InputEvent) -> void:
	if not active():
		return
	if (ev is InputEventKey and ev.keycode == KEY_SPACE and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		get_viewport().set_input_as_handled()
		tap()

func _process(dt: float) -> void:
	if active() and phase != "done":
		tick(dt)
		_show()

## One step. Separate from the screen so a test can play it.
func tick(dt: float) -> void:
	if phase == "ready" or phase == "between":
		_wait -= dt
		if _wait <= 0.0:
			phase = "go"
			_call.text = "GRIP!"
			if mine + theirs == 0:
				Meet.sfx("whistle", -6.0)
		return
	if phase != "go":
		return
	_t += dt
	var mul := 1.0
	if move == "hook":
		_flip -= dt
		if _flip <= 0.0:
			_dir *= -1.0
			_flip = randf_range(1.0, 1.6)
	elif move == "hydraulic":
		mul = 0.8 if fmod(_t, 1.0) < 0.75 else 1.45
	_ph += dt * speed * mul * _dir
	var raw := (sin(_ph) + 1.0) / 2.0
	pos = pow(raw, 2.2) if move == "side" else raw
	if move == "toproll":
		var half := width / 2.0 + 0.02
		zone = clamp(_z0 + sin(_t * 1.7) * 0.22, half, 1.0 - half)
	elif move == "press":
		width = _w0 * max(0.36, 1.0 - _t * 0.32)
	elif move == "fake" and not _used and _t > 0.35 and absf(pos - zone) < width / 2.0 + 0.1:
		_used = true
		zone = randf_range(0.62, 0.8) if zone < 0.5 else randf_range(0.2, 0.38)
	if _t > 7.0:
		_grip_to(false, "Too slow. They take the grip.")

func tap() -> void:
	if phase == "ready":
		_grip_to(false, "Foul! You went before the call.")
	elif phase == "go":
		var hit := absf(pos - zone) < width / 2.0
		_grip_to(hit, ["GRIP!", "Got it!", "Yours!"][randi() % 3] if hit else ["Missed. They take it.", "Slipped!", "They've got your hand."][randi() % 3])

func _grip_to(me: bool, text: String) -> void:
	if me:
		mine += 1
		Meet.sfx("grip", -3.0, 1.0 + mine * 0.08)
	else:
		theirs += 1
		Meet.sfx("miss", -3.0)
	_call.text = text
	Meet.main.rig_lean(_table, float(mine - theirs) / NEED)
	if mine >= NEED or theirs >= NEED:
		_finish(mine >= NEED)
	else:
		phase = "between"
		_wait = 1.1
		_round()

func _show() -> void:
	var w := _track.size.x
	_zone.visible = not (move == "kings" and phase == "go" and sin(_t * 7.0) < -0.1)
	_zone.position = Vector2((zone - width / 2.0) * w, 4)
	_zone.size = Vector2(width * w, 38)
	_needle.position = Vector2(pos * w - 3, 0)
	_needle.size = Vector2(6, 46)
	_pips_me.set_pips(mine, NEED)
	_pips_them.set_pips(theirs, NEED)

func _finish(victory: bool) -> void:
	phase = "done"
	won = victory
	Meet.sfx("win" if victory else "lose")
	Meet.sfx("ooh", -6.0)
	if rival.is_riser:
		Meet.points += (3 if victory else 1) * (2 if Meet.double_points else 1)
		Meet.double_points = false
	if victory:
		Meet.dare("win", rival.id)
	Meet.chalked = false
	Meet.stamina = max(0.0, Meet.stamina - 25.0)
	_grip.visible = false
	_done.visible = true
	_show()
	rival.mind.experience("match", 0.35 if victory else 0.3, 1.0, true, "")
	if rival.guest_ready:
		rival.recruited = true
		Meet.dare("recruit")
		Meet.errand("harry", "ready")
		Meet.errand("erick", "ready")
		Meet.recruits += 1
		_call.text = "You pin %s." % rival.first_name if victory else "%s pins you. Oh." % rival.riser_name
		Meet.results.append(("You beat %s" if victory else "%s beat you, somehow") % rival.first_name)
		rival.say_aloud("That was brilliant. Who's next?" if rival.strength < 80 else "Still got it. Forty years.", 5.0)
		Meet.say("%s is staying for the meet. That's %d talked into it." % [rival.riser_name, Meet.recruits])
		rival.join_meet()
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
		_call.text = "Pinned. %s takes it." % rival.first_name
		if Meet.losses >= 3:
			Meet.grant("medal")
		rival.say_aloud(["Good effort.", "You'll get there.", "Chalk up and go again."][randi() % 3], 4.0)
	rival.after_pull(victory)
	Meet.save()
	Meet.touch_state()

func _close() -> void:
	_root.visible = false
	phase = "off"
	Meet.main.unseat_player(_table)
	UI.close_modal()
