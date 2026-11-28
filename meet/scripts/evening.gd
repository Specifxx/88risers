extends Node3D
## The shape of the evening: the six o'clock bracket, betting on other people's pulls, the
## group photo, packing down, the errands people hand out, and the places round the edges
## (the kebab van, the fisherman, the busker, the bins).

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")
const Character = preload("res://scripts/character.gd")
const Thing = preload("res://scripts/thing.gd")
const People = preload("res://scripts/people.gd")
const Fx = preload("res://scripts/fx.gd")

const BRACKET_AT := 360.0     # 6:00pm
const PHOTO_AT := 600.0       # 6:40pm
const PACK_AT := 780.0        # 7:10pm
const VAN := Vector3(-17.0, 0, 23.5)
const FISHER := Vector3(15.0, 0, 28.3)
const BUSKER := Vector3(-7.5, 0, 26.6)

var main: Node3D
var _br := {}                  # the bracket: opp, others, other_winner, timer
var _seat: Node3D              # "take your seat" prompt
var _bet_things: Array = []
var _photo := ""               # "" | call | done
var _photo_t := 0.0
var _pack := false
var _packed := 0
var _table_nodes: Array = []
var _bins := {}
var _busk := 0.0
var _busker: Node3D
var _fisher: Node3D
var _announced := {}
var _moment := 35.0
var _moments_left: Array = []
var _lights: Array = []
var _balloon: Node3D
var _possum: Node3D
var _possum_t := 0.0
var _join := 6.0
var cyclist: Node3D
var bike: Node3D             # the parked bike, when there is one
var _bike_state := ""          # "" | arriving | parked | stolen | dropped | leaving
var _bike_t := 0.0

func setup(m: Node3D) -> void:
	main = m
	_places()
	for i in main.TABLES.size():
		var b := Thing.new()
		b.setup("Bet on this pull", _bet.bind(i))
		b.remove_from_group("interact")
		add_child(b)
		b.position = main.TABLES[i] + Vector3(0, 0, -1.3)
		_bet_things.append(b)
	var sign_up := Thing.new()
	sign_up.setup("Enter the six o'clock bracket ($5)", _enter)
	add_child(sign_up)
	sign_up.position = Vector3(4.6, 0, 20.2)
	_seat = Thing.new()
	_seat.setup("Take your seat", _sit)
	_seat.remove_from_group("interact")
	add_child(_seat)

func _process(dt: float) -> void:
	if Meet.modal:
		return
	Meet.buzz = max(0.0, Meet.buzz - dt)
	if Meet.buzz > 0.0:
		Meet.stamina = 100.0
	_run_bets()
	_run_bracket(dt)
	_run_photo(dt)
	if not _pack and Meet.clock >= PACK_AT:
		_start_pack()
	# Sit down for a bit and someone may come over.
	if Meet.player.sitting:
		_join -= dt
		if _join <= 0.0:
			_join = randf_range(14.0, 24.0)
			var pool: Array = _free().filter(func(r): return r.mood_level() >= 0 and r.global_position.distance_to(Meet.player.global_position) < 26.0)
			pool.sort_custom(func(a, b): return a.mind.feeling() > b.mind.feeling())
			if not pool.is_empty() and randf() < 0.75:
				var r: Node = pool[0] if randf() < 0.6 else pool[randi() % pool.size()]
				var side: Vector3 = Meet.player.global_transform.basis.x * 0.8
				r.join_on_seat(Meet.player.global_position + side)
	else:
		_join = 6.0
	_run_bike(dt)
	if Meet.dares.any(func(d): return d["event"] in ["bike", "bowl"] and not d["done"]) and _bike_state == "" and Meet.clock > 50.0 and not _announced.has("bike"):
		_announced["bike"] = true
		_m_cyclist()
	_moment -= dt
	if _moment <= 0.0 and Meet.bracket not in ["semi", "final"] and _photo != "call":
		_moment = randf_range(28.0, 50.0)
		_random_moment()
	if Meet.dark > 0.0:
		Meet.dark -= dt
		if Meet.dark <= 0.0:
			for l in _lights:
				l.visible = true
			Meet.say("The lights come back on. Everybody checks their pockets.")
	if _balloon != null:
		_balloon.position += Vector3(1.1, sin(Meet.clock * 2.0) * 0.2, -0.25) * dt
		if _balloon.position.x > 26.0:
			_balloon.queue_free()
			_balloon = null
	if _possum != null:
		_possum_t -= dt
		if _possum_t <= 0.0:
			_possum.queue_free()
			_possum = null
			Meet.say("The possum has gone back up its tree with what it came for.")
	if _busk > 0.0:
		_busk -= dt
		Character.play(_busker, "Dance")
	for mark in [[BRACKET_AT - 60.0, "Ten minutes to the six o'clock bracket. Sign up at the board by the gate if you want in: $5, winner takes the pot."],
			[PHOTO_AT - 30.0, "George is rounding people up. Group photo on the steps in five minutes."],
			[PACK_AT - 30.0, "Nearly time to pack down. Harry is eyeing the tables."]]:
		if Meet.clock >= mark[0] and not _announced.has(mark[0]):
			_announced[mark[0]] = true
			Meet.sfx("whistle", -10.0)
			Meet.say(mark[1])

# --- Betting on other people's pulls --------------------------------------------------------------

func _match_at(i: int) -> Dictionary:
	for m in main._matches:
		if m["table"] == i and m["a"].at_table() and m["b"].at_table():
			return m
	return {}

func _run_bets() -> void:
	for i in _bet_things.size():
		var m := _match_at(i)
		var can: bool = not m.is_empty() and not m.has("bet") and float(m["time"]) > 4.0
		var t: Node = _bet_things[i]
		if can != t.is_in_group("interact"):
			if can:
				t.add_to_group("interact")
			else:
				t.remove_from_group("interact")

func odds(a: Node, b: Node) -> float:
	var p: float = 1.0 / (1.0 + pow(10.0, (b.strength - a.strength) / 12.0))
	return clamp(snappedf(0.92 / p, 0.1), 1.2, 4.0)

func _bet(i: int) -> void:
	var m := _match_at(i)
	if m.is_empty() or m.has("bet"):
		return
	var a: Node = m["a"]
	var b: Node = m["b"]
	var opts: Array = []
	for pick in [a, b]:
		var other: Node = b if pick == a else a
		var o := odds(pick, other)
		for amt in [5, 20]:
			if Meet.money >= amt:
				opts.append(["$%d on %s  (pays $%d)" % [amt, pick.first_name.capitalize(), int(amt * o)], func():
					Meet.pay(-amt)
					m["bet"] = {"on": pick, "amt": amt, "pays": int(amt * o)}
					pick.say_aloud("You've got money on me? No pressure.", 3.5)
					Meet.say("$%d on %s. Don't let them see you watching too closely." % [amt, pick.first_name.capitalize()])])
	if opts.is_empty():
		Meet.say("You need at least $5 to bet.")
		return
	opts.append(["(Keep your money.)", func(): pass])
	Meet.menu.choice("A quiet bet", "%s against %s. The book is whoever's standing nearest." % [a.riser_name, b.riser_name], opts)

## Called by the world when any pull between two other people finishes.
func match_ended(m: Dictionary, winner: Node) -> void:
	if m.has("bet"):
		var bet: Dictionary = m["bet"]
		if bet["on"] == winner:
			Meet.pay(bet["pays"], "%s wins. Your bet comes in." % winner.first_name.capitalize())
			Meet.dare("bet")
		else:
			Meet.say("%s wins. That's your $%d gone." % [winner.first_name.capitalize(), bet["amt"]])
			Meet.sfx("lose", -6.0)
	if m.get("tag", "") == "semi":
		_br["other_winner"] = winner
		Meet.say("Bracket: %s goes through to the final." % winner.riser_name)
	elif m.get("tag", "") == "final":
		Meet.say("%s wins the six o'clock bracket and will be unbearable about it." % winner.riser_name)
		winner.say_aloud("CHAMPION! Six o'clock CHAMPION!", 5.0)
		main.stir(winner.global_position, ["Speech!", "Fix!", "Well pulled.", "Again next week."], 14.0, 0.7, true)
		Meet.bracket = "none"

# --- The six o'clock bracket -----------------------------------------------------------------------

func _enter() -> void:
	if Meet.bracket != "open" or Meet.clock >= BRACKET_AT:
		Meet.say("Entries are closed for tonight." if Meet.clock >= BRACKET_AT else "You're already in.")
		return
	if Meet.money < 5:
		Meet.say("Entry is $5 and you have $%d." % Meet.money)
		return
	Meet.pay(-5)
	Meet.bracket = "in"
	Meet.say("You're in the six o'clock bracket. Four pullers, straight knockout, winner takes $25 and the cup. Be near the tables at six.")

func _pick_three() -> Array:
	var pool: Array = Meet.risers.filter(func(r): return r.is_riser and r.state not in ["winded", "scrap", "confront"] and r.tonight.get("id", "") != "sore")
	pool.shuffle()
	return pool.slice(0, 4)

func _run_bracket(dt: float) -> void:
	if Meet.clock < BRACKET_AT or Meet.bracket in ["none", "out", "won"]:
		return
	if _br.is_empty():
		var four := _pick_three()
		if four.size() < 4:
			Meet.bracket = "none"
			return
		Meet.sfx("whistle")
		Meet.hud.banner("THE SIX O'CLOCK BRACKET", "Semi-finals. Money on the tables, please.")
		var harry: Node = Meet.riser("harry")
		if harry:
			harry.say_aloud("SIX O'CLOCK BRACKET! Semi-finals! Clear the tables!", 6.0)
		for r in four:
			main.drop_match(r)
			if r.state in ["to_table", "pull", "prep", "huddle", "quirk", "sit", "snack", "chat", "watch", "walk"]:
				r.idle()
		if Meet.bracket == "in":
			_br = {"opp": four[0], "others": [four[1], four[2]], "timer": 70.0}
			Meet.bracket = "semi"
			Meet.say("Bracket: you draw %s in the semi. %s pulls %s on the other table. Take your seat." % [four[0].riser_name, four[1].riser_name, four[2].riser_name])
			_offer_seat(four[0], "semi-final")
		else:
			_br = {"others": [four[0], four[1]], "second": [four[2], four[3]], "timer": 0.0}
			Meet.bracket = "watching"
			Meet.say("Bracket: %s v %s, then %s v %s. You can put money on any of them." % [four[0].riser_name, four[1].riser_name, four[2].riser_name, four[3].riser_name])
		main.force_match(_br["others"][0].id, _br["others"][1].id, "semi")
		return
	# Someone who never sits down forfeits.
	if Meet.bracket in ["semi", "final"] and _seat.is_in_group("interact"):
		_br["timer"] -= dt
		if _br["timer"] <= 0.0:
			_seat.remove_from_group("interact")
			Meet.bracket = "out"
			Meet.say("You never took your seat. Harry scratches you from the bracket.")
			_npc_final(_br["opp"])
	elif Meet.bracket == "wait" and _br.has("other_winner"):
		Meet.bracket = "final"
		_br["opp"] = _br["other_winner"]
		_br["timer"] = 70.0
		Meet.sfx("whistle")
		Meet.say("THE FINAL: you against %s. Take your seat." % _br["opp"].riser_name)
		_offer_seat(_br["opp"], "FINAL")
	elif Meet.bracket == "watching" and _br.has("other_winner"):
		if not _br.has("first"):
			_br["first"] = _br["other_winner"]
			_br.erase("other_winner")
			if not main.force_match(_br["second"][0].id, _br["second"][1].id, "semi"):
				_br["other_winner"] = _br["second"][0]
		else:
			Meet.bracket = "none" if not main.force_match(_br["first"].id, _br["other_winner"].id, "final") else "npc_final"
	elif Meet.bracket == "lost_wait" and _br.has("other_winner"):
		_npc_final(_br["opp"])

func _npc_final(a: Node) -> void:
	if _br.has("other_winner") and main.force_match(a.id, _br["other_winner"].id, "final"):
		Meet.bracket = "npc_final"
		Meet.say("The final: %s against %s. You could still make money on it." % [a.riser_name, _br["other_winner"].riser_name])
	elif not _br.has("other_winner"):
		Meet.bracket = "lost_wait"
	else:
		Meet.bracket = "none"

func _offer_seat(opp: Node, what: String) -> void:
	_seat._text = "Take your seat: %s against %s" % [what, opp.first_name]
	_seat.position = main.TABLES[1] + Vector3(0, 0, 1.4)
	_seat.add_to_group("interact")

func _sit() -> void:
	_seat.remove_from_group("interact")
	var opp: Node = _br["opp"]
	opp.bracket = Meet.bracket
	Meet.table.start(opp)

## The player's bracket pull has finished.
func bracket_result(opp: Node, won: bool) -> void:
	if Meet.bracket == "semi":
		if won:
			Meet.bracket = "wait"
			Meet.say("You're through to the final. Catch your breath: eat something.")
		else:
			Meet.bracket = "out"
			Meet.say("Out in the semi. %s goes through." % opp.riser_name)
			_npc_final(opp)
	elif Meet.bracket == "final":
		if won:
			Meet.bracket = "won"
			Meet.pay(25, "The pot is yours.")
			Meet.grant("bracket_cup")
			Meet.points += 5
			Meet.sfx("win")
			for r in Meet.risers:
				if r.is_riser:
					r.mind.experience("match", 0.35, 1.0, false, "the bracket")
			main.stir(Meet.player.global_position, ["CHAMPION!", "Speech!", "Where did THAT come from?", "Respect."], 20.0, 0.9, true)
			Meet.say("You have won the six o'clock bracket. Everyone here saw it.")
		else:
			Meet.bracket = "out"
			Meet.say("Runner-up. %s takes the cup. Second is still second." % opp.riser_name)
			opp.say_aloud("CHAMPION! Good pull, though. Genuinely.", 5.0)

# --- The group photo --------------------------------------------------------------------------------

func _run_photo(dt: float) -> void:
	if _photo == "" and Meet.clock >= PHOTO_AT and Meet.bracket not in ["semi", "final"]:
		_photo = "call"
		_photo_t = 22.0
		Meet.hud.banner("GROUP PHOTO", "Everyone on the steps. George has the camera.")
		var george: Node = Meet.riser("george")
		if george:
			george.say_aloud("GROUP PHOTO! Everyone on the steps! NOW!", 6.0)
		Meet.say("Group photo. Get on the steps with them, or don't, and be the one who wasn't in it.")
		var k := 0
		for r in Meet.risers:
			if (r.is_riser or r.guest) and r.is_free():
				main.drop_match(r)
				r._qanim = "Idle"
				r._qlines = []
				r._face_at = Vector3(0, 0, 4)
				r._timer = 30.0
				var row := k / 5
				r._go(Vector3(-3.2 + (k % 5) * 1.6, 0, -9.6 - row), "quirk")
				k += 1
	elif _photo == "call":
		_photo_t -= dt
		if _photo_t <= 0.0:
			_photo = "done"
			var p: Vector3 = Meet.player.global_position
			var in_it: bool = p.z < -8.0 and absf(p.x) < 6.0
			Meet.sfx("grip", -4.0, 1.6)
			var flash := OmniLight3D.new()
			flash.light_energy = 14.0
			flash.omni_range = 40.0
			flash.position = Vector3(0, 3, 0)
			add_child(flash)
			flash.create_tween().tween_property(flash, "light_energy", 0.0, 0.5)
			var george: Node = Meet.riser("george")
			if in_it:
				for r in Meet.risers:
					if r.is_riser:
						r.mind.experience("photo", 0.3, 0.8, true, "the group photo")
				var prop: String = Meet.worn["head"] if Meet.worn["head"] != "" else Meet.worn["hand"]
				Meet.say("Flash. You're in the club photo%s." % (", wearing the %s. It's going on the page like that" % Meet.ITEMS[prop]["name"].to_lower() if prop != "" else ""))
				Meet.dare("photo")
				if george:
					george.say_aloud("Got it. Nobody blinked. Except Kelvin.", 5.0)
			else:
				Meet.say("Flash. The photo was taken without you.")
				if george:
					george.mind.experience("nagged", -0.1, 0.4)
					george.say_aloud("Where was %s? Typical." % Meet.you(), 5.0)
			for r in Meet.risers:
				if r.state == "quirk" and r._qanim == "Idle":
					r._timer = randf_range(0.5, 3.0)

# --- Packing down -----------------------------------------------------------------------------------

func _start_pack() -> void:
	_pack = true
	Meet.hud.banner("PACK-DOWN", "Carry a table, or stand very still.")
	var harry: Node = Meet.riser("harry")
	if harry:
		harry.say_aloud("Right! Tables down! Many hands!", 6.0)
	Meet.sfx("whistle", -6.0)
	Meet.say("Pack-down. Carry a table to the gate and Harry will remember it. Or stand very still and hope nobody notices.")
	main._director = 9999.0
	for i in main.TABLES.size():
		var t := Thing.new()
		t.setup("Carry this table to the van", _carry.bind(i, t))
		add_child(t)
		t.position = main.TABLES[i] + Vector3(0, 0, 1.2)

func _carry(i: int, t: Node) -> void:
	for m in main._matches.duplicate():
		if m["table"] == i:
			main.drop_match(m["a"])
	t.remove_from_group("interact")
	t.queue_free()
	Meet.player.target = null
	Meet.player.act("PickUp_Table", 1.0)
	main.hide_table(i)
	_packed += 1
	Meet.stamina = max(0.0, Meet.stamina - 30.0)
	for id in ["harry", "george"]:
		var r: Node = Meet.riser(id)
		if r:
			r.mind.experience("helped", 0.35, 1.0, true, "packing down")
	Meet.add_heat(-0.5)
	Meet.say("One table loaded. They're heavier than they look. (%d of 3)" % _packed)
	if _packed >= 3:
		var harry: Node = Meet.riser("harry")
		if harry:
			harry.say_aloud("All three? On your own? ...Here. Get yourself something.", 6.0)
		Meet.pay(10, "Harry tips you for the pack-down.")
		Meet.dare("pack")

# --- Places round the edges -------------------------------------------------------------------------

func _places() -> void:
	# The kebab van.
	var van := Node3D.new()
	add_child(van)
	van.position = VAN
	van.rotation.y = 0.5
	Build.box(van, Vector3(4.2, 2.2, 2.0), Vector3(0, 1.5, 0), Color(0.95, 0.93, 0.85), true)
	Build.box(van, Vector3(1.3, 1.5, 1.9), Vector3(2.7, 1.15, 0), Color(0.85, 0.2, 0.15), true)
	Build.box(van, Vector3(2.6, 0.9, 0.05), Vector3(-0.3, 1.7, 1.02), Color(0.15, 0.12, 0.1))
	Build.box(van, Vector3(2.8, 0.08, 0.7), Vector3(-0.3, 1.2, 1.3), Color(0.7, 0.7, 0.72))
	Build.box(van, Vector3(3.0, 0.06, 1.2), Vector3(-0.3, 2.5, 1.5), Color(0.85, 0.2, 0.15)).rotation.x = 0.25
	for wx in [-1.3, 2.4]:
		for wz in [-0.9, 0.9]:
			Build.cyl(van, 0.36, 0.36, 0.25, Vector3(wx, 0.36, wz), Color(0.08, 0.08, 0.08), 12).rotation.x = PI / 2.0
	Build.label(van, "KEBABS  ·  CHIPS  ·  COLD DRINKS", 3.0, Color(1.0, 0.85, 0.3), 30)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 2.0
	l.omni_range = 7.0
	l.position = Vector3(-0.3, 2.0, 1.8)
	van.add_child(l)
	var cook := Character.make(van, {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.95, 0.95, 0.95)})
	cook.position = Vector3(-0.3, 0.55, 0.5)
	var shop := Thing.new()
	shop.setup("Order at the kebab van", _van)
	add_child(shop)
	shop.position = VAN + Vector3(0.4, 0, 2.2)
	# The fisherman on the railing.
	_fisher = Character.make(self, {"body": "Male_Ranger", "hood": true, "tint": Color(0.35, 0.45, 0.3)})
	_fisher.position = FISHER
	_fisher.rotation.y = 0.0
	Build.cyl(self, 0.012, 0.02, 3.2, FISHER + Vector3(0.3, 1.9, 1.1), Color(0.25, 0.2, 0.15), 5).rotation.x = 0.9
	Build.box(self, Vector3(0.45, 0.3, 0.3), FISHER + Vector3(-0.7, 0.15, 0), Color(0.2, 0.45, 0.7))
	Build.label(self, "The fisherman", 2.2, Color(0.8, 0.8, 0.82), 26).position = FISHER + Vector3(0, 2.2, 0)
	var rod := Thing.new()
	rod.setup("Borrow the fisherman's rod", _fish)
	add_child(rod)
	rod.position = FISHER + Vector3(0, 0, -1.0)
	# The busker.
	_busker = Character.make(self, {"body": "Female_Ranger", "hair": "Hair_Long", "tint": Color(0.75, 0.4, 0.8)})
	_busker.position = BUSKER
	_busker.rotation.y = PI
	Build.box(self, Vector3(0.5, 0.06, 0.35), BUSKER + Vector3(0, 0.03, -0.8), Color(0.15, 0.12, 0.1))
	Build.label(self, "The busker", 2.2, Color(0.8, 0.8, 0.82), 26).position = BUSKER + Vector3(0, 2.2, 0)
	var tip := Thing.new()
	tip.setup("Tip the busker ($2)", _tip)
	add_child(tip)
	tip.position = BUSKER + Vector3(0, 0, -1.2)
	# Bins.
	for at in [Vector3(-11.5, 0, 25.6), Vector3(11.5, 0, 25.6), Vector3(-19, 0, 14)]:
		Build.tcyl(self, 0.32, 0.28, 0.9, at + Vector3(0, 0.45, 0), "iron", Color(0.2, 0.35, 0.25), 10, true)
		Build.cyl(self, 0.34, 0.34, 0.05, at + Vector3(0, 0.92, 0), Color(0.12, 0.12, 0.12), 10)
		var b := Thing.new()
		b.setup("Rummage in the bin", _bin.bind(b))
		add_child(b)
		b.position = at + Vector3(0, 0, -0.7)
		_bins[b] = 3

func _van() -> void:
	var opts: Array = [
		["Kebab, the lot  ($6): health right back up", func(): _buy(6, func():
			Meet.composure = 100.0
			Meet.sfx("crunch")
			Meet.say("Garlic sauce, chilli sauce, regret. Health restored."))],
		["Energy drink  ($4): a minute of endless stamina", func(): _buy(4, func():
			Meet.buzz = 60.0
			Meet.sfx("sip")
			Meet.say("It tastes like a battery. You can run for a minute without tiring."))],
		["Hot chips  ($3): three snacks' worth", func(): _buy(3, func():
			Meet.snacks = min(5, Meet.snacks + 3)
			Meet.say("A box of chips. Counts as snacks. People like chips."))],
		["Lucky dip from the glovebox  ($8)", func(): _buy(8, func():
			for it in ["sunnies", "snag"]:
				if not Meet.owned.has(it):
					Meet.grant(it)
					return
			Meet.pay(8)
			Meet.say("\"Nothing left in the glovebox, mate. Here's your eight back.\""))],
		["(Nothing, thanks.)", func(): pass]]
	Meet.menu.choice("The kebab van", "\"What'll it be? You lot go through chips like nobody's business.\"  You have $%d." % Meet.money, opts)

func _buy(cost: int, then: Callable) -> void:
	if Meet.money < cost:
		Meet.say("That's $%d and you have $%d." % [cost, Meet.money])
		return
	Meet.pay(-cost)
	then.call()
	Meet.touch_state()

func _fish() -> void:
	if Meet.fish >= 4:
		Meet.say("\"That's enough of my bait for one night.\"")
		return
	Meet.strapgame.start(func(hits: int):
		Meet.fish += 1
		if hits >= 2:
			Meet.sfx("win", -8.0, 1.4)
			if Meet.grant("fish"):
				Meet.say("You land a fish. The fisherman says you can keep it. It is a hand item now. It slaps.")
			else:
				Meet.pay(4, "A decent bream. The fisherman buys it off you.")
			Meet.dare("fish")
		else:
			Meet.sfx("lose", -8.0)
			Meet.say("It gets away. \"You pulled too early. They all pull too early.\""),
		"The fisherman's rod", ["Wait...", "Wait for it...", "STRIKE!"])

func _tip() -> void:
	if Meet.money < 2:
		Meet.say("You've nothing to tip with.")
		return
	Meet.pay(-2)
	_busk = 8.0
	Meet.sfx("item", -6.0, 0.8)
	Meet.say("The busker plays your request. It is a song about arm wrestling. There are more of those than you'd think.")
	for r in Meet.risers:
		if r.passer and r.global_position.distance_to(BUSKER) < 14.0:
			r.gesture("Dance", 4.0)
			r.mind.experience("talk", 0.3, 0.6)

func _bin(b: Node) -> void:
	_bins[b] -= 1
	Meet.player.act("Fixing_Kneeling", 1.0)
	var p: Vector3 = Meet.player.global_position
	for r in Meet.risers:
		if r.global_position.distance_to(p) < 8.0 and r.facing(p) and randf() < 0.5:
			r.say_aloud(["Are you in the BIN?", "What are you doing in there?", "Things that bad?"][randi() % 3], 3.5)
			break
	match randi() % 8:
		0: Meet.pay(randi_range(1, 2), "Loose change at the bottom of the bin.")
		1:
			Meet.snacks = min(5, Meet.snacks + 1)
			Meet.say("A snack, still wrapped. You're not proud. You are, however, up a snack.")
		2: Meet.say("A parking ticket, a single sock and somebody's dreams.")
		3: Meet.say("A kebab wrapper. Licked clean. Kelvin's work.")
		4: Meet.say("Half a chalk block and a council fine addressed to 'The Arm People'.")
		_: Meet.say("Nothing. And now your hand smells of bin.")
	Meet.touch_state()
	if _bins[b] <= 0:
		b.remove_from_group("interact")

# --- Things that just happen ------------------------------------------------------------------------

func _free() -> Array:
	return Meet.risers.filter(func(r): return r.is_riser and r.is_free() and r.state != "huddle")

func _random_moment() -> void:
	if _moments_left.is_empty():
		_moments_left = ["cyclist", "phone", "footy", "blackout", "conga", "balloon", "plank", "double", "possum", "wallet", "feast", "tiktok", "star", "sprinkler", "pushups", "tourist", "sneeze", "cap", "fiver" if randf() < 0.4 else "sneeze"]
		_moments_left.shuffle()
	call("_m_" + _moments_left.pop_back())

func _m_fiver() -> void:
	var a := randf() * TAU
	main._coin(main.clear(Vector3(cos(a) * 6.0, 0, sin(a) * 6.0 + 3.0)), 5 if randf() < 0.7 else 20)
	Meet.say("A banknote is skittering across the paving in the breeze. Nobody else has noticed. Yet.")

func _m_phone() -> void:
	var k: Node = Meet.riser("kelvin")
	if k and k.is_free():
		k.gesture("Pistol_Aim_Neutral", 5.0)
		k.say_aloud("Hi Mum. Yes. Yes, I've eaten. ...Yes, a vegetable.", 5.0)
		main.stir(k.global_position, ["Hi, Kelvin's mum!", "Tell her about the red ones.", "Aww."], 8.0, 0.5, false)

func _m_footy() -> void:
	var a := randf() * TAU
	var at: Vector3 = main.clear(Vector3(cos(a) * 5.0, 0, sin(a) * 5.0 + 2.0))
	Meet.sfx("punch", -4.0, 0.7)
	Fx.burst(main, at + Vector3(0, 0.3, 0), Vector3.UP, false, 10)
	main.stir(at, ["HEADS!", "Whose is that?", "Oi! Watch it!"], 12.0, 0.6, false)
	Meet.say("A football comes over from the park and bounces across the plaza. A child's voice, far away: \"Sorry!\"")
	main.drop(["footy"], at)

func _m_blackout() -> void:
	if _lights.is_empty():
		for c in main.get_children():
			if c is OmniLight3D:
				_lights.append(c)
	for l in _lights:
		l.visible = false
	Meet.dark = 14.0
	Meet.hud.banner("POWER CUT", "Nobody can see what anybody is doing.")
	Meet.sfx("zap", -6.0, 0.5)
	main.stir(Vector3(0, 0, 2), ["Who turned the lights off?", "George! The generator!", "Nobody move. Guard your straps.", "Ooooh."], 30.0, 0.8, false)
	Meet.say("The festoon lights go out. For a quarter of a minute nobody can see what anybody is doing. Including you.")
	if not Meet.owned.has("glow_stick"):
		var t: Node = Meet.riser("tommy")
		if t:
			t.say_aloud("I've got glow sticks! Who wants a glow stick!", 5.0)
			main.drop(["glow_stick"], t.global_position + Vector3(0.8, 0, 0.6))

func _m_conga() -> void:
	var t: Node = Meet.riser("tommy")
	if t == null or not t.is_free():
		return
	t.say_aloud("CONGA! Come on! CONGA!", 4.0)
	t.gesture("Dance", 7.0)
	var n := 0
	for r in _free():
		if r != t and (r.mind.chatty > 0.55 or r.mood_level() >= 1) and n < 3:
			r.gesture("Dance", 6.0)
			n += 1
	main.stir(t.global_position, ["Absolutely not.", "Not again.", "Go on, Tommy!"], 12.0, 0.4, false)
	Meet.say("Tommy has started a conga line. It has %s people in it. Dance near them and you're in." % ["no other", "one other", "two other", "three other"][n])

func _m_balloon() -> void:
	if _balloon != null or Meet.owned.has("balloon"):
		return
	var th := Thing.new()
	add_child(th)
	th.position = Vector3(-24, 0, 6)
	Build.sphere(th, 0.2, Vector3(0, 1.8, 0), Color(0.95, 0.2, 0.3))
	Build.cyl(th, 0.005, 0.005, 1.0, Vector3(0, 1.2, 0), Color(1, 1, 1), 4)
	th.setup("Catch the balloon", func():
		th.remove_from_group("interact")
		Meet.player.target = null
		_balloon = null
		th.queue_free()
		Meet.grant("balloon"))
	_balloon = th
	Meet.say("A red balloon is drifting across the grounds at head height. Somewhere a child is having a bad evening.")

func _m_plank() -> void:
	var b: Node = Meet.riser("bhavya")
	if b == null or not b.is_free():
		return
	b.say_aloud("PLANK-OFF! Everybody down! Core is half the pull!", 5.0)
	for r in _free():
		if randf() < 0.6:
			r.gesture("Crouch_Idle", 9.0)
	Meet.menu.choice("Bhavya's plank-off", "Half the club is face down on the paving, shaking. Bhavya is walking up and down correcting hips.", [
		["Get down and plank  (uses your stamina)", func():
			Meet.strapgame.start(func(hits: int):
				Meet.stamina = max(0.0, Meet.stamina - 40.0)
				if hits == 3:
					b.mind.experience("helped", 0.5, 1.2, true, "the plank")
					Meet.pay(8, "Last one standing. Well, lying. Bhavya pays out.")
					Meet.tips = min(4, Meet.tips + 1)
				else:
					Meet.say("You collapse at %d of 3. Bhavya tuts. \"Hips.\"" % hits), "Hold the plank", ["Hold...", "HOLD...", "Thirty more seconds!"])],
		["Watch from a standing position", func(): Meet.say("You watch. Bhavya notes it down.")]])

func _m_double() -> void:
	var h: Node = Meet.riser("harry")
	if h:
		h.say_aloud("Next pull against a founder counts DOUBLE on the ladder!", 5.0)
	Meet.double_points = true
	Meet.sfx("whistle", -8.0)
	Meet.say("Harry has called double ladder points on your next pull against a founder.")

func _m_possum() -> void:
	if _possum != null:
		return
	var th := Thing.new()
	add_child(th)
	th.position = main.SNACKS + Vector3(-1.2, 0.86, 0)
	Build.sphere(th, 0.16, Vector3(0, 0.12, 0), Color(0.5, 0.48, 0.45)).scale = Vector3(1, 0.8, 1.5)
	Build.sphere(th, 0.08, Vector3(0, 0.2, 0.2), Color(0.55, 0.53, 0.5))
	Build.cyl(th, 0.015, 0.025, 0.4, Vector3(0, 0.1, -0.35), Color(0.3, 0.28, 0.27), 5).rotation.x = 1.4
	_possum = th
	_possum_t = 40.0
	Meet.hud.banner("POSSUM", "On the snack table. Like it pays membership.")
	th.setup("Offer the possum a snack", func():
		if Meet.snacks <= 0:
			Meet.say("The possum looks at your empty hands with open contempt.")
			return
		Meet.snacks -= 1
		th.remove_from_group("interact")
		Meet.player.target = null
		_possum = null
		th.queue_free()
		Meet.touch_state()
		if Meet.grant("possum_hat"):
			Meet.say("The possum eats the snack, climbs your arm, and goes to sleep on your head. This is your life now.")
		else:
			Meet.say("The possum takes the snack with both hands and gives you a look of real respect."))
	main.stir(main.SNACKS, ["There's a POSSUM on the snack table.", "Don't touch it, it'll have your finger.", "Aww.", "KELVIN. Don't."], 12.0, 0.6, false)
	Meet.say("A possum has come down out of the trees and is sitting on the snack table like it pays membership.")

func _m_wallet() -> void:
	var a := randf() * TAU
	var at: Vector3 = main.clear(Vector3(cos(a) * 7.0, 0, sin(a) * 7.0 + 3.0))
	main.pickup("a dropped wallet", at, Color(0.4, 0.25, 0.15), func():
		Meet.menu.choice("Somebody's wallet", "Forty dollars, a gym card and a photo of a dog. No name you recognise.", [
			["Hand it to Harry", func():
				for id in ["harry", "george"]:
					var r: Node = Meet.riser(id)
					if r:
						r.mind.experience("helped", 0.6, 1.5, true, "the wallet")
				Meet.add_heat(-1.0)
				Meet.say("Harry finds the owner in two minutes flat. The owner insists on giving you $10.")
				Meet.pay(10)],
			["Keep the forty", func():
				Meet.pay(40, "Yours now.")
				if not main.watchers(Meet.player.global_position, 12.0).is_empty():
					Meet.add_heat(1.5, "seen pocketing a wallet")
					main.stir(Meet.player.global_position, ["Did they just pocket that?", "That's not yours.", "Hand it in!"], 12.0, 0.7, false)]]))
	Meet.say("Somebody has dropped a wallet on the plaza and walked on.")

func _m_feast() -> void:
	var k: Node = Meet.riser("kelvin")
	if k == null:
		return
	k.say_aloud("Mum sent spring rolls. For everyone. ...I've had six.", 5.0)
	main.stir(k.global_position, ["Yes, Mrs Gian!", "Save me two!", "Legend."], 14.0, 0.7, true)
	if Meet.player.global_position.distance_to(k.global_position) < 14.0:
		Meet.snacks = min(5, Meet.snacks + 2)
		Meet.touch_state()
		Meet.say("Kelvin's mum has sent a container of spring rolls. You get two. They count as snacks. They are better than snacks.")
	else:
		Meet.say("Kelvin's mum has sent spring rolls. You were too far away. They're gone.")

func _m_tiktok() -> void:
	var p: Array = Meet.risers.filter(func(r): return r.passer)
	if p.is_empty():
		return
	var r: Node = p[0]
	r.say_aloud("Can you do the arm thing again? For my followers?", 5.0)
	Meet.menu.choice("A stranger with a phone", "%s is filming. \"Do something. Anything. I've got eleven followers and they're hungry.\"" % r.riser_name, [
		["Flex", func():
			Meet.player.act("Sword_Idle", 2.0)
			r.mind.experience("talk", 0.4, 0.8)
			Meet.say("It gets nine likes. That's most of them.")],
		["Dance", func():
			Meet.player.act("Dance", 3.0)
			r.gesture("Dance", 3.0)
			Meet.dare("dance")
			Meet.say("You go mildly viral in one suburb.")],
		["Throw chalk at the camera", func():
			r.dusted(Meet.player)
			Meet.say("That's the clip that gets the views.")],
		["\"No filming.\"", func(): r.say_aloud("Okay, boomer.", 3.0)]])

func _m_star() -> void:
	Meet.sfx("item", -8.0, 1.5)
	Meet.menu.choice("A shooting star", "It goes right over the bridge. A couple of people point. You get one wish.", [
		["Wish for strength", func():
			Meet.tips = min(4, Meet.tips + 1)
			Meet.say("Your hand feels steadier. Probably nothing. (The gold zone is a little wider.)")],
		["Wish for money", func(): Meet.pay(7, "There's a note in your shoe that wasn't there before.")],
		["Wish they'd all like you", func():
			for r in Meet.risers:
				if r.is_riser:
					r.mind.experience("helped", 0.2, 0.5, false, "nothing in particular")
			Meet.say("Nothing happens. But people do seem slightly pleased to see you.")]])

func _m_sprinkler() -> void:
	Meet.say("The council sprinklers have come on over the lawn. On a timer. In the evening. Of course.")
	for i in 14:
		get_tree().create_timer(i * 0.6).timeout.connect(func():
			for sx in [-14.0, 14.0]:
				Fx.burst(main, Vector3(sx + randf_range(-3, 3), 0.3, randf_range(8, 20)), Vector3.UP, false, 6))
	main.stir(Vector3(0, 0, 14), ["Sprinklers!", "My bag!", "Every. Single. Month."], 30.0, 0.5, false)
	for r in Meet.risers:
		if r.passer and absf(r.global_position.x) > 8.0:
			r.bolt(1.8)

func _m_pushups() -> void:
	var e: Node = Meet.riser("erick")
	if e == null or not e.is_free():
		return
	e.say_aloud("Fifty push-ups. Right now. Who's counting?", 4.0)
	e.gesture("Crouch_Idle", 10.0)
	main.stir(e.global_position, ["One! Two! Three!", "He's showing off.", "Go on, Erick!", "Forty-eight, forty-NINE..."], 12.0, 0.7, true)

func _m_tourist() -> void:
	var p: Array = Meet.risers.filter(func(r): return r.passer)
	if p.is_empty():
		return
	var r: Node = p[0]
	Meet.menu.choice("Lost", "%s has stopped you. \"Sorry. Which way's the ferry wharf?\"" % r.riser_name, [
		["\"Left along the water, five minutes.\"  (true)", func():
			r.mind.experience("helped", 0.5, 1.0)
			Meet.pay(2, "\"You're a lifesaver. Here, get a drink.\"")],
		["\"Straight through the arm wrestling.\"", func():
			r.say_aloud("Through... the middle? Okay.", 3.0)
			r._stops = false
			r._go(Vector3(0, 0, 0), "gawk")
			Meet.dare("tourist")
			Meet.add_heat(0.2)
			main.stir(Vector3(0, 0, 2), ["Mate, you can't walk through here.", "Mind the table!", "Who sent you through HERE?"], 10.0, 0.6, false)],
		["\"No idea, sorry.\"", func(): r.say_aloud("No worries.", 2.0)]])

func _m_sneeze() -> void:
	var f := _free()
	if f.is_empty():
		return
	var r: Node = f[randi() % f.size()]
	Fx.burst(main, r.global_position + Vector3(0, 1.5, 0), Vector3.UP, false, 12)
	Meet.sfx("puff", -2.0, 0.7)
	r.say_aloud("Ah... AH... CHOO. ...That was chalk. That was pure chalk.", 5.0)
	main.stir(r.global_position, ["Bless you.", "That came out WHITE.", "Health hazard, this club."], 8.0, 0.6, false)

func _m_cap() -> void:
	var h: Node = Meet.riser("harry")
	var t: Node = Meet.riser("tommy")
	if h == null or t == null or not t.is_free():
		return
	t.say_aloud("Has anyone seen Harry's cap? No reason.", 4.0)
	h.say_aloud("Tommy. Where is my cap. TOMMY.", 5.0)
	Meet.bump("harry", "tommy", -0.04)
	main.pickup("Harry's cap", main.clear(Vector3(randf_range(-8, 8), 0, randf_range(-12, -9.5))), Color(0.9, 0.9, 0.95), func():
		Meet.menu.choice("Harry's cap", "It's full of chalk.", [
			["Take it back to Harry", func():
				h.mind.experience("helped", 0.5, 1.2, true, "the cap")
				h.say_aloud("My cap! ...Why is it full of chalk?", 5.0)
				Meet.say("Harry is grateful. Tommy is making a throat-cutting gesture at you and grinning.")],
			["Give it to Tommy", func():
				t.mind.experience("helped", 0.5, 1.2, true, "the cap")
				Meet.bump("harry", "tommy", -0.08)
				t.say_aloud("YES. Accomplice. I knew I liked you.", 5.0)]]))

# --- The cyclist ------------------------------------------------------------------------------------

static func bike_model() -> Node3D:
	var n := Node3D.new()
	var frame := Color(0.95, 0.2, 0.15)
	for z in [-0.52, 0.52]:
		var w := Build.cyl(n, 0.34, 0.34, 0.04, Vector3(0, 0.34, z), Color(0.08, 0.08, 0.08), 16)
		w.rotation.z = PI / 2.0
		Build.cyl(n, 0.29, 0.29, 0.045, Vector3(0, 0.34, z), Color(0.75, 0.75, 0.78), 12).rotation.z = PI / 2.0
	var top := Build.box(n, Vector3(0.04, 0.04, 0.72), Vector3(0, 0.82, 0.02), frame)
	var down := Build.box(n, Vector3(0.04, 0.04, 0.72), Vector3(0, 0.58, 0.14), frame)
	down.rotation.x = 0.62
	var seat_tube := Build.box(n, Vector3(0.04, 0.56, 0.04), Vector3(0, 0.62, -0.3), frame)
	seat_tube.rotation.x = -0.25
	Build.box(n, Vector3(0.04, 0.5, 0.04), Vector3(0, 0.62, 0.44), frame).rotation.x = 0.3
	Build.box(n, Vector3(0.12, 0.04, 0.24), Vector3(0, 0.93, -0.36), Color(0.1, 0.1, 0.1))
	Build.box(n, Vector3(0.46, 0.035, 0.035), Vector3(0, 0.98, 0.4), Color(0.1, 0.1, 0.1))
	return n

func _m_cyclist() -> void:
	if _bike_state != "" or Meet.main.invaded():
		return
	cyclist = load("res://scripts/riser.gd").new()
	main.add_child(cyclist)
	cyclist.setup(People.CYCLIST, false, Vector3(-30, 0, 27))
	cyclist.passer = true
	cyclist._stops = false
	cyclist.state = "ride"
	Meet.risers.append(cyclist)
	bike = bike_model()
	cyclist.add_child(bike)
	cyclist.riding = true
	_bike_state = "arriving"
	Meet.hud.banner("A CYCLIST", "Eleven thousand dollars of bicycle, and he's going to leave it unattended.")
	Meet.sfx("blip", 0.0, 1.6)
	Meet.say("A cyclist in a great deal of lycra is coming along the foreshore, ringing a bell at nobody.")

func _park(at: Vector3) -> void:
	bike.reparent(main)
	bike.global_position = main.ground(at)
	bike.rotation = Vector3(0, 0.6, -0.22)
	var th := Thing.new()
	bike.add_child(th)
	th.setup("Take the cyclist's bike", _steal)
	th.name = "Take"

func _steal() -> void:
	var p: Node3D = Meet.player
	bike.get_node("Take").queue_free()
	p.target = null
	bike.reparent(p)
	bike.position = Vector3.ZERO
	bike.rotation = Vector3(0, PI, 0)
	p.mount()
	_bike_state = "stolen"
	_bike_t = 0.0
	Meet.dare("bike")
	Meet.add_heat(1.0, "stealing a bicycle")
	Meet.sfx("blip", 0.0, 1.6)
	Meet.ripple("You stole a cyclist's eleven-thousand-dollar bike.")
	if is_instance_valid(cyclist):
		cyclist.mind.experience("theft", -0.9, 3.0, true, "the bike")
		cyclist.say_aloud("OI! THAT'S ELEVEN GRAND! GET OFF MY BIKE!", 6.0)
		cyclist.riding = false
		cyclist.state = "ride"
	main.stir(p.global_position, ["Is that... the cyclist's?", "They've nicked the bike!", "GO ON!", "Harry, are you seeing this?"], 20.0, 0.7, false)
	Meet.say("You're on the bike. Go easy near people: hit someone at speed and they go down. E or USE to get off.")

## The player has got off, or been pulled off.
func dismounted() -> void:
	bike.reparent(main)
	bike.global_position = main.ground(Meet.player.global_position + Meet.player.global_transform.basis.x * 0.8)
	bike.rotation = Vector3(0, Meet.player.rotation.y, -0.22)
	_bike_state = "dropped"

func _run_bike(dt: float) -> void:
	if _bike_state == "" or not is_instance_valid(cyclist):
		if _bike_state != "" and not Meet.player.riding:
			_bike_state = ""
		return
	var c := cyclist
	match _bike_state:
		"arriving":
			# Rides in along the water and up to the gate, then parks to watch.
			var to := Vector3(1.8, 0, 22.6)
			if c.ride_to(to if c.global_position.x > -2.0 else Vector3(0, 0, 27), 6.5, dt):
				if c.global_position.distance_to(to) < 1.0:
					c.riding = false
					_park(to + Vector3(1.0, 0, 0.3))
					_bike_state = "parked"
					_bike_t = randf_range(45.0, 70.0)
					c.say_aloud("Don't touch the bike.", 4.0)
					c._go(Vector3(randf_range(-3, 3), 0, 11.0), "gawk")
		"parked":
			_bike_t -= dt
			if _bike_t <= 0.0 and c.state in ["watch", "idle", "pass"] and not Meet.modal:
				_bike_state = "leaving"
		"leaving", "dropped":
			# Back to the bike, on, and away.
			if c.state in ["winded", "scrap"]:
				return
			c.state = "ride"
			if c.ride_to(bike.global_position, 3.4 if _bike_state == "dropped" else 1.6, dt):
				if bike.has_node("Take"):
					bike.get_node("Take").queue_free()
				bike.reparent(c)
				bike.position = Vector3.ZERO
				bike.rotation = Vector3.ZERO
				c.riding = true
				c.say_aloud("Eleven grand. ELEVEN." if _bike_state == "dropped" else "Right. Twenty k to go.", 4.0)
				_bike_state = "away"
		"away":
			if c.ride_to(Vector3(34, 0, 27.2), 7.5, dt):
				Meet.risers.erase(c)
				c.queue_free()
				cyclist = null
				_bike_state = ""
		"stolen":
			# On foot, furious, after you.
			_bike_t += dt
			var p: Node3D = Meet.player
			c.state = "ride"
			if c.ride_to(p.global_position, 4.4, dt) and p.riding and p.speed() < 5.0:
				p.dismount()
				Meet.hud.shake()
				c.say_aloud("GOT you. Off. OFF.", 4.0)
				Meet.say("The cyclist hauls you off by the collar.")
