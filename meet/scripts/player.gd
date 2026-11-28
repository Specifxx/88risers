extends CharacterBody3D
## You, at the meet: walk about, talk to people, pull at the table, and wear whatever you've won.

const Character = preload("res://scripts/character.gd")
const Asia = preload("res://scripts/asia.gd")
const Build = preload("res://scripts/build.gd")
const Fx = preload("res://scripts/fx.gd")
const Wear = preload("res://scripts/wear.gd")

const WALK := 4.2
const RUN := 7.0
const REACH := 3.2

var cam: Camera3D
var target: Node = null
var look := Vector2.ZERO       # camera drag from touch, consumed each frame
var _pitch := -0.12
var _pivot: Node3D
var _figure: Node3D
var _push := Vector3.ZERO
var _jump := 0.0
var _jump_v := 0.0
var _cooldown := 0.0
var _hold := 0.0
var _down := 0.0
var _worn := {}

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_pivot = Node3D.new()
	_pivot.position.y = 1.6
	add_child(_pivot)
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 900
	cam.position = Vector3(0.5, 0.4, 3.4)
	_pivot.add_child(cam)
	cam.current = true
	_figure = Character.make(self, {"body": "Male_Peasant", "hair": "Hair_Buzzed", "tint": Color(0.2, 0.2, 0.22)})
	_figure.rotation.y = PI
	Asia.quad(_figure, Vector2(0.3, 0.3), Vector3(0, 1.3, -0.17), PI, "ui/emblem.png", true, 0.25)
	rotation.y = 0.0
	Meet.changed.connect(_dress)
	_dress()

func _unhandled_input(ev: InputEvent) -> void:
	if Meet.modal:
		return
	if ev is InputEventMouseButton and ev.pressed and not Meet.touch:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			slap()
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look += ev.relative
	elif ev.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev.is_action_pressed("interact"):
		use()
	elif ev.is_action_pressed("slap"):
		slap()
	elif ev.is_action_pressed("jump"):
		jump()
	elif ev.is_action_pressed("chalk"):
		throw_chalk()
	elif ev.is_action_pressed("eat"):
		Meet.eat()
	elif ev.is_action_pressed("bag"):
		Meet.hud.toggle_bag()
	elif ev.is_action_pressed("photo"):
		Meet.hud.photo()

func use() -> void:
	if target != null and not Meet.modal:
		target.interact()

func jump() -> void:
	if _jump <= 0.0 and _down <= 0.0 and Meet.stamina >= 8.0:
		Meet.stamina -= 8.0
		_jump_v = 5.6

## Play a one-off movement: reaching for a snack, kneeling at a bag.
func act(anim: String, seconds: float) -> void:
	_hold = seconds
	Character.play(_figure, anim, true)

## A slap, a shove, a swing of whatever you're holding. Nobody gets hurt. People do get cross.
func slap() -> void:
	if _cooldown > 0.0 or Meet.modal or _down > 0.0:
		return
	if Meet.stamina < 10.0:
		Meet.hud.float_text("out of breath")
		return
	Meet.stamina -= 10.0
	_cooldown = 0.55
	_hold = 0.6
	# Whatever is in your hand gets swung like it is meant to be swung.
	Character.play(_figure, "Sword_Attack" if Meet.worn["hand"] != "" else "Punch_Cross", true)
	var fwd := -global_transform.basis.z
	var best: Node3D = null
	var bd := 99.0
	for n in get_tree().get_nodes_in_group("hittable"):
		if not n.can_be_hit():
			continue
		var to: Vector3 = n.global_position - global_position
		to.y = 0
		if to.length() < 2.2 and to.length() < bd and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.4):
			best = n
			bd = to.length()
	if best == null:
		return
	best.take_hit(int(22.0 * Meet.hit_power()), global_position)
	if Meet.worn["hand"] == "rubber_chicken":
		Meet.hud.float_text("squeak")
	Fx.burst(Meet.main, best.global_position + Vector3(0, 1.3, 0), Vector3.UP, false, 8)

## A handful of chalk at whoever is in front of you.
func throw_chalk() -> void:
	if _cooldown > 0.0 or Meet.modal or _down > 0.0:
		return
	if Meet.chalk <= 0:
		Meet.say("No chalk in your hand. The bucket's by the middle table.")
		return
	Meet.chalk -= 1
	_cooldown = 0.6
	_hold = 0.45
	Character.play(_figure, "Punch_Jab", true)
	var fwd := -global_transform.basis.z
	var best: Node3D = null
	var bd := 99.0
	for n in get_tree().get_nodes_in_group("hittable"):
		var to: Vector3 = n.global_position - global_position
		to.y = 0
		if to.length() < 9.0 and to.length() < bd and fwd.dot(to.normalized()) > 0.75:
			best = n
			bd = to.length()
	var from := global_position + Vector3(0, 1.4, 0)
	var to_p := best.global_position + Vector3(0, 1.4, 0) if best != null else from + fwd * 6.0
	Meet.main.puff(from, to_p, func():
		if is_instance_valid(best):
			best.dusted(self))
	Meet.touch_state()

## Somebody got you back.
func dusted() -> void:
	Fx.tint(_figure, Color(1, 1, 1, 0.8), 30.0)
	Meet.hud.float_text("pfff")
	Meet.say("You are now mostly chalk.")

## Somebody has clouted you.
func slapped(amount: float, from: Vector3, by: Node) -> void:
	if _down > 0.0:
		return
	Meet.composure -= amount
	var away := global_position - from
	away.y = 0
	_push += away.normalized() * 1.2
	Meet.hud.shake()
	Meet.touch_state()
	if Meet.composure <= 0.0:
		_down = 5.0
		Meet.composure = 60.0
		Character.play(_figure, "Crouch_Idle", true)
		if by != null and not by.alien:
			Meet.main.scrap_over(by, false)
		else:
			Meet.say("You sit down on the paving for a moment and think about your choices.")

func _dress() -> void:
	if Meet.worn == _worn:
		return
	_worn = Meet.worn.duplicate()
	Wear.dress(_figure, _worn)

func _process(dt: float) -> void:
	_cooldown = max(0.0, _cooldown - dt)
	_hold = max(0.0, _hold - dt)
	if not Meet.modal:
		rotation.y -= look.x * 0.004
		_pitch = clamp(_pitch - look.y * 0.004, -0.9, 0.5)
	look = Vector2.ZERO
	_pivot.rotation.x = _pitch
	if _down > 0.0:
		_down -= dt
		return
	if _hold <= 0.0:
		var speed := Vector2(velocity.x, velocity.z).length()
		Character.play(_figure, "Jump" if _jump > 0.05 else ("Idle" if speed < 0.4 else ("Jog_Fwd" if speed > 5.0 else "Walk")))

func _physics_process(dt: float) -> void:
	if Meet.modal or _down > 0.0:
		velocity = Vector3.ZERO
		return
	var dir := Input.get_vector("left", "right", "forward", "back") + Meet.stick
	if dir.length() > 1.0:
		dir = dir.normalized()
	if Input.is_key_pressed(KEY_LEFT):
		rotation.y += 1.8 * dt
	if Input.is_key_pressed(KEY_RIGHT):
		rotation.y -= 1.8 * dt
	var running: bool = (Input.is_action_pressed("sprint") or Meet.stick.length() > 0.9) and dir.length() > 0.1 and Meet.stamina > 1.0
	var pace := RUN if running else WALK
	Meet.stamina = clamp(Meet.stamina + (-13.0 if running else 11.0) * dt, 0.0, 100.0)
	var move := (transform.basis * Vector3(dir.x, 0, dir.y)) * pace
	velocity = Vector3(move.x + _push.x, 0, move.z + _push.z)
	_push = _push.lerp(Vector3.ZERO, min(1.0, dt * 7.0))
	move_and_slide()
	# Jumping and the height of the ground are worked out directly, so steps never trip you.
	if _jump > 0.0 or _jump_v > 0.0:
		_jump += _jump_v * dt
		_jump_v -= 16.0 * dt
		if _jump <= 0.0:
			_jump = 0.0
			_jump_v = 0.0
	var p: Vector3 = Meet.main.clear(global_position)
	global_position = Vector3(p.x, lerp(global_position.y - _jump, p.y, min(1.0, dt * 14.0)) + _jump, p.z)
	if Meet.composure < 100.0:
		Meet.composure = min(100.0, Meet.composure + dt * 2.0)
	_find_target()

func _find_target() -> void:
	var best: Node = null
	var best_score := 0.0
	var fwd := -global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interact"):
		var to: Vector3 = n.global_position - global_position
		to.y = 0
		var dist := to.length()
		if dist > REACH:
			continue
		var facing := fwd.dot(to.normalized()) if dist > 0.3 else 1.0
		if facing < 0.3:
			continue
		var score := facing - dist * 0.12
		if best == null or score > best_score:
			best = n
			best_score = score
	if best != target:
		target = best
		Meet.touch_state()
