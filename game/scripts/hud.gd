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
var _end_title: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_stats = UI.text(root, "", 19)
	_stats.position = Vector2(18, 14)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(_stats)

	_compass = UI.text(root, "", 22, UI.GOLD)
	_compass.autowrap_mode = TextServer.AUTOWRAP_OFF
	_compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_compass.offset_top = 14
	_compass.offset_right = -18
	_shadow(_compass)

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

func _refresh() -> void:
	_stats.text = "Health %d / %d     Chalk %d     Straps %d     Bread %d     Coin %d\nRegister %d / %d" % [
		Game.hp, Game.max_hp, Game.chalk, Game.straps, Game.bread, Game.coins, Game.register_count(), Game.QUOTA]

func _process(_dt: float) -> void:
	if Game.player == null:
		return
	var where := "Inside the Ring" if Game.in_ring(Game.player.global_position) else "Outside the Ring"
	_compass.text = "%s   ·   %s" % [Game.player.heading(), where]
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
	UI.text(v, "WASD move  ·  mouse look (arrow keys also turn)  ·  Shift run  ·  E talk or use  ·  J journal  ·  H eat bread  ·  Esc free the mouse\nIn fights and conversations, click a choice or press its number.", 16, Color(0.7, 0.68, 0.6))
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
