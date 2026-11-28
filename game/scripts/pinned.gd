extends Node3D
## One of the Pinned. Roams near where it died, comes for the player outside the Ring,
## and gets back up after being killed unless it is raised.

const Build = preload("res://scripts/build.gd")
const Character = preload("res://scripts/character.gd")

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
	var tall := 1.0
	var look := {"body": "Male_Peasant", "shade": Color(0.045, 0.045, 0.06)}
	if String(s["shape"]).contains("small"):
		tall = 0.6
	elif String(s["shape"]).contains("tall"):
		tall = 1.22
		look["body"] = "Male_Ranger"
		look["hood"] = true
	if String(s["name"]).begins_with("Edda"):
		look["body"] = "Female_Ranger"
	_body = Character.make(self, look)
	_body.scale = Vector3(tall, tall, tall)
	_label = Build.label(self, s["shape"], 2.15 * tall, Color(0.8, 0.8, 0.9), 24)
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
	Game.word("raised", 0.9, 1.0, "tallow", spirit["name"])
	Game.word("raised", 0.6, 0.5, "rhodes", spirit["name"])

func face_off() -> void:
	Character.play(_body, "Sword_Idle")

func back_off() -> void:
	_grace = 6.0

func _process(dt: float) -> void:
	if state == "gone" or Game.player == null:
		return
	if state == "down":
		_timer -= dt
		if _timer <= 0.0:
			state = "roam"
			global_position = home
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
	elif Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 1.0:
		_target = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	var to := goal - global_position
	to.y = 0
	var moving := false
	if to.length() > 0.3:
		var step := to.normalized() * speed * dt
		var next := global_position + step
		# The Pinned cannot cross the Ring.
		if Vector2(next.x, next.z).length() > Game.RING_RADIUS + 2.0:
			global_position = Game.main.ground(next)
			moving = true
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.12)
	Character.play(_body, ("Jog_Fwd" if speed > 2.0 else "Walk") if moving else "Idle")
	if d < TOUCH and not safe and _grace <= 0.0:
		Game.battle.start_pinned(self)
