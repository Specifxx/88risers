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
var _lamp: OmniLight3D
var _bob := 0.0
var flying := false
var riding := false
var _ride_v := Vector3.ZERO
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
	elif ev.is_action_pressed("shout"):
		Meet.main.shout_menu()
	elif ev.is_action_pressed("throw"):
		throw_snack()
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
		_tag.layers = 0
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

## Thrown straight up.
func launch() -> void:
	sitting = false
	_jump = 0.1
	_jump_v = 13.0

## Held where you are while something happens to you.
func caught(seconds: float) -> void:
	sitting = false
	_gesture = ""
	_down = seconds
	_hold = 0.0

func mount() -> void:
	riding = true
	sitting = false
	_ride_v = Vector3.ZERO
	_figure.position.y = 0.3

func dismount() -> void:
	if not riding:
		return
	riding = false
	_ride_v = Vector3.ZERO
	_figure.position.y = 0.0
	Meet.main.evening.dismounted()

func speed() -> float:
	return _ride_v.length() if riding else Vector2(velocity.x, velocity.z).length()

func use() -> void:
	if riding and not Meet.modal:
		dismount()
		return
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
		# Nothing living in the way. With something heavy enough, the scenery gives.
		if Meet.attack() >= 8:
			Meet.main.smash(global_position + fwd * 1.6)
		return
	if Meet.worn["hand"] == "fish":
		Meet.dare("fishslap")
	Meet.sfx("punch", -2.0, randf_range(0.85, 1.1))
	best.take_hit(8 + Meet.attack() * 5, global_position)
	Meet.hud.float_text(["tap", "tap", "thwack", "thwack", "WHACK", "WHACK", "CRACK", "CRACK", "BOOM", "BOOM", "KA-BOOM"][Meet.attack()])
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
			var muzzle := global_position + Vector3(0, 1.35, 0) - global_transform.basis.z * 0.5
			var hit_at: Vector3 = who.global_position + Vector3(0, 1.2, 0) if who else muzzle - global_transform.basis.z * 14.0
			# Bigger things than people can be shot at too.
			var big: Vector3 = Meet.main.laser_target(muzzle, -global_transform.basis.z) if who == null else Vector3.ZERO
			if big != Vector3.ZERO:
				hit_at = big
			Meet.main.laser(muzzle, hit_at)
			if who:
				Fx.tint(who._figure, Color(1.0, 0.3, 0.9, 0.7), 0.4)
				Fx.burst(Meet.main, hit_at, Vector3.UP, false, 8)
				if who.alien:
					who.take_hit(45, global_position)
				elif who.get("state") in ["scrap", "winded"] and who.get("_fought_player"):
					who.take_hit(40, global_position)
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
		"golden_grip":
			# One clap, and everything near you sits down.
			_cooldown = 6.0
			act("Punch_Cross", 0.8)
			Meet.sfx("crash")
			Meet.hud.shake()
			Meet.hud.banner("THE GOLDEN GRIP", "You clap once.")
			for k in 10:
				var a := TAU * k / 10.0
				Fx.burst(Meet.main, global_position + Vector3(cos(a) * 2.0, 0.6, sin(a) * 2.0), Vector3.UP, false, 8)
			for r in Meet.risers:
				var d: float = r.global_position.distance_to(global_position)
				if d < 7.0 and r.state != "winded":
					if r.alien:
						r.take_hit(200, global_position)
					else:
						r.bowled(r.global_position - global_position)
			Meet.add_heat(1.0, "using THAT at a club meet")
		"harmonica":
			act("Interact", 1.2)
			Meet.sfx("item", -4.0, 1.3)
			Meet.say("You play the only tune you know. It's the first four notes of something.")
			for r in Meet.risers:
				if r.global_position.distance_to(global_position) < 7.0 and not r.alien and r.state not in ["pull", "scrap", "winded", "confront", "post"]:
					if r.mind.chatty > 0.55 or r.mood_level() >= 1:
						r.gesture("Dance", 3.0)
			var dee: Node = Meet.riser("s_busker")
			if dee and dee.global_position.distance_to(global_position) < 9.0:
				dee.say_aloud("Other way round. ...No. Just give it here.", 4.0)
		"catch_ball":
			if who:
				act("Punch_Jab", 0.5)
				var tb := who
				Meet.main.lob(global_position + Vector3(0, 1.4, 0), tb.global_position + Vector3(0, 1.3, 0), Color(0.2, 0.75, 0.6), func():
					if is_instance_valid(tb):
						tb.pranked("ball", ["Did you just try to CATCH me?", "I'm not going in there.", "Ha! Missed."], ["I am not a collectable.", "Throw that at me again."]))
			else:
				Meet.say("Nothing to throw it at. It's for something small, orange and fast.")
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

## Throw one of your snacks at whoever is in front of you.
func throw_snack() -> void:
	if _cooldown > 0.0 or Meet.modal or _down > 0.0 or riding:
		return
	if Meet.snacks <= 0:
		Meet.say("You've nothing to throw. The snack table's by the lights.")
		return
	Meet.snacks -= 1
	_cooldown = 0.5
	act("Punch_Jab", 0.45)
	Meet.touch_state()
	var who := _in_front(11.0)
	var from := global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = who.global_position + Vector3(0, 1.4, 0) if who else from - global_transform.basis.z * 7.0 + Vector3(0, -1.2, 0)
	var tgt := who
	Meet.main.lob(from, to, Color(0.9, 0.3, 0.2), func():
		if tgt != null and is_instance_valid(tgt):
			tgt.splatted(self))
	Meet.main.snack_thrown()

## Somebody landed one on you.
func splatted() -> void:
	Fx.tint(_figure, Color(0.95, 0.75, 0.2, 0.55), 10.0)
	Meet.sfx("crunch", -2.0, 0.8)
	Meet.hud.float_text("SPLAT")
	Meet.hud.shake()

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
	Wear.dust(_figure, 40.0)
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
	# A balloon bobs on its string; in a wind it pulls.
	if Meet.worn["hand"] == "balloon":
		var sway: Node3D = _figure.find_child("Sway", true, false)
		if sway:
			var lean := Vector2(velocity.x, velocity.z).length() * 0.05 + (0.5 if Meet.wind > 0.0 else 0.0)
			sway.global_rotation = Vector3(sin(_bob * 1.7) * 0.18 + lean, 0, cos(_bob * 2.3) * 0.2 + (sin(_bob * 9.0) * 0.12 if Meet.wind > 0.0 else 0.0))
	_bob += dt
	# In the dark, a glow stick in your hand is the only real light. Without one, almost nothing.
	if _lamp == null:
		_lamp = OmniLight3D.new()
		_lamp.position = Vector3(0, 1.3, -0.3)
		add_child(_lamp)
	var lit: bool = Meet.worn["hand"] == "glow_stick"
	_lamp.visible = Meet.dark > 0.0 or lit
	_lamp.light_color = Color(0.4, 1.0, 0.6) if lit else Color(0.5, 0.5, 0.6)
	_lamp.light_energy = (2.4 if Meet.dark > 0.0 else 0.6) if lit else 0.25
	_lamp.omni_range = 11.0 if lit else 2.2
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
	if riding:
		Character.play(_figure, "Driving")
	elif _hold <= 0.0 and not _figure.has_meta("posed"):
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
	if riding:
		# A bike: quicker than running, slow to stop, and it turns with the camera.
		var want := (transform.basis * Vector3(dir.x, 0, dir.y)) * (12.5 if dir.length() > 0.9 or Input.is_action_pressed("sprint") else 7.0)
		_ride_v = _ride_v.lerp(want, min(1.0, dt * (1.6 if want.length() > _ride_v.length() else 2.4)))
		velocity = _ride_v
		move_and_slide()
		var gp: Vector3 = Meet.main.clear(global_position)
		global_position = Vector3(gp.x, lerp(global_position.y, gp.y, min(1.0, dt * 14.0)), gp.z)
		if _ride_v.length() > 6.5:
			for r in Meet.risers:
				var to: Vector3 = r.global_position - global_position
				to.y = 0
				if to.length() < 1.0 and _ride_v.normalized().dot(to.normalized()) > 0.2 and r.state != "winded":
					r.bowled(_ride_v)
					_ride_v *= 0.45
					Meet.hud.shake()
		_find_target()
		return
	var running: bool = (Input.is_action_pressed("sprint") or Meet.stick.length() > 0.9) and dir.length() > 0.1 and Meet.stamina > 1.0
	var pace := RUN if running else WALK
	if Meet.carrying >= 0:
		pace = WALK * 0.7
	Meet.stamina = clamp(Meet.stamina + (-13.0 if running else 0.9) * dt, 0.0, 100.0)
	var move := (transform.basis * Vector3(dir.x, 0, dir.y)) * pace
	velocity = Vector3(move.x + _push.x, 0, move.z + _push.z)
	_push = _push.lerp(Vector3.ZERO, min(1.0, dt * 7.0))
	move_and_slide()
	# Jumping and the height of the ground are worked out directly, so steps never trip you.
	# A balloon in a real wind carries you: hold jump to climb, let go to drift down.
	var lifted: bool = Meet.wind > 0.0 and Meet.worn["hand"] == "balloon"
	if lifted and (Input.is_action_pressed("jump") or _jump > 0.3):
		if not flying:
			flying = true
			Meet.hud.banner("AIRBORNE", "The wind has the balloon and the balloon has you. Hold jump to climb.")
			Meet.main.stir(global_position, ["They're FLYING.", "Is that... a balloon?", "Come DOWN!", "George! CAMERA!"], 30.0, 0.8, false)
			Meet.ripple("You flew over the meet on a child's balloon.")
			Meet.dare("fly")
		_jump_v = lerp(_jump_v, 3.2 if Input.is_action_pressed("jump") and _jump < 13.0 else -1.3, min(1.0, dt * 2.5))
		_jump = max(0.0, _jump + _jump_v * dt)
		if _jump <= 0.0:
			_jump_v = 0.0
			flying = false
	elif _jump > 0.0 or _jump_v > 0.0:
		flying = false
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
