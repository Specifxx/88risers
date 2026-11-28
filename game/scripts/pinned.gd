extends Node3D
## One of the Pinned. Roams near where it died, comes for the player outside the Ring and
## strikes at them. Beaten down, it lies where it fell for a short while: long enough to
## throw chalk and begin the rite. Left alone it sinks, and gets up again later.

const Build = preload("res://scripts/build.gd")
const Character = preload("res://scripts/character.gd")
const Fx = preload("res://scripts/fx.gd")

const SEE := 17.0
const STRIKE_RANGE := 2.0

var spirit: Dictionary
var home := Vector3.ZERO
var state := "roam"  # roam | windup | fallen | down (sunk) | gone
var known := false
var hp := 10
var max_hp := 10
var _timer := 0.0
var _grace := 0.0
var _cooldown := 0.0
var _stagger := 0.0
var _knock := Vector3.ZERO
var _target := Vector3.ZERO
var _body: Node3D
var _label: Label3D

func setup(s: Dictionary, at: Vector3, delay := 0.0) -> void:
	spirit = s
	home = at
	position = at
	_target = at
	max_hp = int(s["hp"])
	hp = max_hp
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
	add_to_group("hittable")
	if delay > 0.0:
		state = "down"
		_timer = delay
		_hide()

func _hide() -> void:
	_body.visible = false
	_label.visible = false
	if is_in_group("interact"):
		remove_from_group("interact")

func display_name() -> String:
	return spirit["name"] if known else spirit["shape"]

func reveal() -> void:
	known = true
	_label.text = spirit["name"]

# --- Being hit --------------------------------------------------------------------

func can_be_hit() -> bool:
	return state in ["roam", "windup"]

func knock(v: Vector3) -> void:
	_knock += v

func take_hit(dmg: int, from: Vector3) -> void:
	if not can_be_hit():
		return
	hp -= dmg
	_stagger = 0.35
	state = "roam"
	var away := global_position - from
	away.y = 0
	_knock += away.normalized() * (4.0 + dmg * 0.4)
	Fx.burst(Game.main, global_position + Vector3(0, 1.2, 0), away, false)
	Fx.tint(_body, Color(0.9, 0.85, 0.7, 0.55), 0.1)
	_label.text = "%s\n%s" % [display_name(), Fx.bar(max(hp, 0) / float(max_hp))]
	if hp <= 0:
		_fall()
	else:
		Character.play(_body, "Hit_Chest", true)

## Beaten down. It lies there for a little while before the dark takes it back.
func _fall() -> void:
	state = "fallen"
	_timer = 25.0
	Character.play(_body, "Death01", true)
	_label.text = "%s, fallen" % display_name()
	add_to_group("interact")
	if not Game.flags.has("told_fallen"):
		Game.flags["told_fallen"] = true
		Game.say("It is down, but not gone. Begin the rite before the dark pulls it under (E).")

func prompt() -> String:
	return "Begin the rite over %s" % display_name()

func interact() -> void:
	if state == "fallen":
		Game.battle.start_rite(self)

## Killed but not raised: it sinks, and will be back.
func put_down() -> void:
	state = "down"
	_timer = 50.0
	_hide()

func raise_up() -> void:
	state = "gone"
	_hide()
	remove_from_group("hittable")
	Game.raised += 1
	Game.word("raised", 0.9, 1.0, "tallow", spirit["name"])
	Game.word("raised", 0.6, 0.5, "rhodes", spirit["name"])
	if spirit.has("leaves"):
		Game.add_item(spirit["leaves"])
		Game.say("Where it stood, something is left behind: %s." % Game.Items.ITEMS[spirit["leaves"]]["name"])

func back_off() -> void:
	_grace = 6.0

# --- Each frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	if state == "gone" or Game.player == null:
		return
	if state == "down":
		_timer -= dt
		if _timer <= 0.0:
			state = "roam"
			hp = max_hp
			global_position = home
			_body.visible = true
			_label.visible = true
			_label.text = display_name()
			_grace = 2.0
			Character.play(_body, "Idle")
		return
	if Game.modal:
		return
	if state == "fallen":
		_timer -= dt
		if _timer <= 0.0:
			put_down()
		return
	_grace = max(0.0, _grace - dt)
	_cooldown = max(0.0, _cooldown - dt)
	if _knock.length() > 0.1:
		var pushed: Vector3 = Game.main.walk(global_position, global_position + _knock * dt)
		if Vector2(pushed.x, pushed.z).length() > Game.RING_RADIUS + 2.0:
			global_position = pushed
		_knock = _knock.lerp(Vector3.ZERO, min(1.0, dt * 4.5))
	if _stagger > 0.0:
		_stagger -= dt
		return
	var p: Vector3 = Game.player.global_position
	var d := global_position.distance_to(p)
	var safe := Game.in_ring(p)
	if state == "windup":
		_timer -= dt
		if _timer <= 0.0:
			state = "roam"
			_cooldown = 1.3
			if d < STRIKE_RANGE + 0.6 and not safe:
				Game.hurt_player(int(spirit["atk"]) + randi_range(-1, 1), global_position)
		return
	var speed := 1.1
	var goal := _target
	var hunting := d < SEE and not safe and _grace <= 0.0
	if hunting:
		goal = p
		speed = 3.5
	elif Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < 1.0:
		_target = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	var to := goal - global_position
	to.y = 0
	if hunting and d < STRIKE_RANGE:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.2)
		if _cooldown <= 0.0:
			state = "windup"
			_timer = 0.55
			Character.play(_body, "Punch_Cross", true)
		else:
			Character.play(_body, "Sword_Idle")
		return
	var moving := false
	if to.length() > 0.3:
		var next: Vector3 = Game.main.walk(global_position, global_position + to.normalized() * speed * dt)
		# The Pinned cannot cross the Ring.
		if Vector2(next.x, next.z).length() > Game.RING_RADIUS + 2.0 and next.distance_to(global_position) > 0.001:
			global_position = next
			moving = true
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.12)
	Character.play(_body, ("Jog_Fwd" if speed > 2.0 else "Walk") if moving else "Idle")
