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
		var l := UI.text(_dares, "%s %s%s%s" % ["✔" if d["done"] else "○", ("[%s] " % Meet.TIER_NAME[tier]) if tier > 0 else "", d["text"], " (%d/%d)" % [d["have"], d["need"]] if d["need"] > 1 and not d["done"] else ""], 14, Color(0.6, 0.9, 0.7) if d["done"] else [Color(0.95, 0.92, 0.85), Color(1.0, 0.8, 0.4), Color(1.0, 0.5, 0.45)][tier])
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_shadow(l)
	if _bag and _bag.visible:
		_fill_bag()

func _process(dt: float) -> void:
	if Meet.player == null:
		return
	var t: Node = Meet.player.target if is_instance_valid(Meet.player.target) else null
	var key := "Tap USE" if Meet.touch else "[E]"
	_prompt.text = "%s  %s" % [key, t.prompt()] if t != null and not Meet.modal else ""
	_touch_ui.visible = Meet.touch and not Meet.modal
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
	for b in [["USE", func(): Meet.player.use()], ["PUNCH", func(): Meet.player.slap()], ["CHALK", func(): Meet.player.throw_chalk()], ["ITEM", func(): Meet.player.use_item()], ["VIEW", func(): Meet.player.toggle_view()], ["JUMP", func(): Meet.player.jump()], ["BAG", toggle_bag], ["PHOTO", photo]]:
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
