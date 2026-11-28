extends Node3D
## One of the Pinned. Roams near where it died, comes for the player outside the Ring,
## and gets back up after being killed unless it is raised.

const Build = preload("res://scripts/build.gd")

const SEE := 17.0
const TOUCH := 1.7

var spirit: Dictionary
var home := Vector3.ZERO
var state := "roam"  # roam | down | gone
var known := false
var _timer := 0.0
var _grace := 0.0
var _target := Vector3.ZERO
var _body: Node3D
var _label: Label3D

func setup(s: Dictionary, at: Vector3, delay := 0.0) -> void:
	spirit = s
	home = at
	position = at
	_target = at
	_body = Node3D.new()
	add_child(_body)
	var dark := Color(0.07, 0.07, 0.09)
	var tall := 1.0
	if String(s["shape"]).contains("small"):
		tall = 0.62
	elif String(s["shape"]).contains("tall"):
		tall = 1.25
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.9
	cm.radial_segments = 8
	cm.rings = 2
	var torso := Build.mesh(_body, cm, Vector3(0, 0.95, 0), dark)
	torso.rotation.x = 0.22
	Build.sphere(_body, 0.2, Vector3(0, 1.9, 0.26), dark)
	Build.sphere(_body, 0.045, Vector3(-0.08, 1.93, 0.43), Color(1.0, 0.75, 0.3), 3.0)
	Build.sphere(_body, 0.045, Vector3(0.08, 1.93, 0.43), Color(1.0, 0.75, 0.3), 3.0)
	_body.scale = Vector3(1, tall, 1)
	_label = Build.label(self, s["shape"], 2.5 * tall, Color(0.8, 0.8, 0.9), 30)
	if delay > 0.0:
		state = "down"
		_timer = delay
		_show_down()

func _show_down() -> void:
	_body.visible = false
	_label.visible = false

func display_name() -> String:
	return spirit["name"] if known else spirit["shape"]

func reveal() -> void:
	known = true
	_label.text = spirit["name"]

## Killed but not raised: it sinks, and will be back.
func put_down() -> void:
	state = "down"
	_timer = 50.0
	_show_down()

func raise_up() -> void:
	state = "gone"
	_show_down()
	Game.raised += 1
	Game.rep["tallow"] += 10

func back_off() -> void:
	_grace = 6.0

func _process(dt: float) -> void:
	if state == "gone" or Game.player == null:
		return
	if state == "down":
		_timer -= dt
		if _timer <= 0.0:
			state = "roam"
			position = home
			_body.visible = true
			_label.visible = true
			_grace = 2.0
		return
	if Game.modal:
		return
	_grace = max(0.0, _grace - dt)
	var p: Vector3 = Game.player.global_position
	var d := global_position.distance_to(p)
	var safe := Game.in_ring(p)
	var speed := 1.1
	var goal := _target
	if d < SEE and not safe and _grace <= 0.0:
		goal = p
		speed = 3.5
	elif global_position.distance_to(_target) < 1.0:
		_target = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	var to := goal - global_position
	to.y = 0
	if to.length() > 0.05:
		var step := to.normalized() * speed * dt
		var next := global_position + step
		# The Pinned cannot cross the Ring.
		if Vector2(next.x, next.z).length() > Game.RING_RADIUS + 2.0:
			global_position = next
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.12)
	_body.position.y = sin(Time.get_ticks_msec() / 260.0 + home.x) * 0.05
	if d < TOUCH and not safe and _grace <= 0.0:
		Game.battle.start_pinned(self)
