extends Node3D
## Someone at the meet. They pull at the tables, eat, talk, watch and sit; they remember how
## the player has treated them (mind.gd) and act on it. Nobody is ever really hurt: someone
## who loses a scrap sits down winded and gets up again.

const Build = preload("res://scripts/build.gd")
const Character = preload("res://scripts/character.gd")
const Mind = preload("res://scripts/mind.gd")
const People = preload("res://scripts/people.gd")
const Fx = preload("res://scripts/fx.gd")
const Wear = preload("res://scripts/wear.gd")
const Pose = preload("res://scripts/pose.gd")

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
var guest := false               # a passer-by who stayed for the meet
var guest_ready := false         # talked into their first pull
var bet := false                 # a snack is riding on the next pull with the player
var done_topics := {}
var _convo := {}
var _pitched := 0
var _insulted := 0
var _att := ""
var _name_label: Label3D
var _level := 0
var _mood_check := 0.0
var _apologised := false
var _backed := false
var _away := 0.0
var _stare := 0.0
var stake := 0                  # dollars riding on the next pull with the player
var pull_angry := false
var wallet := 0
var wallet_taken := 0
var _goaded := 0
var confront_kind := ""          # beef | warn
var confront_text := ""
var settle := false              # the pull in progress settles a grievance
var _chase := 0.0
var _dog_node: Node3D
var _dog_wag := 0.0
var _dog_free := 0.0
var _dog_goal := Vector3.ZERO
var _dog_ate := false
var _lead: MeshInstance3D
var coned := false
var riding := false              # on a bicycle
var post := false                # works a fixed spot: the busker, the fisherman, the kebab van
var _post_at := Vector3.ZERO
var _post_yaw := 0.0
var _lift_t := 0.0
var _give: Callable
var _zap := 0.0
var legend := ""                 # a visiting great: "don" or "lasha"
var sulking := false             # walked off on you tonight; won't pull until you make it right
var _tail := 0.0
var _fought_player := false
var secret_dead := false         # down for good, and nobody but you knows yet
var _found_t := 0.0
var _far_t := 0.0
var _lod := false
var _grief := {}
var _after_talk := ""
var dead := false                # gone for the rest of tonight, unless somebody has a potion
var keen := false                # already half talked into a pull
var bracket := ""                # this pull is the player's bracket semi or final
var _chalk_t := 0.0
var backing := false             # has agreed to watch your back tonight
var _asked := {}
var _pace_boost := 1.0
var _shout_then := 0.0
var lefts := false               # the next pull is left-handed: everyone is worse at it
var _act_anim := ""
var _act_t := 0.0
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
	_name_label = Build.label(self, riser_name, 2.2 if d["id"] != "alien" else 1.75, Color(1, 0.95, 0.8) if riser else Color(0.8, 0.8, 0.82), 16)
	_bark = Build.label(self, "", 2.75 if d["id"] != "alien" else 2.2, Color(1.0, 0.93, 0.6), 44)
	# Speech stays the same size on screen however far away they are, so it can be read.
	_bark.fixed_size = true
	_bark.pixel_size = 0.0008
	_bark.outline_size = 14
	_bark.width = 560.0
	_bark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bark.no_depth_test = true
	_bark.visible = false
	# The words themselves are drawn by the display, in 2D, so they stay sharp at any
	# distance and at any graphics setting. These two only hold the text and colour.
	_name_label.layers = 0
	_bark.layers = 0
	add_to_group("tagged")
	_timer = randf_range(1.0, 6.0)
	wallet = 10 + randi() % 4 * 5 if riser else 0
	_level = mood_level()
	_show_mood()
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
	if def.has("size"):
		var sz: float = def["size"]
		_figure.scale = Vector3(0.8, sz, 0.8)
		_bark.position.y = 2.75 * sz
		_name_label.position.y = 2.2 * sz
	match def.get("prop", ""):
		"bun":
			for sx in [-1.0, 1.0]:
				Build.sphere(self, 0.3, Vector3(sx * 0.33, 1.05, 0), Color(0.85, 0.62, 0.3)).scale = Vector3(0.6, 2.6, 1.0)
			Build.cyl(self, 0.03, 0.03, 1.2, Vector3(0, 1.1, 0.3), Color(0.95, 0.85, 0.15), 6)
		"door":
			Build.box(self, Vector3(0.9, 2.0, 0.06), Vector3(0.1, 1.3, 0.38), Color(0.5, 0.33, 0.18))
			Build.sphere(self, 0.04, Vector3(0.45, 1.25, 0.43), Color(0.9, 0.8, 0.3))
		"pram":
			Build.box(self, Vector3(0.5, 0.35, 0.8), Vector3(0, 0.6, 0.9), Color(0.2, 0.25, 0.5))
			Build.box(self, Vector3(0.5, 0.3, 0.05), Vector3(0, 0.95, 0.52), Color(0.2, 0.25, 0.5))
			for sx in [-1.0, 1.0]:
				for sz2 in [0.6, 1.2]:
					Build.cyl(self, 0.13, 0.13, 0.04, Vector3(sx * 0.27, 0.13, sz2), Color(0.1, 0.1, 0.1), 10).rotation.z = PI / 2.0
			Build.sphere(self, 0.13, Vector3(0, 0.85, 0.95), Color(0.9, 0.55, 0.2))
			for sx in [-1.0, 1.0]:
				Build.cyl(self, 0.0, 0.04, 0.08, Vector3(sx * 0.07, 0.99, 0.95), Color(0.9, 0.55, 0.2), 4)

func _dog() -> void:
	var dog := Node3D.new()
	add_child(dog)
	_dog_node = dog
	dog.position = Vector3(0.75, 0, 0.5)
	var c: Color = def.get("dog_color", Color(0.72, 0.52, 0.3))
	var dog_name: String = def.get("dog_name", "Biscuit")
	dog.scale = Vector3.ONE * float(def.get("dog_size", 1.0))
	Build.box(dog, Vector3(0.2, 0.2, 0.5), Vector3(0, 0.32, 0), c)
	Build.box(dog, Vector3(0.18, 0.18, 0.2), Vector3(0, 0.48, 0.3), c)
	Build.box(dog, Vector3(0.08, 0.07, 0.1), Vector3(0, 0.44, 0.43), c * 0.6)
	for e in [-1.0, 1.0]:
		Build.box(dog, Vector3(0.05, 0.1, 0.03), Vector3(e * 0.07, 0.6, 0.26), c * 0.7)
		for z in [-0.18, 0.18]:
			Build.box(dog, Vector3(0.05, 0.22, 0.05), Vector3(e * 0.07, 0.11, z), c)
	Build.box(dog, Vector3(0.04, 0.16, 0.04), Vector3(0, 0.46, -0.27), c).rotation.x = -0.6
	_lead = Build.cyl(self, 0.006, 0.006, 0.95, Vector3(0.52, 0.72, 0.42), Color(0.8, 0.1, 0.1), 4)
	_lead.rotation = Vector3(0.5, 0, -0.9)
	var unclip: Node3D = load("res://scripts/thing.gd").new()
	dog.add_child(unclip)
	unclip.position = Vector3(-0.3, 0, -0.3)
	unclip.setup("Unclip %s's lead" % dog_name, func():
		if _dog_free > 0.0:
			return
		_dog_free = 24.0
		Meet.dare("dog")
		_lead.visible = false
		dog.reparent(Meet.main)
		_dog_goal = dog.global_position
		say_aloud("%s! NO! Come BACK!" % dog_name.to_upper(), 4.0)
		Meet.add_heat(0.5, "letting a dog loose")
		Meet.say("%s is free, and has never been happier." % dog_name)
		Meet.main.stir(global_position, ["There's a dog loose!", "Get it away from the snacks!", "Ha! Go on, mate!", "Who let the dog out?"], 30.0, 0.6, false))
	var pat: Node3D = load("res://scripts/thing.gd").new()
	dog.add_child(pat)
	pat.position = Vector3(0.3, 0, 0.3)
	pat.setup("Pet %s" % dog_name, func():
		_dog_wag = 2.6
		Meet.dare("pet")
		Meet.sfx("bark", -4.0, 1.3 if def.get("dog_size", 1.0) < 1.0 else 1.0)
		Meet.player.gesture("pet", 2.6, _dog_node.global_position + Vector3(0, 0.5 * _dog_node.scale.y, 0.2 * _dog_node.scale.y))
		Meet.composure = min(100.0, Meet.composure + 10.0)
		say_aloud(["She likes you.", "He doesn't do that for everyone.", "You've made a friend."][randi() % 3], 3.5)
		Meet.say("%s leans into your hand. %s approves of you. You feel better about everything." % [dog_name, dog_name])
		if not _fed:
			_fed = true
			mind.experience("helped", 0.5, 1.0))

func prompt() -> String:
	if state == "scrap" and _vs_player:
		return "Put your hands up: \"Alright, alright. I'm sorry.\""
	return "Talk to %s" % riser_name

func interact() -> void:
	if state == "scrap" and _vs_player:
		back_down()
		return
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
	if dead:
		return
	_bark.text = text
	_bark.visible = true
	_bark_time = max(seconds, 2.2) + text.length() * 0.035

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

func set_post(at: Vector3, yaw: float) -> void:
	post = true
	_post_at = at
	_post_yaw = yaw
	global_position = at
	rotation.y = yaw
	state = "post"
	_timer = randf_range(6.0, 14.0)

func is_free() -> bool:
	if post or dead:
		return false
	if state == "walk" and _then in ["answer", "bench", "swarm"]:
		return false   # on their way to the player; nothing else gets to claim them
	return state in ["idle", "walk", "watch", "sit", "chat", "snack", "quirk", "huddle"] and not alien and not passer

func has_strap() -> bool:
	return not Meet.straps.has(id)

func facing(p: Vector3) -> bool:
	var to := p - global_position
	to.y = 0
	return to.length() < 0.5 or Vector3(sin(rotation.y), 0, cos(rotation.y)).dot(to.normalized()) > 0.35

func at_table() -> bool:
	return state == "pull"

func idle() -> void:
	if dead:
		return
	if post:
		state = "post"
		global_position = _post_at
		return
	Wear.drop(_figure)
	_convo = {}
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
	if dead:
		if secret_dead:
			_wait_to_be_found(dt)
		return
	# Far away, their animation only needs to tick over now and then.
	_far_t -= dt
	if _far_t <= 0.0:
		_far_t = 1.0
		var ap: AnimationPlayer = _figure.get_meta("anim")
		var far: bool = global_position.distance_to(Meet.player.global_position) > 26.0
		ap.speed_scale = 1.0
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if far else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		if far:
			ap.advance(1.0)
		var mid: bool = global_position.distance_to(Meet.player.global_position) > 15.0
		if mid != _lod:
			_lod = mid
			for mi in _figure.find_children("*", "MeshInstance3D", true, false):
				var nm := String(mi.name)
				if nm.contains("Eye") or nm.contains("Brow") or nm.contains("Teeth") or nm.contains("Tongue"):
					mi.visible = not mid
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
	if _dog_free > 0.0:
		_run_dog(dt)
		return
	if _dog_wag > 0.0:
		# Being petted: the dog wriggles and its owner waits.
		_dog_wag -= dt
		_dog_node.rotation.y = sin(_dog_wag * 16.0) * 0.25
		_dog_node.position.y = absf(sin(_dog_wag * 9.0)) * 0.05
		Character.play(_figure, "Idle")
		return
	_mood_check -= dt
	if _mood_check <= 0.0 and (is_riser or guest):
		_mood_check = 0.5
		_mood_changed()
	if is_riser or guest:
		for k in needs:
			needs[k] = min(1.5, needs[k] + float(life.get(k, 0.5)) * float(tonight.get(k, 1.0)) * dt / 45.0)
	if _act_t > 0.0:
		_act_t -= dt
		_look(Meet.player.global_position, 0.2)
		Character.play(_figure, _act_anim)
		return
	# Something has their whole attention: they stand and look straight at you.
	if _stare > 0.0 and state not in ["pull", "to_table", "prep", "scrap", "winded", "flee", "search"]:
		_stare -= dt
		_look(Meet.player.global_position, 0.25)
		Character.play(_figure, "Idle")
		return
	_notice()
	if state not in ["pull", "prep", "lift"] and Pose.posed(_figure):
		Pose.stop(_figure)
	match state:
		"idle":
			Character.play(_figure, "Idle")
			_timer -= dt
			if _timer <= 0.0:
				_choose()
		"walk", "to_table":
			if _walk(dt, _pace_boost if state == "walk" else 1.0):
				_pace_boost = 1.0
				_arrive()
		"prep":
			# Rummaging in the bag for the strap, or chalking up.
			_timer -= dt
			if _then == "chalk":
				_chalk_t += dt
				Pose.chalk(_figure, _chalk_t)
			else:
				Character.play(_figure, _qanim)
			if _timer <= 0.0:
				Pose.stop(_figure)
				if _then == "bag":
					# The strap comes out of the bag in their hand.
					var st := Node3D.new()
					Build.box(st, Vector3(0.05, 0.3, 0.02), Vector3(0, 0.02, 0.03), def.get("strap", Color.WHITE))
					Wear.hold(_figure, st)
				_next_leg()
		"pull":
			_look(_face_at, 0.2)
			if not Pose.posed(_figure):
				Character.play(_figure, "Idle")
		"huddle":
			_huddle(dt)
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
		"ride":
			pass   # moved by whoever is running the bike
		"tail":
			# Walking with you for a bit, because of something you said.
			_tail -= dt
			var tp: Vector3 = Meet.player.global_position
			if global_position.distance_to(tp) > 2.4:
				_goal = tp
				_walk(dt, 1.6 if global_position.distance_to(tp) > 5.0 else 1.0)
			else:
				_look(tp, 0.15)
				Character.play(_figure, "Idle")
			_qbark -= dt
			if _qbark <= 0.0:
				_qbark = randf_range(7.0, 11.0)
				var own: Array = People.SMALL.get(id, ["Nice night for it."])
				say_aloud(own[randi() % own.size()], 4.5)
			if _tail <= 0.0 or Meet.modal and Meet.table.active():
				say_aloud(["Right. I'm up soon. Good talk.", "Catch you in a bit.", "Go on. I'll find you later."][randi() % 3], 3.5)
				idle()
		"post":
			# At work. Looks up when you come close.
			global_position = _post_at
			var pd: float = global_position.distance_to(Meet.player.global_position)
			if pd < 4.5:
				_look(Meet.player.global_position, 0.1)
			else:
				rotation.y = lerp_angle(rotation.y, _post_yaw, 0.05)
			Character.play(_figure, def.get("anim", "Idle") if pd < 4.5 or id == "s_busker" else "Idle")
			_timer -= dt
			if _timer <= 0.0 and pd < 9.0:
				_timer = randf_range(14.0, 26.0)
				say_aloud(def["chat"][randi() % def["chat"].size()], 4.5)
		"lift":
			_lift_t += dt
			Pose.curl(_figure, _lift_t)
			_timer -= dt
			if _timer <= 0.0:
				Pose.stop(_figure)
				say_aloud(["And that's the set.", "Forearms. Always forearms.", "Light weight."][randi() % 3], 3.0)
				idle()
		"confront":
			# Walking you down for a word. It happens when they reach you.
			_chase += dt
			_goal = Meet.player.global_position
			if global_position.distance_to(_goal) > 2.0:
				_walk(dt, 1.8)
				if _chase > 22.0:
					say_aloud("Yeah. Run. I'll remember.", 3.5)
					mind.experience("heckle", -0.15, 0.6)
					idle()
			else:
				_look(_goal, 0.3)
				Character.play(_figure, "Idle_Talking")
				if not Meet.modal:
					Meet.menu.confrontation(self)
		"pass":
			_pass(dt)
		"snack":
			# Reach for one off the table, then stand there eating it.
			_timer -= dt
			if _timer > 3.2:
				Character.play(_figure, "PickUp_Table")
				_look(Meet.main.SNACKS, 0.2)
			else:
				if _phase != "eating":
					_phase = "eating"
					var sn := Node3D.new()
					Build.box(sn, Vector3(0.1, 0.14, 0.05), Vector3(0, 0.08, 0.03), [Color(0.9, 0.3, 0.2), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.9)][randi() % 3])
					Wear.hold(_figure, sn)
				Character.play(_figure, "Idle_Talking")
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
			if _timer <= 0.0:
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
	if not is_riser and not guest:
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
			if is_riser and randf() < 0.7 and _start_huddle():
				return
			var others: Array = Meet.risers.filter(func(r): return r != self and (r.state == "idle" or (r.passer and r.state == "watch")))
			if others.is_empty():
				_watch(main)
				return
			_partner = others[randi() % others.size()]
			var to: Vector3 = global_position - _partner.global_position
			to.y = 0
			_go(_partner.global_position + to.normalized() * 1.3, "chat")
		"rest":
			if randf() < 0.6:
				_outing(main)
				return
			var a2 := PI + 0.4 + randf() * (PI - 0.8)
			var rr: float = main.PLAZA + 0.5 + randi() % 5
			_go(Vector3(cos(a2) * rr, 0, sin(a2) * rr), "sit")
		"quirk":
			_quirk(main)

## Go and use the place: the van, the busker, the fisherman, the weights, the bench, the ladder.
func _outing(main: Node3D) -> void:
	_qlines = []
	_qbark = 1.0
	_qanim = "Idle"
	_timer = randf_range(7.0, 12.0)
	var options := ["van", "busker", "fisher", "weights", "ladder", "bin" if id == "kelvin" else "van", "rail"]
	if id == "phillip":
		options = ["weights", "weights", "rail"]
	elif id == "luie":
		options = ["fisher", "rail", "busker"]
	match options[randi() % options.size()]:
		"van":
			_qlines = ["The lot. Garlic AND chilli.", "Chips. Large. Chicken salt.", "Just a drink, thanks, Sami.", "Same as last time."] if id != "kelvin" else ["The Sunday, please, Sami.", "Two lamb, one chicken. And whatever's left.", "Is that all for me? ...Yes. Yes it is."]
			_qanim = "Interact"
			_face_at = Vector3(-17.0, 0, 23.5)
			_go(Vector3(-15.8, 0, 27.0) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(0.2, 0.9)), "quirk")
		"busker":
			_qlines = ["Play the one about the pad!", "She's good, you know.", "Wonderwall!", "..."]
			_qanim = "Dance" if mind.chatty > 0.6 else "Idle"
			_face_at = Vector3(-7.5, 0, 26.6)
			_go(Vector3(-7.5 + randf_range(-1.5, 1.5), 0, 24.6), "quirk")
		"fisher":
			_qlines = ["Catching anything, Con?", "What's biting?", "Is Kevin about?", "..."]
			_face_at = Vector3(15.0, 0, 40)
			_go(Vector3(15.0 + randf_range(1.2, 2.4), 0, 28.2), "quirk")
		"weights":
			_face_at = Vector3.ZERO
			_go(Vector3(-6.5, 0, -5.5) + Vector3(randf_range(-0.6, 0.6), 0, 0.9) if randf() < 0.5 else Vector3(7.5, 0, 9.5) + Vector3(0.9, 0, randf_range(-0.6, 0.6)), "lift")
		"ladder":
			_qlines = {"harry": ["Second? Who's first? ...Erick. Right."], "erick": ["First. As it should be.", "Still top. Good."], "kelvin": ["Third. I'll take third."], "tommy": ["Seventh. The board's wrong. The board has always been wrong."], "luie": ["...Eighth. Fine."]}.get(id, ["Hm. Could be worse.", "Who updates this thing?"])
			_face_at = Vector3(3.6, 0, 21.5)
			_go(Vector3(3.6 + randf_range(-0.5, 0.5), 0, 19.6), "quirk")
		"bin":
			_qlines = ["Somebody threw away half a kebab. HALF.", "Just checking. Just looking.", "Don't tell anyone."]
			_qanim = "Fixing_Kneeling"
			_face_at = Vector3(11.5, 0, 25.6)
			_go(Vector3(11.5, 0, 24.8), "quirk")
		_:
			_qlines = ["Nice out.", "...", "Ferry's late."]
			var x := randf_range(-12.0, 10.0)
			_face_at = Vector3(x, 0, 60)
			_go(Vector3(x, 0, 28.4), "quirk")

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
				camera()
				_qanim = "Pistol_Aim_Neutral"
				_face_at = main.TABLES[main.nearest_match(global_position)]
				_go(_face_at + Vector3(randf_range(-1.5, 1.5), 0, 2.4), "quirk")
			else:
				_qlines = People.QUIRK["spruik"]
				_face_at = Vector3(0, 0, 30)
				_go(Vector3(randf_range(-1.5, 1.5), 0, 21.0), "quirk")
		"drill":
			_qanim = "Crouch_Idle"
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
	if dead:
		return
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
	if is_riser and not strap_known_gone:
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
			if wallet_taken > 0:
				_wallet_missed()
				return
			if Meet.planted.has(id):
				_strap_planted()
				return
			if has_strap():
				state = "prep"
				_qanim = "Fixing_Kneeling"
				_look(Meet.main._bags[id]["at"], 1.0)
				_timer = 1.8
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
			if Meet.chalk_hidden > 0.0:
				say_aloud(["Where's the chalk?!", "Who's moved the chalk?", "No chalk. Brilliant."][randi() % 3], 3.5)
				Meet.main.stir(global_position, ["It was right there.", "Not again.", "Check behind the banners."], 8.0, 0.4, false)
				_next_leg()
				return
			state = "prep"
			_qanim = "Interact"
			_look(Meet.main.CHALK, 1.0)
			_chalk_t = 0.0
			_timer = 1.8
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
			if passer:
				_face_at = Vector3(0, 0, 0)
			_timer = randf_range(18.0, 40.0) if passer else randf_range(5.0, 9.0)
		"snack":
			state = "snack"
			_phase = ""
			_timer = randf_range(4.4, 6.5)
		"huddle":
			state = "huddle"
		"fooled":
			state = "quirk"
			_qanim = "Idle"
			_qlines = []
			_face_at = Vector3(0, 0, 30)
			_timer = 4.0
			mind.experience("nagged", -0.12, 0.5, true, riser_name)
			say_aloud("...I've been to the gate. There is NOTHING at the gate. I'm coming back for whoever shouted." if id == "kelvin" else ["There's nothing here.", "Where are the snacks?", "Who shouted that?", "...We've been had.", "I ran for this."][randi() % 5], 4.5)
		"hug":
			state = "quirk"
			_qanim = "Interact"
			_qlines = []
			_face_at = Meet.player.global_position
			_timer = 3.0
			if not _asked.has("hug"):
				_asked["hug"] = true
				mind.experience("talk", 0.3, 0.8, true, "the hug")
		"raced":
			Meet.main.race_arrival(self)
			state = "quirk"
			_qanim = "Idle"
			_qlines = []
			_face_at = Vector3(global_position.x, 0, 60)
			_timer = 5.0
		"swarm":
			state = "quirk"
			_qanim = "Punch_Cross"
			_qlines = []
			_face_at = Meet.player.global_position
			_timer = 4.0
		"answer":
			if Meet.player.global_position.distance_to(global_position) < 5.0 and not Meet.modal:
				Meet.table.start(self)
			else:
				say_aloud("Where've they gone? Called me over and wandered off.", 4.0)
				mind.experience("nagged", -0.1, 0.4)
				idle()
		"lift":
			state = "lift"
			_lift_t = 0.0
			_timer = randf_range(5.0, 8.0)
			say_aloud(["One set.", "Just a quick pump.", "Don't watch me."][randi() % 3], 2.5)
		"give":
			# Hand something over, properly.
			state = "quirk"
			_qanim = "Interact"
			_qlines = []
			_face_at = Meet.player.global_position
			_timer = 2.5
			_look(Meet.player.global_position, 1.0)
			gesture("Interact", 1.2)
			if _give.is_valid():
				_give.call()
		"bench":
			if Meet.player.sitting and not Meet.modal:
				state = "sit"
				_timer = 20.0
				rotation.y = Meet.player.rotation.y + PI
				global_position.y = Meet.player.global_position.y
				mind.experience("talk", 0.3, 0.8, true, "sitting together")
				Meet.menu.bench(self)
			else:
				idle()
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
					_partner.say_aloud(_partner.def["chat"][randi() % _partner.def["chat"].size()], 5.0)
				else:
					Meet.bump(id, _partner.id, 0.04)
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
		Meet.ripple("%s told %s what you did." % [first_name, other.first_name], true)

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
	if _costume():
		return
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
		var line: String = lines[randi() % lines.size()]
		if Meet.player_name != "" and randf() < 0.5:
			line = {"close": "%s! Over here!", "mates": "Hey, %s.", "known": "Evening, %s.", "irritated": "Not now, %s.", "gone": "Stay away from me, %s."}[bond()] % Meet.player_name
		say_aloud(line)
		_look(p, 1.0)

# --- Being bothered ----------------------------------------------------------------------

func can_be_hit() -> bool:
	# Someone who squared up to you and lost is still fair game while they are down.
	return not dead and (state != "winded" or (_fought_player and not alien))

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
func square_up(joined := false) -> void:
	_fought_player = true
	Meet.sfx("sting", -4.0, 1.0, 1.0)
	if not joined and is_riser:
		# A close friend may pile in.
		var bm: Array = best_mate()
		var mate: Node = bm[0]
		if mate != null and bm[1] > 0.4 and mate.is_free() and mate.global_position.distance_to(global_position) < 14.0 and randf() < 0.25 + float(bm[1]) * 0.4 and not mate.backing:
			mate.say_aloud("You take on %s, you take on me." % first_name, 4.5)
			mate.mind.experience("scrap", -0.3, 1.0, false, riser_name)
			mate.square_up(true)
	for r in Meet.risers:
		if r != self and r.backing and r.is_free() and r.global_position.distance_to(global_position) < 16.0:
			r.backing = false
			r.say_aloud("Leave it, %s. They're with me." % first_name, 4.5)
			r._go(global_position + (Meet.player.global_position - global_position) * 0.5, "gawk")
			say_aloud("...Fine. This time.", 3.5)
			Meet.say("%s steps in between you. That was the favour used up." % r.riser_name)
			Meet.bump(id, r.id, -0.05)
			idle()
			return
	Meet.main.drop_match(self)
	say_aloud(People.SQUARE_UP[randi() % People.SQUARE_UP.size()])
	_vs_player = true
	_foe = null
	state = "scrap"
	_strike = 0.8
	Meet.scraps += 1

func take_hit(dmg: int, from: Vector3) -> void:
	if dead:
		return
	if state == "winded":
		if _fought_player and not alien:
			finished_by_player()
		return
	composure -= dmg
	var away := global_position - from
	away.y = 0
	_knock += away.normalized() * 0.6   # a stagger, not a flight
	Character.play(_figure, "Hit_Chest", true)
	Fx.tint(_figure, Color(1.0, 0.95, 0.5, 0.5), 0.1)
	say_aloud(["Oof!", "Hey!", "Ow!", "Oi!"][randi() % 4], 1.2)
	if alien:
		if composure <= 0.0:
			_go_down()
		return
	if post:
		say_aloud(["OI! I'm WORKING here!", "What's the matter with you?", "Touch me again and I'm calling someone."][randi() % 3], 4.0)
		mind.experience("scrap", -0.6, 1.5, true, riser_name)
		Meet.add_heat(1.5, "hitting someone at work")
		Meet.main.warn("That's %s. They've got nothing to do with us. What is WRONG with you?" % riser_name)
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
		Meet.add_heat(1.0, "throwing a punch")
		Meet.main.defend(self, "punch")
		Meet.main.stir(global_position, ["Whoa, whoa!", "Not at the meet!", "Break it up!", "Did you see that?"], 14.0, 0.7, true)
		# Hit out of nowhere: everyone watching thinks less of the player for it.
		mind.experience("scrap", -0.8, 2.5, true, riser_name)
		for r in Meet.risers:
			if r != self and r.is_riser and r.global_position.distance_to(global_position) < 9.0:
				r.mind.experience("scrap", -0.4, 1.0, false, riser_name)
		square_up()
	if composure <= 0.0:
		_go_down()

func _go_down() -> void:
	if not alien:
		for r in Meet.risers:
			if r != self and not r.alien and r.global_position.distance_to(global_position) < 24.0:
				r.saw_beating(self)
	if alien:
		Meet.main.alien_down(self)
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
	# Give them room for a few seconds and the heat goes out of it.
	if _vs_player:
		_away = _away + dt if (target - global_position).length() > 9.0 else 0.0
		if _away > 4.0:
			_away = 0.0
			_vs_player = false
			say_aloud(["Yeah. Walk away.", "That's what I thought.", "Keep walking."][randi() % 3], 3.5)
			Meet.say("%s lets you go. Giving people space works." % riser_name)
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
	if dead:
		return
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
	if dead:
		return
	if state in ["flee", "scrap"]:
		idle()
	if is_riser:
		mind.experience("aliens", 0.8, 2.0, true, "the visitors")
		say_aloud(People.AFTER_ALIENS[randi() % People.AFTER_ALIENS.size()], 4.0)

## A visitor: picks someone, runs at them, zaps them. Three good hits and it sits down.
func _alien(dt: float) -> void:
	if state == "winded":
		return
	if not is_instance_valid(_foe) or _foe.dead or randf() < dt * 0.15:
		_foe = null
		_vs_player = randf() < 0.6 and not (Meet.worn["head"] == "antennae" and composure >= 150.0)
		if not _vs_player:
			var pick: Array = Meet.risers.filter(func(r): return r.state != "winded" and not r.dead and not r.post)
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
					Meet.player.slapped(22.0, global_position, self)
				else:
					_foe.knock(to.normalized() * 2.5)
					_foe.zapped(34.0, "the visitors")
		return
	# From a distance they shoot. It hurts less than a zap up close, but it finds you.
	_zap -= dt
	if _vs_player and to.length() > 3.0 and to.length() < 14.0 and _zap <= 0.0:
		_zap = randf_range(2.2, 3.4)
		Meet.sfx("zap", -4.0, randf_range(1.2, 1.5))
		Character.play(_figure, "Spell_Simple_Shoot", true)
		var from := global_position + Vector3(0, 1.0, 0)
		var aim: Vector3 = target + Vector3(0, 1.2, 0)
		Meet.main.bolt(from, aim, func():
			if Meet.player.global_position.distance_to(aim - Vector3(0, 1.2, 0)) < 1.6:
				Meet.player.slapped(9.0, from, self))
	if to.length() > 1.8:
		_goal = target
		state = "walk"
		_walk(dt, 2.7)
		return
	_look(target, 0.3)
	if _strike <= 0.0:
		_wind = 0.6
		Meet.sfx("zap", -5.0, randf_range(0.9, 1.2))
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
	Meet.add_heat(0.8, "caught with a strap")
	say_aloud("That's MY strap. Hand it over.", 4.0)
	Meet.main.stir(global_position, ["Ooh.", "Busted.", "In his BAG?", "Not cool."], 12.0, 0.6, false)
	Meet.say("%s takes the strap back off you. That did not go unnoticed." % riser_name)
	Meet.touch_state()
	if mind.feeling() < -0.45:
		confront()
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
	if dead:
		return
	if state == "winded":
		return
	Wear.dust(_figure, 50.0)
	Fx.burst(Meet.main, global_position + Vector3(0, 1.5, 0), Vector3.UP, false, 10)
	if by != Meet.player:
		say_aloud("%s!" % by.first_name.to_upper(), 2.5)
		Meet.bump(id, by.id, -0.08 if mind.grudge > 0.95 else 0.03)
		return
	Meet.main.defend(self, "chalk")
	Meet.dusted += 1
	Meet.dare("chalk", id)
	if guest or recruited:
		Meet.dare("recruit_chalk")
	if id == "kelvin":
		Meet.errand("tommy", "ready")
	Meet.add_heat(0.4)
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
			# Someone who barely knows you: it lands badly, and the touchy ones come over about it.
			var n: int = _asked.get("chalked", 0)
			_asked["chalked"] = n + 1
			mind.experience("chalk", -0.35 - 0.2 * n, 1.2 + n, true, riser_name)
			gesture("Hit_Chest", 0.6)
			_look(Meet.player.global_position, 1.0)
			if (mind.grudge >= 1.1 or n >= 1) and state != "scrap":
				confront()
			elif randf() < 0.4 and state not in ["pull", "to_table", "prep", "scrap"]:
				say_aloud("Right. Have some back.", 3.0)
				Meet.main.puff(global_position + Vector3(0, 1.4, 0), Meet.player.global_position + Vector3(0, 1.4, 0), func(): Meet.player.dusted(), 0.9)
		_:
			mind.experience("chalk", -0.5, 1.5, true, riser_name)
			gesture("Hit_Chest", 0.6)
			if state != "scrap":
				confront()
	_mood_check = 0.0

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

# --- Standing about talking ---------------------------------------------------------------

## Gather two or three people into a circle for a conversation of their own.
func _start_huddle() -> bool:
	var free := func(r): return r.is_riser and r.state in ["idle", "watch", "sit"] and r != self
	var lines: Array = []
	var members: Array = [self]
	var b := bond()
	if b in ["irritated", "gone"] or (b == "close" and randf() < 0.4):
		var o: Array = Meet.risers.filter(free)
		if o.is_empty():
			return false
		members.append(o[randi() % o.size()])
		lines = People.ABOUT_YOU if b != "close" else People.ABOUT_YOU_GOOD
		var news: Dictionary = mind.gossip()
		if not news.is_empty():
			members[1].mind.hear(news)
	else:
		var pool: Array = People.CONVOS.duplicate()
		pool.shuffle()
		for c in pool:
			var who: Array = c["who"]
			if not who.has(id) and not who.has("any"):
				continue
			var cast: Array = []
			var others: Array = Meet.risers.filter(free)
			others.shuffle()
			var me_placed := false
			var ok := true
			for w in who:
				if w == id:
					cast.append(self)
					me_placed = true
				elif w == "any":
					if not me_placed and not who.has(id):
						cast.append(self)
						me_placed = true
					elif others.is_empty():
						ok = false
					else:
						cast.append(others.pop_back())
				else:
					var named: Node = Meet.riser(w)
					if named == null or not free.call(named):
						ok = false
					else:
						others.erase(named)
						cast.append(named)
			if ok and me_placed:
				members = cast
				lines = c["lines"]
				break
		if lines.is_empty():
			return false
	var at: Vector3 = global_position
	for m in members:
		at += m.global_position
	at = Meet.main.clear(at / (members.size() + 1))
	var convo := {"who": members, "lines": lines, "i": 0, "t": 1.0, "wait": 12.0, "at": at, "lead": self}
	for i in members.size():
		var a := TAU * i / members.size() + randf() * 0.3
		var m: Node3D = members[i]
		m._convo = convo
		m._partner = null
		m._go(at + Vector3(cos(a), 0, sin(a)) * 0.95, "huddle")
		m._convo = convo
	return true

func _huddle(dt: float) -> void:
	if _convo.is_empty():
		idle()
		return
	_look(_convo["at"], 0.12)
	var i: int = _convo["i"]
	var lines: Array = _convo["lines"]
	var who: Array = _convo["who"]
	var talking: bool = i > 0 and i <= lines.size() and who[lines[i - 1][0]] == self
	Character.play(_figure, "Idle_Talking" if talking else "Idle")
	if _convo["lead"] != self:
		return
	# Whoever started it keeps it moving.
	var here := 0
	for m in who:
		if is_instance_valid(m) and m.state == "huddle" and m._convo == _convo:
			here += 1
		elif not is_instance_valid(m) or not (m.state == "walk" and m._convo == _convo):
			_end_huddle()
			return
	_convo["wait"] -= dt
	if here < who.size():
		if _convo["wait"] <= 0.0:
			_end_huddle()
		return
	_convo["t"] -= dt
	if _convo["t"] > 0.0:
		return
	if i >= lines.size():
		_end_huddle()
		return
	who[lines[i][0]].say_aloud(String(lines[i][1]).replace("The new one", Meet.you("The new one").capitalize()), 3.0)
	if i == 0:
		for m in who:
			for o in who:
				if m.id < o.id:
					Meet.bump(m.id, o.id, 0.05)
	_convo["i"] = i + 1
	_convo["t"] = 3.1

func _end_huddle() -> void:
	var c := _convo
	for m in c.get("who", []):
		if is_instance_valid(m) and m._convo == c and m.state in ["huddle", "walk"]:
			m.idle()

# --- What gets said to them ---------------------------------------------------------------

## The first thing out of their mouth on a later visit: the strongest thing they remember.
func memory_line() -> String:
	if Meet.flags.has(id) and not Meet.flags[id].is_empty():
		for k in Meet.flags[id]:
			if k.ends_with("_dig") or k in ["sore", "called_cheat", "weaker_brother", "beard_tug", "snitch"]:
				return People.REMEMBER["insult-"]
	var best := {}
	var score := 0.0
	for m in mind.memories:
		var sc: float = absf(m["valence"]) * float(m.get("weight", 1.0))
		if sc > score and m.get("firsthand", true):
			score = sc
			best = m
	if best.is_empty():
		return ""
	return People.REMEMBER.get("%s%s" % [best["kind"], "+" if best["valence"] > 0.0 else "-"], "")

## The player says something unkind. Most of it bounces off. One thing doesn't.
func insult(key: String) -> String:
	_insulted += 1
	Meet.heckles += 1
	if Meet.heckles >= 5:
		Meet.grant("rubber_chicken")
	Meet.main.defend(self, "insult")
	if People.SORE.get(id, "") == key:
		mind.experience("heckle", -0.95, 2.5, true, riser_name)
		Meet.add_heat(0.7, "going too far")
		Meet.flag(id, "sore")
		for r in Meet.risers:
			if r != self and r.is_riser and r.global_position.distance_to(global_position) < 8.0:
				r.mind.experience("heckle", -0.35, 0.8, false, riser_name)
				r.say_aloud(People.TOO_FAR[randi() % People.TOO_FAR.size()], 3.0)
		var line: String = People.SORE_REPLY[key][randi() % 2]
		Meet.menu.close()
		say_aloud(line, 4.0)
		confront()
		return ""
	mind.experience("heckle", -0.3, 0.8, true, riser_name)
	if passer:
		if _insulted >= 2:
			Meet.menu.close()
			say_aloud("Right. I'm going.")
			bolt(1.6)
			return ""
		return ["Excuse me?", "I'm just walking here.", "Do I know you?"][randi() % 3]
	if _insulted >= 3 or mind.feeling() < -0.45:
		Meet.menu.close()
		confront()
		return ""
	return People.SHRUG[key][randi() % 2]

## The player tries a line on a stranger. Returns [did it work, what they said].
func pitch(key: String) -> Array:
	_pitched += 1
	if keen or def.get("likes", "") == key or mind.feeling() + randf() * 0.4 > 0.6:
		guest_ready = true
		return [true, People.PITCH_YES[key]]
	mind.experience("nagged", -0.15, 0.5)
	if _pitched >= 3:
		Meet.menu.close()
		say_aloud("I said no. Goodnight.")
		bolt(1.5)
		return [false, ""]
	return [false, People.PITCH_NO[randi() % People.PITCH_NO.size()]]

## A passer-by who has had a pull stays on as one of the crowd.
func join_meet() -> void:
	passer = false
	guest = true
	guest_ready = false
	if id.begins_with("p_") and not Meet.joined.has(id):
		Meet.joined.append(id)
		Meet.ripple("%s joined the club because of you." % riser_name)
	life = {"pull": 1.2, "eat": 0.7, "talk": 0.3, "rest": 0.4, "quirk": 0.0}
	wants_pull = true
	state = "idle"
	_timer = 3.0

func after_pull(player_won: bool) -> void:
	pull_angry = false
	if id == "kaiju":
		Meet.main.evening.kaiju_result(player_won)
		return
	if legend != "":
		Meet.main.evening.legend_result(self, player_won)
	if bracket != "":
		bracket = ""
		Meet.main.evening.bracket_result(self, player_won)
	if settle:
		settle = false
		for m in mind.memories:
			if m["valence"] < 0.0:
				m["weight"] *= 0.35
		mind.experience("match", 0.4, 1.5, true, "settling it")
		say_aloud("Fine. You earned that. We're square." if player_won else "That's that, then. We're square.", 4.5)
		Meet.say("Settled at the table. %s lets it go." % riser_name)
	if stake > 0:
		if player_won:
			Meet.pay(stake, "%s pays up." % first_name)
			say_aloud(["Take it. Don't spend it all on snacks.", "Fair's fair.", "Double or nothing next time."][randi() % 3], 4.0)
		else:
			Meet.pay(-stake, "You pay %s." % first_name)
			say_aloud(["Pleasure doing business.", "That's dinner sorted.", "Any time."][randi() % 3], 4.0)
		stake = 0
	if not bet:
		return
	bet = false
	if player_won:
		Meet.snacks += 1
		mind.experience("match", 0.3, 0.8)
		say_aloud("A bet's a bet. Here. Don't gloat.", 4.0)
		Meet.say("%s hands over a snack." % first_name)
	else:
		Meet.snacks = max(0, Meet.snacks - 1)
		say_aloud("That's my snack, I believe.", 4.0)
		Meet.say("%s takes a snack off you. A bet's a bet." % first_name)

# --- Each other ---------------------------------------------------------------------------

## Their closest friend among the founders, and how close.
func best_mate() -> Array:
	var best: Node = null
	var v := -2.0
	for r in Meet.risers:
		if r != self and r.is_riser and Meet.tie(id, r.id) > v:
			v = Meet.tie(id, r.id)
			best = r
	return [best, v]

## Something worth looking at is happening over there.
func gawp(at: Vector3, line: String, gather: bool) -> void:
	if dead:
		return
	if state == "walk" and _then in ["answer", "bench", "prank", "coach", "callout", "chat", "huddle", "swarm"]:
		say_aloud(line, 2.5)
		return
	if state in ["pull", "to_table", "prep", "scrap", "winded", "flee", "search", "pass"] and not (state == "pass" and gather):
		if state == "pull":
			say_aloud(line, 2.5)
		return
	say_aloud(line, 3.0)
	_face_at = at
	if gather and global_position.distance_to(at) > 4.5 and not passer:
		var to := (global_position - at).normalized()
		_go(at + to * randf_range(3.2, 4.2), "gawk")
		_timer = 0.0
	else:
		state = "watch"
		_timer = randf_range(5.0, 9.0)

## A friend is being picked on. Step in, with words or with more than words.
func stand_up_for(victim: Node, kind: String, closeness: float) -> void:
	if dead:
		return
	mind.experience("scrap" if kind == "punch" else "heckle", -0.45, 1.2, false, victim.riser_name)
	Meet.bump(id, victim.id, 0.08)
	var lines := {"punch": ["Hey! Hands off %s!", "You touch %s, you deal with me."], "chalk": ["Oi. Leave %s alone.", "Pick on someone else. Not %s."], "insult": ["Don't talk to %s like that.", "Say that about %s again."]}
	say_aloud(lines[kind][randi() % 2] % victim.first_name, 4.5)
	if kind == "punch" and (closeness > 0.55 or mind.feeling() < -0.3 or randf() < 0.3 + closeness * 0.5):
		say_aloud("Right. You've got two of us now.", 4.0)
		square_up(true)
	else:
		_face_at = Meet.player.global_position
		var to: Vector3 = (victim.global_position - Meet.player.global_position).normalized()
		_go(victim.global_position + to.rotated(Vector3.UP, 0.9) * 1.1, "gawk")

# --- How they feel about you, said out loud -------------------------------------------------

## -3 hates, -2 dislikes, -1 annoyed, 0 neutral, 1 likes, 2 close.
func mood_level() -> int:
	var f: float = mind.feeling()
	if f < -0.65:
		return -3
	if f < -0.4:
		return -2
	if f < -0.15:
		return -1
	if f > 0.6:
		return 2
	if f > 0.3:
		return 1
	return 0

## The separate things they keep track of about you, each -1..1, from everything remembered.
func axes() -> Dictionary:
	var a := {"trust": 0.0, "respect": 0.0, "fun": 0.0, "irritation": 0.0, "wary": 0.0, "warmth": 0.0}
	for m in mind.memories:
		var v: float = float(m["valence"]) * float(m.get("weight", 1.0)) * (1.0 if m.get("firsthand", true) else 0.5)
		match m["kind"]:
			"theft": a["trust"] += v * 1.2
			"helped":
				a["trust"] += v
				a["respect"] += v * 0.3
			"gift":
				a["trust"] += v * 0.4
				a["warmth"] += v * 0.8
			"match": a["respect"] += v * 1.3
			"chalk":
				a["fun"] += max(v, 0.0) * 1.5
				a["irritation"] -= min(v, 0.0) * 1.2
			"photo":
				a["fun"] += v * 0.6
				a["warmth"] += v * 0.6
			"talk":
				a["warmth"] += v * 0.8
				a["fun"] += max(v, 0.0) * 0.3
			"heckle", "nagged": a["irritation"] -= v * 1.1
			"violence", "scrap":
				a["wary"] -= v * 0.9
				a["trust"] += v * 0.3
			"aliens": a["respect"] += v * 0.4
	if Meet.beaten.has(id):
		a["respect"] += 0.5
	if _asked.has("dance") or _asked.has("joke"):
		a["fun"] += 0.3
	for k in a:
		a[k] = tanh(a[k] * 0.55)
	return a

## Which of the attitudes in People.ATTITUDES fits them right now.
func attitude_key() -> String:
	var a := axes()
	var lvl := mood_level()
	if lvl <= -3:
		return "afraid" if a["wary"] > 0.5 else "done"
	if a["wary"] > 0.5 and lvl < 0:
		return "afraid"
	if a["trust"] < -0.35:
		return "arm_not_bag" if a["respect"] > 0.3 else "no_trust"
	if a["irritation"] > 0.45:
		if a["fun"] > 0.3:
			return "funny_pest"
		return "hurt" if a["warmth"] > 0.35 else "mouth"
	if a["wary"] > 0.35:
		return "wary"
	if lvl < 0:
		return "cold"
	if a["respect"] > 0.45:
		return "rates_likes" if a["warmth"] > 0.35 or lvl >= 1 else "respects"
	if a["fun"] > 0.45:
		return "laugh" if a["warmth"] > 0.3 or lvl >= 1 else "amused"
	if a["trust"] > 0.45:
		return "trusts" if a["warmth"] > 0.3 else "owes"
	if a["warmth"] > 0.4 or lvl >= 1:
		return "warming"
	return "sussing" if mind.familiarity < 0.5 else "neutral"

func attitude() -> String:
	return People.ATTITUDES[attitude_key()][0]

func attitude_line() -> String:
	var l: Array = People.ATTITUDES[attitude_key()][1]
	return l[randi() % l.size()]

func mood_word() -> String:
	if is_riser or guest:
		var k := attitude_key()
		return "" if k in ["neutral", "sussing"] else attitude()
	return {-3: "hates you", -2: "dislikes you", -1: "annoyed with you", 0: "", 1: "likes you", 2: "close mate"}[mood_level()]

func _show_mood() -> void:
	if _name_label == null:
		return
	var w := mood_word()
	_name_label.text = riser_name if w == "" else "%s\n(%s)" % [riser_name, w]
	_name_label.modulate = {-3: Color(1.0, 0.25, 0.2), -2: Color(1.0, 0.45, 0.25), -1: Color(1.0, 0.7, 0.35), 0: Color(1, 0.95, 0.8) if is_riser else Color(0.8, 0.8, 0.82), 1: Color(0.7, 1.0, 0.7), 2: Color(0.5, 1.0, 0.6)}[mood_level()]

func _mood_changed() -> void:
	var now := mood_level()
	var key := attitude_key()
	if key != _att:
		# How they have you figured has shifted, even if how much they like you hasn't.
		var first := _att == ""
		_att = key
		_show_mood()
		if not first and now == _level and key not in ["neutral", "sussing"] and not (Meet.modal and Meet.menu.who != self):
			Meet.say("%s now %s." % [riser_name, attitude()])
	if now == _level:
		return
	var was := _level
	_level = now
	_show_mood()
	if Meet.modal and Meet.menu.who != self:
		return
	if now < was:
		match now:
			-1: Meet.say("%s is getting annoyed with you." % riser_name)
			-2: Meet.say("%s dislikes you now." % riser_name)
			-3: Meet.say("%s hates you. That will take real work to undo." % riser_name)
		if now < 0 and not Meet.told_peace:
			Meet.told_peace = true
			Meet.say("To make it right: talk to them and apologise, bring a snack as a peace offering, or just give them space.")
	else:
		match now:
			0: Meet.say("%s has cooled down." % riser_name) if was < 0 else null
			-1: Meet.say("%s still isn't happy, but it's better than it was." % riser_name)
			-2: Meet.say("%s no longer hates you. Only dislikes." % riser_name)
			1:
				Meet.say("%s has warmed to you." % riser_name)
				Meet.dare("like", id)
			2: Meet.say("%s counts you a close mate." % riser_name)

# --- Making it right ---------------------------------------------------------------------------

## Say sorry. Words work on an annoyance; anything worse wants a peace offering as well.
func apologise(with_snack: bool) -> String:
	var lvl := mood_level()
	sulking = false
	Meet.add_heat(-0.7)
	if _apologised and not with_snack:
		return "You already said sorry. Show me."
	_apologised = true
	var ease := func(k: float):
		for m in mind.memories:
			if m["valence"] < 0.0:
				m["weight"] *= k
	if with_snack:
		if lvl <= -3:
			ease.call(0.4)
			mind.experience("helped", 0.5, 2.5, true, "the apology")
			return "...Fine. You're on probation. One more and we're done."
		mind.forgive()
		if Meet.flags.has(id):
			Meet.flags[id].erase("sore")
		return ["Alright. We're good. Don't make it weird.", "Apology accepted. Snack accepted more.", "Okay. Clean slate."][randi() % 3]
	match lvl:
		-1:
			ease.call(0.35)
			mind.experience("helped", 0.45, 1.5, true, "the apology")
			return ["Alright. Forget it.", "Yeah, okay. It's fine.", "Thanks for saying it."][randi() % 3]
		-2:
			ease.call(0.7)
			mind.experience("helped", 0.25, 1.0, true, "the apology")
			return "Words are cheap. But okay. It's a start."
		_:
			return "Save it. I don't want to hear it."

## Hands up in the middle of a scrap.
func back_down() -> void:
	if _backed:
		say_aloud("Too late for sorry.", 2.5)
		return
	_backed = true
	_vs_player = false
	for m in mind.memories:
		if m["valence"] < 0.0:
			m["weight"] *= 0.7
	mind.experience("helped", 0.25, 0.8, true, "backing down")
	say_aloud(["...Don't do it again.", "Fine. FINE. Walk it off.", "That's the only one you get."][randi() % 3], 4.0)
	Meet.say("You put your hands up. %s lets it go, this once." % riser_name)
	Meet.main.stir(global_position, ["Good. Leave it.", "That's better.", "Shake hands, you two."], 10.0, 0.4, false)
	idle()

# --- Being watched ---------------------------------------------------------------------------

## Stop and look at the player for a while.
func stare(seconds: float, line := "") -> void:
	if dead:
		return
	_stare = max(_stare, seconds)
	if line != "":
		say_aloud(line, min(seconds, 4.0))

## They watched the player put someone on the floor.
func saw_beating(victim: Node) -> void:
	if dead:
		return
	if passer:
		say_aloud("I'm calling someone.", 3.0)
		bolt(2.0)
		return
	if state == "winded":
		return
	var close: float = Meet.tie(id, victim.id) if is_riser and victim.is_riser else 0.1
	mind.experience("violence", -0.55 - 0.35 * max(close, 0.0), 2.2 + close, true, victim.riser_name)
	_mood_check = 0.0
	stare(6.0, ["What is WRONG with you?", "That's one of ours.", "Get out.", "Are you serious?", "Somebody get Harry.", "..."][randi() % 6])

# --- Talking someone into a pull they don't want ------------------------------------------------

## Why they would say no right now, or "" if they would pull.
func reluctance() -> String:
	if tonight.get("id", "") == "sore":
		return "Elbow's gone. Ask me next week."
	if Meet.stars() >= 3:
		return "Not while you're carrying on like this. Calm down first."
	if sulking:
		return "After what you said to me? No."
	if mood_level() <= -2:
		return "Not with you. Not tonight."
	if mood_level() == -1:
		return "I'm not in the mood for you right now."
	return ""

## kind: goad | money | nice. Returns [worked, what they said].
func talk_into(kind: String) -> Array:
	_goaded += 1
	var proud: bool = mind.grudge >= 1.0 or strength >= 80.0
	match kind:
		"goad":
			mind.experience("heckle", -0.25, 0.8, true, riser_name)
			if proud or _goaded >= 3:
				pull_angry = true
				if tonight.get("id", "") == "sore":
					strength -= 8.0
				return [true, ["Scared? SCARED? Sit down.", "Right. Hand on the pad. Now.", "You'll regret asking."][randi() % 3]]
			return [false, ["That doesn't work on me.", "Nice try.", "I'm not twelve."][randi() % 3]]
		"money":
			if Meet.money < 10:
				return [false, "With what? You're skint."]
			stake = 10
			return [true, ["Ten dollars? ...Fine. Easy money.", "Now you're talking.", "Go on, then. Cash on the table."][randi() % 3]]
		_:
			if not proud and mood_level() >= -1:
				mind.experience("talk", 0.15, 0.4)
				return [true, ["...One. Then you leave me be.", "Alright. Since you asked properly.", "Go on. Quick one."][randi() % 3]]
			return [false, ["No.", "Asking nicely doesn't change it.", "Still no."][randi() % 3]]

# --- Their wallet ------------------------------------------------------------------------------

func _wallet_missed() -> void:
	var taken := wallet_taken
	wallet_taken = 0
	Meet.main.drop_match(self)
	var witness := false
	for r in Meet.risers:
		if r.saw_theft.has(id + "$"):
			witness = true
	if witness:
		Meet.pay(-min(taken, Meet.money))
		mind.experience("theft", -0.85, 2.5, true, "my wallet")
		Meet.add_heat(1.5, "caught thieving")
		say_aloud("My wallet's light, and I know EXACTLY who was in my bag.", 5.0)
		Meet.say("%s marches over and takes the money back out of your pocket." % riser_name)
		Meet.main.stir(global_position, ["From his WALLET?", "That's low.", "Not cool. Not cool at all."], 14.0, 0.7, false)
		square_up()
	else:
		mind.experience("theft", -0.3, 0.9, false, "my wallet")
		say_aloud("Hang on. I had a twenty in here.", 4.0)
		Meet.main.stir(global_position, ["Not me.", "Check your pockets.", "There's a thief at the meet?"], 10.0, 0.5, false)
		idle()

# --- Having it out ------------------------------------------------------------------------------

## They have had enough: they come over and make you talk about it.
func confront(kind := "beef", text := "") -> void:
	if dead:
		return
	if alien or state in ["winded", "scrap", "confront"]:
		return
	if passer:
		bolt(1.6)
		return
	if Meet.main.invaded():
		# Not while there are aliens on the plaza. It keeps.
		say_aloud("We are NOT done. After this.", 3.0)
		return
	Meet.main.drop_match(self)
	confront_kind = kind
	confront_text = text
	_chase = 0.0
	_stare = 0.0
	Meet.sfx("sting", -6.0, 1.2, 1.0)
	state = "confront"
	say_aloud(["Oi. You. A word.", "Hey. We need to talk.", "Come here. Now."][randi() % 3], 3.0)

# --- Being handed the clipboard -------------------------------------------------------------------

const _WORDS := {
	"insult": ["stupid", "idiot", "weak", "loser", "ugly", "suck", "trash", "hate", "dumb", "fat", "useless", "clown", "rubbish", "pathetic", "smell", "stink"],
	"praise": ["strong", "best", "great", "legend", "respect", "champion", "champ", "goat", "amazing", "hero", "thank", "awesome", "beast", "king"],
	"sorry": ["sorry", "apolog", "my bad", "forgive"],
	"pull": ["pull", "table", "challenge", "1v1", "rematch", "arm wrestle", "armwrestle", "versus", " vs"],
	"love": ["love", "date", "cute", "number", "marry", "kiss", "handsome", "dinner"],
	"sign": ["sign", "join", "member", "petition", "88", "name here", "register", "roster"],
	"money": ["$", "dollar", "money", "pay", "owe", "cash", "bucks", "iou"],
	"snack": ["snack", "food", "hungry", "eat", "chips", "pizza"],
}

## They read whatever you wrote on the clipboard and take it how it reads.
func read_clipboard(text: String) -> String:
	var t := text.to_lower().strip_edges()
	if t == "":
		return "It's blank. You've handed me a blank clipboard."
	var found: Array = []
	for k in _WORDS:
		for w in _WORDS[k]:
			if t.contains(w):
				found.append(k)
				break
	var other := ""
	for r in Meet.risers:
		if r.is_riser and r != self and t.contains(r.first_name.to_lower()):
			other = r.id
	var quote := "\"%s.\" " % text.strip_edges().left(60)
	if other != "" and found.has("insult"):
		Meet.said.append({"by": id, "about": other, "tone": "bad"})
		Meet.bump(id, other, -0.05)
		mind.experience("talk", 0.15, 0.5)
		return quote + "Ha! About %s? I'm not signing that. ...I'm not NOT signing it." % Meet.riser(other).first_name
	if other != "" and found.has("praise"):
		Meet.bump(id, other, 0.08)
		return quote + "That's nice. You should show %s that. I'll initial it." % Meet.riser(other).first_name
	if found.has("insult"):
		mind.experience("heckle", -0.5, 1.4, true, riser_name)
		if mind.feeling() < -0.4:
			Meet.menu.close()
			confront()
			return ""
		return quote + "You wrote that down. You took the time to write that down."
	if found.has("sorry"):
		return quote + apologise(false)
	if found.has("pull"):
		calling = 30.0
		wants_pull = true
		return quote + "A written challenge. Formal. I accept. Find me at the table."
	if found.has("love"):
		mind.experience("talk", 0.1 if mind.warmth > 0.2 else -0.15, 0.6)
		return quote + ("...I'm flattered. I'm keeping this." if mind.warmth > 0.2 else "I'm going to pretend I didn't read that.")
	if found.has("money"):
		return quote + ("I don't owe you anything. Do I? ...Do I?" if Meet.money > 20 else "If this is an invoice, send it to George.")
	if found.has("snack"):
		mind.experience("talk", 0.15, 0.4)
		return quote + "A snack order form. Finally, some organisation. Put me down for two red."
	if found.has("praise"):
		mind.experience("talk", 0.35, 0.9)
		return quote + ["Well. That's going on my fridge.", "You wrote that about me? Cheers.", "I'll take it. In writing, too."][randi() % 3]
	if found.has("sign"):
		mind.experience("talk", 0.2, 0.5)
		return quote + "Where do I sign? There. That's my good signature, too."
	mind.experience("talk", 0.05, 0.3)
	return quote + ["...Okay? What do you want me to do with this?", "I've read it twice. I still don't know.", "Is this a quiz?", "Noted. I think."][randi() % 4]

## A one-off movement of their own: a high five, a dance.
func gesture(anim: String, seconds: float) -> void:
	if dead:
		return
	_act_anim = anim
	_act_t = seconds
	Character.play(_figure, anim, true)

# --- More trouble ---------------------------------------------------------------------------------

## Their strap has turned up in somebody else's bag.
func _strap_planted() -> void:
	var where: String = Meet.planted[id]
	Meet.planted.erase(id)
	Meet.main.drop_match(self)
	Meet.main.strap_back(id)
	var other: Node = Meet.riser(where)
	say_aloud("My strap's gone. ...Hang on. It's in %s's bag!" % other.first_name, 5.0)
	var witness: Node = null
	for r in Meet.risers:
		if r.saw_theft.has(id) and r != self:
			witness = r
	if witness != null:
		witness.say_aloud("It wasn't %s. I watched who did it." % other.first_name, 5.0)
		mind.experience("theft", -0.6, 1.8, true, "my strap")
		other.mind.experience("theft", -0.5, 1.5, false, "being set up")
		Meet.add_heat(1.0, "caught planting a strap")
		confront()
		return
	other.say_aloud("I never touched it! Why would I want YOUR strap?", 5.0)
	Meet.bump(id, where, -0.3)
	Meet.dare("feud")
	Meet.ripple("%s and %s fell out over a strap you planted." % [first_name, other.first_name])
	Meet.main.stir(global_position, ["Ooh.", "In his BAG?", "Awkward.", "I'm staying out of this."], 12.0, 0.6, true)
	Meet.say("%s and %s are having words about a strap. Nobody is looking at you." % [riser_name, other.riser_name])
	idle()

func _run_dog(dt: float) -> void:
	_dog_free -= dt
	var d := _dog_node
	var to := _dog_goal - d.global_position
	to.y = 0
	if to.length() < 0.6:
		var a := randf() * TAU
		_dog_goal = Meet.main.clear(Vector3(cos(a) * randf_range(2, 8), 0, sin(a) * randf_range(2, 8) + 3.0))
		if randf() < 0.5:
			_dog_goal = Meet.main.SNACKS + Vector3(randf_range(-1, 1), 0, 1.3)
	else:
		d.global_position += to.normalized() * 5.5 * dt
		d.global_position.y = absf(sin(_dog_free * 14.0)) * 0.12
		d.rotation.y = atan2(to.x, to.z)
	Meet.sfx("bark", -8.0, randf_range(1.0, 1.4), 1.6)
	if not _dog_ate and d.global_position.distance_to(Meet.main.SNACKS) < 1.8:
		_dog_ate = true
		Meet.say("The dog has found the snack table. The dog is having the best night of its life.")
		var kelvin: Node = Meet.riser("kelvin")
		if kelvin:
			kelvin.say_aloud("NOT THE RED ONES!", 4.0)
	# The owner, in pursuit.
	_goal = d.global_position
	var od := _goal - global_position
	od.y = 0
	if od.length() > 1.0:
		global_position = Meet.main.clear(global_position + od.normalized() * 3.2 * dt)
		_look(_goal, 0.2)
		Character.play(_figure, "Jog_Fwd")
	if _dog_free <= 0.0 or (od.length() < 1.0 and _dog_free < 14.0):
		_dog_free = 0.0
		d.reparent(self)
		d.position = Vector3(0.75, 0, 0.5)
		d.rotation = Vector3.ZERO
		_lead.visible = true
		say_aloud("Got you. Bad. BAD. ...Who unclipped this?", 5.0)
		mind.experience("nagged", -0.4, 1.0)
		state = "pass"

## The traffic cone, placed on their head by the player.
func cone_on() -> String:
	if coned:
		return "I'm already wearing it. Apparently."
	coned = true
	Meet.cone_with = id
	Wear.hold(_figure, Wear.model("cone"), "Head", "Cone")
	Meet.dare("cone")
	Meet.main.stir(global_position, ["HA!", "Leave it on!", "Suits you.", "Somebody get a photo."], 10.0, 0.7, false)
	Meet.sfx("laugh", -6.0)
	var lvl := mood_level()
	if lvl >= 1:
		mind.experience("talk", 0.2, 0.6)
		return "...Is it straight? I'm keeping it on. I'm the cone now."
	if lvl == 0:
		mind.experience("nagged", -0.15, 0.6)
		Meet.add_heat(0.3)
		return "Very funny. Very mature."
	mind.experience("heckle", -0.5, 1.4, true, riser_name)
	Meet.add_heat(0.6)
	Meet.menu.close()
	confront()
	return ""

## The player wants the cone back.
func cone_off() -> String:
	coned = false
	Meet.cone_with = ""
	Wear.drop(_figure, "Cone")
	Meet.touch_state()
	if mood_level() >= 1:
		return "Aw. I was getting used to it. Here."
	if mood_level() == 0:
		return "Take it. Please. Take it."
	return "Get it off me and get away from me."

## Something silly done at them with an item: they take it as a joke or they don't.
func pranked(kind: String, amused: Array, annoyed: Array) -> void:
	if alien or state == "winded":
		return
	Meet.dare("item")
	var n: int = _asked.get("prank", 0)
	_asked["prank"] = n + 1
	var likes: bool = (mood_level() >= 1 or mind.chatty > 0.6 or People.HUMOUR.get(id, "") in ["pun", "dad"] or passer) and n < 2 and mood_level() > -2
	_look(Meet.player.global_position, 1.0)
	if likes:
		mind.experience("chalk", 0.25, 0.5, true, "messing about")
		say_aloud(amused[randi() % amused.size()], 3.5)
		Meet.sfx("laugh", -8.0, randf_range(0.9, 1.2), 1.5)
		gesture("Hit_Chest", 0.5)
	else:
		mind.experience("nagged", -0.25, 0.7, true, riser_name)
		say_aloud(annoyed[randi() % annoyed.size()] if n < 3 else "RIGHT. That's enough.", 3.5)
		Meet.add_heat(0.15)
		if n >= 3 or mind.feeling() < -0.45:
			if passer:
				bolt(1.6)
			else:
				confront()

## Come and sit beside the player for a talk.
func join_on_seat(at: Vector3) -> void:
	_convo = {}
	_partner = null
	_go(at, "bench")

## Go straight to a point, on a bike or on foot after one. True on arrival.
func ride_to(to: Vector3, pace: float, dt: float) -> bool:
	var d := to - global_position
	d.y = 0
	if d.length() < 0.9:
		Character.play(_figure, "Idle")
		return true
	global_position = Meet.main.ground(global_position + d.normalized() * pace * dt)
	_look(global_position + d, 0.2)
	_figure.position.y = 0.3 if riding else 0.0
	Character.play(_figure, "Driving" if riding else "Jog_Fwd")
	return false

## Hit by a bicycle going too fast.
func bowled(dir: Vector3) -> void:
	if dead:
		return
	if state == "winded":
		return
	Meet.sfx("punch", 0.0, 0.8)
	Meet.dare("bowl")
	Fx.burst(Meet.main, global_position + Vector3(0, 1.0, 0), Vector3.UP, false, 10)
	if alien:
		take_hit(60, global_position - dir)
		return
	Meet.main.drop_match(self)
	_knock += dir.normalized() * 3.0
	say_aloud(["OOF!", "MY LEG!", "WATCH IT!", "Aaagh!"][randi() % 4], 3.0)
	mind.experience("violence", -0.5, 1.6, true, riser_name)
	_mood_check = 0.0
	Meet.add_heat(0.8, "mowing people down")
	Meet.main.stir(global_position, ["They just ran %s over!" % first_name, "On a BIKE?", "Somebody stop them!", "Ohhh!"], 14.0, 0.7, false)
	_vs_player = false
	state = "winded"
	_timer = 5.0
	Character.play(_figure, "Death01" if passer else "Crouch_Idle", true)
	if is_riser:
		Meet.main.defend(self, "punch")

# --- What you're wearing changes how they take you ---------------------------------------------------

func _costume() -> bool:
	var head: String = Meet.worn["head"]
	var body: String = Meet.worn["body"]
	var p: Vector3 = Meet.player.global_position
	if body == "ghost" and not _asked.has("ghost"):
		_asked["ghost"] = true
		_look(p, 1.0)
		if mind.grudge < 1.0 or Meet.dark > 0.0 or Meet.clock > 600.0:
			say_aloud(["AAAH! ...Oh. It's you. Don't DO that.", "GHOST! GHOST! ...It's a bedsheet.", "NOPE."][randi() % 3], 4.0)
			gesture("Hit_Chest", 0.6)
			_knock += (global_position - p).normalized() * 2.5
			Meet.sfx("ooh", -6.0, 1.3)
			Meet.dare("item")
		else:
			say_aloud("It's a sheet with holes in. I can see your shoes.", 4.0)
		return true
	if head == "cone" and not _asked.has("cone_seen"):
		_asked["cone_seen"] = true
		say_aloud(["Has anyone seen %s? There's just this cone." % Meet.you("the new one"), "Who left a cone here? ...It's breathing.", "Evening, cone."][randi() % 3], 4.5)
		return true
	if head == "lion_mask" and not _asked.has("lion") and randf() < 0.6:
		_asked["lion"] = true
		_look(p, 1.0)
		gesture("Crouch_Idle", 1.6)
		say_aloud(["The lion walks among us. *bows*", "All rise for the lion. Or, kneel. One of those.", "Your Majesty."][randi() % 3], 4.0)
		return true
	if head == "possum_hat" and not _asked.has("possum"):
		_asked["possum"] = true
		say_aloud(["There is a POSSUM on your HEAD.", "Don't move. Don't. Move. It's looking at me.", "Is it... asleep? Can I pat it?"][randi() % 3], 4.5)
		return true
	if head == "antennae" and passer and not _asked.has("ant"):
		_asked["ant"] = true
		say_aloud("ONE OF THEM IS STILL HERE!", 3.5)
		bolt(2.2)
		return true
	return false

# --- Being shouted at, and being hit with a snack ----------------------------------------------------

## The player has bellowed something at the whole plaza. Each person takes it their own way.
func shouted(kind: String, i: int) -> void:
	if dead:
		return
	if alien or state in ["winded", "scrap", "confront", "search", "ride"] or (state == "pull" and kind != "tables"):
		return
	Meet.main.drop_match(self) if kind == "tables" else null
	var keen: bool = mood_level() >= 1 or mind.chatty > 0.6 or passer or guest
	match kind:
		"dance":
			if keen:
				gesture("Dance", 5.0)
				if i < 3:
					say_aloud(["Oh, we're DANCING!", "This is my song!", "Go on then!"][i % 3], 3.0)
			elif i < 3:
				say_aloud(["I don't dance.", "No.", "Who is shouting?"][i % 3], 3.0)
		"snacks":
			# Every last one of them goes to the gate. There are no snacks at the gate.
			_convo = {}
			_partner = null
			_shout_then = 0.0
			_go(Vector3(randf_range(-3.5, 3.5), 0, randf_range(21.0, 23.5)), "fooled")
			_pace_boost = 2.3 if id == "kelvin" else 1.7
			if id == "kelvin":
				say_aloud("FREE SNACKS?! MOVE. MOVE!", 3.5)
			elif i < 3:
				say_aloud(["At the gate? Go go go.", "Free?!", "Save me one!"][i % 3], 3.0)
		"tables":
			idle()
			say_aloud("I said NO SUCH THING!" if id == "harry" else ["Already? It's not seven.", "Harry said that?", "But I'm mid-pull!", "Fine by me."][i % 4], 4.0)
		"hug":
			if keen:
				_go(Meet.player.global_position + Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 1.1, "hug")
				if i < 3:
					say_aloud(["Bring it in!", "Aww. Fine.", "Group hug!"][i % 3], 3.0)
			elif i < 4:
				say_aloud(["No.", "I'm good over here.", "We're not that kind of club.", "..."][i % 4], 3.0)
		"spider":
			if id == "phillip":
				say_aloud("It's a leaf.", 4.0)
			elif id == "luie":
				say_aloud("...Where? I like spiders.", 4.0)
			else:
				gesture("Hit_Chest", 0.5)
				_knock += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 4.0
				if i < 5:
					say_aloud(["WHERE?!", "GET IT OFF ME!", "Is it on me? IS IT ON ME?", "AAAH!", "I'm not good with spiders!"][i % 5], 3.0)
		"race":
			_convo = {}
			_partner = null
			_go(Vector3(randf_range(-12, 12), 0, 26.4), "raced")
			_pace_boost = 1.3 + (strength - 60.0) / 40.0 + randf() * 0.5
			if i < 3:
				say_aloud(["I'm not a novice!", "You're on!", "GO GO GO"][i % 3], 2.5)

## A snack, thrown at them.
func splatted(by: Node) -> void:
	if dead:
		return
	if alien or state == "winded":
		return
	Fx.tint(_figure, Color(0.95, 0.75, 0.2, 0.55), 12.0)
	Fx.burst(Meet.main, global_position + Vector3(0, 1.5, 0), Vector3.UP, false, 8)
	Meet.sfx("crunch", -2.0, 0.8)
	if by != Meet.player:
		if not Meet.main.food_fight():
			say_aloud(["Oi!", "Who threw that?!", "Right in the ear!"][randi() % 3], 2.0)
		return
	var n: int = _asked.get("splat", 0)
	_asked["splat"] = n + 1
	var fun: bool = (mood_level() >= 1 or mind.chatty > 0.6 or id == "kelvin") and n < 2
	if id == "kelvin":
		say_aloud("You THREW it? At ME? ...Waste of a red one. *eats it off his shirt*", 4.5)
		mind.experience("gift", 0.1, 0.4)
	elif fun:
		say_aloud(["FOOD FIGHT!", "Oh, it's ON.", "You'll pay for that!"][randi() % 3], 3.0)
		mind.experience("chalk", 0.2, 0.5)
		throw_at(Meet.player)
	else:
		say_aloud(["This is a clean shirt!", "Did you just throw FOOD at me?", "Unbelievable."][randi() % 3], 3.5)
		mind.experience("nagged", -0.3, 0.9, true, riser_name)
		Meet.add_heat(0.3)
		if passer:
			bolt(1.6)

## Lob something at someone.
func throw_at(target: Node) -> void:
	gesture("Punch_Jab", 0.5)
	var from := global_position + Vector3(0, 1.5, 0)
	var tgt := target
	Meet.main.lob(from, tgt.global_position + Vector3(0, 1.4, 0), [Color(0.9, 0.3, 0.2), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.9)][randi() % 3], func():
		if not is_instance_valid(tgt):
			return
		if tgt == Meet.player:
			tgt.splatted()
		else:
			tgt.splatted(self))

## One of the player's stone lions has come over to have a look at them.
func pet_visit() -> void:
	if dead:
		return
	if state in ["pull", "winded", "scrap", "confront"]:
		return
	_look(Meet.player.global_position, 0.5)
	var lines: Array = {
		"harry": ["That is council property and it is sniffing my shoe.", "...Good boy. Don't tell anyone I said that."],
		"george": ["Hold still. HOLD STILL. This is the best content we've ever had.", "Does it want to be in the photo?"],
		"phillip": ["...", "...It's heavy. Good."],
		"bhavya": ["Its posture is excellent. Look at that spine.", "It likes the beard. Everything likes the beard."],
		"kelvin": ["Does it eat snacks? It's looking at my snacks.", "You can have a yellow one. Not a red."],
		"tommy": ["CAN I RIDE IT.", "I'm naming this one Chalky."],
		"luie": ["...Hello.", "It sat on my foot. I'm staying here now."],
		"erick": ["I could beat it.", "It's got a good grip. Look at those paws."],
	}.get(id, ["Is that... is that the statue?", "It's STONE. It's WALKING.", "Nice... cat?", "Does it bite? It looks like it bites."])
	say_aloud(lines[randi() % lines.size()], 4.5)
	if passer and randf() < 0.4:
		bolt(1.8)
	elif mind.chatty > 0.5 or id in ["kelvin", "luie", "tommy"]:
		gesture("Fixing_Kneeling", 1.6)
		if not _asked.has("lionpet"):
			_asked["lionpet"] = true
			mind.experience("talk", 0.25, 0.7, true, "the lion")

## George's camera, in his hands whenever he is filming.
func camera() -> void:
	var c := Node3D.new()
	Build.box(c, Vector3(0.16, 0.11, 0.08), Vector3(0, 0.08, 0.04), Color(0.08, 0.08, 0.1))
	Build.cyl(c, 0.04, 0.045, 0.09, Vector3(0, 0.08, 0.12), Color(0.15, 0.15, 0.18), 10).rotation.x = PI / 2.0
	Build.sphere(c, 0.03, Vector3(0, 0.08, 0.17), Color(0.4, 0.6, 1.0), 0.8)
	Build.sphere(c, 0.012, Vector3(0.05, 0.15, 0.04), Color(1.0, 0.1, 0.1), 2.5)
	Wear.hold(_figure, c)

## Carrying a light for a while.
func glow(seconds: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.6)
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position = Vector3(0, 1.4, 0)
	add_child(l)
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(l):
			l.queue_free())

# --- What a conversation sets in motion ----------------------------------------------------------------

## Something the player said has landed, well or badly. They act on it, and it travels.
## Returns a line describing what is about to happen, for the conversation to show.
func react(v: float) -> String:
	if not (is_riser or guest) or absf(v) < 0.2:
		return ""
	var mate_pair: Array = best_mate() if is_riser else [null, 0.0]
	var mate: Node = mate_pair[0]
	# Anyone standing close enough heard it.
	for r in Meet.risers:
		if r != self and (r.is_riser or r.guest) and r.global_position.distance_to(global_position) < 5.0 and r.state not in ["pull", "winded"]:
			r.mind.experience("talk" if v > 0.0 else "heckle", v * 0.3, 0.5, false, riser_name)
			if absf(v) >= 0.4:
				r.say_aloud((["Ha. Nice.", "Aw.", "Good on you."] if v > 0.0 else ["Ooh.", "Bit much.", "Did you hear that?", "Yikes."])[randi() % 3], 2.5)
	if v >= 0.45:
		gesture("Dance" if mind.chatty > 0.7 else "Interact", 1.6)
		match randi() % 3:
			0:
				Meet.snacks = min(5, Meet.snacks + 1)
				Meet.touch_state()
				return "%s presses one of their own snacks into your hand." % first_name
			1:
				if mate != null and mate_pair[1] > 0.3:
					mate.mind.experience("helped", 0.3, 1.0, false, "what %s says about you" % first_name)
					mate._mood_check = 0.0
					Meet.ripple("%s told %s you're alright." % [first_name, mate.first_name], true)
					return "%s is going to tell %s about you. Good things." % [first_name, mate.first_name]
				return "%s will remember that." % first_name
			_:
				_tail = 45.0
				_qbark = 4.0
				_after_talk = "tail"
				return "%s decides to walk with you for a while." % first_name
	if v >= 0.2:
		gesture("Interact", 0.8)
		return "%s liked that." % first_name
	if v <= -0.45:
		sulking = true
		_after_talk = "storm"
		if mate != null and mate_pair[1] > 0.3:
			mate.mind.experience("heckle", -0.3, 1.0, false, "what you said to %s" % first_name)
			mate._mood_check = 0.0
			Meet.ripple("%s told %s what you said." % [first_name, mate.first_name], true)
			return "%s is going straight to %s with that. And won't be pulling you tonight." % [first_name, mate.first_name]
		return "%s won't be pulling you tonight. Not until you make it right." % first_name
	gesture("Hit_Chest", 0.5)
	return "%s didn't like that." % first_name

## Called when the conversation ends: do whatever the talk set up.
func after_talk() -> void:
	var what := _after_talk
	_after_talk = ""
	if state in ["scrap", "confront", "winded", "pull", "to_table"] or post:
		return
	if what == "tail":
		state = "tail"
	elif what == "storm":
		say_aloud(["I'm done here.", "Unbelievable.", "Don't follow me."][randi() % 3], 3.5)
		var away := (global_position - Meet.player.global_position).normalized()
		_pace_boost = 1.7
		var mate: Node = best_mate()[0] if is_riser else null
		if mate != null and mate.is_free():
			_partner = mate
			_go(mate.global_position + Vector3(1.2, 0, 0.6), "chat")
		else:
			_go(global_position + away * 9.0, "idle")

# --- Gone, and back ------------------------------------------------------------------------------------

## Hit by something not of this world. Enough of it and they are gone for the night.
func zapped(dmg: float, cause: String) -> void:
	if dead or alien or passer or post:
		return
	composure -= dmg
	Fx.tint(_figure, Color(0.5, 1.0, 0.6, 0.6), 0.3)
	if composure > 0.0:
		say_aloud(["Aah!", "That STINGS!", "Get OFF!", "My arm!"][randi() % 4], 1.5)
		return
	die(cause)

func die(cause: String) -> void:
	if dead or not (is_riser or guest):
		return
	Meet.main.drop_match(self)
	Pose.stop(_figure)
	dead = true
	state = "dead"
	_vs_player = false
	_convo = {}
	visible = false
	remove_from_group("interact")
	remove_from_group("hittable")
	Meet.dead[id] = cause
	Meet.dare_void(id)
	Meet.sfx("lose")
	for k in 5:
		Fx.burst(Meet.main, global_position + Vector3(0, 0.4 + k * 0.3, 0), Vector3.UP, false, 12)
	Meet.hud.banner("%s IS GONE" % first_name.to_upper(), "Taken by %s. There is a strap on the paving where they stood." % cause)
	Meet.ripple("%s was taken by %s." % [first_name, cause])
	Meet.main.memorial(self)
	# Everyone who was close to them takes it hard, and remembers whether you were any use.
	for r in Meet.risers:
		if r == self or r.dead or not r.is_riser:
			continue
		var t: float = Meet.tie(id, r.id) if is_riser else 0.1
		r._grief[id] = t
		if t > 0.3:
			r._stare = 0.0
			r.say_aloud(["%s! NO!" % first_name.to_upper(), "Not %s. Not %s." % [first_name, first_name], "...%s?" % first_name][randi() % 3], 5.0)
			r._act_anim = "Crouch_Idle"
			r._act_t = 4.0
		elif randf() < 0.5:
			r.say_aloud(["Was that... %s?" % first_name, "Oh no.", "Somebody DO something."][randi() % 3], 4.0)

## Brought back. They remember who did it.
func revive() -> void:
	if not dead:
		return
	dead = false
	Meet.dead.erase(id)
	visible = true
	composure = 80.0
	add_to_group("interact")
	add_to_group("hittable")
	state = "idle"
	_timer = 6.0
	for k in 6:
		Fx.burst(Meet.main, global_position + Vector3(0, 0.3 + k * 0.3, 0), Vector3.UP, false, 14)
	Fx.tint(_figure, Color(0.6, 1.0, 0.8, 0.6), 2.0)
	Meet.sfx("win")
	Meet.hud.banner("%s IS BACK" % first_name.to_upper(), "Coughing, furious, and covered in something that glows.")
	mind.experience("helped", 0.95, 4.0, true, "bringing me back")
	_mood_check = 0.0
	say_aloud(["I saw a light. It was the kebab van.", "...Was I GONE? How long? Who's got my strap?", "I'm fine. I'm fine. What year is it?"][randi() % 3], 6.0)
	Meet.ripple("You brought %s back." % first_name)
	Meet.dare("revive")
	for r in Meet.risers:
		if r != self and r.is_riser and not r.dead:
			r._grief.erase(id)
			var t: float = Meet.tie(id, r.id) if is_riser else 0.1
			r.mind.experience("helped", 0.3 + max(t, 0.0) * 0.6, 2.0, true, "bringing %s back" % first_name)
			r._mood_check = 0.0
			if t > 0.3:
				r.say_aloud("%s! You're... HOW?" % first_name, 5.0)
				r.gesture("Dance", 4.0)

## What they say about someone who is gone, by how close they were and what they make of you.
func grief_line(who_id: String) -> String:
	var gone: Node = Meet.riser(who_id)
	var t: float = _grief.get(who_id, 0.1)
	var name: String = gone.first_name if gone else "them"
	var blame: bool = mood_level() < 0
	if t > 0.5:
		return ("%s was the best of us. And where were YOU?" % name) if blame else ("I keep looking over to where %s stands. Stood. ...If there's any way to get them back, find it." % name)
	if t > 0.2:
		return ("%s is gone and you're asking me how I FEEL?" % name) if blame else ("We weren't always easy, me and %s. I'd give anything for one more argument." % name)
	if t < 0.0:
		return "We weren't speaking, me and %s. Now we can't. That's worse than I thought it'd be." % name
	return ("Don't. Just don't." if blame else "I didn't know %s as well as I should have. That's on me." % name)

## For the display: what to write over their head, and where.
func tag() -> Dictionary:
	if dead or not visible:
		return {}
	return {"name": _name_label.text, "color": _name_label.modulate, "at": global_position + Vector3(0, _name_label.position.y - 0.25, 0),
		"say": _bark.text if _bark.visible else ""}

# --- Finished by you ---------------------------------------------------------------------------------

## The player hit someone who was already down. Whether anyone saw decides everything after.
func finished_by_player() -> void:
	if dead:
		return
	var seen: Array = Meet.main.watchers(global_position, 18.0).filter(func(r): return r != self and not r.dead)
	for r in Meet.risers:
		if r != self and not r.dead and (r.guest or r.post) and r.global_position.distance_to(global_position) < 12.0 and Meet.dark <= 0.0:
			seen.append(r)
	Meet.main.drop_match(self)
	Pose.stop(_figure)
	Meet.sfx("lose")
	Meet.dare_void(id)
	if not seen.is_empty():
		# Witnessed. That is the end of the night, and of a good deal more.
		die("you")
		for r in Meet.risers:
			if r != self and not r.dead and (r.is_riser or r.guest or r.post):
				r.mind.experience("violence", -0.95, 5.0, true, riser_name)
				r._mood_check = 0.0
		Meet.hud.banner("THEY SAW", "%s watched you do it." % seen[0].riser_name)
		Meet.ripple("You finished %s in front of witnesses." % first_name)
		Meet.heat = 4.99
		Meet.add_heat(0.1, "what you did to %s" % first_name)
		return
	# Nobody saw. They lie where they fell until somebody walks past.
	dead = true
	secret_dead = true
	state = "dead"
	_vs_player = false
	_convo = {}
	composure = 0.0
	_found_t = 12.0
	remove_from_group("hittable")
	remove_from_group("tagged")
	Character.play(_figure, "Death01", true)
	Meet.secret[id] = true
	Meet.hud.banner("NOBODY SAW", "%s isn't getting up. For now, that is between you and the paving." % first_name)
	Meet.ripple("%s is gone, and only you know why." % first_name)
	Meet.say("Anything that needed %s tonight can't happen now. Sooner or later somebody will walk this way." % first_name)

func prompt_dead() -> String:
	return "%s is lying very still" % first_name

## Lying there. Somebody will come past eventually.
func _wait_to_be_found(dt: float) -> void:
	_found_t -= dt
	if _found_t > 0.0:
		return
	_found_t = 1.5
	for r in Meet.risers:
		if r != self and not r.dead and r.is_riser and r.state not in ["pull", "winded"] and r.global_position.distance_to(global_position) < 6.0 and Meet.dark <= 0.0:
			_discovered(r)
			return

func _discovered(by: Node) -> void:
	secret_dead = false
	Meet.secret.erase(id)
	visible = false
	Meet.dead[id] = "somebody here"
	Meet.main.memorial(self)
	by.say_aloud("%s? ...%s! SOMEBODY! Over here!" % [first_name, first_name.to_upper()], 6.0)
	Meet.sfx("sting")
	Meet.hud.banner("%s HAS BEEN FOUND" % first_name.to_upper(), "%s found them. Everybody is counting heads." % by.first_name)
	var near: bool = Meet.player.global_position.distance_to(global_position) < 12.0
	var suspect: bool = near or _fought_player and Meet.scraps > 0
	for r in Meet.risers:
		if r == self or r.dead or not r.is_riser:
			continue
		var t: float = Meet.tie(id, r.id)
		r._grief[id] = t
		r.mind.experience("violence", -0.75 if suspect else -0.2, 3.0 if suspect else 1.0, suspect, riser_name)
		r._mood_check = 0.0
		r.gawp(global_position, ["Who did this?", "He was fine an hour ago!", "Nobody leaves. NOBODY leaves.", "%s had words with them earlier. I saw." % Meet.you("The new one").capitalize() if suspect else "Did anyone see anything?"][randi() % 4], true)
	if suspect:
		Meet.add_heat(3.0, "they think it was you")
		Meet.say("You were the last one seen squaring up to %s. Every face in the amphitheatre turns to you." % first_name)
	else:
		Meet.add_heat(1.0, "nobody trusts anybody now")
		Meet.say("Nobody knows who did it. Nobody is looking at you in particular. Yet.")
