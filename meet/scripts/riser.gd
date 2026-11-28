extends Node3D
## Someone at the meet. They pull at the tables, eat, talk, watch and sit; they remember how
## the player has treated them (mind.gd) and act on it. Nobody is ever really hurt: someone
## who loses a scrap sits down winded and gets up again.

const Build = preload("res://scripts/build.gd")
const Character = preload("res://scripts/character.gd")
const Mind = preload("res://scripts/mind.gd")
const People = preload("res://scripts/people.gd")
const Fx = preload("res://scripts/fx.gd")

const WALK := 1.5

var def: Dictionary
var id := ""
var riser_name := ""
var first_name := ""
var role := ""
var is_riser := false
var alien := false
var strength := 60.0
var mind: RefCounted
var state := "idle"   # idle | walk | to_table | prep | pull | snack | chat | watch | sit | quirk | search | scrap | winded | flee | pass
var needs := {"pull": 0.0, "eat": 0.0, "talk": 0.0, "rest": 0.0, "quirk": 0.0}
var life := {}
var tonight := {}
var wants_pull := false
var strap_known_gone := false   # they have looked in their bag and it isn't there
var saw_theft := {}             # whose strap they watched the player take
var passer := false
var recruited := false
var calling := 0.0              # seconds left on an open challenge to the player
var composure := 100.0

var _figure: Node3D
var _bark: Label3D
var _bark_time := 0.0
var _timer := 0.0
var _goal := Vector3.ZERO
var _then := ""
var _face_at := Vector3.ZERO
var _partner: Node3D = null
var _foe: Node3D = null      # who they are scrapping with (the player is null + _vs_player)
var _vs_player := false
var _strike := 0.0
var _wind := 0.0
var _knock := Vector3.ZERO
var _noticed := false
var _heckled := 0
var _seat := Vector3.ZERO
var _legs: Array = []           # what is left of the walk to the table: bag, chalk, seat
var _qanim := "Idle"
var _qlines: Array = []
var _qbark := 0.0
var _phase := ""
var _asks := 0
var _dir := 1.0
var _lane := 27.2
var _pace := 1.0
var _stops := false
var _told := false
var _dust := 0.0
var _fed := false

func setup(d: Dictionary, riser: bool, at: Vector3) -> void:
	def = d
	id = d["id"]
	riser_name = d["name"]
	first_name = riser_name.split(" ")[0] if riser else riser_name.to_lower()
	life = d.get("life", {})
	if riser:
		tonight = People.TONIGHT[randi() % People.TONIGHT.size()]
		for k in needs:
			needs[k] = randf() * 0.8
	role = d["role"]
	is_riser = riser
	strength = float(d["strength"])
	position = at
	mind = Mind.new()
	mind.setup(id, d.get("mind", {}))
	if riser and Meet.bonds.has(id):
		mind.from_data(Meet.bonds[id])
	var look: Dictionary = d["look"]
	_figure = Character.make(self, look)
	var b: float = look.get("build", 1.0)
	_figure.scale = Vector3(b, 1.0 + (b - 1.0) * 0.25, b) * (0.72 if d["id"] == "alien" else 1.0)
	if d["id"] == "alien":
		for sx in [-1.0, 1.0]:
			Build.cyl(self, 0.01, 0.015, 0.3, Vector3(sx * 0.08, 1.42, 0), Color(0.3, 0.9, 0.4), 4)
			Build.sphere(self, 0.04, Vector3(sx * 0.08, 1.58, 0), Color(1.0, 0.4, 0.9), 1.5)
	Build.label(self, riser_name, 2.2 if d["id"] != "alien" else 1.75, Color(1, 0.95, 0.8) if riser else Color(0.8, 0.8, 0.82), 34 if riser else 26)
	_bark = Build.label(self, "", 2.5 if d["id"] != "alien" else 2.0, Color(1.0, 0.9, 0.6), 30)
	_bark.visible = false
	_timer = randf_range(1.0, 6.0)
	add_to_group("hittable")
	if d["id"] != "alien":
		add_to_group("interact")
	if d.get("dog", false):
		_dog()

## Someone walking past along the water.
func pass_by(dir: float) -> void:
	passer = true
	_dir = dir
	_lane = 27.2 + randf_range(-1.0, 1.0)
	_pace = float(def.get("pace", 1.4))
	_stops = randf() < float(def.get("stops", 0.4))
	position = Vector3(-31.0 * dir, 0, _lane)
	state = "pass"

func _dog() -> void:
	var dog := Node3D.new()
	add_child(dog)
	dog.position = Vector3(0.75, 0, 0.5)
	var c := Color(0.72, 0.52, 0.3)
	Build.box(dog, Vector3(0.2, 0.2, 0.5), Vector3(0, 0.32, 0), c)
	Build.box(dog, Vector3(0.18, 0.18, 0.2), Vector3(0, 0.48, 0.3), c)
	Build.box(dog, Vector3(0.08, 0.07, 0.1), Vector3(0, 0.44, 0.43), c * 0.6)
	for e in [-1.0, 1.0]:
		Build.box(dog, Vector3(0.05, 0.1, 0.03), Vector3(e * 0.07, 0.6, 0.26), c * 0.7)
		for z in [-0.18, 0.18]:
			Build.box(dog, Vector3(0.05, 0.22, 0.05), Vector3(e * 0.07, 0.11, z), c)
	Build.box(dog, Vector3(0.04, 0.16, 0.04), Vector3(0, 0.46, -0.27), c).rotation.x = -0.6
	Build.cyl(self, 0.006, 0.006, 0.95, Vector3(0.52, 0.72, 0.42), Color(0.8, 0.1, 0.1), 4).rotation = Vector3(0.5, 0, -0.9)
	var pat: Node3D = load("res://scripts/thing.gd").new()
	dog.add_child(pat)
	pat.position = Vector3(0.3, 0, 0.3)
	pat.setup("Pat Biscuit", func():
		Meet.say("Biscuit leans on your leg. Biscuit approves of you.")
		if not _fed:
			_fed = true
			mind.experience("helped", 0.5, 1.0))

func prompt() -> String:
	return "Talk to %s" % riser_name

func interact() -> void:
	if state in ["scrap", "winded", "flee"]:
		return
	if state == "search" and not _told:
		_told = true
	mind.met()
	if not mind.remembers("meet"):
		mind.experience("meet", 0.2, 0.4)
	Meet.menu.open(self)

func portrait() -> String:
	return def.get("portrait", "")

func say_aloud(text: String, seconds := 3.0) -> void:
	_bark.text = text
	_bark.visible = true
	_bark_time = seconds

## How things stand between them and the player.
func bond() -> String:
	var f: float = mind.feeling()
	if f < -0.5:
		return "gone"
	if f < -0.15:
		return "irritated"
	if f < 0.3:
		return "known"
	if f < 0.6:
		return "mates"
	return "close"

func bond_text() -> String:
	return {"gone": "wants nothing to do with you", "irritated": "is fed up with you", "known": "knows you", "mates": "counts you a mate", "close": "would back you in anything"}[bond()]

func is_free() -> bool:
	return state in ["idle", "walk", "watch", "sit", "chat", "snack", "quirk"] and not alien and not passer

func has_strap() -> bool:
	return not Meet.straps.has(id)

func facing(p: Vector3) -> bool:
	var to := p - global_position
	to.y = 0
	return to.length() < 0.5 or Vector3(sin(rotation.y), 0, cos(rotation.y)).dot(to.normalized()) > 0.35

func at_table() -> bool:
	return state == "pull"

func idle() -> void:
	if passer:
		state = "pass"
		return
	state = "idle"
	_partner = null
	_timer = randf_range(2.0, 6.0)

# --- The evening -----------------------------------------------------------------------

func _process(dt: float) -> void:
	if Meet.player == null:
		return
	mind.tick(dt)
	if _bark_time > 0.0:
		_bark_time -= dt
		if _bark_time <= 0.0:
			_bark.visible = false
	if Meet.modal:
		if Meet.menu.who == self:
			_look(Meet.player.global_position, 0.15)
			Character.play(_figure, "Idle_Talking")
		return
	if _knock.length() > 0.05:
		global_position = Meet.main.clear(global_position + _knock * dt)
		_knock = _knock.lerp(Vector3.ZERO, min(1.0, dt * 5.0))
	if alien:
		_alien(dt)
		return
	calling = max(0.0, calling - dt)
	if is_riser:
		for k in needs:
			needs[k] = min(1.5, needs[k] + float(life.get(k, 0.5)) * float(tonight.get(k, 1.0)) * dt / 45.0)
	_notice()
	match state:
		"idle":
			Character.play(_figure, "Idle")
			_timer -= dt
			if _timer <= 0.0:
				_choose()
		"walk", "to_table":
			if _walk(dt, 1.0):
				_arrive()
		"prep":
			# Rummaging in the bag for the strap, or chalking up.
			_timer -= dt
			Character.play(_figure, "Interact")
			if _timer <= 0.0:
				_next_leg()
		"pull":
			_look(_face_at, 0.2)
			Character.play(_figure, "Sword_Idle")
		"quirk":
			_timer -= dt
			_qbark -= dt
			_look(_face_at, 0.1)
			Character.play(_figure, _qanim)
			if _qbark <= 0.0 and not _qlines.is_empty():
				_qbark = randf_range(3.5, 6.0)
				say_aloud(_qlines[randi() % _qlines.size()])
			if _timer <= 0.0:
				idle()
		"search":
			_search(dt)
		"pass":
			_pass(dt)
		"snack":
			_timer -= dt
			Character.play(_figure, "Interact")
			if _timer <= 0.0:
				say_aloud(People.EATING[randi() % People.EATING.size()])
				idle()
		"chat":
			_timer -= dt
			Character.play(_figure, "Idle_Talking")
			if is_instance_valid(_partner):
				_look(_partner.global_position, 0.1)
			if _timer <= 0.0:
				idle()
		"watch":
			_timer -= dt
			_look(_face_at, 0.1)
			Character.play(_figure, "Idle")
			if _timer <= 0.0 or not Meet.main.match_on():
				idle()
		"sit":
			_timer -= dt
			Character.play(_figure, "Sitting_Idle")
			if _timer <= 0.0:
				idle()
		"scrap":
			_scrap(dt)
		"winded":
			_timer -= dt
			Character.play(_figure, "Crouch_Idle")
			if _timer <= 0.0:
				composure = 60.0
				say_aloud("...I'm fine. I'm fine.")
				idle()
		"flee":
			_goal = Meet.main.clear(global_position + (global_position - _threat()).normalized() * 5.0)
			_walk(dt, 2.2)

## What next? Whichever want has built up most, with a bit of chance in it. Everyone's wants
## build at their own rates, and tonight's twist bends them, so no two nights run the same.
func _choose() -> void:
	var main: Node3D = Meet.main
	if not is_riser:
		idle()
		return
	var best := "talk"
	var score := -1.0
	for k in needs:
		var v: float = needs[k] + randf() * 0.4
		if v > score:
			score = v
			best = k
	needs[best] = 0.0
	match best:
		"pull":
			# Hang about near the tables until the next pairing.
			wants_pull = true
			if main.match_on():
				_watch(main)
			else:
				var t: Vector3 = main.TABLES[randi() % 3]
				_go(t + Vector3(randf_range(-2.5, 2.5), 0, randf_range(1.6, 3.0)), "idle")
		"eat":
			_go(main.SNACKS + Vector3(randf_range(-1.0, 1.0), 0, 1.0), "snack")
		"talk":
			var others: Array = Meet.risers.filter(func(r): return r != self and (r.state == "idle" or (r.passer and r.state == "watch")))
			if others.is_empty():
				_watch(main)
				return
			_partner = others[randi() % others.size()]
			var to: Vector3 = global_position - _partner.global_position
			to.y = 0
			_go(_partner.global_position + to.normalized() * 1.3, "chat")
		"rest":
			var a2 := PI + 0.4 + randf() * (PI - 0.8)
			var rr: float = main.PLAZA + 0.5 + randi() % 5
			_go(Vector3(cos(a2) * rr, 0, sin(a2) * rr), "sit")
		"quirk":
			_quirk(main)

func _watch(main: Node3D) -> void:
	if not main.match_on():
		_timer = 2.0
		return
	var at: Vector3 = main.TABLES[main.nearest_match(global_position)]
	var a := randf() * TAU
	_face_at = at
	_go(at + Vector3(cos(a) * 2.6, 0, sin(a) * 2.6), "watch")

## The thing only they do.
func _quirk(main: Node3D) -> void:
	var does: String = life.get("does", "")
	var pick := func() -> Node3D:
		var o: Array = Meet.risers.filter(func(r): return r != self and r.is_free() and r.state != "walk")
		return o[randi() % o.size()] if not o.is_empty() else null
	_qlines = People.QUIRK.get(does, [])
	_qanim = "Idle_Talking"
	_timer = randf_range(8.0, 14.0)
	_qbark = 0.5
	match does:
		"ref":
			if main.match_on():
				_face_at = main.TABLES[main.nearest_match(global_position)]
				_go(_face_at + Vector3(0, 0, 1.25), "quirk")
			else:
				_qlines = People.QUIRK["rounds"]
				_partner = pick.call()
				_face_at = _partner.global_position if _partner else global_position
				_go(_face_at + Vector3(1.2, 0, 0.6), "quirk")
				_timer = 4.0
		"film":
			if main.match_on():
				_qanim = "Pistol_Aim_Neutral"
				_face_at = main.TABLES[main.nearest_match(global_position)]
				_go(_face_at + Vector3(randf_range(-1.5, 1.5), 0, 2.4), "quirk")
			else:
				_qlines = People.QUIRK["spruik"]
				_face_at = Vector3(0, 0, 30)
				_go(Vector3(randf_range(-1.5, 1.5), 0, 21.0), "quirk")
		"drill":
			_qanim = "Push"
			var a := randf_range(0.3, 2.8)
			_face_at = Vector3.ZERO
			_go(Vector3(cos(a) * 7.6, 0, sin(a) * 7.6), "quirk")
		"coach":
			_partner = pick.call()
			if _partner == null:
				idle()
				return
			_face_at = _partner.global_position
			_go(_face_at + Vector3(1.1, 0, 0.7), "coach")
			_timer = 6.0
		"seconds":
			_go(main.SNACKS + Vector3(randf_range(-1.0, 1.0), 0, 1.0), "snack")
			say_aloud(_qlines[randi() % _qlines.size()])
		"prank":
			_partner = pick.call()
			if _partner == null:
				idle()
				return
			_go(_partner.global_position + Vector3(1.6, 0, 1.0), "prank")
		"water":
			_qanim = "Idle"
			_timer = randf_range(14.0, 24.0)
			_qbark = 6.0
			var x := randf_range(-14.0, 14.0)
			_face_at = Vector3(x, 0, 60)
			_go(Vector3(x, 0, 26.4), "quirk")
		"callout":
			var p: Vector3 = Meet.player.global_position
			if bond() in ["known", "mates", "close"] and tonight.get("id", "") != "sore" and p.distance_to(global_position) < 16.0:
				calling = 25.0
				_face_at = p
				_timer = 7.0
				_qbark = 99.0
				_go(p + (global_position - p).normalized() * 1.6, "callout")
			else:
				wants_pull = true
				_partner = pick.call()
				if _partner and _partner.is_riser:
					_partner.wants_pull = true
					_partner.say_aloud("Fine. Go on then.")
				say_aloud("Who hasn't pulled yet? Come on.")
				idle()
		_:
			idle()

func _go(to: Vector3, then: String) -> void:
	_goal = Meet.main.clear(to)
	_then = then
	state = "walk"

## Called to a table. First the bag for the strap, then the chalk, then the seat.
func go_pull(seat: Vector3, table_at: Vector3) -> void:
	wants_pull = false
	needs["pull"] = 0.0
	_seat = seat
	_face_at = table_at
	_legs = ["chalk", "seat"]
	if not strap_known_gone:
		_legs.push_front("bag")
	state = "to_table"
	_next_leg()

func _next_leg() -> void:
	state = "to_table"
	var leg: String = _legs.pop_front()
	_then = leg
	match leg:
		"bag":
			_goal = Meet.main.bag_spot(id)
		"chalk":
			_goal = Meet.main.CHALK + (_seat - Meet.main.CHALK).normalized() * 1.0
		"seat":
			_goal = _seat
			_then = "pull"

func finish_pull(won: bool) -> void:
	var lines: Array = People.WON if won else People.LOST
	say_aloud(lines[randi() % lines.size()])
	idle()

func _walk(dt: float, pace: float) -> bool:
	var d := _goal - global_position
	d.y = 0
	if d.length() < 0.3:
		return true
	global_position = Meet.main.ground(global_position + d.normalized() * WALK * pace * dt) if state == "to_table" else Meet.main.clear(global_position + d.normalized() * WALK * pace * dt)
	_look(global_position + d, 0.18)
	Character.play(_figure, "Jog_Fwd" if pace > 1.5 else "Walk")
	return false

func _arrive() -> void:
	match _then:
		"pull":
			state = "pull"
		"bag":
			if has_strap():
				state = "prep"
				_timer = 1.0
			else:
				Meet.main.drop_match(self)
				strap_known_gone = true
				strength -= 5.0
				state = "search"
				_phase = "rummage"
				_timer = 3.0
				_asks = 0
				say_aloud(People.STRAP_HUNT[0])
		"chalk":
			state = "prep"
			_timer = 1.3
			Fx.burst(Meet.main, global_position + Vector3(0, 1.1, 0), Vector3.UP, false, 5)
		"quirk":
			state = "quirk"
		"callout":
			state = "quirk"
			say_aloud(People.QUIRK["callout"][randi() % 3], 5.0)
		"coach":
			state = "quirk"
			_qbark = 99.0
			say_aloud(_qlines[randi() % _qlines.size()], 3.5)
			if is_instance_valid(_partner):
				_partner.say_aloud(People.QUIRK["coached"][randi() % 3], 5.0)
		"prank":
			if is_instance_valid(_partner) and _partner.global_position.distance_to(global_position) < 5.0:
				say_aloud(_qlines[randi() % _qlines.size()])
				var tgt := _partner
				Meet.main.puff(global_position + Vector3(0, 1.4, 0), tgt.global_position + Vector3(0, 1.4, 0), func():
					if is_instance_valid(tgt):
						tgt.dusted(self))
				state = "quirk"
				_qanim = "Dance"
				_qlines = []
				_timer = 3.0
			else:
				idle()
		"gawk":
			state = "watch"
			_face_at = Vector3(0, 0, 0)
			_timer = randf_range(18.0, 40.0)
		"snack":
			state = "snack"
			_timer = randf_range(3.0, 5.0)
		"watch":
			state = "watch"
			_timer = randf_range(8.0, 16.0)
		"sit":
			state = "sit"
			rotation.y = atan2(-global_position.x, -global_position.z)
			_timer = randf_range(12.0, 25.0)
		"chat":
			if is_instance_valid(_partner) and _partner.state in ["idle", "watch"] and _partner.global_position.distance_to(global_position) < 3.0:
				state = "chat"
				_timer = randf_range(5.0, 9.0)
				if _partner.passer:
					say_aloud(["You should have a go.", "We're here every month.", "It's all technique, honestly."][randi() % 3])
					_partner.say_aloud(_partner.def["chat"][randi() % 3], 5.0)
				else:
					_partner.state = "chat"
					_partner._partner = self
					_partner._timer = _timer
					_gossip(_partner)
			else:
				idle()
		_:
			idle()

## What they think of the player gets passed on over a chat.
func _gossip(other: Node3D) -> void:
	if randf() > mind.chatty:
		return
	var news: Dictionary = mind.gossip()
	if not news.is_empty() and other.mind.hear(news):
		say_aloud("...and then, right in front of everyone...", 3.5)

func _look(at: Vector3, speed: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), speed)

func _notice() -> void:
	var p: Vector3 = Meet.player.global_position
	var d := global_position.distance_to(p)
	if d > 9.0:
		_noticed = false
		return
	if _noticed or d > 5.0 or not is_riser or state in ["pull", "to_table", "prep", "search", "scrap", "winded", "flee"]:
		return
	_noticed = true
	mind.met()
	# First thing they notice is whatever ridiculous thing you have on.
	var on: Array = []
	for slot in Meet.worn:
		if People.WEARING.has(Meet.worn[slot]):
			on.append(Meet.worn[slot])
	if not on.is_empty() and randf() < 0.45:
		var lines: Array = People.WEARING[on[randi() % on.size()]]
		say_aloud(lines[randi() % lines.size()], 4.0)
		_look(p, 1.0)
	elif randf() < 0.55:
		var lines: Array = People.BARKS[bond()]
		say_aloud(lines[randi() % lines.size()])
		_look(p, 1.0)

# --- Being bothered ----------------------------------------------------------------------

func can_be_hit() -> bool:
	return state != "winded"

func knock(v: Vector3) -> void:
	_knock += v

## The player has a go at them with words.
func heckle() -> String:
	_heckled += 1
	Meet.heckles += 1
	mind.experience("heckle", -0.45, 0.9, true, riser_name)
	if passer:
		if _heckled >= 2:
			Meet.menu.close()
			say_aloud("Right. I'm going.")
			bolt(1.6)
			return ""
		return ["Excuse me?", "I'm just walking here.", "Do I know you?"][randi() % 3]
	for r in Meet.risers:
		if r != self and r.global_position.distance_to(global_position) < 7.0:
			r.mind.experience("heckle", -0.2, 0.4, false, riser_name)
	if Meet.heckles >= 5:
		Meet.grant("rubber_chicken")
	if _heckled >= 3 or mind.feeling() < -0.45:
		Meet.menu.close()
		square_up()
		return ""
	return People.HECKLED[randi() % People.HECKLED.size()]

## Enough. They come for the player.
func square_up() -> void:
	Meet.main.drop_match(self)
	say_aloud(People.SQUARE_UP[randi() % People.SQUARE_UP.size()])
	_vs_player = true
	_foe = null
	state = "scrap"
	_strike = 0.8
	Meet.scraps += 1

func take_hit(dmg: int, from: Vector3) -> void:
	if state == "winded":
		return
	composure -= dmg
	var away := global_position - from
	away.y = 0
	_knock += away.normalized() * (3.5 + dmg * 0.12)
	Character.play(_figure, "Hit_Chest", true)
	Fx.tint(_figure, Color(1.0, 0.95, 0.5, 0.5), 0.1)
	say_aloud(["Oof!", "Hey!", "Ow!", "Oi!"][randi() % 4], 1.2)
	if alien:
		if composure <= 0.0:
			_go_down()
		return
	if passer:
		say_aloud("Help! This one's lost the plot!", 4.0)
		for r in Meet.risers:
			if r.is_riser and r.global_position.distance_to(global_position) < 14.0:
				r.mind.experience("scrap", -0.5, 1.2, false, riser_name)
		bolt(2.6)
		Meet.main.public_hit(self)
		return
	if state != "scrap":
		# Hit out of nowhere: everyone watching thinks less of the player for it.
		mind.experience("scrap", -0.8, 2.5, true, riser_name)
		for r in Meet.risers:
			if r != self and r.is_riser and r.global_position.distance_to(global_position) < 9.0:
				r.mind.experience("scrap", -0.4, 1.0, false, riser_name)
				r.say_aloud(["Whoa, whoa!", "Not at the meet!", "Break it up!"][randi() % 3])
		square_up()
	if composure <= 0.0:
		_go_down()

func _go_down() -> void:
	state = "winded"
	_timer = 9.0 if not alien else 9999.0
	_vs_player = false
	say_aloud("Okay! Okay." if not alien else "Bzzt.", 2.5)
	Character.play(_figure, "Death01" if alien else "Crouch_Idle", true)
	if not alien:
		Meet.main.scrap_over(self, true)

func _scrap(dt: float) -> void:
	var target: Vector3 = Meet.player.global_position if _vs_player else (_foe.global_position if is_instance_valid(_foe) else global_position)
	if not _vs_player and (not is_instance_valid(_foe) or _foe.state == "winded"):
		idle()
		return
	var to := target - global_position
	to.y = 0
	_strike = max(0.0, _strike - dt)
	if _wind > 0.0:
		_wind -= dt
		if _wind <= 0.0:
			_strike = 1.5
			if to.length() < 2.3:
				if _vs_player:
					Meet.player.slapped(12.0 + strength * 0.1, global_position, self)
				else:
					_foe.take_hit(18, global_position)
		return
	if to.length() > 1.7:
		_goal = target
		_walk(dt, 1.8)
		return
	_look(target, 0.25)
	if _strike <= 0.0:
		_wind = 0.5
		Fx.tint(_figure, Color(1.0, 0.5, 0.1, 0.5), 0.5)
		Character.play(_figure, "Punch_Cross", true)
	else:
		Character.play(_figure, "Sword_Idle")

# --- Visitors from the sky -------------------------------------------------------------

func _threat() -> Vector3:
	var best := global_position + Vector3(0, 0, 5)
	var bd := 99.0
	for a in Meet.main.aliens():
		var d: float = a.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = a.global_position
	return best

func aliens_arrive() -> void:
	if state == "winded":
		return
	# The bold ones go for the visitors; everyone else gets up the steps.
	if is_riser and strength >= 76.0:
		var all: Array = Meet.main.aliens()
		if not all.is_empty():
			_foe = all[randi() % all.size()]
			_vs_player = false
			state = "scrap"
			say_aloud(People.ALIEN_LINES[randi() % People.ALIEN_LINES.size()])
			return
	state = "flee"

func aliens_gone() -> void:
	if state in ["flee", "scrap"]:
		idle()
	if is_riser:
		mind.experience("aliens", 0.8, 2.0, true, "the visitors")
		say_aloud(People.AFTER_ALIENS[randi() % People.AFTER_ALIENS.size()], 4.0)

## A visitor: picks someone, runs at them, zaps them. Three good hits and it sits down.
func _alien(dt: float) -> void:
	if state == "winded":
		return
	if not is_instance_valid(_foe) or randf() < dt * 0.15:
		_foe = null
		_vs_player = randf() < 0.45
		if not _vs_player:
			var pick: Array = Meet.risers.filter(func(r): return r.state != "winded")
			if not pick.is_empty():
				_foe = pick[randi() % pick.size()]
			else:
				_vs_player = true
	var target: Vector3 = Meet.player.global_position if _vs_player else _foe.global_position
	var to := target - global_position
	to.y = 0
	_strike = max(0.0, _strike - dt)
	if _wind > 0.0:
		_wind -= dt
		if _wind <= 0.0:
			_strike = 1.8
			if to.length() < 2.4:
				if _vs_player:
					Meet.player.slapped(10.0, global_position, self)
				elif _foe.state != "scrap":
					_foe.knock(to.normalized() * 4.0)
					_foe.say_aloud("Aah!", 1.0)
		return
	if to.length() > 1.8:
		_goal = target
		state = "walk"
		_walk(dt, 2.0)
		return
	_look(target, 0.3)
	if _strike <= 0.0:
		_wind = 0.6
		Fx.tint(_figure, Color(1.0, 0.3, 0.9, 0.6), 0.6)
		Character.play(_figure, "Spell_Simple_Shoot", true)

# --- Straps -----------------------------------------------------------------------------

## The strap isn't in the bag. Turn the bag out, then go round asking.
func _search(dt: float) -> void:
	match _phase:
		"rummage":
			_timer -= dt
			Character.play(_figure, "Fixing_Kneeling")
			if _timer <= 0.0:
				say_aloud(People.STRAP_HUNT[1 + randi() % 2])
				_ask_next()
		"walk":
			if not is_instance_valid(_partner):
				_ask_next()
			else:
				_goal = _partner.global_position + Vector3(1.2, 0, 0.4)
				if _walk(dt, 1.4):
					_phase = "ask"
					_timer = 3.0
					_asks += 1
					say_aloud(People.STRAP_ASK[randi() % 3])
					if _partner.saw_theft.has(id):
						_partner.say_aloud("The new one was in your bag earlier.", 4.0)
						_phase = "told"
					else:
						_partner.say_aloud(People.STRAP_NO[randi() % 3], 3.0)
		"ask", "told":
			_timer -= dt
			Character.play(_figure, "Idle_Talking")
			if _timer <= 0.0:
				if _phase == "told":
					_phase = "accuse"
					say_aloud("Oh, was it now.")
				elif _asks >= 3:
					say_aloud(People.STRAP_GONE[randi() % 3], 4.0)
					mind.experience("theft", -0.2, 0.5, false, "my strap")
					idle()
				else:
					_ask_next()
		"accuse":
			_goal = Meet.player.global_position
			if _walk(dt, 1.8) or global_position.distance_to(_goal) < 2.0:
				caught_with_strap()

func _ask_next() -> void:
	var o: Array = Meet.risers.filter(func(r): return r != self and r.is_free())
	if o.is_empty():
		_asks = 3
		_phase = "ask"
		_timer = 0.5
		return
	_partner = o[randi() % o.size()]
	_phase = "walk"

## They have worked out who has it.
func caught_with_strap() -> void:
	Meet.straps.erase(id)
	strap_known_gone = false
	strength += 5.0
	Meet.main.strap_back(id)
	mind.experience("theft", -0.7, 2.0, true, "my strap")
	say_aloud("That's MY strap. Hand it over.", 4.0)
	Meet.say("%s takes the strap back off you. That did not go unnoticed." % riser_name)
	Meet.touch_state()
	if mind.feeling() < -0.45:
		square_up()
	elif state == "search":
		idle()

## The player hands it back before, or after, it was missed.
func strap_returned() -> String:
	Meet.straps.erase(id)
	Meet.main.strap_back(id)
	Meet.touch_state()
	if strap_known_gone:
		strap_known_gone = false
		strength += 5.0
		if state == "search":
			idle()
		mind.experience("helped", 0.5, 1.0, true, "my strap")
		return "My strap! Where was it? You're a lifesaver."
	mind.experience("theft", -0.3, 0.8, true, "my strap")
	return "...Why do you have my strap?"

# --- Chalk ------------------------------------------------------------------------------

## A faceful of chalk, from the player or from Tommy.
func dusted(by: Node) -> void:
	if state == "winded":
		return
	Fx.tint(_figure, Color(1, 1, 1, 0.8), 40.0)
	Fx.burst(Meet.main, global_position + Vector3(0, 1.5, 0), Vector3.UP, false, 10)
	if by != Meet.player:
		say_aloud("%s!" % by.first_name.to_upper(), 2.5)
		return
	Meet.dusted += 1
	if Meet.dusted >= 5:
		Meet.grant("ghost")
	if alien:
		composure -= 20.0
		say_aloud("Bzzk! Kff!", 2.0)
		if composure <= 0.0:
			_go_down()
		return
	if passer:
		mind.experience("chalk", -0.5, 1.0)
		say_aloud("What the— I'm calling the council!", 4.0)
		bolt(2.0)
		return
	var b := bond()
	var lines: Array = People.DUSTED[b]
	say_aloud(lines[randi() % lines.size()], 4.0)
	for r in Meet.risers:
		if r != self and r.is_riser and r.state != "winded" and r.global_position.distance_to(global_position) < 8.0 and randf() < 0.5:
			r.say_aloud(["Ha!", "Got you!", "Chalk fight!", "Hahaha."][randi() % 4], 2.5)
	match b:
		"close", "mates":
			mind.experience("chalk", 0.2, 0.5)
			if state not in ["pull", "to_table", "prep", "scrap"]:
				Meet.main.puff(global_position + Vector3(0, 1.4, 0), Meet.player.global_position + Vector3(0, 1.4, 0), func(): Meet.player.dusted(), 0.9)
		"known":
			mind.experience("chalk", -0.15, 0.6)
		_:
			mind.experience("chalk", -0.4, 1.0)
			if mind.feeling() < -0.45 and state != "scrap":
				square_up()

# --- Passing by ---------------------------------------------------------------------------

func _pass(dt: float) -> void:
	position.x += _dir * _pace * dt
	position.z = move_toward(position.z, _lane, dt * 2.0)
	position.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(_dir, 0.0), 0.15)
	Character.play(_figure, "Jog_Fwd" if _pace > 2.6 else "Walk")
	if _stops and absf(position.x) < 0.6:
		# Something is going on over there. Go and look.
		_stops = false
		_go(Vector3(randf_range(-5.0, 5.0), 0, randf_range(9.6, 11.5)), "gawk")
	elif absf(position.x) > 32.0:
		Meet.risers.erase(self)
		queue_free()

## Leave, quickly.
func bolt(pace: float) -> void:
	_stops = false
	_pace = max(_pace, 1.4) * pace
	state = "pass"
