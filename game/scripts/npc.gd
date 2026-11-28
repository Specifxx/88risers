extends Node3D
## A person: a founder in Rhodes or a villager. Holds their own disposition,
## willingness, capability and memory of what the player has done.

const Build = preload("res://scripts/build.gd")
const Data = preload("res://scripts/data.gd")
const Character = preload("res://scripts/character.gd")

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
var memory: Array = []
var _served := {}
var _figure: Node3D

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
		disp = 40
	else:
		willing = d["willing"]
		willing_cap = d["willing_cap"]
		capable = d["capable"]
		disp = d["disp"]
	position = d["pos"]
	_figure = Character.make(self, Data.LOOKS.get(id, {}))
	Build.label(self, npc_name, 2.22)
	Build.label(self, role, 2.0, Color(0.75, 0.72, 0.65), 26)
	add_to_group("interact")

func prompt() -> String:
	return "Talk to %s" % npc_name

func interact() -> void:
	Game.dialogue.open(self)

func _process(_dt: float) -> void:
	if Game.player and alive:
		var p: Vector3 = Game.player.global_position
		if global_position.distance_to(p) < 9.0:
			var to := p - global_position
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 0.08)
		Character.play(_figure, "Idle_Talking" if Game.dialogue.npc == self and Game.dialogue.active() else "Idle")

func eff_disp() -> int:
	return disp + int(Game.rep[village])

func hostile() -> bool:
	return eff_disp() < 5

func remember(what: String) -> void:
	if not memory.has(what):
		memory.append(what)

func greeting() -> String:
	if hostile():
		return "I've nothing to say to you. Everyone here knows what you did."
	if recruited and not is_founder:
		return "My name's on the Register. Tell me when it's time."
	if memory.has("raised_father"):
		return "I went down to the jetty this morning. The planks were empty. Thank you."
	if memory.has("gift"):
		return "You again. The chalk was needed. I won't forget it."
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
	Game.touch()
	return "Again. Again. Better. You hit harder than you did this morning, and you'll stand a little longer."

func _heal() -> String:
	Game.heal_full()
	return "There. You'll hold together. Try to come back with the same number of holes."

func _buy(what: String, cost: int) -> String:
	if Game.coins < cost:
		return "You haven't the coin."
	Game.coins -= cost
	Game.set(what, Game.get(what) + 1)
	Game.touch()
	return "Done. Anything else?"

func _persuade() -> String:
	persuaded += 1
	if eff_disp() < 35:
		return "They hear you out, arms folded. It makes no difference. They don't trust you enough to be moved."
	willing = min(willing_cap, willing + 12)
	if willing >= willing_cap and willing < 60:
		return "They listen, and they are nearly moved. But something else is holding them, and words won't shift it."
	return "They listen. You can see them turning it over."

func _train() -> String:
	if eff_disp() < 35:
		return "They won't follow you out past the fence. Not yet."
	capable = min(100, capable + 15)
	Game.hud.fade("You spend the afternoon at the edge of the fields, facing what comes out of the trees.")
	if capable >= 60:
		return "They stood their ground today. They're ready."
	return "They ran, but later than last time. They want to try again."

func _gift() -> String:
	gifts += 1
	Game.chalk -= 1
	disp += 10
	remember("gift")
	Game.touch()
	return "They take it in both hands. \"For my own, when the time comes. Thank you.\""

func _attack() -> String:
	Game.dialogue.close()
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
	var seen := Game.witnesses(global_position, self)
	if seen.size() > 0:
		Game.rep[village] -= 60
		Game.say("%s saw you kill %s. Word will get round." % [seen[0].npc_name, npc_name])
	else:
		Game.say("Nobody saw. %s lies where they fell, unrisen." % npc_name)
	Game.note("You killed %s. Unless someone raises them, they will come back as one of the Pinned." % npc_name)
	Game.main.spawn_victim(npc_name, global_position)
	Game.touch()
