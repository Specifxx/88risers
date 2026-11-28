extends CharacterBody3D
## First-person player: walk, look, and interact with whatever is in front of you.

const WALK := 5.5
const SPRINT := 8.5
const REACH := 3.6

var cam: Camera3D
var target: Node = null
var _pitch := 0.0

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.65
	cam.fov = 75
	cam.far = 600
	add_child(cam)
	cam.current = true

func _unhandled_input(ev: InputEvent) -> void:
	if Game.modal:
		return
	if ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= ev.relative.x * 0.0025
		_pitch = clamp(_pitch - ev.relative.y * 0.0025, -1.4, 1.4)
		cam.rotation.x = _pitch
	elif ev.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev.is_action_pressed("interact") and target != null:
		target.interact()
	elif ev.is_action_pressed("journal"):
		Game.hud.toggle_journal()
	elif ev.is_action_pressed("eat"):
		if Game.eat():
			Game.say("You eat some bread.")

func _physics_process(dt: float) -> void:
	if Game.modal:
		velocity = Vector3.ZERO
		return
	var dir := Input.get_vector("left", "right", "forward", "back")
	# Arrow keys also turn, for players without a mouse.
	if Input.is_key_pressed(KEY_LEFT):
		rotation.y += 1.8 * dt
	if Input.is_key_pressed(KEY_RIGHT):
		rotation.y -= 1.8 * dt
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
	var move := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = velocity.y - 20.0 * dt if not is_on_floor() else 0.0
	move_and_slide()
	_find_target()

func _find_target() -> void:
	var best: Node = null
	var best_score := 0.0
	var fwd := -cam.global_transform.basis.z
	var eye := cam.global_position
	for n in get_tree().get_nodes_in_group("interact"):
		var at: Vector3 = n.global_position + Vector3(0, 1.2, 0)
		var to := at - eye
		var dist := to.length()
		if dist > REACH + float(n.get_meta("reach", 0.0)):
			continue
		var facing := fwd.dot(to.normalized())
		if facing < 0.55:
			continue
		var score := facing - dist * 0.05
		if best == null or score > best_score:
			best = n
			best_score = score
	target = best

func look_level(pitch := 0.0) -> void:
	_pitch = pitch
	cam.rotation.x = pitch

func heading() -> String:
	var a := fposmod(rad_to_deg(-rotation.y), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[int(round(a / 45.0)) % 8]
