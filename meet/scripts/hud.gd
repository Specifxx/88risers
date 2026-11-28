extends CanvasLayer
## On-screen display: how you're holding up, touch controls, the bag, photos, the title.

const UI = preload("res://scripts/ui.gd")

var _stats: Label
var _bar: ProgressBar
var _prompt: Label
var _log: VBoxContainer
var _float: Label
var _bag: Control
var _bag_list: VBoxContainer
var _title: Control
var _over: Control
var _over_text: Label
var _root: Control
var _touch_ui: Control
var _stick_base: Control
var _stick_id := -1
var _look_id := -1
var _stick_origin := Vector2.ZERO
var _shake := 0.0

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top := UI.panel(_root, Color(0.05, 0.04, 0.04, 0.72))
	top.position = Vector2(14, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)
	var crest := TextureRect.new()
	crest.texture = load("res://assets/ui/emblem.png")
	crest.custom_minimum_size = Vector2(56, 56)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(crest)
	var col := VBoxContainer.new()
	row.add_child(col)
	UI.text(col, "Meet night  ·  Rhodes Amphitheatre", 15, UI.GOLD).autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(280, 10)
	_bar.show_percentage = false
	col.add_child(_bar)
	_stats = UI.text(col, "", 15)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt = UI.text(_root, "", 22)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -210
	_prompt.offset_bottom = -180
	_shadow(_prompt)
	_float = UI.text(_root, "", 26, Color(1.0, 0.92, 0.6))
	_float.autowrap_mode = TextServer.AUTOWRAP_OFF
	_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_float.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_float.offset_left = -150
	_float.offset_right = 150
	_float.offset_top = -90
	_float.modulate.a = 0.0
	_shadow(_float)
	_log = VBoxContainer.new()
	_log.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_log.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log.offset_right = -16
	_log.offset_top = 14
	_log.custom_minimum_size = Vector2(520, 0)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_log)
	_build_touch()
	_build_bag()
	_build_over()
	_build_title()
	Meet.changed.connect(_refresh)
	Meet.toast.connect(_toast)
	_refresh()

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

func _refresh() -> void:
	_bar.max_value = 100.0
	_bar.value = Meet.composure
	_stats.text = "Snacks %d  ·  Chalk %d%s%s  ·  Won %d, lost %d" % [Meet.snacks, Meet.chalk, "  ·  Hands chalked" if Meet.chalked else "",
		"  ·  Straps in pocket %d" % Meet.straps.size() if not Meet.straps.is_empty() else "", Meet.wins, Meet.losses]
	if _bag and _bag.visible:
		_fill_bag()

func _process(dt: float) -> void:
	if Meet.player == null:
		return
	var t: Node = Meet.player.target
	var key := "Tap USE" if Meet.touch else "[E]"
	_prompt.text = "%s  %s" % [key, t.prompt()] if t != null and not Meet.modal else ""
	_touch_ui.visible = Meet.touch and not Meet.modal
	_bar.value = Meet.composure
	if _shake > 0.0:
		_shake -= dt
		_root.position = Vector2(randf_range(-6, 6), randf_range(-6, 6)) if _shake > 0.0 else Vector2.ZERO

func shake() -> void:
	_shake = 0.25

func float_text(t: String) -> void:
	_float.text = t
	_float.modulate.a = 1.0
	create_tween().tween_property(_float, "modulate:a", 0.0, 0.8)

func _toast(t: String) -> void:
	var l := UI.text(_log, t, 17)
	l.custom_minimum_size = Vector2(520, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shadow(l)
	if _log.get_child_count() > 4:
		_log.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

# --- Touch ---------------------------------------------------------------------------

func _build_touch() -> void:
	_touch_ui = Control.new()
	_touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_touch_ui)
	_stick_base = UI.panel(_touch_ui, Color(1, 1, 1, 0.1))
	_stick_base.custom_minimum_size = Vector2(150, 150)
	_stick_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_stick_base.offset_left = 40
	_stick_base.offset_top = -200
	_stick_base.offset_right = 190
	_stick_base.offset_bottom = -50
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grid.offset_right = -30
	grid.offset_bottom = -40
	_touch_ui.add_child(grid)
	for b in [["USE", func(): Meet.player.use()], ["PUNCH", func(): Meet.player.slap()], ["CHALK", func(): Meet.player.throw_chalk()], ["JUMP", func(): Meet.player.jump()], ["BAG", toggle_bag], ["PHOTO", photo]]:
		var btn := UI.button(grid, b[0], b[1], 20)
		btn.custom_minimum_size = Vector2(110, 70)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

## Left half of the screen moves you; dragging anywhere else turns the camera.
func _input(ev: InputEvent) -> void:
	if not Meet.touch or Meet.modal:
		_stick_id = -1
		_look_id = -1
		Meet.stick = Vector2.ZERO
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var w := get_viewport().get_visible_rect().size
			if ev.position.x < w.x * 0.4 and ev.position.y > w.y * 0.35 and _stick_id < 0:
				_stick_id = ev.index
				_stick_origin = ev.position
			elif ev.position.x >= w.x * 0.4 and ev.position.x < w.x - 390 and _look_id < 0:
				_look_id = ev.index
		else:
			if ev.index == _stick_id:
				_stick_id = -1
				Meet.stick = Vector2.ZERO
			if ev.index == _look_id:
				_look_id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == _stick_id:
			Meet.stick = ((ev.position - _stick_origin) / 70.0).limit_length(1.0)
		elif ev.index == _look_id:
			Meet.player.look += ev.relative * 0.6

# --- Bag -----------------------------------------------------------------------------

func _build_bag() -> void:
	_bag = CenterContainer.new()
	_bag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_bag)
	var p := UI.panel(_bag)
	p.custom_minimum_size = Vector2(760, 520)
	var v := VBoxContainer.new()
	p.add_child(v)
	UI.text(v, "Your bag", 28, UI.GOLD)
	UI.text(v, "Things you've won or found. They stay yours between visits. Tap one to wear it or take it off.", 15, Color(0.75, 0.72, 0.62))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_bag_list = VBoxContainer.new()
	_bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_list.add_theme_constant_override("separation", 4)
	sc.add_child(_bag_list)
	UI.button(v, "Close", toggle_bag, 18)
	_bag.visible = false

func _fill_bag() -> void:
	UI.clear(_bag_list)
	for id in Meet.ITEMS:
		var it: Dictionary = Meet.ITEMS[id]
		if Meet.owned.has(id):
			var on: bool = Meet.worn[it["slot"]] == id
			var b := UI.button(_bag_list, "%s%s" % ["● " if on else "", it["name"]], Meet.wear.bind(id), 18)
			if on:
				b.add_theme_color_override("font_color", UI.GOLD)
		else:
			UI.text(_bag_list, "?  ?  ?      %s" % it["how"], 15, Color(0.55, 0.53, 0.48))

func toggle_bag() -> void:
	if _bag.visible:
		_bag.visible = false
		UI.close_modal()
	elif not Meet.modal:
		_bag.visible = true
		_fill_bag()
		UI.open_modal()

# --- Photos ------------------------------------------------------------------------------

## Capture the moment, with nothing on screen but the meet.
func photo() -> void:
	if Meet.modal:
		return
	_root.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_root.visible = true
	Meet.moments += 1
	var name := "88risers-moment-%d.png" % Meet.moments
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), name, "image/png")
		Meet.say("Saved to your downloads: %s" % name)
	else:
		img.save_png("user://" + name)
		Meet.say("Photo saved.")
	Meet.save()

# --- Title, and being sent home ----------------------------------------------------------

func _overlay() -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.04, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	return v

func _build_title() -> void:
	var v := _overlay()
	_title = v.get_parent().get_parent()
	var t := UI.text(v, "MEET NIGHT", 62, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := UI.text(v, "88 Risers  ·  Rhodes Amphitheatre", 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.text(v, "It's a club night. Walk in. Talk to people, pull at the table, eat the snacks, chalk your hands or throw it at someone, borrow a strap when nobody's looking, bother the public, take a photo. What people think of you, and what you've won, stays with you between visits.", 19)
	if Meet.touch:
		UI.text(v, "Left thumb moves, drag to look around, buttons on the right.", 16, Color(0.75, 0.72, 0.62))
	else:
		UI.text(v, "WASD move  ·  mouse look  ·  Shift run  ·  Space jump  ·  E talk or use  ·  click or F punch  ·  G throw chalk  ·  Tab bag  ·  P photo  ·  Esc free the mouse", 16, Color(0.75, 0.72, 0.62))
	UI.button(v, "Walk in", _begin, 26).alignment = HORIZONTAL_ALIGNMENT_CENTER

func _begin() -> void:
	_title.visible = false
	Meet.modal = false
	if not Meet.touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Meet.say("Visit %d. The tables are out and the lights are on." % Meet.visits)
	Meet.save()

func _build_over() -> void:
	var v := _overlay()
	_over = v.get_parent().get_parent()
	var t := UI.text(v, "SENT HOME", 50, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_text = UI.text(v, "", 21)
	UI.button(v, "Come back next week", _again, 24).alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.visible = false

func night_over(text: String) -> void:
	Meet.menu.close()
	_over_text.text = text
	_over.visible = true
	UI.open_modal()
	Meet.save()

func _again() -> void:
	Meet.new_night()
	get_tree().reload_current_scene()
