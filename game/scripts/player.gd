extends CharacterBody3D
## The pilgrim: walk, run, jump, look, talk, swing a weapon and block.

const WALK := 5.5
const SPRINT := 8.5
const REACH := 3.6
const JUMP := 6.8

const Character = preload("res://scripts/character.gd")
const Asia = preload("res://scripts/asia.gd")
const Build = preload("res://scripts/build.gd")

var cam: Camera3D
var target: Node = null
var third := true
var _pitch := 0.0
var _pivot: Node3D
var _figure: Node3D
var _hand: Node3D          # weapon shown in first person
var _held := "?"           # what the hand model currently shows
var _cooldown := 0.0
var _swing := 0.0          # time until the blow in progress lands
var _anim_hold := 0.0

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
	_hand = Node3D.new()
	cam.add_child(_hand)
	_hand.position = Vector3(0.38, -0.42, -0.62)
	# The pilgrim: dark hooded travelling clothes with the club crest on the back.
	_figure = Character.make(self, {"body": "Male_Ranger", "hood": true, "tint": Color(0.3, 0.3, 0.33)})
	_figure.rotation.y = PI
	Asia.quad(_figure, Vector2(0.34, 0.34), Vector3(0, 1.3, -0.215), PI, "ui/emblem.png", true, 0.25)

func _unhandled_input(ev: InputEvent) -> void:
	if Game.modal:
		return
	if ev is InputEventMouseButton and ev.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			swing()
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= ev.relative.x * 0.0025
		_pitch = clamp(_pitch - ev.relative.y * 0.0025, -1.3, 1.3)
	elif ev.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev.is_action_pressed("interact") and target != null:
		target.interact()
	elif ev.is_action_pressed("attack"):
		swing()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_V:
		third = not third
	elif ev.is_action_pressed("journal"):
		Game.hud.toggle_journal()
	elif ev.is_action_pressed("inventory"):
		Game.inventory.toggle()
	elif ev.is_action_pressed("eat"):
		if Game.eat():
			Game.say("You eat some bread.")

# --- Fighting ------------------------------------------------------------------

## Start a blow with whatever is in hand. It lands a moment later, if anything is there.
func swing() -> bool:
	if _cooldown > 0.0 or Game.modal:
		return false
	var w := Game.weapon()
	_cooldown = float(w["speed"])
	_swing = 0.2
	_anim_hold = 0.55
	Game.spend(5.0 + float(w["weight"]) * 0.6)
	Character.play(_figure, "Sword_Attack" if Game.equip["weapon"] != "" else "Punch_Cross", true)
	var tw := create_tween()
	tw.tween_property(_hand, "rotation", Vector3(-1.1, 0.5, 0.3), 0.14)
	tw.tween_property(_hand, "rotation", Vector3.ZERO, 0.3)
	return true

func _land_blow() -> void:
	var w := Game.weapon()
	var fwd := -global_transform.basis.z
	var best: Node3D = null
	var best_d := 99.0
	for n in get_tree().get_nodes_in_group("hittable"):
		if not n.can_be_hit():
			continue
		var to: Vector3 = n.global_position - global_position
		var flat := Vector2(to.x, to.z)
		var d := flat.length()
		if d > float(w["reach"]) + 0.4 or absf(to.y) > 2.5:
			continue
		if d > 0.6 and Vector2(fwd.x, fwd.z).normalized().dot(flat.normalized()) < 0.45:
			continue
		if d < best_d:
			best = n
			best_d = d
	if best == null:
		return
	var skill: String = w["skill"]
	if randf() > Game.hit_chance(skill):
		Game.hud.float_text("miss")
		Game.train(skill, 0.4)
		return
	var dmg := randi_range(w["dmg"][0], w["dmg"][1])
	dmg = int(round(dmg * (0.75 + Game.skills[skill] * 0.012) * (0.6 + 0.4 * Game.fatigue / Game.max_fatigue)))
	dmg = max(dmg, 1)
	Game.hud.float_text(str(dmg))
	Game.train(skill, 1.0)
	best.take_hit(dmg, global_position)

# --- Each frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	_cooldown = max(0.0, _cooldown - dt)
	_anim_hold = max(0.0, _anim_hold - dt)
	if _swing > 0.0:
		_swing -= dt
		if _swing <= 0.0:
			_land_blow()
	Game.blocking = not Game.modal and _cooldown <= 0.2 and (Input.is_action_pressed("block") or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)))
	if not Game.modal:
		var regen := 2.5 if Game.blocking else (7.0 if velocity.length() < 6.5 else 0.0)
		Game.fatigue = min(Game.max_fatigue, Game.fatigue + regen * dt)
	# Conversations and the rite are seen through the pilgrim's own eyes.
	var behind := third and not Game.modal
	_pivot.rotation.x = _pitch
	_figure.visible = behind
	_show_hand(not behind and not Game.modal)
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
	if behind and _anim_hold <= 0.0:
		var speed := Vector2(velocity.x, velocity.z).length()
		var anim := "Idle" if speed < 0.5 else ("Jog_Fwd" if speed > 6.5 else "Walk")
		if Game.blocking:
			anim = "Sword_Idle"
		if not is_on_floor():
			anim = "Jump"
		Character.play(_figure, anim)

## The weapon in the corner of the screen when looking through the pilgrim's eyes.
func _show_hand(on: bool) -> void:
	_hand.visible = on
	var id: String = Game.equip["weapon"]
	if id == _held:
		return
	_held = id
	for c in _hand.get_children():
		c.queue_free()
	if id == "":
		return
	var long: float = Game.weapon()["reach"] - 1.2
	var metal: bool = id in ["sword", "old_sword"]
	var shaft := Build.tcyl(_hand, 0.022, 0.028, long, Vector3(0, long / 2.0 - 0.2, 0), "iron" if metal else "darkwood", Color(0.75, 0.75, 0.8) if metal else Color.WHITE, 6)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if id == "axe":
		Build.tbox(_hand, Vector3(0.22, 0.16, 0.03), Vector3(0.1, long - 0.3, 0), "iron", Color(0.6, 0.6, 0.65))
	elif id == "spear":
		Build.tcyl(_hand, 0.0, 0.04, 0.25, Vector3(0, long - 0.08, 0), "iron", Color(0.7, 0.7, 0.75), 4)

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
	var loaded: float = clamp(1.3 - Game.weight() / Game.CAPACITY * 0.6, 0.35, 1.0)
	var running := Input.is_action_pressed("sprint") and Game.fatigue > 1.0 and dir.length() > 0.1
	var speed := (SPRINT if running else WALK) * loaded * (0.55 if Game.blocking else 1.0)
	if running:
		Game.spend(5.0 * dt)
		Game.train("athletics", dt * 0.15)
	var move := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized() * speed
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and Game.fatigue >= 6.0:
			jump()
	else:
		velocity.y -= 20.0 * dt
	move_and_slide()
	_find_target()

func jump() -> void:
	var loaded: float = clamp(1.3 - Game.weight() / Game.CAPACITY * 0.6, 0.35, 1.0)
	velocity.y = JUMP * (0.9 + Game.skills["acrobatics"] * 0.006) * (0.8 + 0.2 * loaded)
	Game.spend(6.0)
	Game.train("acrobatics", 1.0)

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
