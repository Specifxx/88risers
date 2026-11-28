extends Node3D
## A person: a founder in Rhodes or a villager. Each has a mind of their own (mind.gd)
## that learns how they feel about the player, and a small life: a post they keep,
## places they drift to, people they stop and talk to, and a home they go to at night.

const Build = preload("res://scripts/build.gd")
const Data = preload("res://scripts/data.gd")
const Character = preload("res://scripts/character.gd")
const Mind = preload("res://scripts/mind.gd")

const WALK := 1.35

var def: Dictionary
var id := ""
var npc_name := ""
var role := ""
var village := "tallow"
var is_founder := false
var alive := true
var recruited := false
var willing := 0
var willing_cap := 100
var capable := 0
var disp := 30
var persuaded := 0
var gifts := 0
var mind: RefCounted
var post := Vector3.ZERO
var aggro := false

var _served := {}
var _figure: Node3D
var _bark: Label3D
var _bark_time := 0.0
var _state := "post"   # post | walk | linger | chat | avoid
var _goal := Vector3.ZERO
var _timer := 0.0
var _partner: Node3D = null
var _noticed := false
var _think := 0.0

func setup(d: Dictionary, founder: bool) -> void:
	def = d
	id = d["id"]
	npc_name = d["name"]
	role = d["role"]
	is_founder = founder
	village = "rhodes" if founder else "tallow"
	if founder:
		recruited = true
		willing = 100
		capable = 100
		disp = 60
	else:
		willing = d["willing"]
		willing_cap = d["willing_cap"]
		capable = d["capable"]
		disp = d["disp"]
	position = d["pos"]
	post = d["pos"]
	mind = Mind.new()
	mind.setup(id, Data.MINDS.get(id, {}))
	var look: Dictionary = Data.LOOKS.get(id, {})
	_figure = Character.make(self, look)
	var b: float = look.get("build", 1.0)
	_figure.scale = Vector3(b, 1.0 + (b - 1.0) * 0.25, b)
	Build.label(self, npc_name, 2.22)
	Build.label(self, role, 2.0, Color(0.75, 0.72, 0.65), 26)
	_bark = Build.label(self, "", 2.5, Color(1.0, 0.92, 0.7), 30)
	_bark.visible = false
	_timer = randf_range(4.0, 14.0)
	add_to_group("interact")

func prompt() -> String:
	return "Talk to %s" % npc_name

func interact() -> void:
	mind.met()
	if not mind.remembers("meet"):
		mind.experience("meet", 0.15, 0.3)
	Game.dialogue.open(self)

func portrait() -> String:
	return Data.LOOKS.get(id, {}).get("portrait", "")

# --- How they feel -------------------------------------------------------------

## Their disposition towards the player: where they started, moved by what their mind has learned.
func eff_disp() -> int:
	return disp + int(round(mind.feeling() * 50.0))

func hostile() -> bool:
	return eff_disp() < 5

func say_aloud(text: String, seconds := 3.5) -> void:
	_bark.text = text
	_bark.visible = true
	_bark_time = seconds

# --- Their day -------------------------------------------------------------------

func _process(dt: float) -> void:
	if not alive or Game.player == null:
		return
	mind.tick(dt)
	if _bark_time > 0.0:
		_bark_time -= dt
		if _bark_time <= 0.0:
			_bark.visible = false
	if Game.modal:
		Character.play(_figure, "Idle_Talking" if Game.dialogue.npc == self and Game.dialogue.active() else "Idle")
		return
	_think -= dt
	if _think <= 0.0:
		_think = 2.5
		mind.reflect(2)
	_notice_player()
	match _state:
		"post", "linger":
			_timer -= dt
			Character.play(_figure, "Idle")
			if _timer <= 0.0:
				_choose()
		"walk", "avoid":
			if _step_towards(_goal, dt):
				_arrive()
		"chat":
			_timer -= dt
			Character.play(_figure, "Idle_Talking")
			if is_instance_valid(_partner):
				_face(_partner.global_position, 0.1)
			if _timer <= 0.0:
				_go(post, "walk")

func _notice_player() -> void:
	var p: Vector3 = Game.player.global_position
	var d := global_position.distance_to(p)
	if d > 11.0:
		_noticed = false
		return
	if _state in ["post", "linger"] and d < 8.0:
		_face(p, 0.07)
	if _noticed or d > 7.0:
		return
	_noticed = true
	mind.met()
	var word := String(mind.state_word())
	if randf() < (0.9 if word in ["hostile", "trusting"] else 0.45):
		var lines: Array = Data.BARKS[word]
		say_aloud(lines[randi() % lines.size()])
	# Someone who fears or hates you does not stand and wait for you.
	if mind.feeling() < -0.55 and _state != "avoid":
		var away := (global_position - p)
		away.y = 0
		_go(global_position + away.normalized() * 9.0, "avoid")

func _choose() -> void:
	if Game.is_night():
		if global_position.distance_to(post) > 2.0:
			_go(post, "walk")
		else:
			_timer = randf_range(10.0, 20.0)
		return
	var roll := randf()
	if roll < 0.4:
		_timer = randf_range(6.0, 16.0)
	elif roll < 0.72:
		var spots: Array = Data.SPOTS[village]
		var s: Vector3 = spots[randi() % spots.size()]
		_go(s + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)), "walk")
	else:
		var others := Game.villagers(village)
		var o: Node3D = others[randi() % others.size()]
		if o != self and o._state in ["post", "linger"] and o.global_position.distance_to(global_position) < 45.0:
			_partner = o
			var to := global_position - o.global_position
			to.y = 0
			_go(o.global_position + to.normalized() * 1.4, "walk")
		else:
			_timer = 4.0

func _go(to: Vector3, state: String) -> void:
	_goal = to
	_state = state

func _step_towards(to: Vector3, dt: float) -> bool:
	var d := to - global_position
	d.y = 0
	if d.length() < 0.35:
		return true
	var speed := WALK * (1.6 if _state == "avoid" else 1.0)
	global_position = Game.main.ground(global_position + d.normalized() * speed * dt)
	_face(global_position + d, 0.15)
	Character.play(_figure, "Jog_Fwd" if _state == "avoid" else "Walk")
	return false

func _arrive() -> void:
	if _state == "avoid":
		_state = "linger"
		_timer = randf_range(8.0, 14.0)
		return
	if is_instance_valid(_partner) and _partner.alive and _partner.global_position.distance_to(global_position) < 3.0:
		_state = "chat"
		_timer = randf_range(6.0, 10.0)
		_partner.listen_to(self)
		_tell(_partner)
		return
	_partner = null
	if global_position.distance_to(post) < 1.0:
		_state = "post"
		_timer = randf_range(8.0, 20.0)
	else:
		_state = "linger"
		_timer = randf_range(6.0, 14.0)

## Someone has come over to talk.
func listen_to(who: Node3D) -> void:
	if _state in ["post", "linger"]:
		_partner = who
		_state = "chat"
		_timer = randf_range(6.0, 10.0)

## Pass on the thing most on their mind. This is how word gets round a village.
func _tell(other: Node3D) -> void:
	if randf() > mind.chatty + 0.2:
		return
	var news: Dictionary = mind.gossip()
	if news.is_empty():
		return
	if other.mind.hear(news) and Data.GOSSIP.has(news["kind"]):
		var line: String = Data.GOSSIP[news["kind"]]
		say_aloud(line % news["about"] if line.contains("%s") else line, 5.0)

func _face(at: Vector3, speed: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), speed)

# --- Conversation ----------------------------------------------------------------

func greeting() -> String:
	if hostile():
		if mind.remembers("violence"):
			return "Murderer. I've nothing to say to you."
		if mind.remembers("theft"):
			return "Thief. I've nothing to say to you."
		return "I've nothing to say to you."
	if recruited and not is_founder:
		return "My name's on the Register. Tell me when it's time."
	if mind.remembers("raised_kin"):
		return "I went down to the jetty this morning. The planks were empty. Thank you."
	if mind.remembers("theft") and mind.feeling() < 0.2:
		return "I heard about the strongbox. Keep your hands where I can see them."
	if mind.remembers("violence"):
		return "People are saying things about you. I hope they're wrong."
	if mind.remembers("gift"):
		return "You again. The chalk was needed. I won't forget it."
	if mind.feeling() > 0.45 and mind.familiarity > 0.2:
		return "Good to see you, pilgrim. " + String(def["greet"])
	return def["greet"]

func topics() -> Array:
	if hostile():
		return []
	var out: Array = def["topics"].keys()
	if not is_founder:
		out.append(Data.TOPIC_JOIN)
	if id == "harry" and Game.recruits.size() >= Game.SLICE_GOAL and not Game.flags.has("slice_done"):
		out.append("I've brought three from Tallow Ford")
	return out

func can_join() -> bool:
	return willing >= 60 and capable >= 60 and eff_disp() >= 40

func topic_text(t: String) -> String:
	mind.met()
	if t == "The Register":
		var n := Game.register_count()
		return "%d names. Room for %d. Eight of them have been there since before you came.\n\nAnyone willing and able can fill a line. There are not many who are both." % [n, Game.QUOTA]
	if t == "I've brought three from Tallow Ford":
		Game.flags["slice_done"] = true
		Game.hud.show_end()
		return "Three, from one village, and you walked that road to get them. Then it can be done.\n\nThere are a great many villages. Rest. Then go further."
	if t == "Your father":
		Game.flags["knows_oswin"] = true
		Game.note("Mara Quill's father Oswin drowned at the old jetty, south of Tallow Ford along the river. He walks there still. She can't go near him.")
	if t == "The Pilgrimage":
		Game.note("Harry: go out the east gate, keep to the road, reach Tallow Ford. Bring back three who are willing and able.")
	if t == "Tallow Ford" and id == "george":
		Game.note("George: the road bends north round a stand of pines, then south again. The roofs come before the river.")
	if t == "The road" and id == "wren":
		Game.note("Wren Calloway wants to see Pinned on the road raised properly, so they stay gone.")
	if t == Data.TOPIC_JOIN:
		return _join_text()
	return def["topics"][t]

func _join_text() -> String:
	if recruited:
		return "I've said yes. I meant it."
	if willing < 60:
		var s: String = def["no_willing"]
		return s if s != "" else "It isn't for me. I'm sorry."
	if capable < 60:
		var s2: String = def["no_capable"]
		return s2 if s2 != "" else "I'd be no use to you out there."
	if eff_disp() < 40:
		return def.get("no_trust", "I don't know you well enough to follow you anywhere.")
	recruited = true
	Game.recruits.append(npc_name)
	Game.say("%s will become a Riser. The Register stands at %d of %d." % [npc_name, Game.register_count(), Game.QUOTA])
	Game.note("%s of Tallow Ford agreed to become a Riser." % npc_name)
	Game.touch()
	return def["yes"]

## Things you can do with this person, beyond asking about topics.
func actions() -> Array:
	var out: Array = []
	if not alive:
		return out
	if not hostile():
		match id:
			"harry":
				if not _served.has("kit"):
					out.append(["Ask for chalk and straps", _give_kit])
			"phillip":
				if not _served.has("train"):
					out.append(["Train with Phillip", _phillip_train])
			"bhavya":
				out.append(["Ask Bhavya to tend your wounds", _heal])
			"tommy":
				out.append(["Buy chalk (4 coin)", _buy.bind("chalk", 4)])
				out.append(["Buy a strap (10 coin)", _buy.bind("straps", 10)])
				out.append(["Buy bread (3 coin)", _buy.bind("bread", 3)])
			"pell":
				out.append(["Buy chalk (5 coin)", _buy.bind("chalk", 5)])
				out.append(["Buy a strap (12 coin)", _buy.bind("straps", 12)])
				out.append(["Buy bread (3 coin)", _buy.bind("bread", 3)])
		if not is_founder and not recruited:
			if willing < willing_cap and willing < 60 and persuaded < 3:
				out.append(["Make the case for the Risers", _persuade])
			if willing >= 50 and capable < 60:
				out.append(["Train together against the Pinned", _train])
			if gifts < 2 and Game.chalk > 0:
				out.append(["Give them chalk for their dead", _gift])
	out.append(["Attack %s" % npc_name, _attack])
	return out

func _give_kit() -> String:
	_served["kit"] = true
	Game.chalk += 4
	Game.straps += 3
	Game.touch()
	return "Four chalk, three straps. That's what we can spare. Tommy sells more, and so does the shop at the ford, for a price."

func _phillip_train() -> String:
	_served["train"] = true
	Game.power += 2
	Game.max_hp += 6
	Game.hp = Game.max_hp
	mind.experience("trained", 0.5, 0.6)
	Game.touch()
	return "Again. Again. Better. You hit harder than you did this morning, and you'll stand a little longer."

func _heal() -> String:
	Game.heal_full()
	return "There. You'll hold together. Try to come back with the same number of holes."

func _buy(what: String, cost: int) -> String:
	# A shopkeeper who has learned that dealing with you goes badly will not deal.
	if mind.expects("trade") < -0.35:
		return "Not to you. Not after what I've heard."
	if Game.coins < cost:
		return "You haven't the coin."
	Game.coins -= cost
	Game.set(what, Game.get(what) + 1)
	if not _served.has("traded"):
		_served["traded"] = true
		mind.experience("trade", 0.35, 0.4)
	Game.touch()
	return "Done. Anything else?"

func _persuade() -> String:
	persuaded += 1
	# Whether arguing with them works depends on what they have learned to expect from you.
	if eff_disp() < 35:
		mind.experience("nagged", -0.3, 0.4)
		return "They hear you out, arms folded. It makes no difference. They don't trust you enough to be moved, and they like being pressed even less."
	mind.experience("nagged", 0.15, 0.3)
	willing = min(willing_cap, willing + 12)
	if willing >= willing_cap and willing < 60:
		return "They listen, and they are nearly moved. But something else is holding them, and words won't shift it."
	return "They listen. You can see them turning it over."

func _train() -> String:
	if eff_disp() < 35:
		return "They won't follow you out past the fence. Not yet."
	capable = min(100, capable + 15)
	mind.experience("trained", 0.6, 0.8, true, npc_name)
	Game.hud.fade("You spend the afternoon at the edge of the fields, facing what comes out of the trees.")
	if capable >= 60:
		return "They stood their ground today. They're ready."
	return "They ran, but later than last time. They want to try again."

func _gift() -> String:
	gifts += 1
	Game.chalk -= 1
	mind.experience("gift", 0.7, 1.0, true, npc_name)
	Game.touch()
	return "They take it in both hands. \"For my own, when the time comes. Thank you.\""

func _attack() -> String:
	Game.dialogue.close()
	mind.experience("violence", -1.0, 3.0, true, npc_name)
	Game.battle.start_npc(self)
	return ""

## Called when the player kills this person.
func die() -> void:
	alive = false
	visible = false
	remove_from_group("interact")
	if is_founder:
		Game.founders_alive -= 1
	if recruited and not is_founder:
		Game.recruits.erase(npc_name)
	recruited = false
	var seen := Game.deed("violence", -1.0, 9.0, global_position, village, npc_name)
	if seen.size() > 0:
		Game.say("%s saw you kill %s. They will not keep it to themselves." % [seen[0].npc_name, npc_name])
	else:
		Game.say("Nobody saw. %s lies where they fell, unrisen." % npc_name)
	Game.note("You killed %s. Unless someone raises them, they will come back as one of the Pinned." % npc_name)
	Game.main.spawn_victim(npc_name, global_position)
	Game.touch()
