extends CharacterBody3D
## First-person player: walk, look, and interact with whatever is in front of you.

const WALK := 5.5
const SPRINT := 8.5
const REACH := 3.6

const Character = preload("res://scripts/character.gd")
const Asia = preload("res://scripts/asia.gd")

var cam: Camera3D
var target: Node = null
var third := true
var _pitch := 0.0
var _pivot: Node3D
var _figure: Node3D

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	_pivot = Node3D.new()
	_pivot.position.y = 1.65
	add_child(_pivot)
	cam = Camera3D.new()
	cam.fov = 72
	cam.far = 1800
	_pivot.add_child(cam)
	cam.current = true
	# The pilgrim: dark hooded travelling clothes with the club crest on the back.
	_figure = Character.make(self, {"body": "Male_Ranger", "hood": true, "tint": Color(0.3, 0.3, 0.33)})
	_figure.rotation.y = PI
	Asia.quad(_figure, Vector2(0.34, 0.34), Vector3(0, 1.3, -0.215), PI, "ui/emblem.png", true, 0.25)

func _unhandled_input(ev: InputEvent) -> void:
	if Game.modal:
		return
	if ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= ev.relative.x * 0.0025
		_pitch = clamp(_pitch - ev.relative.y * 0.0025, -1.3, 1.3)
	elif ev.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev.is_action_pressed("interact") and target != null:
		target.interact()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_V:
		third = not third
	elif ev.is_action_pressed("journal"):
		Game.hud.toggle_journal()
	elif ev.is_action_pressed("eat"):
		if Game.eat():
			Game.say("You eat some bread.")

func _process(_dt: float) -> void:
	# Conversations and fights are seen through the pilgrim's own eyes.
	var behind := third and not Game.modal
	_pivot.rotation.x = _pitch
	_figure.visible = behind
	var want := Vector3(0.55, 0.35, 3.1) if behind else Vector3.ZERO
	if behind:
		# Pull the camera in if a wall or the ground is in the way.
		var from := _pivot.global_position
		var to := _pivot.global_transform * want
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			want *= clamp((from.distance_to(hit["position"]) - 0.25) / from.distance_to(to), 0.05, 1.0)
	cam.position = cam.position.lerp(want, 0.3)
	if behind:
		var speed := Vector2(velocity.x, velocity.z).length()
		Character.play(_figure, "Idle" if speed < 0.5 else ("Jog_Fwd" if speed > 6.5 else "Walk"))

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
	var eye := _pivot.global_position
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
	_pivot.rotation.x = pitch

func heading() -> String:
	var a := fposmod(rad_to_deg(-rotation.y), 360.0)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[int(round(a / 45.0)) % 8]
