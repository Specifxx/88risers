extends CharacterBody3D
## You, at the meet: walk about, talk to people, pull at the table, and wear whatever you've won.

const Character = preload("res://scripts/character.gd")
const Asia = preload("res://scripts/asia.gd")
const Build = preload("res://scripts/build.gd")
const Fx = preload("res://scripts/fx.gd")
const Wear = preload("res://scripts/wear.gd")
const Pose = preload("res://scripts/pose.gd")

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
var _tag: Label3D
var sitting := false
var _orbit := false
var _orbit_yaw := PI
var _orbit_zoom := 3.4
var _weights: Array = []
var _gesture := ""
var _gesture_t := 0.0
var _gesture_len := 0.0
var _gesture_at := Vector3.ZERO
var _gesture_done: Callable

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
	elif ev.is_action_pressed("mute"):
		Meet.audio.set_muted(not Meet.muted)
		Meet.say("Sound off." if Meet.muted else "Sound on.")
	elif ev.is_action_pressed("view"):
		toggle_view()
	elif ev is InputEventMouseButton and ev.pressed and _orbit and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_orbit_zoom = clamp(_orbit_zoom + (-0.4 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.4), 1.6, 8.0)
	elif ev.is_action_pressed("item"):
		use_item()
	elif ev.is_action_pressed("eat"):
		Meet.eat()
	elif ev.is_action_pressed("bag"):
		Meet.hud.toggle_bag()
	elif ev.is_action_pressed("photo"):
		Meet.hud.photo()

func set_name_tag() -> void:
	if _tag == null:
		_tag = Build.label(self, "", 2.05, Color(0.75, 0.9, 1.0), 16)
	_tag.text = Meet.player_name

## A movement done with your own hands, start to finish: "chalk" or "pet".
func gesture(kind: String, seconds: float, at := Vector3.ZERO, done := Callable()) -> void:
	_gesture = kind
	_gesture_t = 0.0
	_gesture_len = seconds
	_gesture_at = at
	_gesture_done = done
	if at != Vector3.ZERO:
		var to := at - global_position
		rotation.y = atan2(-to.x, -to.z)

func _run_gesture(dt: float) -> void:
	_gesture_t += dt
	if _gesture == "curl":
		Pose.curl(_figure, _gesture_t)
		if _weights.is_empty():
			for b in ["hand_r", "hand_l"]:
				var n := Node3D.new()
				Build.cyl(n, 0.02, 0.02, 0.3, Vector3(0, 0.08, 0), Color(0.6, 0.6, 0.65), 6).rotation.z = PI / 2.0
				for sx in [-0.14, 0.14]:
					Build.cyl(n, 0.09, 0.09, 0.06, Vector3(sx, 0.08, 0), Color(0.12, 0.12, 0.14), 10).rotation.z = PI / 2.0
				Wear.hold(_figure, n, b, "Weight_" + b)
				_weights.append(b)
	elif _gesture == "chalk":
		Pose.chalk(_figure, _gesture_t)
		if fmod(_gesture_t, 0.5) < dt:
			Fx.burst(Meet.main, global_position - global_transform.basis.z * 0.35 + Vector3(0, 1.25, 0), Vector3.UP, false, 3)
	else:
		Pose.pet(_figure, _gesture_at, _gesture_t)
	if _gesture_t >= _gesture_len:
		for b in _weights:
			Wear.drop(_figure, "Weight_" + b)
		_weights.clear()
		_gesture = ""
		Pose.stop(_figure)
		if _gesture_done.is_valid():
			_gesture_done.call()
		_chalk_hands()

## White hands for as long as the chalk is on them.
func _chalk_hands() -> void:
	for b in ["hand_r", "hand_l"]:
		Wear.drop(_figure, "Chalk_" + b)
		if Meet.chalked:
			var n := Node3D.new()
			Build.sphere(n, 0.055, Vector3(0, 0.06, 0), Color(0.97, 0.97, 0.97)).scale = Vector3(1, 1.3, 0.7)
			Wear.hold(_figure, n, b, "Chalk_" + b)

## Look at yourself: the camera swings round to the front and can be dragged all the way about.
func toggle_view() -> void:
	_orbit = not _orbit
	_orbit_yaw = PI
	_orbit_zoom = 3.4
	Meet.say("Looking at yourself. Drag to turn the view, scroll to zoom, move to go back." if _orbit else "Back to normal view.")

func sit(at: Vector3, yaw: float) -> void:
	if sitting:
		return
	sitting = true
	global_position = at
	rotation.y = yaw
	Meet.say("You sit down. You'll get your breath back faster here, and somebody might come and join you. Move to stand up.")

func stand_up() -> void:
	sitting = false
	global_position = Meet.main.clear(global_position - global_transform.basis.z * 0.8)

## Held where you are while something happens to you.
func caught(seconds: float) -> void:
	sitting = false
	_gesture = ""
	_down = seconds
	_hold = 0.0

func use() -> void:
	if is_instance_valid(target) and not Meet.modal:
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
	Meet.sfx("whoosh", -6.0, randf_range(0.9, 1.2))
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
	if Meet.worn["hand"] == "fish":
		Meet.dare("fishslap")
	Meet.sfx("punch", -2.0, randf_range(0.85, 1.1))
	best.take_hit(int(22.0 * Meet.hit_power()), global_position)
	if Meet.worn["hand"] == "rubber_chicken":
		Meet.hud.float_text("squeak")
	Fx.burst(Meet.main, best.global_position + Vector3(0, 1.3, 0), Vector3.UP, false, 8)

func _in_front(reach: float) -> Node3D:
	var fwd := -global_transform.basis.z
	var best: Node3D = null
	var bd := 99.0
	for n in get_tree().get_nodes_in_group("hittable"):
		var to: Vector3 = n.global_position - global_position
		to.y = 0
		if to.length() < reach and to.length() < bd and (to.length() < 0.6 or fwd.dot(to.normalized()) > 0.5):
			best = n
			bd = to.length()
	return best

## Do the thing your hand item does, at whoever is in front of you.
func use_item() -> void:
	var item: String = Meet.worn["hand"]
	if _cooldown > 0.0 or Meet.modal or _down > 0.0:
		return
	if item == "":
		Meet.say("Nothing in your hand. Put something on from your bag.")
		return
	_cooldown = 0.9
	var who := _in_front(8.0 if item in ["raygun", "footy", "foam_finger", "gold_chalk"] else 3.2)
	match item:
		"rubber_chicken":
			act("Punch_Jab", 0.5)
			Meet.sfx("squeak", 0.0, randf_range(0.9, 1.25))
			Meet.hud.float_text("SQUEAK")
			if who:
				who.pranked("squeak", ["Ha! Do it again.", "Why is that so funny?", "SQUEAK yourself."], ["Get that thing out of my face.", "Stop. Squeaking."])
		"pool_noodle":
			act("Sword_Attack", 0.6)
			Meet.sfx("boing", -2.0)
			if who:
				who.pranked("bonk", ["Bonk me again, I dare you.", "En garde!", "Ha! Noodle fight!"], ["It's a pool noodle. Grow up.", "Do not noodle me."])
		"raygun":
			act("Pistol_Shoot", 0.5)
			Meet.sfx("zap", -2.0, 1.2)
			if who:
				Fx.tint(who._figure, Color(1.0, 0.3, 0.9, 0.7), 0.4)
				if who.alien:
					who.take_hit(45, global_position)
				else:
					who.pranked("zap", ["Pew pew! Got me.", "Aagh! I'm vaporised!", "Where did you GET that?"], ["Point that somewhere else.", "Is that thing real? Put it down."])
		"foam_finger":
			act("Punch_Jab", 0.6)
			if who:
				who.pranked("point", ["Number one? Me? Go on.", "Finally, recognition."], ["Stop pointing that at me.", "I just lost. Read the room."])
		"footy":
			act("Punch_Cross", 0.5)
			Meet.sfx("punch", -6.0, 0.7)
			if who:
				var tgt := who
				Meet.main.puff(global_position + Vector3(0, 0.4, 0), tgt.global_position + Vector3(0, 1.0, 0), func():
					if is_instance_valid(tgt):
						tgt.pranked("footy", ["Good hands! Go long!", "Kick it back? Go on then.", "Mark!"], ["OI. Watch the table!", "This isn't a park."]), 0.5)
		"balloon":
			act("Punch_Jab", 0.4)
			Meet.sfx("pop")
			if who:
				who.pranked("pop", ["AH! ...Ha. You got me.", "My HEART."], ["Don't DO that.", "Not funny. My heart."])
			Meet.say("Pop. The balloon is tougher than it looks. It reinflates out of spite.")
		"boom_box":
			act("Interact", 0.8)
			if Meet.muted:
				Meet.audio.set_muted(false)
			var name: String = Meet.audio.next_track()
			Meet.say("You hit the button on the boom box. Now playing: %s. Press again for the next one." % name)
			Meet.ripple("You changed the music at the meet.")
			for r in Meet.risers:
				if r.global_position.distance_to(global_position) < 9.0 and not r.alien and r.state not in ["pull", "scrap", "winded", "confront"]:
					if r.mind.chatty > 0.5 or r.mood_level() >= 1 or r.passer:
						r.gesture("Dance", 4.0)
					else:
						r.say_aloud(["Turn it down.", "Who put that on?", "..."][randi() % 3], 3.0)
			act("Dance", 3.5)
		"gold_chalk":
			act("Punch_Jab", 0.5)
			if who:
				var tg := who
				Meet.main.puff(global_position + Vector3(0, 1.4, 0), tg.global_position + Vector3(0, 1.4, 0), func():
					if is_instance_valid(tg):
						Fx.tint(tg._figure, Color(1.0, 0.82, 0.25, 0.75), 30.0)
						tg.pranked("gold", ["I'm GOLD. Look at me. I'm a trophy.", "Do my other side."], ["This had better wash out.", "I look like a statue."]))
		"golden_chip", "snag", "fish":
			act("Interact", 0.8)
			var kelvin: Node = Meet.riser("kelvin")
			if kelvin and kelvin.is_free() and kelvin.global_position.distance_to(global_position) < 18.0:
				kelvin.say_aloud("Is that... are you going to eat that?", 4.0)
				kelvin._go(global_position + Vector3(1.2, 0, 0.6), "gawk")
			if item == "fish" and Meet.main._gulls == null and randf() < 0.5:
				Meet.say("You wave the fish about. Something over the water takes an interest.")
				Meet.main.start_gulls()
			else:
				Meet.say("You hold the %s up. Kelvin has noticed." % Meet.ITEMS[item]["name"].to_lower())
		"katana_88", "bracket_cup", "glow_stick":
			act("Sword_Idle", 1.5)
			Meet.sfx("ooh", -8.0)
			Meet.main.stir(global_position, ["Ooh.", "Put it away, show-off.", "Nice.", "Careful with that."], 8.0, 0.6, false)
		"clipboard":
			if who and not who.alien:
				who.interact()
			else:
				Meet.say("Stand in front of someone to hand them the clipboard.")
		_:
			act("Punch_Jab", 0.5)
			Meet.say("You wave the %s about. Nothing happens, but you feel better." % Meet.ITEMS[item]["name"].to_lower())

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
		Meet.dare("floored")
		if by != null and not by.alien:
			Meet.main.scrap_over(by, false)
		else:
			Meet.say("You sit down on the paving for a moment and think about your choices.")

func _dress() -> void:
	if Meet.worn == _worn:
		return
	_worn = Meet.worn.duplicate()
	Wear.dress(_figure, _worn)
	if _gesture == "":
		_chalk_hands()

func _process(dt: float) -> void:
	if _gesture != "":
		_run_gesture(dt)
	_cooldown = max(0.0, _cooldown - dt)
	_hold = max(0.0, _hold - dt)
	if not Meet.modal:
		if _orbit:
			_orbit_yaw -= look.x * 0.005
		else:
			rotation.y -= look.x * 0.004
		_pitch = clamp(_pitch - look.y * 0.004, -0.9, 0.5)
	look = Vector2.ZERO
	_pivot.rotation = Vector3(_pitch, _orbit_yaw if _orbit else 0.0, 0)
	cam.position = cam.position.lerp(Vector3(0.0, 0.2, _orbit_zoom) if _orbit else Vector3(0.5, 0.4, 3.4), min(1.0, dt * 8.0))
	if sitting:
		Character.play(_figure, "Sitting_Idle")
		Meet.stamina = min(100.0, Meet.stamina + dt * 4.0)
		Meet.composure = min(100.0, Meet.composure + dt * 1.2)
		if (Input.get_vector("left", "right", "forward", "back") + Meet.stick).length() > 0.4 and not Meet.modal:
			stand_up()
		return
	if _down > 0.0:
		_down -= dt
		return
	if _hold <= 0.0 and not _figure.has_meta("posed"):
		var speed := Vector2(velocity.x, velocity.z).length()
		Character.play(_figure, "Jump" if _jump > 0.05 else ("Idle" if speed < 0.4 else ("Jog_Fwd" if speed > 5.0 else "Walk")))

func _physics_process(dt: float) -> void:
	if Meet.modal or _down > 0.0 or _gesture != "" or sitting or _orbit:
		velocity = Vector3.ZERO
		if _orbit and (Input.get_vector("left", "right", "forward", "back") + Meet.stick).length() > 0.4 and not Meet.modal:
			toggle_view()
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
	Meet.stamina = clamp(Meet.stamina + (-13.0 if running else 0.9) * dt, 0.0, 100.0)
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
		Meet.composure = min(100.0, Meet.composure + dt * 0.25)
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
