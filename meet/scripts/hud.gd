extends CanvasLayer
## On-screen display: how you're holding up, touch controls, the bag, photos, the title.

const UI = preload("res://scripts/ui.gd")
const Character = preload("res://scripts/character.gd")
const Wear = preload("res://scripts/wear.gd")

var _stats: Label
var _bar: ProgressBar
var _stam: ProgressBar
var _clock: Label
var _doll: Node3D
var _bag_side: VBoxContainer
var _bag_people: VBoxContainer
var _over_title: Label
var _name_box: LineEdit
var _heat: Label
const STICK := 85.0
var _knob: Panel
var _stick_label: Label
var _pads: Array = []
var _use_pad: Button
var _use_text: Button
var _hint: Label
var _hint_t := 9.0
var _cam_id := -1
var _cam_origin := Vector2.ZERO
var _cam_vec := Vector2.ZERO
var _cam_moved := 0.0
var _cam_knob: Panel
var _dares: VBoxContainer
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
var _stick_base: Panel
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
	_clock = UI.text(col, "", 17, UI.GOLD)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bar = _meter(col, "Health", Color(0.85, 0.25, 0.25))
	_stam = _meter(col, "Stamina", Color(0.3, 0.75, 0.4))
	_stats = UI.text(col, "", 15)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_heat = UI.text(col, "", 15, Color(1.0, 0.55, 0.3))
	_heat.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Tonight's dares, under the panel.
	_dares = VBoxContainer.new()
	_dares.position = Vector2(18, 168)
	_dares.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dares)
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

func _meter(parent: Node, name: String, c: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := UI.text(row, name, 13)
	l.custom_minimum_size = Vector2(62, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(240, 12)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.12, 0.11)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	row.add_child(b)
	return b

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)

func _refresh() -> void:
	_bar.value = Meet.composure
	_stats.text = "$%d  ·  Snacks %d  ·  Chalk %d%s%s  ·  Won %d, lost %d" % [Meet.money, Meet.snacks, Meet.chalk, "  ·  Hands chalked" if Meet.chalked else "",
		"  ·  Straps in pocket %d" % Meet.straps.size() if not Meet.straps.is_empty() else "", Meet.wins, Meet.losses]
	_heat.text = "Heat  %s%s" % ["★".repeat(Meet.stars()), "☆".repeat(5 - Meet.stars())] if Meet.stars() > 0 else ""
	_heat.visible = Meet.stars() > 0
	UI.clear(_dares)
	for d in Meet.dares:
		var tier: int = int(d.get("tier", 0))
		var l := UI.text(_dares, "%s %s%s%s" % ["✔" if d["done"] else "○", "", d["text"], " (%d/%d)" % [d["have"], d["need"]] if d["need"] > 1 and not d["done"] else ""], 14, Color(0.6, 0.9, 0.7) if d["done"] else Color(0.95, 0.92, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_shadow(l)
	if _bag and _bag.visible:
		_fill_bag()

func _process(dt: float) -> void:
	if Meet.player == null:
		return
	var t: Node = Meet.player.target if is_instance_valid(Meet.player.target) else null
	var riding: bool = Meet.player.riding
	_prompt.text = ("[E]  Get off the bike" if riding else "[E]  %s" % t.prompt()) if (t != null or riding) and not Meet.modal and not Meet.touch else ""
	_touch_ui.visible = Meet.touch and not Meet.modal and not _title.visible
	if _cam_id >= 0 and not Meet.modal:
		Meet.player.look += Vector2(_cam_vec.x * 560.0, _cam_vec.y * 300.0) * dt
	if Meet.touch:
		# The big button and the pill above the stick say exactly what a tap will do.
		_use_text.visible = t != null or riding
		if riding:
			_use_text.text = "Get off the bike"
		elif t != null:
			_use_text.text = t.prompt()
		_use_pad.modulate.a = 1.0 if (t != null or riding) else 0.35
		if _touch_ui.visible and _hint_t > 0.0:
			_hint_t -= dt
			_hint.modulate.a = clamp(_hint_t, 0.0, 1.0)
		_hint.visible = _hint_t > 0.0
		if get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x:
			_hint.visible = true
			_hint.modulate.a = 1.0
			_hint.text = "Turn your phone sideways to play."
	_bar.value = Meet.composure
	_stam.value = Meet.stamina
	_clock.text = "%s  ·  Rhodes Amphitheatre  ·  ends 7:30" % Meet.time_text()
	if _bag.visible and _doll:
		_doll.rotation.y += dt * 0.7
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
	var tw := l.create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

# --- Touch ---------------------------------------------------------------------------

func _round(size: float, fill: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(size / 2.0))
	return sb

func _pad(parent: Control, label: String, size: float, at: Vector2, cb: Callable, fill := Color(0.08, 0.07, 0.07, 0.6)) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.add_theme_font_size_override("font_size", int(size * 0.2))
	b.add_theme_color_override("font_color", UI.PAPER)
	b.add_theme_stylebox_override("normal", _round(size, fill, Color(UI.GOLD, 0.7)))
	b.add_theme_stylebox_override("hover", _round(size, fill, Color(UI.GOLD, 0.7)))
	b.add_theme_stylebox_override("pressed", _round(size, Color(0.5, 0.38, 0.15, 0.85), UI.GOLD))
	# Anchored to the bottom-right corner; `at` is the centre, measured back from that corner.
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = -at.x - size / 2.0
	b.offset_right = -at.x + size / 2.0
	b.offset_top = -at.y - size / 2.0
	b.offset_bottom = -at.y + size / 2.0
	b.button_down.connect(cb)
	parent.add_child(b)
	_pads.append(b)
	return b

## Phone controls: a thumbstick that appears under your left thumb, a big context button
## that says what it will do, and everything else in reach of the right thumb.
func _build_touch() -> void:
	_touch_ui = Control.new()
	_touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_touch_ui)
	# The stick: a ring and a knob. It rests bottom-left and jumps to wherever the thumb lands.
	_stick_base = Panel.new()
	_stick_base.size = Vector2(STICK * 2.0, STICK * 2.0)
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_theme_stylebox_override("panel", _round(STICK * 2.0, Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.45)))
	_touch_ui.add_child(_stick_base)
	_knob = Panel.new()
	_knob.size = Vector2(70, 70)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.add_theme_stylebox_override("panel", _round(70, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.8)))
	_touch_ui.add_child(_knob)
	_stick_label = UI.text(_touch_ui, "MOVE", 16, Color(1, 1, 1, 0.75))
	_stick_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shadow(_stick_label)
	# Right thumb. The big one does whatever the prompt says.
	# Tap it to use; hold and drag it to swing the camera, like a second stick.
	_use_pad = _pad(_touch_ui, "USE\ndrag: look", 138, Vector2(112, 122), func(): pass, Color(0.3, 0.22, 0.08, 0.7))
	_use_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pads.erase(_use_pad)
	_cam_knob = Panel.new()
	_cam_knob.size = Vector2(54, 54)
	_cam_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cam_knob.add_theme_stylebox_override("panel", _round(54, Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.8)))
	_cam_knob.visible = false
	_touch_ui.add_child(_cam_knob)
	_pad(_touch_ui, "PUNCH", 104, Vector2(250, 86), func(): Meet.player.slap())
	_pad(_touch_ui, "JUMP", 92, Vector2(124, 292), func(): Meet.player.jump())
	_pad(_touch_ui, "CHALK", 84, Vector2(232, 214), func(): Meet.player.throw_chalk())
	_pad(_touch_ui, "ITEM", 84, Vector2(366, 150), func(): Meet.player.use_item())
	# Less-used things, small, up the right-hand edge.
	var k := 0
	for b in [["BAG", toggle_bag], ["EAT", Meet.eat], ["VIEW", func(): Meet.player.toggle_view()], ["PHOTO", photo], ["SOUND", func(): Meet.audio.set_muted(not Meet.muted)]]:
		var p := _pad(_touch_ui, b[0], 58, Vector2(52, 0), b[1])
		p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		p.offset_left = -70
		p.offset_right = -12
		p.offset_top = 146 + k * 62
		p.offset_bottom = 204 + k * 62
		k += 1
	# What the big button will do, said in words, and tappable itself.
	_use_text = Button.new()
	_use_text.focus_mode = Control.FOCUS_NONE
	_use_text.add_theme_font_size_override("font_size", 24)
	_use_text.add_theme_color_override("font_color", UI.GOLD)
	var pill := _round(52, Color(0.05, 0.04, 0.04, 0.8), Color(UI.GOLD, 0.8))
	pill.set_content_margin_all(12)
	for st in ["normal", "hover", "pressed"]:
		_use_text.add_theme_stylebox_override(st, pill)
	_use_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_use_text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_use_text.offset_top = -150
	_use_text.offset_bottom = -96
	_use_text.button_down.connect(func(): Meet.player.use())
	_touch_ui.add_child(_use_text)
	_pads.append(_use_text)
	# Shown for the first few seconds.
	_hint = UI.text(_touch_ui, "Left thumb: move  (push all the way to run)\nTap the big button to use; hold and drag it to look around\nOr drag anywhere on the right to look", 20, Color(1, 1, 1, 0.95))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_left = -330
	_hint.offset_right = 330
	_shadow(_hint)
	_rest_stick()

func _rest_stick() -> void:
	var w := get_viewport().get_visible_rect().size
	_stick_origin = Vector2(150, w.y - 150)
	_place_stick(Vector2.ZERO)

func _place_stick(v: Vector2) -> void:
	_stick_base.position = _stick_origin - Vector2(STICK, STICK)
	_knob.position = _stick_origin + v * STICK - Vector2(35, 35)
	_stick_label.position = _stick_origin + Vector2(-24, -STICK - 28)
	_stick_label.text = "RUN" if v.length() > 0.9 else ("MOVE" if _stick_id < 0 else "")
	_stick_base.modulate.a = 1.0 if _stick_id >= 0 else 0.55
	_knob.modulate.a = 1.0 if _stick_id >= 0 else 0.55

func _on_pad(p: Vector2) -> bool:
	for b in _pads:
		if b.is_visible_in_tree() and b.get_global_rect().grow(8).has_point(p):
			return true
	return false

## The left side of the screen is the stick, wherever the thumb comes down. Anywhere else
## that is not a button turns the camera.
func _input(ev: InputEvent) -> void:
	if not Meet.touch or Meet.modal:
		if _stick_id >= 0 or _look_id >= 0 or _cam_id >= 0:
			_stick_id = -1
			_look_id = -1
			_cam_id = -1
			_cam_vec = Vector2.ZERO
			_cam_knob.visible = false
			Meet.stick = Vector2.ZERO
			_rest_stick()
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			var w := get_viewport().get_visible_rect().size
			if _use_pad.get_global_rect().grow(6).has_point(ev.position) and _cam_id < 0:
				_cam_id = ev.index
				_cam_origin = ev.position
				_cam_vec = Vector2.ZERO
				_cam_moved = 0.0
				return
			if _on_pad(ev.position):
				return
			if ev.position.x < w.x * 0.45 and ev.position.y > 150 and _stick_id < 0:
				_stick_id = ev.index
				_stick_origin = Vector2(clamp(ev.position.x, STICK + 10, w.x * 0.45), clamp(ev.position.y, 150 + STICK, w.y - STICK - 10))
				_hint_t = min(_hint_t, 1.5)
				_place_stick(Vector2.ZERO)
			elif _look_id < 0:
				_look_id = ev.index
		else:
			if ev.index == _stick_id:
				_stick_id = -1
				Meet.stick = Vector2.ZERO
				_rest_stick()
			if ev.index == _look_id:
				_look_id = -1
			if ev.index == _cam_id:
				_cam_id = -1
				_cam_vec = Vector2.ZERO
				_cam_knob.visible = false
				if _cam_moved < 16.0:
					Meet.player.use()
	elif ev is InputEventScreenDrag:
		if ev.index == _cam_id:
			_cam_moved = max(_cam_moved, (ev.position - _cam_origin).length())
			var cv: Vector2 = ((ev.position - _cam_origin) / 75.0).limit_length(1.0)
			_cam_vec = cv if cv.length() > 0.2 else Vector2.ZERO
			_cam_knob.visible = _cam_moved >= 16.0
			_cam_knob.position = _cam_origin + cv * 75.0 - Vector2(27, 27)
			return
		if ev.index == _stick_id:
			var v: Vector2 = ((ev.position - _stick_origin) / STICK).limit_length(1.0)
			# A small dead zone so a resting thumb doesn't creep.
			Meet.stick = v if v.length() > 0.15 else Vector2.ZERO
			_place_stick(v)
		elif ev.index == _look_id:
			Meet.player.look += Vector2(ev.relative.x * 0.75, ev.relative.y * 0.45)

# --- Bag -----------------------------------------------------------------------------

func _build_bag() -> void:
	_bag = CenterContainer.new()
	_bag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_bag)
	var p := UI.panel(_bag)
	p.custom_minimum_size = Vector2(1140, 640)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	# You: the figure, your standing, how you're holding up.
	_bag_side = VBoxContainer.new()
	_bag_side.custom_minimum_size = Vector2(250, 0)
	h.add_child(_bag_side)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(250, 320)
	svc.stretch = true
	_bag_side.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(250, 320)
	svc.add_child(sv)
	var stage := Node3D.new()
	sv.add_child(stage)
	_doll = Character.make(stage, {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": Color(0.2, 0.2, 0.22)})
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.1)
	cam.fov = 40
	stage.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	stage.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.08, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.75, 0.7)
	we.environment = env
	stage.add_child(we)
	# Kit.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	UI.text(mid, "Your kit", 28, UI.GOLD)
	UI.text(mid, "Won, found or dropped from the sky. Yours between visits. Tap to wear or take off.", 14, Color(0.75, 0.72, 0.62))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(sc)
	_bag_list = VBoxContainer.new()
	_bag_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_list.add_theme_constant_override("separation", 6)
	sc.add_child(_bag_list)
	var row := HBoxContainer.new()
	mid.add_child(row)
	UI.button(row, "Eat a snack", Meet.eat, 18).custom_minimum_size = Vector2(150, 0)
	UI.button(row, "Put down what's in your hand", _put_down.bind("hand"), 16).custom_minimum_size = Vector2(250, 0)
	UI.button(row, "Take off and leave hat", _put_down.bind("head"), 16).custom_minimum_size = Vector2(200, 0)
	UI.button(row, "Close", toggle_bag, 18).custom_minimum_size = Vector2(180, 0)
	# The club.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	h.add_child(right)
	UI.text(right, "Where you stand", 22, UI.GOLD)
	_bag_people = VBoxContainer.new()
	_bag_people.add_theme_constant_override("separation", 5)
	right.add_child(_bag_people)
	_bag.visible = false

## Leave a piece of kit on the ground where you stand. It can be picked up again, by you.
func _put_down(slot: String) -> void:
	var item: String = Meet.worn[slot]
	if item == "":
		Meet.say("Nothing there to put down.")
		return
	Meet.worn[slot] = ""
	Meet.away[item] = true
	var at: Vector3 = Meet.player.global_position - Meet.player.global_transform.basis.z * 0.9
	Meet.main.leave_item(item, at)
	toggle_bag()
	Meet.touch_state()
	Meet.say("You put the %s down. If you leave it, it finds its way back to your bag by next week." % Meet.ITEMS[item]["name"].to_lower())

func _tile(parent: Node, id: String) -> void:
	var it: Dictionary = Meet.ITEMS[id]
	var have: bool = Meet.owned.has(id)
	var on: bool = Meet.worn[it["slot"]] == id
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 78)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 14)
	b.text = (it["name"] + ("\n(left on the ground)" if Meet.away.has(id) else "")) if have else "? ? ?\n%s" % it["how"]
	b.tooltip_text = it["how"]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.16, 0.12) if have else Color(0.1, 0.09, 0.09)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.border_width_left = 10
	sb.border_color = Wear.COLORS.get(id, Color.GRAY) if have else Color(0.25, 0.25, 0.25)
	if on:
		sb.set_border_width_all(3)
		sb.border_width_left = 10
		sb.border_color = UI.GOLD
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", UI.GOLD if on else (UI.PAPER if have else Color(0.5, 0.48, 0.44)))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.44))
	b.disabled = not have
	b.pressed.connect(Meet.wear.bind(id))
	parent.add_child(b)

func _fill_bag() -> void:
	Wear.dress(_doll, Meet.worn)
	UI.clear(_bag_list)
	for slot in [["hand", "In your hand (and what you swing)"], ["head", "On your head"], ["body", "On your body"]]:
		var on: String = Meet.worn[slot[0]]
		UI.text(_bag_list, "%s:  %s" % [slot[1], Meet.ITEMS[on]["name"] if on != "" else "nothing"], 16, UI.GOLD)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_bag_list.add_child(grid)
		for id in Meet.ITEMS:
			if Meet.ITEMS[id]["slot"] == slot[0]:
				_tile(grid, id)
	# You.
	while _bag_side.get_child_count() > 1:
		var c := _bag_side.get_child(1)
		_bag_side.remove_child(c)
		c.queue_free()
	UI.text(_bag_side, Meet.standing(), 20, UI.GOLD)
	var rep := _meter(_bag_side, "Standing", UI.GOLD)
	rep.custom_minimum_size = Vector2(170, 12)
	rep.value = Meet.reputation()
	UI.text(_bag_side, "Reputation %d / 100" % Meet.reputation(), 14)
	UI.text(_bag_side, "Health %d   Stamina %d" % [Meet.composure, Meet.stamina], 14)
	UI.text(_bag_side, "Money $%d" % Meet.money, 16, UI.GOLD)
	UI.text(_bag_side, "Snacks %d   Chalk %d%s" % [Meet.snacks, Meet.chalk, "   Hands chalked" if Meet.chalked else ""], 14)
	if not Meet.straps.is_empty():
		var names: Array = Meet.straps.map(func(id): return Meet.riser(id).first_name)
		UI.text(_bag_side, "Straps in your pocket: %s" % ", ".join(names), 14, Color(0.95, 0.6, 0.5))
	UI.text(_bag_side, "Pulls: %d won, %d lost\nVisits %d   Recruits %d   Tips %d" % [Meet.wins, Meet.losses, Meet.visits, Meet.recruits, Meet.tips], 14, Color(0.75, 0.72, 0.62))
	# Everyone else.
	UI.clear(_bag_people)
	for r in Meet.risers:
		if not r.is_riser:
			continue
		var f: float = r.mind.feeling()
		var line := UI.text(_bag_people, "%s  —  %s" % [r.first_name, r.attitude()], 13, Color(0.95, 0.6, 0.5) if f < -0.15 else (UI.GOLD if f > 0.3 else UI.PAPER))
		line.custom_minimum_size = Vector2(290, 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(280, 7)
		bar.show_percentage = false
		bar.min_value = -1.0
		bar.max_value = 1.0
		bar.step = 0.01
		bar.value = f
		_bag_people.add_child(bar)
		var bm: Array = r.best_mate()
		var word: String = Meet.tie_word(bm[1])
		if word != "":
			UI.text(_bag_people, "   %s %s" % [word, bm[0].first_name], 12, Color(0.65, 0.62, 0.55))

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
	if Meet.main.match_on() and Meet.main.TABLES[Meet.main.nearest_match(Meet.player.global_position)].distance_to(Meet.player.global_position) < 6.0:
		Meet.errand("george", "ready")
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
	UI.text(v, "It's Sunday, five o'clock, and the meet runs till half past seven: fifteen minutes of your time. Walk in. Talk to people, pull at the table, eat the snacks, chalk your hands or throw it at someone, borrow a strap when nobody's looking, bother the public, take a photo. What people think of you, and what you've won, stays with you between visits.", 19)
	if Meet.touch:
		UI.text(v, "Left thumb moves, drag to look around, buttons on the right.", 16, Color(0.75, 0.72, 0.62))
	else:
		UI.text(v, "WASD move  ·  mouse look  ·  Shift run  ·  Space jump  ·  E talk or use  ·  click or F punch  ·  G throw chalk  ·  X use what's in your hand  ·  C look at yourself  ·  R eat a snack  ·  M sound  ·  Tab bag  ·  P photo  ·  Esc free the mouse", 16, Color(0.75, 0.72, 0.62))
	var g: Dictionary = load("res://scripts/people.gd").GUESTS[Meet.week() % 5]
	var f: Dictionary = load("res://scripts/people.gd").FINDS[Meet.week() % 4]
	var wk := "This week: %s is visiting." % g["name"]
	if not Meet.owned.has(f["item"]):
		wk += " And somebody has left something %s." % f["hint"]
	UI.text(v, wk, 16, Color(0.65, 0.85, 1.0))
	if Meet.last_recap != "":
		UI.text(v, Meet.last_recap, 15, Color(0.75, 0.72, 0.62))
	UI.text(v, "What do they call you?", 16, UI.GOLD)
	_name_box = LineEdit.new()
	_name_box.placeholder_text = "Your name"
	_name_box.max_length = 16
	_name_box.text = Meet.player_name
	_name_box.add_theme_font_size_override("font_size", 22)
	_name_box.custom_minimum_size = Vector2(0, 48)
	_name_box.text_submitted.connect(func(_t): _begin())
	v.add_child(_name_box)
	UI.button(v, "Walk in", _begin, 26).alignment = HORIZONTAL_ALIGNMENT_CENTER

func _begin() -> void:
	Meet.player_name = _name_box.text.strip_edges()
	_name_box.release_focus()
	Meet.player.set_name_tag()
	_title.visible = false
	Meet.modal = false
	if not Meet.touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Meet.audio.set_muted(Meet.muted)
	Meet.say("Visit %d. The tables are out and the lights are on. Three dares for tonight are on the left." % Meet.visits)
	Meet.save()

func _build_over() -> void:
	var v := _overlay()
	_over = v.get_parent().get_parent()
	_over_title = UI.text(v, "SENT HOME", 50, UI.GOLD)
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_text = UI.text(v, "", 21)
	UI.button(v, "Come back next week", _again, 24).alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.visible = false

func night_over(text: String, title := "SENT HOME") -> void:
	if _over.visible:
		return
	_over_title.text = title
	Meet.menu.close()
	_over_text.text = text
	_over.visible = true
	UI.open_modal()
	Meet.save()

func _again() -> void:
	Meet.new_night()
	get_tree().reload_current_scene()
