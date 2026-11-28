extends Node3D
## The shape of the evening: the six o'clock bracket, betting on other people's pulls, the
## group photo, packing down, the errands people hand out, and the places round the edges
## (the kebab van, the fisherman, the busker, the bins).

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")
const Character = preload("res://scripts/character.gd")
const Thing = preload("res://scripts/thing.gd")
const People = preload("res://scripts/people.gd")
const Moments = preload("res://scripts/moments.gd")
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
var _fog := 0.0
var _rod: MeshInstance3D
var _float: MeshInstance3D
var _bite := 30.0
var _critter: Node3D
var _critter_t := 0.0
var _critter_goal := Vector3.ZERO
var _swimmer: Node3D
var _swim_t := 0.0
var _invited := false
var _legends: Array = []
var _kaiju: Node3D
var _kaiju_r: Node3D
var _kaiju_state := ""
var _kaiju_t := 0.0
var _wave: MeshInstance3D
var _kaiju_dmg := 0.0
var _hand: Node3D
var _last_choice := -99.0
var _walk_n := 0

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
		_moment = randf_range(14.0, 25.0)
		_random_moment()
	if _fog > 0.0:
		_fog -= dt
		main._env.fog_density = lerp(main._env.fog_density, 0.06 if _fog > 2.0 else 0.004, min(1.0, dt * 1.5))
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
	_run_kaiju(dt)
	_run_carry()
	if Meet.wind > 0.0:
		Meet.wind -= dt
		if fmod(Meet.wind, 3.0) < dt:
			for r in Meet.risers:
				if not r.alien and r.state not in ["pull", "winded", "post"] and randf() < 0.3:
					r._knock += Vector3(randf_range(1.0, 2.5), 0, randf_range(-1.0, 1.0))
		if Meet.wind <= 0.0:
			Meet.say("The wind drops as suddenly as it came.")
			Meet.touch_state()
	# Someone comes to find you about the bracket.
	if not _invited and Meet.clock > 285.0 and Meet.clock < BRACKET_AT - 20.0 and Meet.bracket == "open" and _kaiju_state == "" and not main.invaded():
		var asker: Node = Meet.riser("george")
		if asker == null or not asker.is_free() or asker.mood_level() < -1:
			asker = Meet.riser("harry")
		if asker and asker.is_free():
			_invited = true
			asker._convo = {}
			asker._partner = null
			asker.say_aloud("Oi, %s! Got a second?" % Meet.you("you"), 4.0)
			var who := asker
			asker._give = func():
				Meet.menu.choice("%s has come to find you" % who.riser_name, "\"Six o'clock bracket. Four pullers, knockout, five dollars in, winner takes the pot and the cup. You look like you fancy it. Are you in?\"", [
					["\"I'm in.\"  ($5)", func():
						_enter()
						if Meet.bracket == "in":
							who.mind.experience("talk", 0.25, 0.6)
							who.say_aloud("That's the spirit. Be at the tables at six.", 4.0)],
					["\"Not tonight.\"", func(): who.say_aloud("Fair enough. You can still bet on it.", 4.0)]])
			asker._go(Meet.player.global_position + (asker.global_position - Meet.player.global_position).normalized() * 1.4, "give")
	_run_fishing(dt)
	_run_critter(dt)
	_run_swimmer(dt)
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
		var gcam: Node = Meet.riser("george")
		if gcam:
			gcam.camera()
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

## Pick a table up. It goes over your head, and stays there until you get it to the gate.
func _carry(i: int, t: Node) -> void:
	if Meet.carrying >= 0:
		Meet.say("You're already carrying one. They're not light.")
		return
	for m in main._matches.duplicate():
		if m["table"] == i:
			# Somebody was mid-pull on it.
			for r in [m["a"], m["b"]]:
				r.say_aloud(["OI! We were USING that!", "I was WINNING!", "Put it BACK!", "Mid-pull! MID-PULL!"][randi() % 4], 4.0)
				r.mind.experience("nagged", -0.25, 0.9, true, r.riser_name)
				r.stare(4.0)
			main.stir(main.TABLES[i], ["Ha! They took the table!", "While they were pulling!", "Savage."], 12.0, 0.6, false)
			main.drop_match(m["a"])
	t.remove_from_group("interact")
	t.queue_free()
	Meet.player.target = null
	Meet.player.act("PickUp_Table", 1.0)
	var root: Node3D = main._table_roots[i]
	main._gone_tables[i] = true
	root.reparent(Meet.player)
	root.position = Vector3(0, 1.95, 0.1)
	root.rotation = Vector3(PI, 0, 0)
	root.scale = Vector3(0.8, 0.8, 0.8)
	Meet.carrying = i
	Meet.stamina = max(0.0, Meet.stamina - 15.0)
	Meet.touch_state()
	Meet.say("You've got the table over your head. Get it to the gate. You can't run with it.")

func _run_carry() -> void:
	if Meet.carrying < 0:
		return
	var p: Vector3 = Meet.player.global_position
	if p.z > 21.0 and absf(p.x) < 6.0:
		var root: Node3D = main._table_roots[Meet.carrying]
		root.visible = false
		Meet.carrying = -1
		_packed += 1
		Meet.player.act("PickUp_Table", 0.8)
		Meet.sfx("punch", -6.0, 0.6)
		for id in ["harry", "george"]:
			var r: Node = Meet.riser(id)
			if r:
				r.mind.experience("helped", 0.35, 1.0, true, "packing down")
		Meet.add_heat(-0.5)
		Meet.say("Table loaded at the gate. (%d of 3)" % _packed)
		Meet.touch_state()
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
	var shop := Thing.new()
	shop.setup("Order at the kebab van", _van)
	add_child(shop)
	shop.position = VAN + Vector3(0.4, 0, 2.2)
	# The fisherman on the railing.
	# His rod over the rail, a line down to the water, a float, and a bucket.
	_rod = Build.cyl(self, 0.012, 0.02, 3.4, FISHER + Vector3(0.3, 2.0, 1.3), Color(0.25, 0.2, 0.15), 5)
	_rod.rotation.x = 0.95
	_rod.set_meta("live", true)
	Build.cyl(self, 0.004, 0.004, 3.3, FISHER + Vector3(0.3, 1.25, 2.7), Color(0.9, 0.9, 0.9), 3)
	_float = Build.sphere(self, 0.07, FISHER + Vector3(0.3, -0.3, 2.7), Color(1.0, 0.3, 0.2))
	_float.set_meta("live", true)
	Build.box(self, Vector3(0.45, 0.3, 0.3), FISHER + Vector3(-0.7, 0.15, 0), Color(0.2, 0.45, 0.7))
	var rod := Thing.new()
	rod.setup("Borrow the fisherman's rod", _fish)
	add_child(rod)
	rod.position = FISHER + Vector3(0, 0, -1.0)
	# The busker.
	Build.box(self, Vector3(0.5, 0.06, 0.35), BUSKER + Vector3(0, 0.03, -0.8), Color(0.15, 0.12, 0.1))
	var tip := Thing.new()
	tip.setup("Tip the busker ($2)", _tip)
	add_child(tip)
	tip.position = BUSKER + Vector3(0, 0, -1.2)
	# George's merch table, by the ladder board.
	Build.tbox(self, Vector3(1.8, 0.06, 0.7), Vector3(6.4, 0.8, 21.4), "planks", Color(0.7, 0.6, 0.5), true)
	for sx in [-0.8, 0.8]:
		Build.tbox(self, Vector3(0.06, 0.8, 0.6), Vector3(6.4 + sx, 0.4, 21.4), "darkwood")
	for i in 4:
		Build.box(self, Vector3(0.3, 0.1, 0.3), Vector3(5.75 + i * 0.44, 0.9, 21.4), [Color(0.75, 0.1, 0.12), Color(0.1, 0.1, 0.12), Color(0.95, 0.95, 0.9), Color(1.0, 0.82, 0.25)][i])
	Build.label(self, "CLUB MERCH", 1.6, Color(1.0, 0.85, 0.3), 26).position = Vector3(6.4, 1.6, 21.4)
	var merch := Thing.new()
	merch.setup("Look at the club merch", _merch)
	add_child(merch)
	merch.position = Vector3(6.4, 0, 20.5)
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
		["Sami's 'special sauce'  ($35): brings anybody back from anything", func(): _buy(35, func():
			Meet.potions += 1
			Meet.say("A sauce bottle with a skull drawn on it. \"One squirt. On where they fell. Don't get it on your hands.\" (Revival potion: %d.)" % Meet.potions))],
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
			var odd: String = Meet.unowned("fish")
			if Meet.grant("fish"):
				Meet.say("You land a fish. The fisherman says you can keep it. It is a hand item now. It slaps.")
			elif odd != "" and randf() < 0.45:
				Meet.grant(odd)
				Meet.say("That's not a fish. That's %s. Con: \"Keep it. I've got three.\"" % Meet.ITEMS[odd]["name"].to_lower())
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
	busk()
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
	var found: String = Meet.unowned("bin")
	if found != "" and randf() < 0.22:
		Meet.grant(found)
		Meet.say("Right at the bottom, under the wrappers: %s. Yours now." % Meet.ITEMS[found]["name"].to_lower())
		Meet.touch_state()
		return
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
		_moments_left = ["critter", "swimmer", "lostprop", "lostprop", "oz" if randf() < 0.5 else "lostprop", "gale", "gale" if Meet.owned.has("balloon") else "phone", "legend_don" if randf() < 0.5 else "sneeze", "legend_lasha" if randf() < 0.5 else "phone", "cyclist", "phone", "footy", "blackout", "conga", "balloon", "plank", "double", "possum", "wallet", "feast", "tiktok", "star", "sprinkler", "pushups", "tourist", "sneeze", "cap", "fiver" if randf() < 0.4 else "sneeze"]
		for m in Moments.LIST:
			_moments_left.append("d_" + m["id"])
		_moments_left.shuffle()
	# Anything that stops to ask you something waits its turn: no more than one a minute, and
	# never while you are busy with something else.
	for tries in 6:
		if _moments_left.is_empty():
			return
		var name: String = _moments_left.pop_back()
		if not name.begins_with("d_"):
			call("_m_" + name)
			return
		var m: Dictionary = {}
		for x in Moments.LIST:
			if x["id"] == name.substr(2):
				m = x
		var asks: bool = m.has("choice")
		if asks and (Meet.clock - _last_choice < 55.0 or Meet.player.riding or Meet.player.sitting):
			_moments_left.push_front(name)
			continue
		if play(m):
			return

## Carry out one of the written moments. False if it couldn't happen just now.
func play(m: Dictionary) -> bool:
	match m.get("need", ""):
		"match":
			if not main.match_on():
				return false
		"passer":
			if not Meet.risers.any(func(r): return r.passer):
				return false
		"night":
			if Meet.clock < 480.0:
				return false
	if main.invaded():
		return false
	var cast := {}
	var pool: Array = _free()
	pool.shuffle()
	cast["any"] = pool[0] if pool.size() > 0 else null
	cast["any2"] = pool[1] if pool.size() > 1 else null
	if m.has("walkon"):
		cast["walkon"] = _walkon(m["walkon"])
	if m.has("tie_any") and cast["any"] and cast["any2"]:
		Meet.bump(cast["any"].id, cast["any2"].id, m["tie_any"])
	var last := 0.0
	for l in m.get("lines", []):
		var who: Node = cast.get(l[0], null) if cast.has(l[0]) else Meet.riser(l[0])
		last = max(last, float(l[2]))
		if who == null:
			continue
		var text: String = l[1]
		var w := who
		get_tree().create_timer(float(l[2])).timeout.connect(func():
			if is_instance_valid(w) and w.state not in ["winded", "scrap", "confront"]:
				w.say_aloud(text, 3.5))
	if m.has("chalk_one") and cast["any"]:
		load("res://scripts/wear.gd").dust(cast["any"]._figure, 40.0)
	var body := m.duplicate()
	body.erase("choice")
	fx(body)
	if m.has("choice"):
		_last_choice = Meet.clock
		var title: String = m["banner"][0].capitalize() if m.has("banner") else "Something's happening"
		var ch: Array = m["choice"]
		get_tree().create_timer(last + 1.6).timeout.connect(func():
			if not Meet.modal and not main.invaded():
				_ask(title, ch))
	return true

func _ask(title: String, ch: Array) -> void:
	var opts: Array = []
	for o in ch[1]:
		var e: Dictionary = o[1]
		# A third entry is a piece of kit you must own for the option to be there at all.
		if o.size() > 2 and not Meet.owned.has(o[2]):
			continue
		opts.append([("★ " if o.size() > 2 else "") + o[0], func(): fx(e)])
	Meet.menu.choice(title, ch[0], opts)

## The effects a moment, or an answer to one, can have.
func fx(e: Dictionary) -> void:
	if int(e.get("money", 0)) < 0 and Meet.money < -int(e["money"]):
		Meet.say("You haven't got the money for that.")
		return
	if int(e.get("snacks", 0)) < 0 and Meet.snacks < -int(e["snacks"]):
		Meet.say("You haven't got a snack to spare.")
		return
	if e.has("banner"):
		Meet.hud.banner(e["banner"][0], e["banner"][1])
	if e.has("sfx"):
		Meet.sfx(e["sfx"], -6.0)
	if e.has("shake"):
		Meet.hud.shake()
	if e.has("say"):
		Meet.say(e["say"])
	if e.has("money"):
		Meet.pay(int(e["money"]))
	if e.has("snacks"):
		Meet.snacks = clamp(Meet.snacks + int(e["snacks"]), 0, 5)
	if e.has("heat"):
		Meet.add_heat(float(e["heat"]))
	if e.has("health"):
		Meet.composure = clamp(Meet.composure + float(e["health"]), 5.0, 100.0)
	if e.has("stamina"):
		Meet.stamina = clamp(Meet.stamina + float(e["stamina"]), 0.0, 100.0)
	if e.has("tip"):
		Meet.tips = min(4, Meet.tips + 1)
	if e.has("item"):
		main.drop([e["item"]], Meet.player.global_position - Meet.player.global_transform.basis.z * 1.5)
	if e.has("rep"):
		var v: float = e["rep"]
		for r in Meet.risers:
			if r.is_riser:
				r.mind.experience("helped" if v > 0.0 else "heckle", v, 1.0, false, "tonight")
	for id in e.get("feel", {}):
		var r: Node = Meet.riser(id)
		var v2: float = e["feel"][id]
		if r:
			r.mind.experience("helped" if v2 > 0.0 else "heckle", v2, 1.2, true, "tonight")
			r._mood_check = 0.0
	if e.has("tie"):
		Meet.bump(e["tie"][0], e["tie"][1], e["tie"][2])
	if e.has("dark"):
		if _lights.is_empty():
			for c in main.get_children():
				if c is OmniLight3D:
					_lights.append(c)
		for l in _lights:
			l.visible = false
		Meet.dark = float(e["dark"])
	if e.has("fog"):
		_fog = float(e["fog"])
	for i in int(e.get("flash", 0)):
		get_tree().create_timer(i * 0.9 + 0.2).timeout.connect(func():
			var fl := OmniLight3D.new()
			fl.light_color = [Color(1, 0.4, 0.4), Color(0.4, 1, 0.5), Color(0.5, 0.6, 1), Color(1, 0.9, 0.5)][randi() % 4]
			fl.light_energy = 9.0
			fl.omni_range = 60.0
			fl.position = Vector3(randf_range(-10, 10), 12, 20)
			add_child(fl)
			var tw := fl.create_tween()
			tw.tween_property(fl, "light_energy", 0.0, 0.7)
			tw.tween_callback(fl.queue_free))
	if e.has("chalk_all"):
		for r in Meet.risers:
			if not r.alien:
				load("res://scripts/wear.gd").dust(r._figure, 35.0)
		Meet.player.dusted()
	if e.has("to_gate"):
		for r in _free():
			r._go(Vector3(randf_range(-2.5, 2.5), 0, randf_range(23.2, 25.5)), "gawk")
	if e.has("scatter"):
		for r in Meet.risers:
			if r.state not in ["pull", "winded"] and not r.alien:
				r.gesture("Hit_Chest", 0.5)
				r._knock += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 2.5
	if e.has("gulls"):
		main.start_gulls()
	if e.has("camera"):
		var gc: Node = Meet.riser("george")
		if gc and gc.is_free():
			gc.camera()
			gc.gesture("Pistol_Aim_Neutral", 5.0)
	if e.has("raffle") or e.has("raffle5"):
		if randf() < (0.6 if e.has("raffle5") else 0.2):
			Meet.snacks = 5
			Meet.say("YOUR NUMBER. You win the meat tray. Kelvin is looking at you the way a dog looks at a door.")
			var k: Node = Meet.riser("kelvin")
			if k:
				k.say_aloud("Nine tickets. NINE.", 4.0)
		else:
			Meet.say("Kelvin wins the meat tray. Kelvin always wins the meat tray.")
	if e.has("stir"):
		main.stir(Vector3(0, 0, 3), e["stir"], 34.0, 0.55, false)
	if e.has("gesture"):
		var g: Array = e["gesture"]
		for r in Meet.risers:
			if r.alien or r.state in ["pull", "winded", "scrap", "confront", "ride"]:
				continue
			if g[0] == "all" or g[0] == r.id or (g[0] == "keen" and (r.mind.chatty > 0.5 or r.mood_level() >= 1 or r.passer)):
				r.gesture(g[1], float(g[2]))
	for i in int(e.get("runners", 0)):
		_runner(i)
	if e.has("pickup"):
		var p: Array = e["pickup"]
		var a := randf() * TAU
		var then: Dictionary = p[2]
		main.pickup(p[0], main.clear(Vector3(cos(a) * randf_range(3, 8), 0, sin(a) * randf_range(3, 8) + 3.0)), p[1], func(): fx(then))
	if e.has("choice"):
		_ask("Well?", e["choice"])
	Meet.touch_state()

## A stranger who comes in for one scene, says their piece, and wanders off again.
func _walkon(w: Dictionary) -> Node:
	_walk_n += 1
	var female: bool = w.get("female", false)
	var d := {"id": "w_%d" % _walk_n, "name": w["name"], "role": w["role"], "strength": w.get("strength", 58), "pace": 1.5, "stops": 0.0, "likes": "dare",
		"look": {"body": "Female_Ranger" if female else "Male_Ranger", "hair": "Hair_Long" if female else "Hair_SimpleParted", "tint": w.get("tint", Color(0.7, 0.7, 0.7))},
		"mind": {"warmth": 0.1}, "chat": w["lines"]}
	var r: Node3D = load("res://scripts/riser.gd").new()
	main.add_child(r)
	r.setup(d, false, Vector3.ZERO)
	r.pass_by(1.0)
	r.global_position = Vector3(randf_range(-2, 2), 0, 26.5)
	if w.get("small", false):
		r._figure.scale = Vector3(0.6, 0.6, 0.6)
	Meet.risers.append(r)
	r._go(Vector3(randf_range(-4, 4), 0, randf_range(10.0, 12.5)), "gawk")
	var lines: Array = w["lines"]
	r.say_aloud(lines[0], 4.5)
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(r):
			r.say_aloud(lines[1], 4.5))
	return r

## Somebody running straight through the middle of the meet.
func _runner(i: int) -> void:
	_walk_n += 1
	var d := {"id": "w_%d" % _walk_n, "name": "A runner", "role": "Passing through", "strength": 50, "pace": randf_range(4.0, 5.5), "stops": 0.0,
		"look": {"body": "Female_Ranger" if i % 2 else "Male_Ranger", "hair": "Hair_Buns" if i % 2 else "Hair_Buzzed", "tint": Color.from_hsv(randf(), 0.6, 1.0)}, "mind": {}, "chat": ["Can't stop!", "On your left!"]}
	var r: Node3D = load("res://scripts/riser.gd").new()
	main.add_child(r)
	r.setup(d, false, Vector3.ZERO)
	r.pass_by(1.0 if i % 2 == 0 else -1.0)
	r._lane = randf_range(1.0, 9.0)
	r.global_position = Vector3(-30.0 * r._dir - i * 1.6 * r._dir, 0, r._lane)
	Meet.risers.append(r)

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
	Meet.dark = 22.0
	Meet.hud.banner("POWER CUT", "Pitch black. Nobody can see what you do. A glow stick is all the light there is.")
	var tm: Node = Meet.riser("tommy")
	if tm:
		tm.glow(22.0)
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
	th.hittable(func(_d: int):
		if _possum == null:
			return
		Meet.sfx("squeak", 0.0, 1.5)
		Fx.burst(main, th.position, Vector3.UP, false, 8)
		_possum = null
		th.remove_from_group("interact")
		th.remove_from_group("hittable")
		Meet.player.target = null
		th.queue_free()
		Meet.hud.banner("YOU HIT THE POSSUM", "It is a protected species. Everyone is looking at you.")
		Meet.add_heat(1.6, "hitting a possum")
		for r in Meet.risers:
			if r.is_riser or r.post:
				r.mind.experience("violence", -0.35, 1.2, true, "the possum")
				r._mood_check = 0.0
		var lu: Node = Meet.riser("luie")
		if lu:
			lu.say_aloud("...It was just a possum.", 5.0)
		main.stir(main.SNACKS, ["A POSSUM?!", "What is WRONG with you?", "It had little hands!", "That's a fine. That's an actual fine."], 30.0, 0.9, false)
		Meet.ripple("You hit a possum. A possum."))
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

# --- The people at their posts ----------------------------------------------------------------------

## Dee plays. People nearby who are that way inclined dance.
func busk(for_tommy := false) -> void:
	_busk = 9.0
	var dee: Node = Meet.riser("s_busker")
	if dee:
		dee.gesture("Dance", 8.0)
	Meet.sfx("item", -6.0, 0.8)
	for r in Meet.risers:
		if r.passer and r.global_position.distance_to(BUSKER) < 14.0:
			r.gesture("Dance", 4.0)
	if for_tommy:
		var t: Node = Meet.riser("tommy")
		if t:
			t.say_aloud("...That's my song. She's playing MY SONG.", 6.0)
			t.gesture("Dance", 7.0)
			t.mind.experience("helped", 0.8, 2.0, true, "the song")
			Meet.hud.banner("EYE OF THE TIGER (SLOW)", "Tommy has gone very quiet. He might be crying.")
			Meet.ripple("You got the busker to play Tommy's real request.")

## Con's float bobs; now and then it goes under and he lands one.
func _run_fishing(dt: float) -> void:
	if _float == null:
		return
	_bite -= dt
	_float.position.y = -0.3 + sin(Meet.clock * 2.2) * 0.04 - (0.25 if _bite < 1.2 else 0.0)
	_rod.rotation.x = 0.95 + (sin(Meet.clock * 22.0) * 0.06 if _bite < 1.2 else 0.0)
	if _bite > 0.0:
		return
	_bite = randf_range(32.0, 60.0)
	var con: Node = Meet.riser("s_fisher")
	if con == null or con.state != "post":
		return
	Fx.burst(main, _float.position + Vector3(0, 0.3, 0), Vector3.UP, false, 12)
	Meet.sfx("puff", -8.0, 0.6)
	con.gesture("Sword_Attack", 0.8)
	var from: Vector3 = _float.position
	var to: Vector3 = FISHER + Vector3(-0.7, 0.4, 0)
	var fish := Build.sphere(self, 0.1, from, Color(0.55, 0.7, 0.8))
	fish.scale = Vector3(0.5, 0.5, 2.0)
	var tw := create_tween()
	tw.tween_method(func(f: float):
		fish.position = from.lerp(to, f) + Vector3(0, sin(f * PI) * 2.6, 0)
		fish.rotation.x = f * 10.0, 0.0, 1.0, 0.9)
	tw.tween_callback(fish.queue_free)
	con.say_aloud(["Got one. Bream.", "There he is. ...Not Kevin.", "That's dinner. For the cat.", "Jandal. Another jandal.", "HA. Thirty years and it never gets old."][randi() % 5], 4.0)
	if Meet.player.global_position.distance_to(FISHER) < 12.0:
		main.stir(FISHER, ["Nice one, Con!", "What is it?", "Throw it back!"], 12.0, 0.4, false)

# --- A Gripling ----------------------------------------------------------------------------------------

func _m_critter() -> void:
	if _critter != null or Meet.owned.has("gripling"):
		return
	var th := Thing.new()
	main.add_child(th)
	th.position = main.ground(Vector3(randf_range(-6, 6), 0, randf_range(8, 14)))
	th.add_child(load("res://scripts/wear.gd").gripling())
	_critter = th
	_critter_t = 55.0
	_critter_goal = th.position
	Meet.hud.banner("WHAT IS THAT?", "Small, orange, round. One arm much too big for it.")
	Meet.sfx("boing", -4.0, 1.5)
	main.stir(th.position, ["What IS that?", "It's got an arm on it.", "Don't touch it.", "It's flexing at me."], 14.0, 0.6, false)
	th.setup("Try to catch the Gripling", func():
		if not Meet.owned.has("catch_ball"):
			Meet.say("It looks at your empty hands, flexes its one big arm at you, and hops out of reach. You'd need something to catch it with. Old Con might know.")
			_critter_goal = main.clear(th.position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
			return
		Meet.strapgame.start(func(hits: int):
			if hits >= 2:
				th.remove_from_group("interact")
				Meet.player.target = null
				_critter = null
				Fx.burst(main, th.position + Vector3(0, 0.4, 0), Vector3.UP, false, 20)
				th.queue_free()
				Meet.sfx("win")
				Meet.hud.banner("GOTCHA", "The Gripling climbs onto your shoulder and arm wrestles your ear.")
				Meet.grant("gripling")
				Meet.ripple("You caught a Gripling. Nobody knows what a Gripling is.")
			else:
				Meet.say("The ball bounces off its arm. It looks offended.")
				_critter_goal = main.clear(th.position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))), "Throw the catch-ball", ["Wind up...", "Lead it...", "THROW"]))

func _run_critter(dt: float) -> void:
	if _critter == null:
		return
	_critter_t -= dt
	var to := _critter_goal - _critter.position
	to.y = 0
	if to.length() < 0.4:
		if randf() < dt * 0.5:
			_critter_goal = main.clear(_critter.position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		_critter.position.y = main.height(_critter.position.x, _critter.position.z)
	else:
		_critter.position += to.normalized() * 3.2 * dt
		_critter.position.y = main.height(_critter.position.x, _critter.position.z) + absf(sin(Meet.clock * 11.0)) * 0.35
		_critter.rotation.y = atan2(to.x, to.z)
	if _critter_t <= 0.0:
		Meet.say("The Gripling hops over the sea wall and is gone. It'll be back.")
		_critter.queue_free()
		_critter = null

# --- Someone in the water --------------------------------------------------------------------------------

func _m_swimmer() -> void:
	if _swimmer != null:
		return
	var x := randf_range(-10.0, 8.0)
	_swimmer = Node3D.new()
	main.add_child(_swimmer)
	_swimmer.position = Vector3(x, -0.55, 32.5)
	Build.sphere(_swimmer, 0.16, Vector3(0, 0.5, 0), Color(0.82, 0.64, 0.5))
	for sx in [-1.0, 1.0]:
		Build.cyl(_swimmer, 0.04, 0.04, 0.5, Vector3(sx * 0.28, 0.7, 0), Color(0.82, 0.64, 0.5), 6).rotation.z = sx * 0.5
	_swim_t = 40.0
	Meet.hud.banner("SOMEONE'S IN THE WATER", "Off the sea wall. Arms going. Not waving.")
	Meet.sfx("ooh")
	main.stir(Vector3(x, 0, 28), ["Someone's gone in!", "Can they swim?", "Get something that floats!", "CON! Your rod!"], 40.0, 0.8, false)
	var th := Thing.new()
	_swimmer.add_child(th)
	th.position = Vector3(0, 0.55, -3.9)
	th.setup("Help the person in the water", func():
		var opts: Array = []
		if Meet.owned.has("pool_noodle"):
			opts.append(["★ Throw them the pool noodle", func(): _rescue("You wind up and throw the pool noodle like a javelin. It lands across their arms. They hug it like a long-lost friend and kick to the wall.", 0.6, true)])
		if Meet.owned.has("balloon"):
			opts.append(["★ Throw them the balloon", func(): _rescue("It's not much. It's a balloon. They cling to it with total commitment and somehow that's enough.", 0.4, true)])
		opts.append(["Jump in after them  (costs health)", func():
			Meet.composure = max(10.0, Meet.composure - 35.0)
			Meet.stamina = max(0.0, Meet.stamina - 50.0)
			_rescue("You go over the rail. The water is every bit as cold as it looks. You haul them to the wall and Con pulls you both out with the gaff.", 0.7, true)])
		opts.append(["Shout for Old Con", func(): _rescue("Con has them out in ten seconds with a landing net. \"Third one this year.\"", 0.1, false)])
		Meet.menu.choice("Someone's in the water", "They've gone in off the sea wall and they're not doing well.", opts))

func _rescue(text: String, rep: float, hero: bool) -> void:
	if _swimmer == null:
		return
	_swimmer.queue_free()
	_swimmer = null
	Meet.player.target = null
	Meet.say(text)
	if hero:
		Meet.saved += 1
		Meet.saved_total += 1
		Meet.milestones()
		Meet.hud.banner("RESCUED", "The whole meet is clapping. Even Phillip.")
		Meet.sfx("win")
		Meet.add_heat(-2.0)
		Meet.pay(10, "The person you pulled out insists.")
		Meet.ripple("You pulled someone out of the bay.")
		Meet.dare("rescue")
	for r in Meet.risers:
		if r.is_riser or r.post:
			r.mind.experience("helped", rep, 1.8, true, "the rescue")
			r._mood_check = 0.0
	main.stir(Meet.player.global_position, ["HERO!", "Did you SEE that?", "Somebody get them a towel.", "That's a Riser, that is."], 30.0, 0.8, true)

func _run_swimmer(dt: float) -> void:
	if _swimmer == null:
		return
	_swim_t -= dt
	_swimmer.position.y = -0.55 + sin(Meet.clock * 5.0) * 0.12
	_swimmer.rotation.y += dt * 2.0
	if _swim_t <= 0.0:
		_rescue("Old Con gets them with the landing net in the end. He looks at you for a long moment.", -0.15, false)

# --- Visiting legends -----------------------------------------------------------------------------------
# Both are made up. Any resemblance to the real greats of the sport is affectionate.

func _legend(key: String, d: Dictionary, scale: float) -> Node:
	for l in _legends:
		if is_instance_valid(l) and l.legend == key:
			return null
	var r: Node3D = load("res://scripts/riser.gd").new()
	main.add_child(r)
	r.setup(d, false, Vector3.ZERO)
	r.legend = key
	r.pass_by(1.0)
	r._stops = false
	r.global_position = Vector3(0, 0, 26.0)
	r._figure.scale = Vector3(scale, scale, scale)
	Meet.risers.append(r)
	_legends.append(r)
	r._go(Vector3(randf_range(-1.5, 1.5), 0, 9.5), "gawk")
	r._timer = 80.0
	main.stir(Vector3(0, 0, 14), ["Is that...?", "No. NO. It can't be.", "It IS.", "Somebody pinch me.", "George. GEORGE. Camera."], 40.0, 0.9, true)
	for m in main._matches.duplicate():
		main.drop_match(m["a"])
	return r

func _m_legend_don() -> void:
	var r := _legend("don", {"id": "l_don", "name": "Big Don from Ottawa", "role": "Fourteen-time world champion. Will tell you about it.", "strength": 97, "pace": 1.6, "stops": 0.0, "likes": "dare",
		"look": {"body": "Male_Peasant", "hair": "Hair_Long", "beard": true, "tint": Color(0.85, 0.15, 0.15), "build": 0.95}, "mind": {"warmth": 0.4, "chatty": 1.0, "open": 1.4},
		"chat": ["I'm going to pull every one of you. Then the table. Then whoever built the table.", "Arm wrestling is ninety percent talking. I've done the maths. Out loud. For hours.", "You know what your problem is? I don't either, but give me ten minutes.", "I once pulled for six hours straight. Nobody asked me to. Nobody could stop me."]}, 1.12)
	if r == null:
		return
	Meet.hud.banner("NO WAY", "Big Don from Ottawa has just walked through the gate. Talking.")
	Meet.sfx("win", -4.0)
	r.say_aloud("Is this the place? This is the place. Who's first? Everybody's first.", 6.0)
	for l in [["harry", "Mr... Don. Sir. Welcome. It's an honour.", 3.0], ["tommy", "I have all your videos. ALL of them.", 5.0], ["erick", "Pull me. Pull me right now.", 6.5], ["phillip", "...Wow.", 8.0]]:
		var w: Node = Meet.riser(l[0])
		var text: String = l[1]
		if w:
			get_tree().create_timer(float(l[2])).timeout.connect(func():
				if is_instance_valid(w):
					w.say_aloud(text, 3.5))

func _m_legend_lasha() -> void:
	var r := _legend("lasha", {"id": "l_lasha", "name": "Lasha the Giant", "role": "From Georgia. Says very little. Needs to say very little.", "strength": 118, "pace": 1.0, "stops": 0.0, "likes": "food",
		"look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.15, 0.15, 0.18), "build": 1.3}, "mind": {"warmth": 0.3, "chatty": 0.1},
		"chat": ["Hello.", "Strong table.", "Good snacks.", "...Yes."]}, 1.45)
	if r == null:
		return
	Meet.hud.banner("THE GROUND IS SHAKING", "Lasha the Giant has ducked under the gate.")
	Meet.sfx("crash", -4.0, 0.6)
	Meet.hud.shake()
	r.say_aloud("Hello.", 4.0)
	for l in [["kelvin", "He's... he's bigger than me. Nobody's bigger than me.", 2.5], ["bhavya", "His wrist is the size of my head. I have no notes.", 4.5], ["phillip", "Finally. Someone normal.", 6.5], ["tommy", "I'm going to ask him to lift me.", 8.0]]:
		var w: Node = Meet.riser(l[0])
		var text: String = l[1]
		if w:
			get_tree().create_timer(float(l[2])).timeout.connect(func():
				if is_instance_valid(w):
					w.say_aloud(text, 3.5))

## What you can do with a legend, offered when you talk to one.
func legend_options(r: Node) -> Array:
	if r.legend == "oz":
		return [
			["Shake his hand", func():
				r.gesture("Interact", 1.2)
				Meet.player.act("Interact", 1.2)
				Meet.composure = max(5.0, Meet.composure * 0.5)
				Meet.hud.shake()
				Meet.sfx("crash", -4.0, 1.4)
				Meet.hud.banner("THE HANDSHAKE", "You hear it before you feel it. Half your health, gone.")
				r.say_aloud("Good grip. For a Riser.", 4.0)
				Meet.touch_state()
				if not r._asked.has("shake"):
					r._asked["shake"] = true
					r.mind.experience("talk", 0.4, 1.0)
					for f in Meet.risers:
						if f.is_riser:
							f.mind.experience("helped", 0.1, 0.4, false, "shaking Oz's hand")],
			["\"Pull me.\"", func():
				r.say_aloud("That's the spirit. Hand on the pad.", 3.5)
				Meet.table.start(r)],
			["Ask about the Spartans", func():
				Meet.tips = min(4, Meet.tips + 1)
				r.say_aloud("We train back pressure till it's boring. Then we train it more.", 5.0)
				Meet.say("He shows you one thing with your wrist. One. It changes everything. (The gold zone is a little wider for good.)")],
			["\"Risers would take the Spartans any day.\"", func():
				r.say_aloud("Ha! Bring eight. I'll bring two.", 4.5)
				Meet.main.stir(r.global_position, ["OOOH.", "We would!", "...Would we?", "Don't write cheques, mate."], 20.0, 0.8, false)
				for f in Meet.risers:
					if f.is_riser:
						f.mind.experience("talk", 0.2, 0.5, false, "sticking up for the club")]]
	if r.legend == "don":
		return [
			["\"Pull me.\"", func():
				r.say_aloud("YES. Finally. Somebody with questionable judgement.", 3.5)
				Meet.table.start(r)],
			["Ask for one piece of advice", func():
				Meet.stamina = max(0.0, Meet.stamina - 30.0)
				Meet.tips = min(4, Meet.tips + 2)
				Meet.hud.banner("FORTY MINUTES LATER", "He is still talking. You have learned a great deal.")
				Meet.say("It covered wrist height, breathing, his diet in 2009, and a man called Gerry. You feel older. Your gold zone is wider for good.")],
			["Ask him to sign something", func():
				r.gesture("Interact", 1.2)
				if Meet.grant("signed_band"):
					Meet.say("He takes the headband off his own head, signs it, and puts it on yours. It's still warm. He's already talking again.")
				else:
					Meet.say("He signs your forearm. \"Don't wash that.\"")],
			["Trash talk him", func():
				Meet.composure = max(10.0, Meet.composure - 20.0)
				Meet.hud.banner("DESTROYED", "He had four minutes of material ready. About you. Specifically.")
				main.stir(r.global_position, ["OHHHH!", "He's been ROASTED.", "Sit down. Just sit down.", "That was art."], 20.0, 0.9, false)
				r.mind.experience("talk", 0.3, 0.8)]]
	return [
		["\"Pull me.\"", func():
			if Meet.worn["hand"] == "golden_grip":
				r.strength = 86.0
				r.say_aloud("...Interesting glove.", 3.5)
			else:
				r.say_aloud("Okay.", 3.0)
			Meet.table.start(r)],
		["Shake his hand", func():
			Meet.composure = max(10.0, Meet.composure - 10.0)
			r.gesture("Interact", 1.2)
			Meet.hud.shake()
			Meet.say("Your hand disappears up to the wrist. He is being gentle. It still makes a noise.")
			for f in Meet.risers:
				if f.is_riser:
					f.mind.experience("helped", 0.12, 0.4, false, "the handshake")],
		["Offer him a snack", func():
			if Meet.snacks <= 0:
				Meet.say("You've nothing to offer. He looks at the snack table. The snack table looks nervous.")
				return
			Meet.snacks = 0
			r.mind.experience("gift", 0.8, 2.0)
			Meet.touch_state()
			r.say_aloud("Thank you. ...All of them? Thank you.", 4.0)
			var k: Node = Meet.riser("kelvin")
			if k:
				k.say_aloud("He ate five in one hand. I've found my people.", 5.0)
			Meet.say("He eats every snack you own, with great courtesy, and nods at you. From him that's a speech.")],
		["Ask him to lift you", func():
			r.gesture("Sword_Attack", 0.8)
			Meet.player.launch()
			Meet.hud.banner("UP", "One hand. He isn't even looking.")
			main.stir(r.global_position, ["HAHA!", "Do me next!", "He's not even trying.", "Put them down gently!"], 20.0, 0.8, false)]]

func legend_result(r: Node, won: bool) -> void:
	if won:
		Meet.hud.banner("YOU BEAT A LEGEND", "%s is laughing. Everyone else has gone silent." % r.riser_name)
		Meet.points += 10
		for f in Meet.risers:
			if f.is_riser:
				f.mind.experience("match", 0.6, 2.0, false, "beating %s" % r.riser_name)
		Meet.ripple("You beat %s at the table. Nobody will believe it." % r.riser_name)
		if r.legend == "lasha":
			Meet.grant("giant_band")
	else:
		Meet.say("%s pins you before 'go' has finished echoing. Everyone claps anyway: you asked." % r.riser_name)
		for f in Meet.risers:
			if f.is_riser:
				f.mind.experience("match", 0.15, 0.5, false, "having a go")
		if r.legend == "lasha" and randf() < 0.5:
			r.say_aloud("Good. Brave.", 4.0)
			Meet.grant("giant_band")

# --- What comes out of the bay ---------------------------------------------------------------------------

func start_kaiju() -> void:
	if _kaiju_state != "" or main.invaded():
		return
	_kaiju_state = "rise"
	_kaiju_t = 0.0
	_kaiju_dmg = 0.0
	_kaiju = Node3D.new()
	main.add_child(_kaiju)
	_kaiju.position = Vector3(0, -26.0, 52.0)
	var c := Color(0.12, 0.42, 0.4)
	Build.box(_kaiju, Vector3(11, 15, 8), Vector3(0, 9, 0), c)
	Build.box(_kaiju, Vector3(6.5, 5, 6), Vector3(0, 19, 1.0), c * 1.1)
	Build.box(_kaiju, Vector3(5.5, 1.2, 4.5), Vector3(0, 16.9, 2.6), c * 0.7)
	for sx in [-1.0, 1.0]:
		Build.sphere(_kaiju, 0.7, Vector3(sx * 1.7, 20.2, 3.9), Color(1.0, 0.85, 0.2), 3.0)
		Build.box(_kaiju, Vector3(3.5, 9, 4), Vector3(sx * 3.4, -2, 0), c * 0.85)
	for i in 6:
		Build.cyl(_kaiju, 0.0, 1.1, 3.2, Vector3(0, 21.5 - i * 3.2, -3.6 - (0.6 if i > 2 else 0.0)), c * 1.4, 5)
	# One arm, enormous. The other one is an afterthought.
	_hand = Node3D.new()
	_kaiju.add_child(_hand)
	_hand.position = Vector3(5.6, 13.0, 2.0)
	Build.cyl(_hand, 1.6, 2.2, 9.0, Vector3(1.4, -3.4, 2.6), c * 0.95, 8).rotation = Vector3(0.9, 0, -0.35)
	Build.cyl(_hand, 1.4, 1.7, 9.0, Vector3(2.0, -7.0, 8.6), c * 0.9, 8).rotation = Vector3(1.75, 0, 0)
	Build.sphere(_hand, 2.3, Vector3(2.0, -8.0, 13.6), c * 1.2)
	Build.box(_kaiju, Vector3(1.6, 5, 1.6), Vector3(-6.0, 9.5, 2.0), c * 0.9).rotation.x = 0.8
	Meet.hud.banner("THE WATER IS GOING OUT", "All of it. Old Con has stopped fishing. Old Con has never stopped fishing.")
	Meet.sfx("rumble", 0.0)
	Meet.hud.shake()
	for m in main._matches.duplicate():
		main.drop_match(m["a"])
	main.stir(Vector3(0, 0, 20), ["What's happening to the bay?", "Why is it so quiet?", "...Something's coming up.", "Everybody off the sea wall. NOW."], 60.0, 0.9, false)

func _run_kaiju(dt: float) -> void:
	if _kaiju_state == "":
		return
	_kaiju_t += dt
	match _kaiju_state:
		"rise":
			_kaiju.position = _kaiju.position.move_toward(Vector3(0, -3.0, 39.0), dt * 5.5)
			if fmod(_kaiju_t, 1.3) < dt:
				Meet.hud.shake()
				Meet.sfx("crash", -6.0, 0.5)
			if _kaiju.position.distance_to(Vector3(0, -3.0, 39.0)) < 0.2:
				_kaiju_state = "wave"
				_kaiju_t = 0.0
				Meet.hud.banner("WAVE", "Hold on to something. Not the snack table.")
				Meet.sfx("crash")
				var wm := BoxMesh.new()
				wm.size = Vector3(70, 3.2, 3.0)
				_wave = MeshInstance3D.new()
				_wave.mesh = wm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.25, 0.5, 0.75, 0.8)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_wave.material_override = mat
				main.add_child(_wave)
				_wave.position = Vector3(0, 1.4, 31.0)
		"wave":
			_wave.position.z -= dt * 13.0
			for r in Meet.risers:
				if not r.alien and absf(r.global_position.z - _wave.position.z) < 1.4 and r.state != "pull":
					r._knock += Vector3(0, 0, -7.0)
					r.gesture("Hit_Chest", 0.6)
					Fx.tint(r._figure, Color(0.3, 0.55, 0.9, 0.45), 8.0)
			var p: Node3D = Meet.player
			if absf(p.global_position.z - _wave.position.z) < 1.4 and p.global_position.y < 100.0:
				p.slapped(6.0, p.global_position + Vector3(0, 0, 3), null)
				p.splatted()
			if _wave.position.z < -14.0:
				# The wave takes someone who was standing too near the wall.
				var near: Array = Meet.risers.filter(func(r): return r.is_riser and not r.dead and r.state != "pull")
				near.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)
				if not near.is_empty():
					near[0].die("the wave")
				_wave.queue_free()
				_wave = null
				main._free_snacks = 0
				_kaiju_state = "dare"
				_kaiju_t = 0.0
				Meet.hud.banner("IT PUTS ITS ELBOW ON THE SEA WALL", "One arm, the size of a bus. It is looking at the tables. It wants a pull.")
				Meet.sfx("ooh")
				var th := Thing.new()
				_kaiju.add_child(th)
				th.global_position = main.ground(Vector3(2.0, 0, 28.3))
				th.name = "Offer"
				th.setup("Walk up to the thing from the bay", _kaiju_offer)
				main.stir(Vector3(0, 0, 20), ["It wants to PULL?", "Not it.", "I'm not chalked for this.", "Somebody has to.", "%s. You're up." % Meet.you("New one").capitalize()], 60.0, 0.9, true)
		"dare":
			_kaiju.position.y = -3.0 + sin(_kaiju_t * 0.8) * 0.4
			if _kaiju_t > 75.0 and not Meet.modal:
				_kaiju_leave("Nobody steps up. The thing from the bay waits, sighs a sigh that flattens the lawn, and goes back under. Harry: \"We could have had it.\"")
		"sink":
			_kaiju.position.y -= dt * 6.0
			if _kaiju.position.y < -40.0:
				_kaiju.queue_free()
				_kaiju = null
				_kaiju_state = "done"

## The ray gun against the thing from the bay: every shot that lands weakens its arm.
func kaiju_shot(from: Vector3, flat: Vector3) -> Vector3:
	if _kaiju == null or _kaiju_state not in ["rise", "wave", "dare"]:
		return Vector3.ZERO
	var to: Vector3 = _kaiju.global_position - from
	if flat.dot(Vector3(to.x, 0, to.z).normalized()) < 0.8:
		return Vector3.ZERO
	var at: Vector3 = _kaiju.global_position + Vector3(randf_range(-3, 3), randf_range(10, 20), 3.5)
	_kaiju_dmg = min(24.0, _kaiju_dmg + 6.0)
	Fx.burst(main, at, Vector3.UP, false, 26)
	Meet.sfx("crash", -6.0, 1.3)
	Meet.hud.shake()
	Meet.hud.banner("IT FELT THAT", "Scorched. It is %d%% weaker for the pull." % int(_kaiju_dmg / 138.0 * 100.0) if _kaiju_dmg < 24.0 else "It can't get any more scorched than that.")
	return at

## Everything that counts for you, and how much.
func kaiju_odds() -> Array:
	var lines: Array = []
	var prep := 0.0
	var mates: Array = Meet.risers.filter(func(r): return r.is_riser and r.mood_level() >= 1)
	if not mates.is_empty():
		prep += mates.size() * 5.0
		lines.append("%s on the rope behind you" % ", ".join(mates.map(func(r): return r.first_name)))
	for it in [["golden_grip", 16.0, "the Golden Grip"], ["gripling", 5.0, "the Gripling, flexing"], ["raygun", 4.0, "the ray gun"], ["belt", 3.0, "the belt"], ["bracket_cup", 3.0, "the cup"], ["katana_88", 3.0, "the katana"], ["catch_ball", 2.0, "the catch-ball"]]:
		if Meet.owned.has(it[0]):
			prep += it[1]
			lines.append(it[2])
	if Meet.lions > 0:
		prep += Meet.lions * 6.0
		lines.append("%d stone lion%s roaring" % [Meet.lions, "" if Meet.lions == 1 else "s"])
	if Meet.chalked:
		prep += 3.0
		lines.append("chalk")
	if Meet.pump > 0:
		prep += Meet.pump * 2.0
		lines.append("a pump")
	prep += Meet.tips * 1.5
	if _kaiju_dmg > 0.0:
		prep += _kaiju_dmg
		lines.append("ray-gun burns all down its arm")
	if Meet.saved > 0:
		prep += 4.0
		lines.append("the bay owes you one")
	for l in _legends:
		if is_instance_valid(l):
			prep += 12.0
			lines.append(l.riser_name)
	return [clamp(138.0 - prep, 62.0, 138.0), lines]

func _kaiju_offer() -> void:
	var o := kaiju_odds()
	var st: float = o[0]
	var verdict := "You might actually do this." if st < 82.0 else ("It'll be close. It'll be very close." if st < 100.0 else "This is hopeless. You have almost nothing.")
	Meet.menu.choice("The thing from the bay", "Its hand is open on the sea wall, palm up, each finger the size of a puller.\n\nWith you: %s.\n\n%s" % [", ".join(o[1]) if not o[1].is_empty() else "nobody and nothing", verdict], [
		["Put your hand in its hand", func():
			_kaiju_r = load("res://scripts/riser.gd").new()
			main.add_child(_kaiju_r)
			_kaiju_r.setup({"id": "kaiju", "name": "The Thing From The Bay", "role": "", "strength": st, "look": {"body": "Male_Peasant"}, "mind": {}}, false, Vector3(0, -50, 60))
			_kaiju_r.visible = false
			_kaiju_r.remove_from_group("interact")
			_kaiju_r.remove_from_group("hittable")
			Meet.player.global_position = main.ground(Vector3(2.0, 0, 28.3))
			Meet.player.rotation.y = PI
			for r in Meet.risers:
				if r.is_riser and r.mood_level() >= 1:
					r._go(Vector3(2.0 + randf_range(-2.5, 2.5), 0, 26.0 - randf() * 2.0), "gawk")
			Meet.table.start(_kaiju_r)],
		["Back away slowly", func(): Meet.say("It watches you go. It is not going anywhere.")]])

func kaiju_result(won: bool) -> void:
	if is_instance_valid(_kaiju_r):
		_kaiju_r.queue_free()
	if won:
		Meet.hud.banner("PINNED", "Its knuckles hit the paving. The bay goes flat as glass.")
		Meet.sfx("win")
		Meet.points += 15
		Meet.add_heat(-5.0)
		for r in Meet.risers:
			if r.is_riser or r.post:
				r.mind.experience("helped", 0.8, 3.0, true, "the thing from the bay")
				r._mood_check = 0.0
				r.gesture("Dance", 6.0)
		Meet.ripple("You arm wrestled a sea monster for Rhodes, and won.")
		main.drop(["kaiju_claw"], Vector3(2.0, 0, 26.8))
		_kaiju_leave("It bows its enormous head, leaves something on the sea wall, and walks back into the bay.")
	else:
		_kaiju_state = "sink"
		Meet.hud.night_over("It pins you so hard the sea wall cracks.\n\nThen it stands, stretches, and the second wave takes the tables, the snacks, the chalk bucket and you. You are found at dawn in Meadowbank, holding a strap.\n\nYou needed more on your side: founders who like you, the right kit, a lion or two. It will be back.", "WASHED AWAY")

func _kaiju_leave(text: String) -> void:
	Meet.say(text)
	if _kaiju.has_node("Offer"):
		_kaiju.get_node("Offer").queue_free()
	Meet.player.target = null
	_kaiju_state = "sink"

func _m_gale() -> void:
	Meet.wind = 32.0
	Meet.hud.banner("WIND", "A proper one, off the bay. Banners straight out. Hats gone.")
	Meet.sfx("puff", 0.0, 0.5)
	Meet.touch_state()
	main.stir(Vector3(0, 0, 4), ["My hat!", "Hold the tables!", "It's blowing the chalk to Meadowbank!", "Lean into it!"], 40.0, 0.7, false)
	if Meet.owned.has("balloon"):
		Meet.say("It's windy enough that a balloon would take your weight. Put it in your hand and hold jump.")

func _merch() -> void:
	var opts: Array = []
	for id in Meet.ITEMS:
		var it: Dictionary = Meet.ITEMS[id]
		if it.get("src", "") == "merch" and not Meet.owned.has(id):
			var price: int = it["price"]
			opts.append(["%s  ($%d)" % [it["name"], price], func():
				if Meet.money < price:
					Meet.say("That's $%d and you have $%d." % [price, Meet.money])
					return
				Meet.pay(-price)
				Meet.grant(id)
				var g: Node = Meet.riser("george")
				if g:
					g.mind.experience("gift", 0.3, 0.8, true, "buying merch")
					g.say_aloud(["A sale! An actual sale!", "That's the tin sorted for a week.", "Wear it with pride."][randi() % 3], 4.0)])
	if opts.is_empty():
		Meet.say("You've bought everything on the table. George is thinking about a second table.")
		return
	opts.append(["(Just looking.)", func(): pass])
	Meet.menu.choice("Club merch", "George's handwriting: 'ALL PROFITS TO THE TIN'. You have $%d." % Meet.money, opts)

func _m_lostprop() -> void:
	var id: String = Meet.unowned("lost")
	if id == "":
		_m_fiver()
		return
	var a := randf() * TAU
	var r := randf_range(5.0, 16.0)
	main.drop([id], main.clear(Vector3(cos(a) * r, 0, absf(sin(a)) * r + 3.0)))
	Meet.say("Somebody has left something behind on the grounds. Lost property is finders keepers here.")

# --- Oz ---------------------------------------------------------------------------------------------------

func _m_oz() -> void:
	var r := _legend("oz", {"id": "l_oz", "name": "Oz from the Sydney Spartans", "role": "Came across town for this", "strength": 106, "pace": 1.5, "stops": 0.0, "likes": "dare",
		"look": {"body": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.1, 0.1, 0.12), "build": 1.25}, "mind": {"warmth": 0.3, "chatty": 0.6},
		"chat": ["Spartans send their regards. And their heavyweights.", "Good room. Good energy. Who's your strongest?", "You lot pull light. Come to a Spartans night. Bring a spare elbow."]}, 1.22)
	if r == null:
		return
	Meet.hud.banner("OZ IS HERE", "From the Sydney Spartans. The music changes. Nobody knows who changed it.")
	Meet.audio.interlude("music4", 28.0)
	r.say_aloud("Evening, Risers. Tables. Now. All of them.", 5.0)
	# Everybody who can is on a table within seconds.
	var free: Array = Meet.risers.filter(func(x): return (x.is_riser or x.guest) and x.is_free() and x.tonight.get("id", "") != "sore")
	free.shuffle()
	var k := 0
	while k + 1 < free.size():
		if not main.force_match(free[k].id, free[k + 1].id):
			break
		k += 2
	for x in free.slice(k):
		x.gesture("Dance", 5.0)
	for l in [["harry", "Oz! You should have said you were coming!", 2.5], ["erick", "Spartans. Finally, a real pull.", 4.5], ["tommy", "Is the music coming from HIM?", 6.0]]:
		var w: Node = Meet.riser(l[0])
		var text: String = l[1]
		if w:
			get_tree().create_timer(float(l[2])).timeout.connect(func():
				if is_instance_valid(w):
					w.say_aloud(text, 3.5))
