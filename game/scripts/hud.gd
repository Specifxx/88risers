extends CanvasLayer
## Always-on display: health and supplies, compass, what you can interact with,
## recent messages, the journal, and the title and end screens.

const UI = preload("res://scripts/ui.gd")

var _stats: Label
var _compass: Label
var _prompt: Label
var _log: VBoxContainer
var _journal: Control
var _journal_text: RichTextLabel
var _title: Control
var _end: Control
var _fade: ColorRect
var _fade_text: Label
var _cross: Label
var _health: ProgressBar
var _wind: ProgressBar
var _float: Label
var _hurt: ColorRect
var _register: ProgressBar
var _goal: Label
var _band: Control
var _slots := {}
var _end_title: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top left: the crest, health, the Register, and what you are doing.
	var top := UI.panel(root, Color(0.05, 0.04, 0.04, 0.72))
	top.position = Vector2(14, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	var crest := TextureRect.new()
	crest.texture = load("res://assets/ui/emblem.png")
	crest.custom_minimum_size = Vector2(64, 64)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(crest)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	_health = _bar(col, Color(0.74, 0.14, 0.13))
	_wind = _bar(col, Color(0.2, 0.45, 0.72))
	_register = _bar(col, UI.GOLD)
	_stats = UI.text(col, "", 15, UI.PAPER)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_goal = UI.text(col, "", 15, Color(0.86, 0.78, 0.6))
	_goal.custom_minimum_size = Vector2(300, 0)

	# Top centre: a compass band that turns with you.
	_band = Control.new()
	_band.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_band.custom_minimum_size = Vector2(420, 34)
	_band.offset_left = -210
	_band.offset_right = 210
	_band.offset_top = 14
	_band.offset_bottom = 48
	_band.clip_contents = true
	_band.draw.connect(_draw_band)
	root.add_child(_band)
	_compass = UI.text(root, "", 15, Color(0.86, 0.78, 0.6))
	_compass.autowrap_mode = TextServer.AUTOWRAP_OFF
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_compass.offset_top = 50
	_shadow(_compass)

	# Bottom right: what you are carrying.
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	slots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	slots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	slots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slots.offset_right = -16
	slots.offset_bottom = -16
	root.add_child(slots)
	for item in ["Chalk", "Straps", "Bread", "Coin"]:
		var slot := UI.panel(slots, Color(0.05, 0.04, 0.04, 0.72))
		slot.custom_minimum_size = Vector2(78, 70)
		var v := VBoxContainer.new()
		slot.add_child(v)
		var n := UI.text(v, "0", 26, UI.GOLD)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		var l := UI.text(v, item + ("  H" if item == "Bread" else ""), 13, Color(0.75, 0.72, 0.65))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_slots[item] = n

	_hurt = ColorRect.new()
	_hurt.color = Color(0.6, 0.02, 0.02)
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.modulate.a = 0.0
	root.add_child(_hurt)
	_float = UI.text(root, "", 24, Color(1.0, 0.92, 0.7))
	_float.autowrap_mode = TextServer.AUTOWRAP_OFF
	_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_float.offset_left = -100
	_float.offset_right = 100
	_float.offset_top = -70
	_float.offset_bottom = -40
	_float.modulate.a = 0.0
	_shadow(_float)
	_cross = UI.text(root, "·", 30, Color(1, 1, 1, 0.7))
	_cross.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_prompt = UI.text(root, "", 22)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -170
	_prompt.offset_bottom = -140
	_shadow(_prompt)

	_log = VBoxContainer.new()
	_log.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log.offset_left = 18
	_log.offset_bottom = -18
	_log.offset_top = -18
	_log.custom_minimum_size = Vector2(620, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_log)

	_build_journal(root)
	_build_fade(root)
	_build_end(root)
	_build_title(root)

	Game.changed.connect(_refresh)
	Game.message.connect(_on_message)
	_refresh()

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

func _bar(parent: Node, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 14)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.1, 0.09)
	bg.border_color = Color(UI.GOLD, 0.45)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b

func _objective() -> String:
	if Game.flags.has("slice_done"):
		return "Walk the island. Most of the Register is still empty."
	if Game.recruits.size() >= Game.SLICE_GOAL:
		return "Return to Harry Lu at the Register."
	if Game.chalk + Game.straps == 0 and Game.journal.is_empty():
		return "Speak to Harry Lu at the Register."
	return "Find three at Tallow Ford who are willing and able  (%d / %d)" % [Game.recruits.size(), Game.SLICE_GOAL]

func _refresh() -> void:
	_health.max_value = Game.max_hp
	_health.value = Game.hp
	_register.max_value = Game.QUOTA
	_register.value = Game.register_count()
	_stats.text = "Health %d / %d      Register %d / %d      %s" % [max(Game.hp, 0), Game.max_hp, Game.register_count(), Game.QUOTA, Game.weapon()["name"]]
	_goal.text = _objective()
	_slots["Chalk"].text = str(Game.chalk)
	_slots["Straps"].text = str(Game.straps)
	_slots["Bread"].text = str(Game.bread)
	_slots["Coin"].text = str(Game.coins)

func _draw_band() -> void:
	if Game.player == null:
		return
	var font := ThemeDB.fallback_font
	var w := _band.size.x
	_band.draw_rect(Rect2(0, 0, w, 34), Color(0.05, 0.04, 0.04, 0.6))
	_band.draw_rect(Rect2(0, 0, w, 34), Color(UI.GOLD, 0.45), false, 1.0)
	var facing := fposmod(rad_to_deg(-Game.player.rotation.y), 360.0)
	var marks := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for deg in range(0, 360, 15):
		var off := wrapf(deg - facing, -180.0, 180.0)
		var x := w / 2.0 + off * 3.2
		if x < -20 or x > w + 20:
			continue
		if marks.has(deg):
			var big: bool = deg % 90 == 0
			var t: String = marks[deg]
			var fs := 20 if big else 13
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_band.draw_string(font, Vector2(x - tw / 2.0, 24), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD if big else Color(0.75, 0.72, 0.65))
		else:
			_band.draw_line(Vector2(x, 12), Vector2(x, 22), Color(0.75, 0.72, 0.65, 0.6), 1.0)
	_band.draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, 7), UI.GOLD, 2.0)

## A quick word at the crosshair: the damage dealt, or "miss".
func float_text(t: String) -> void:
	_float.text = t
	_float.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_float, "modulate:a", 0.0, 0.4)

func hurt_flash() -> void:
	_hurt.modulate.a = 0.45
	create_tween().tween_property(_hurt, "modulate:a", 0.0, 0.5)

func _process(_dt: float) -> void:
	if Game.player == null:
		return
	_wind.max_value = Game.max_fatigue
	_wind.value = Game.fatigue
	_band.queue_redraw()
	var where := "Inside the Ring" if Game.in_ring(Game.player.global_position) else "Outside the Ring"
	var h := int(Game.hour)
	var part := "Night" if Game.is_night() else ("Morning" if h < 11 else ("Midday" if h < 15 else ("Afternoon" if h < 18 else "Evening")))
	_compass.text = "%s   ·   %s" % [where, part]
	var t: Node = Game.player.target
	_prompt.text = "[E]  %s" % t.prompt() if t != null and not Game.modal else ""
	_cross.visible = not Game.modal

func _on_message(t: String) -> void:
	var l := UI.text(_log, t, 18)
	l.custom_minimum_size = Vector2(620, 0)
	_shadow(l)
	if _log.get_child_count() > 5:
		_log.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)

# --- Journal -----------------------------------------------------------------

func _build_journal(root: Control) -> void:
	_journal = CenterContainer.new()
	_journal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_journal)
	var p := UI.panel(_journal)
	p.custom_minimum_size = Vector2(760, 500)
	var v := VBoxContainer.new()
	p.add_child(v)
	UI.text(v, "Journal", 28, UI.GOLD)
	UI.text(v, "What people have told you. Nothing here is marked on any map.", 16, Color(0.7, 0.68, 0.6))
	_journal_text = UI.rich(v, 19)
	UI.button(v, "Close (J)", toggle_journal)
	_journal.visible = false

func toggle_journal() -> void:
	if _journal.visible:
		_journal.visible = false
		UI.close_modal()
		return
	if Game.modal:
		return
	_journal_text.clear()
	if Game.journal.is_empty():
		_journal_text.append_text("[i]Nothing yet. Talk to people.[/i]")
	for j in Game.journal:
		_journal_text.append_text("•  %s\n\n" % j)
	_journal.visible = true
	UI.open_modal()

func _unhandled_input(ev: InputEvent) -> void:
	if _journal.visible and (ev.is_action_pressed("journal") or ev.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle_journal()

# --- Fade, for time passing --------------------------------------------------

func _build_fade(root: Control) -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.add_child(c)
	_fade_text = UI.text(c, "", 24)
	_fade_text.custom_minimum_size = Vector2(700, 0)
	_fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func fade(t: String) -> void:
	_fade_text.text = t
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)

# --- Title and end -------------------------------------------------------------

func _overlay(root: Control) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.03, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	return v

func _build_title(root: Control) -> void:
	var v := _overlay(root)
	_title = v.get_parent().get_parent()
	var t := UI.text(v, "88 RISERS", 64, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.text(v, "The dead cannot rise on their own any more. Whatever dies unattended sinks into the ground and comes back as one of the Pinned.\n\nA Riser knows the rite that lets the dead pass on. There used to be 88. Now there are eight, in one village, inside one ring of safe ground.\n\nYou are a pilgrim. Find more.", 21)
	UI.text(v, "WASD move  ·  mouse look  ·  Shift run  ·  Space jump  ·  left click or F attack  ·  right click or C block\nE talk or use  ·  Tab inventory  ·  V first or third person  ·  J journal  ·  H eat bread  ·  Esc free the mouse\nIn fights and conversations, click a choice or press its number.", 16, Color(0.7, 0.68, 0.6))
	UI.button(v, "Begin", _begin, 24).alignment = HORIZONTAL_ALIGNMENT_CENTER

func _begin() -> void:
	_title.visible = false
	Game.modal = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.say("Harry Lu is waiting by the Register. Talk to him.")

func _build_end(root: Control) -> void:
	var v := _overlay(root)
	_end = v.get_parent().get_parent()
	_end_title = UI.text(v, "", 40, UI.GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.text(v, "That is the end of this slice: Rhodes, one road, one village.\n\nMost of the board is still empty. You can keep walking the island as it is: raise what is left on the road, trade, or do worse.", 21)
	UI.button(v, "Keep playing", _hide_end, 22).alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end.visible = false

func show_end() -> void:
	Game.dialogue.close()
	_end_title.text = "THE REGISTER STANDS AT %d OF %d" % [Game.register_count(), Game.QUOTA]
	_end.visible = true
	UI.open_modal()

func _hide_end() -> void:
	_end.visible = false
	UI.close_modal()
