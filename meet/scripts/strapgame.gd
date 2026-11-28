extends CanvasLayer
## Strapping two pullers' hands together: three quick timed taps. Wrap, cross, pull tight.

const UI = preload("res://scripts/ui.gd")
const STEPS := ["Wrap it round", "Cross it over", "Pull it TIGHT"]
var _steps: Array = STEPS
var _head: Label

var step := 0
var hits := 0
var pos := 0.0
var zone := 0.5
var width := 0.26
var _ph := 0.0
var _t := 0.0
var _done: Callable
var _root: Control
var _call: Label
var _track: Control
var _zone: ColorRect
var _needle: ColorRect

func _ready() -> void:
	layer = 23
	_root = CenterContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var p := UI.panel(_root)
	p.custom_minimum_size = Vector2(640, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_head = UI.text(v, "Strap them in", 24, UI.GOLD)
	_call = UI.text(v, "", 26)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 40)
	v.add_child(_track)
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_track.add_child(bg)
	_zone = ColorRect.new()
	_zone.color = UI.GOLD
	_track.add_child(_zone)
	_needle = ColorRect.new()
	_track.add_child(_needle)
	var b := UI.button(v, "TAP   (Space, click or tap)", tap, 22)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, 56)
	_root.visible = false

func active() -> bool:
	return _root.visible

func start(done: Callable, title := "Strap them in", steps: Array = STEPS) -> void:
	_done = done
	_steps = steps
	_head.text = title
	step = 0
	hits = 0
	_root.visible = true
	UI.open_modal()
	_next()

func _next() -> void:
	zone = randf_range(0.25, 0.75)
	width = 0.26 - step * 0.05
	_ph = randf() * TAU
	_t = 0.0
	_call.text = "%d of %d: %s" % [step + 1, _steps.size(), _steps[step]]

func _unhandled_input(ev: InputEvent) -> void:
	if not active():
		return
	if (ev is InputEventKey and ev.keycode == KEY_SPACE and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		get_viewport().set_input_as_handled()
		tap()

func _process(dt: float) -> void:
	if not active():
		return
	tick(dt)
	var w := _track.size.x
	_zone.position = Vector2((zone - width / 2.0) * w, 4)
	_zone.size = Vector2(width * w, 32)
	_needle.position = Vector2(pos * w - 3, 0)
	_needle.size = Vector2(6, 40)

func tick(dt: float) -> void:
	_t += dt
	_ph += dt * (4.5 + step * 1.2)
	pos = (sin(_ph) + 1.0) / 2.0
	if _t > 4.0:
		tap()

func tap() -> void:
	if not active():
		return
	if absf(pos - zone) < width / 2.0:
		hits += 1
	step += 1
	if step >= _steps.size():
		_root.visible = false
		UI.close_modal()
		_done.call(hits)
	else:
		_next()
