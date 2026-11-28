extends CanvasLayer
## Turn-based fights, and what comes after one of the Pinned goes down:
## chalk to see the spirit, a strap to hold it, and the rite to raise it.

const UI = preload("res://scripts/ui.gd")

const STRAP_HOLD := 5

var foe: Node = null
var foe_is_pinned := true
var foe_name := ""
var foe_hp := 0
var foe_max := 0
var foe_atk := 0
var stamina := 3
var guarding := false
var grip := 0
var turns := 0
var lines: Array = []
var result := ""
var _mode := "fight"
var _pins := [0, 0]
var _rival: Node = null

var _root: Control
var _title: Label
var _status: Label
var _log: RichTextLabel
var _buttons: VBoxContainer

func _ready() -> void:
	layer = 20
	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.3)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 50)
	m.add_theme_constant_override("margin_top", 405)
	m.add_theme_constant_override("margin_bottom", 24)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	_title = UI.text(v, "", 24, UI.GOLD)
	_status = UI.text(v, "", 16, Color(0.8, 0.78, 0.7))
	_log = UI.rich(v, 18)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 5)
	scroll.add_child(_buttons)
	_root.visible = false

func active() -> bool:
	return _root.visible

func start_pinned(p: Node) -> void:
	if active():
		return
	foe = p
	foe_is_pinned = true
	var s: Dictionary = p.spirit
	_begin(p.display_name(), s["hp"], s["atk"])
	_say("[i]It comes at you without a sound.[/i]")
	_fight_menu()

func start_npc(n: Node) -> void:
	if active():
		return
	foe = n
	foe_is_pinned = false
	_begin(n.npc_name, 16 + int(n.capable / 4.0) + (30 if n.id == "phillip" else 0), 3 + int(n.capable / 25.0))
	_say("[i]%s backs away, then stands their ground.[/i]" % n.npc_name)
	_fight_menu()

func _begin(n: String, hp: int, atk: int) -> void:
	_mode = "fight"
	foe_name = n
	foe_hp = hp
	foe_max = hp
	foe_atk = atk
	stamina = 3
	guarding = false
	result = ""
	_log.clear()
	var to: Vector3 = foe.global_position - Game.player.global_position
	to.y = 0
	if to.length() < 0.1:
		to = Vector3(0, 0, -1)
	Game.player.rotation.y = atan2(-to.x, -to.z)
	Game.player.look_level(-0.3)
	if foe_is_pinned:
		foe.global_position = Game.main.ground(Game.player.global_position + to.normalized() * 3.4)
		foe.rotation.y = atan2(-to.x, -to.z)
		foe.face_off()
	_root.visible = true
	UI.open_modal()
	_refresh()

func _say(t: String) -> void:
	_log.append_text(t + "\n")

func _refresh() -> void:
	if _mode == "wrestle":
		_status.text = "You %d   ·   %s %d   ·   first to three   ·   your coin: %d" % [_pins[0], foe_name, _pins[1], Game.coins]
		Game.touch()
		return
	_title.text = foe_name
	_status.text = "You: %d / %d health, %d wind   ·   Them: %d / %d   ·   Chalk %d, straps %d" % [
		Game.hp, Game.max_hp, stamina, max(foe_hp, 0), foe_max, Game.chalk, Game.straps]
	Game.touch()

func _menu(items: Array) -> void:
	UI.clear(_buttons)
	var i := 1
	for it in items:
		UI.button(_buttons, "%d.  %s" % [i, it[0]], it[1], 17)
		i += 1
	_refresh()

func _unhandled_key_input(ev: InputEvent) -> void:
	if not active() or not ev.pressed or ev.echo:
		return
	var k: int = ev.keycode - KEY_1
	if k >= 0 and k < _buttons.get_child_count():
		get_viewport().set_input_as_handled()
		(_buttons.get_child(k) as Button).pressed.emit()

# --- The table: arm wrestling in the tavern ------------------------------------

const BEATS := {"Toproll": "Hook", "Hook": "Press", "Press": "Toproll"}

func start_wrestle() -> void:
	if active():
		return
	if Game.coins < 5:
		Game.say("It is five coin on the table to pull. You haven't got it.")
		return
	var founders: Array = Game.villagers("rhodes")
	if founders.is_empty():
		Game.say("There is nobody left to pull against.")
		return
	_rival = founders[randi() % founders.size()]
	if _rival.hostile():
		Game.say("%s will not sit down with you." % _rival.npc_name)
		return
	_mode = "wrestle"
	foe = null
	foe_name = _rival.npc_name
	_pins = [0, 0]
	result = ""
	_log.clear()
	_title.text = "The table: %s" % foe_name
	_root.visible = true
	UI.open_modal()
	_say("%s sits down opposite and sets an elbow on the pad. Five coin each." % foe_name)
	_say("[color=#9a968a]A toproll peels open a hook. A hook drags a press inside. A press drives through a toproll.[/color]")
	_wrestle_menu()

func _wrestle_menu() -> void:
	_menu([["Toproll", _pull.bind("Toproll")], ["Hook", _pull.bind("Hook")], ["Press", _pull.bind("Press")], ["Stand up and leave", _leave_table]])

func _pull(mine: String) -> void:
	# Everyone at the table has a move they lean on.
	var moves: Array = BEATS.keys()
	var favourite: String = moves[abs(hash(foe_name)) % 3]
	var theirs: String = favourite if randf() < 0.5 else moves[randi() % 3]
	if mine == theirs:
		_say("\nYou both go for the %s. Neither arm moves. The referee resets you." % mine.to_lower())
	elif BEATS[mine] == theirs:
		_pins[0] += 1
		_say("\nYour %s beats the %s. [b]Pin.[/b]" % [mine.to_lower(), theirs.to_lower()])
	else:
		_pins[1] += 1
		_say("\n%s's %s beats your %s. You are pinned." % [foe_name, theirs.to_lower(), mine.to_lower()])
	if _pins[0] >= 3:
		Game.coins += 5
		_say("\nYou take the table, and five coin. %s shakes your hand." % foe_name)
		_rival.mind.experience("helped", 0.5, 0.6)
		_finish("wrestled")
	elif _pins[1] >= 3:
		Game.coins -= 5
		_say("\n%s takes the table, and your five coin. \"Again some time.\"" % foe_name)
		_rival.mind.experience("helped", 0.4, 0.5)
		_finish("wrestled")
	else:
		_wrestle_menu()

func _leave_table() -> void:
	_say("\nYou stand up. Nobody holds it against you.")
	_finish("left")

# --- The fight -------------------------------------------------------------

func _fight_menu() -> void:
	var items := [["Strike", _move.bind("strike")]]
	if stamina >= 2:
		items.append(["Heavy strike (2 wind)", _move.bind("heavy")])
	items.append(["Guard (take half, recover wind)", _move.bind("guard")])
	if Game.bread > 0 and Game.hp < Game.max_hp:
		items.append(["Eat bread", _move.bind("eat")])
	items.append(["Run", _move.bind("run")])
	_menu(items)

func _move(kind: String) -> void:
	guarding = false
	match kind:
		"strike":
			var dmg := Game.power + randi_range(-1, 1)
			foe_hp -= dmg
			_say("You strike for [b]%d[/b]." % dmg)
		"heavy":
			stamina -= 2
			var dmg2 := Game.power * 2 + randi_range(-1, 2)
			foe_hp -= dmg2
			_say("You put your whole weight into it: [b]%d[/b]." % dmg2)
		"guard":
			guarding = true
			stamina = min(3, stamina + 2)
			_say("You set your feet and get your breath.")
		"eat":
			Game.eat()
			_say("You tear off some bread and swallow it.")
		"run":
			if randf() < 0.65:
				_say("You break away.")
				if foe_is_pinned:
					foe.back_off()
				_finish("ran")
				return
			_say("It is on you before you have turned.")
	if foe_hp <= 0:
		_foe_down()
		return
	var hit := foe_atk + randi_range(-1, 1)
	if guarding:
		hit = int(ceil(hit / 2.0))
	hit = max(hit, 1)
	Game.hp -= hit
	_say("%s hits you for [b]%d[/b]." % [foe_name, hit])
	if Game.hp <= 0:
		_say("\n[i]You go down.[/i]")
		if foe_is_pinned:
			foe.back_off()
		_finish("fell")
		return
	_fight_menu()

func _foe_down() -> void:
	if not foe_is_pinned:
		_say("\n%s falls and does not get up." % foe_name)
		foe.die()
		_finish("killed")
		return
	_say("\nIt folds to the ground. Already the dark is pulling it under.")
	var items: Array = []
	if Game.chalk > 0:
		items.append(["Throw chalk", _chalk])
	items.append(["Leave it. It will be back.", _abandon])
	_menu(items)

# --- Chalk, strap, rite ------------------------------------------------------

func _chalk() -> void:
	Game.chalk -= 1
	foe.reveal()
	foe_name = foe.spirit["name"]
	_say("\nYou throw chalk. It hangs in the air, and a shape stands up inside it.")
	_say("[color=#edc259]%s[/color]" % foe.spirit["seen"])
	var items: Array = []
	if Game.straps > 0:
		items.append(["Bind it with a strap", _strap])
	items.append(["Leave it. It will be back.", _abandon])
	_menu(items)

func _strap() -> void:
	Game.straps -= 1
	grip = foe.spirit["grip"]
	turns = STRAP_HOLD - int(foe.spirit["strain"])
	lines = (foe.spirit["say"] as Array).duplicate()
	lines.shuffle()
	_say("\nYou loop the strap and pull it tight. It holds. For now.")
	_rite_menu()

func _rite_menu() -> void:
	_say("[color=#9a968a]The strap will hold for %d more.[/color]" % turns)
	var items: Array = []
	for l in lines:
		items.append(["Say: \"%s\"" % l[0], _speak.bind(l)])
	items.append(["Say the Rite of Rising", _rite])
	_menu(items)

func _speak(l: Array) -> void:
	lines.erase(l)
	_say("\n\"%s\"" % l[0])
	_say("[i]%s[/i]" % l[1])
	if l[2]:
		grip -= 1
	_spend()

func _rite() -> void:
	if grip <= 0:
		_say("\nYou say the words. The chalk lifts, and what was standing in it lifts with it, and is gone.")
		_say("[color=#edc259]%s has risen.[/color]" % foe.spirit["name"])
		foe.raise_up()
		if foe.spirit["name"].begins_with("Oswin"):
			_oswin_raised()
		_finish("raised")
		return
	_say("\nYou begin the words. It will not go. It is still holding on to something.")
	_spend()

func _spend() -> void:
	turns -= 1
	if turns <= 0:
		_say("\nThe strap gives. The dark takes it back under.")
		foe.put_down()
		_finish("lost")
		return
	_rite_menu()

func _abandon() -> void:
	_say("\nYou step back. It sinks into the ground. It will be up again before long.")
	foe.put_down()
	_finish("left")

func _oswin_raised() -> void:
	for n in Game.npcs:
		if n.id == "mara" and n.alive:
			n.willing = 90
			n.willing_cap = 100
			n.mind.experience("raised_kin", 1.0, 4.0, true, "Oswin")
	Game.note("Oswin Quill has risen. Mara should be told.")

func _finish(r: String) -> void:
	result = r
	_menu([["Continue", _close]])

func _close() -> void:
	_root.visible = false
	UI.close_modal()
	if result == "fell":
		Game.fall()
	elif result == "raised":
		Game.say("One fewer on the road. People in the villages will hear of it.")
	Game.touch()
