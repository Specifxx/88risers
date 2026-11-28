extends Node
## Plays a night through by calling the game's own functions, and takes pictures along the way.

var _dir := ""
var _fails := 0

## --soak: let whole nights run at high speed with nobody playing, and print what happens.
func _soak() -> void:
	Meet.main.evening._moment = 20.0
	Meet.toast.connect(func(t: String): print("  [%s] %s" % [Meet.time_text().replace("Sunday ", ""), t.left(110)]))
	Meet.hud._begin()
	Meet.muted = true
	Engine.time_scale = 24.0
	var tick := 0
	while not Meet.hud._over.visible:
		tick += 1
		if tick % 8 == 0:
			print("  MON %s nodes=%d objects=%d orphans=%d risers=%d interact=%d" % [Meet.time_text(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Meet.risers.size(), get_tree().get_nodes_in_group("interact").size()])
		if Meet.menu.active():
			Meet.menu._forced = false
			Meet.menu.close()
		if Meet.table.active():
			Meet.table._finish(false)
			Meet.table._close()
		if Meet.strapgame.active():
			Meet.strapgame.tap()
		await get_tree().create_timer(1.0).timeout
	print("NIGHT OVER seen_ufo=", Meet.seen_ufo)
	Meet.save()
	get_tree().quit(0)

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--soak"):
		_soak.call_deferred()
		return
	var args := OS.get_cmdline_user_args()
	var i := args.find("--selftest")
	if i >= 0 and i + 1 < args.size():
		_dir = args[i + 1]
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(name: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])

func stand(at: Vector3, look_at: Vector3) -> void:
	var p: Node3D = Meet.player
	p.global_position = Meet.main.ground(at)
	var to := look_at - at
	p.rotation.y = atan2(-to.x, -to.z)

func _run() -> void:
	Meet.wipe()
	await wait(0.5)
	await shot("00_title")
	Meet.main.evening._moment = 99999.0
	Meet.hud._name_box.text = "Sam"
	Meet.hud._begin()
	var p: Node3D = Meet.player
	await wait(2.0)
	await shot("01_arrive")
	get_viewport().scaling_3d_scale = 0.5
	await wait(0.3)
	await shot("01a_half_res")
	get_viewport().scaling_3d_scale = 1.0
	if OS.get_cmdline_user_args().has("--quick"):
		get_tree().quit(0)
		return
	# Phone controls: a thumb on the left moves the stick; a drag on the right turns the view.
	var first := InputEventScreenTouch.new()
	first.index = 5
	first.pressed = true
	first.position = Vector2(640, 60)
	Input.parse_input_event(first)
	await wait(0.2)
	first = InputEventScreenTouch.new()
	first.index = 5
	first.pressed = false
	first.position = Vector2(640, 60)
	Input.parse_input_event(first)
	await wait(0.2)
	var tch0 := InputEventScreenTouch.new()
	tch0.index = 0
	tch0.pressed = true
	tch0.position = Vector2(260, 480)
	Input.parse_input_event(tch0)
	await wait(0.2)
	check(Meet.touch, "the first touch switches to phone controls")
	var drg0 := InputEventScreenDrag.new()
	drg0.index = 0
	drg0.position = Vector2(260, 400)
	drg0.relative = Vector2(0, -80)
	Input.parse_input_event(drg0)
	var tch1 := InputEventScreenTouch.new()
	tch1.index = 1
	tch1.pressed = true
	tch1.position = Vector2(760, 300)
	Input.parse_input_event(tch1)
	var yaw0: float = p.rotation.y
	var drg1 := InputEventScreenDrag.new()
	drg1.index = 1
	drg1.position = Vector2(700, 300)
	drg1.relative = Vector2(-60, 0)
	Input.parse_input_event(drg1)
	await wait(0.5)
	check(Meet.stick.y < -0.8 and p.rotation.y != yaw0, "left thumb pushes forward (%.2f), right drag turns the view" % Meet.stick.y)
	stand(Meet.main.NOTE_SPOTS[2] + Vector3(0, 0, 1.5), Meet.main.NOTE_SPOTS[2])
	await wait(0.4)
	await shot("01b_phone")
	for tt in [tch0, tch1]:
		var up := InputEventScreenTouch.new()
		up.index = tt.index
		up.pressed = false
		up.position = tt.position
		Input.parse_input_event(up)
	await wait(0.2)
	Meet.touch = false
	Meet.stick = Vector2.ZERO
	stand(Vector3(0, 0, 9.5), Vector3(0, 0, 0))
	await wait(14.0)
	await shot("02_plaza")
	check(Meet.dares[0]["tier"] == 0 and Meet.dares[2]["tier"] == 2, "one ordinary, one cheeky, one unhinged")
	check(Meet.dares.size() == 3, "three dares for tonight: %s" % ", ".join(Meet.dares.map(func(d): return d["text"])))
	check(Meet.riser(preload("res://scripts/people.gd").GUESTS[Meet.week() % 5]["id"]) != null, "this week's guest is here")
	for n in ["puff", "punch", "grip", "win", "coin", "murmur", "music", "bark", "gull", "ufo"]:
		Meet.audio.play(n, -40.0)
	check(Meet.audio._cache.size() >= 10, "the sounds load and play")
	check(Meet.risers.size() >= 8, "the founders are here (%d people)" % Meet.risers.size())
	await wait(16.0)
	check(Meet.main.match_on() or not Meet.results.is_empty(), "people pull at the tables without being asked")
	var states := {}
	for r in Meet.risers:
		states[r.state] = true
	check(states.size() >= 3, "people are doing different things: %s" % str(states.keys()))
	await shot("03_night")

	# Talk, snack, heckle.
	var harry: Node3D = Meet.riser("harry")
	var tommy: Node3D = Meet.riser("tommy")
	var f0: float = tommy.mind.feeling()
	tommy.interact()
	check(Meet.menu.active(), "talking to someone opens the menu")
	await wait(0.2)
	check(Meet.menu._sub.size.x > 250.0 and Meet.menu._sub.size.y < 120.0, "the attitude line has room to read across (%d x %d)" % [Meet.menu._sub.size.x, Meet.menu._sub.size.y])
	await wait(0.3)
	await shot("04_talk")
	Meet.menu._chat()
	Meet.menu._snack()
	Meet.menu._snack()
	check(tommy.mind.feeling() > f0, "a chat and snacks warm someone up (%.2f -> %.2f)" % [f0, tommy.mind.feeling()])
	Meet.menu.close()

	# Chalk: your own hands, then somebody's face.
	Meet.main._chalk_up()
	await wait(1.2)
	await shot("04b_chalking")
	await wait(1.4)
	Meet.main._chalk_take()
	Meet.main._chalk_take()
	check(Meet.chalked and Meet.chalk == 2, "chalk on the hands and two handfuls to throw")
	var luie: Node3D = Meet.riser("luie")
	stand(luie.global_position + Vector3(0, 0, 3.0), luie.global_position)
	var fl: float = luie.mind.feeling()
	p.throw_chalk()
	await wait(1.0)
	await shot("05_chalk")
	check(Meet.dusted == 1 and Meet.risers.any(func(r): return r.mind.remembers("chalk")), "thrown chalk lands and is remembered (%.2f -> %.2f)" % [fl, luie.mind.feeling()])

	# Straps: caught when the owner is looking, away with it when nobody is.
	var erick: Node3D = Meet.riser("erick")
	var bag: Vector3 = Meet.main._bags["erick"]["at"]
	stand(bag + Vector3(0.8, 0, 0), bag)
	erick.global_position = bag + Vector3(3, 0, 0)
	erick.rotation.y = atan2(-1.0, 0.0)
	Meet.main._strap_take("erick")
	check(not Meet.straps.has("erick"), "the owner watching stops you taking the strap")
	for r in Meet.risers:
		r.global_position = Meet.main.ground(Vector3(8, 0, -6))
		r.rotation.y = 0.0
	Meet.main._strap_take("erick")
	check(Meet.straps.has("erick") and Meet.straps_lifted == 1, "with nobody looking, the strap is yours")
	await shot("06_strap")
	erick.state = "idle"
	erick.go_pull(Meet.main.TABLES[0] + Vector3(-0.85, 0, 0), Meet.main.TABLES[0])
	var searched := false
	for i in 120:
		await wait(0.25)
		if erick.state == "search":
			searched = true
			break
	check(searched, "the owner goes to their bag, finds it gone and starts looking")
	await wait(1.5)
	await shot("07_search")
	erick.interact()
	Meet.menu._strap()
	check(not Meet.straps.has("erick") and not erick.strap_known_gone, "handing it back ends the search")
	Meet.menu.close()

	# Their own conversations, and what they cost.
	var bhavya: Node3D = Meet.riser("bhavya")
	bhavya.state = "idle"
	bhavya.interact()
	var topic: Dictionary = preload("res://scripts/people.gd").TALK["bhavya"].filter(func(t): return t["key"] == "form")[0]
	Meet.menu._topic(topic)
	await wait(0.2)
	await shot("07b_topic")
	Meet.menu._answer(topic["opts"][0])
	check(Meet.tips == 1, "asking Bhavya to fix one thing earns a lasting tip")
	Meet.menu.close()
	var harry2: Node3D = Meet.riser("harry")
	var george2: Node3D = Meet.riser("george")
	harry2.state = "idle"
	george2.state = "idle"
	george2.global_position = harry2.global_position + Vector3(2, 0, 0)
	var fg: float = george2.mind.feeling()
	harry2.interact()
	Meet.menu._insult({"key": "technique", "say": "x"})
	check(Meet.menu.active(), "an ordinary insult gets shrugged off")
	check(george2.mind.feeling() < fg, "George steps in for his brother (%.2f -> %.2f)" % [fg, george2.mind.feeling()])
	Meet.menu._insult({"key": "loss", "say": "x"})
	check(not Meet.menu.active() and harry2.state == "confront" and Meet.has_flag("harry", "sore"), "the sore spot ends the chat; he comes to have it out")
	Meet.modal = false
	stand(harry2.global_position + Vector3(0, 0, 1.6), harry2.global_position)
	await wait(1.0)
	check(Meet.menu.active() and Meet.menu._forced, "he forces the conversation")
	await shot("07a_confronted")
	Meet.menu._forced = false
	Meet.menu.close()
	harry2.square_up()
	Meet.modal = false
	await wait(0.8)
	check(harry2.mood_level() < 0 and harry2._name_label.text != harry2.riser_name, "his name now reads: %s" % harry2._name_label.text.replace("\n", " "))
	harry2.interact()
	check(harry2.state != "scrap", "putting your hands up in a scrap ends it, once")
	harry2.interact()
	var before_sorry: float = harry2.mind.feeling()
	Meet.snacks = 2
	Meet.menu._sorry(true)
	check(harry2.mind.feeling() > before_sorry, "an apology with a snack mends it (%.2f -> %.2f)" % [before_sorry, harry2.mind.feeling()])
	Meet.menu.close()
	Meet.snacks = 1
	Meet.notes.append({"spot": 0, "text": "Harry's left arm is a trap. Typed by hand."})
	Meet.scraps = 0
	check(Meet.stamina <= 100.0 and Meet.time_text().begins_with("Sunday 5:"), "the clock is running: %s" % Meet.time_text())
	var huddled := false
	for r in Meet.risers:
		if r.is_riser:
			r.state = "idle"
			r.global_position = Meet.main.ground(Vector3(randf_range(-5, 5), 0, randf_range(5, 8)))
	for r in Meet.risers:
		if r.is_riser and r._start_huddle():
			huddled = true
			break
	check(huddled, "people gather for a conversation of their own")
	await wait(9.0)
	stand(Vector3(0, 0, 10.5), Vector3(0, 0, 6))
	await wait(0.3)
	await shot("07c_huddle")

	# Heat, and the tools for causing it.
	Meet.heat = 0.0
	Meet.add_heat(1.2, "test")
	check(Meet.stars() == 1, "mischief raises heat: %d star" % Meet.stars())
	for r in Meet.risers:
		r.global_position = Meet.main.ground(Vector3(8, 0, -6))
		r.rotation.y = 0.0
	stand(Meet.main.CHALK + Vector3(0, 0, -1.2), Meet.main.CHALK)
	Meet.main._hide_chalk()
	check(Meet.chalk_hidden > 0.0 and not Meet.main._bucket[0].visible, "the chalk bucket can be hidden when nobody is looking")
	Meet.chalk_hidden = 0.01
	Meet.straps = ["tommy"]
	Meet.main._strap_plant("phillip")
	check(Meet.planted.get("tommy", "") == "phillip", "a strap can be planted in someone else's bag")
	var tie_tp: float = Meet.tie("phillip", "tommy")
	tommy._strap_planted()
	check(Meet.tie("phillip", "tommy") < tie_tp, "Tommy finds it in Phillip's bag and they fall out")
	Meet.worn["head"] = ""
	var line: String = Meet.riser("luie").cone_on()
	check(Meet.riser("luie").coned, "the cone goes on someone's head: %s" % line)
	Meet.menu.ladder()
	await wait(0.2)
	await shot("07f_ladder")
	check(Meet.menu.active(), "the club ladder can be read")
	Meet.menu.close()
	var d0: Dictionary = Meet.dares[0]
	Meet.dare(d0["event"], d0["arg"])
	Meet.dare(d0["event"], d0["arg"])
	Meet.night_cash = 99
	Meet.dare("cash")
	check(d0["done"], "doing what a dare says ticks it off")
	Meet.heat = 0.0

	# Talk that carries from one person to the next.
	var People2 = preload("res://scripts/people.gd")
	tommy.state = "idle"
	tommy.interact()
	var jokes: Dictionary = People2.TALK["tommy"].filter(func(t): return t["key"] == "jokes")[0]
	Meet.menu._topic(jokes)
	Meet.menu._answer(jokes["opts"][0])
	check(Meet.leads.has("joke_bhavya"), "laughing at Tommy's joke gives you something to raise with Bhavya")
	var out_good: String = tommy.react(0.6)
	var out_bad: String = Meet.riser("luie").react(-0.6)
	check(out_good != "" and Meet.riser("luie").sulking and Meet.riser("luie").reluctance() != "", "what you say has consequences you can see: '%s' / '%s'" % [out_good, out_bad])
	Meet.riser("luie").sulking = false
	Meet.riser("luie")._after_talk = ""
	tommy._after_talk = ""
	Meet.menu.close()
	bhavya.state = "idle"
	bhavya.interact()
	await wait(0.2)
	await shot("07d_lead")
	Meet.menu._lead("joke_bhavya")
	var Web = preload("res://scripts/web.gd")
	var tie0: float = Meet.tie("bhavya", "tommy")
	Meet.menu._answer(Web.LEADS["joke_bhavya"]["opts"][1])
	check(Meet.leads.has("joke_six") and Meet.tie("bhavya", "tommy") > tie0, "Bhavya's answer sends you back to Tommy, and warms the two of them")
	Meet.menu.close()
	tommy.state = "idle"
	tommy.interact()
	var ft: float = tommy.mind.feeling()
	Meet.menu._lead("joke_six")
	check(tommy.mind.feeling() > ft - 0.08 and Meet.used.has("joke_six"), "Tommy is delighted with a six")
	Meet.menu.close()
	var erick2: Node3D = Meet.riser("erick")
	erick2.state = "idle"
	erick2.interact()
	Meet.ties[Meet._key("erick", "kelvin")] = -0.3
	Meet.menu._about(Meet.riser("kelvin"))
	Meet.said.append({"by": "erick", "about": "kelvin", "tone": "bad"})
	Meet.menu.close()
	var kel: Node3D = Meet.riser("kelvin")
	kel.state = "idle"
	kel.interact()
	check(Meet.said.size() >= 1, "what Erick said about Kelvin can be carried to Kelvin")
	Meet.menu.close()

	# Money.
	var m0: int = Meet.money
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Pick up the $2"):
			n.interact()
			break
	check(Meet.money == m0 + 2, "loose change can be picked up ($%d)" % Meet.money)
	for r in Meet.risers:
		r.global_position = Meet.main.ground(Vector3(8, 0, -6))
		r.rotation.y = 0.0
	stand(Meet.main._bags["luie"]["at"] + Vector3(0.8, 0, 0), Meet.main._bags["luie"]["at"])
	Meet.main._wallet_take("luie")
	check(Meet.money > m0 + 2 and luie.wallet_taken > 0, "a wallet can be lifted when nobody is looking ($%d)" % Meet.money)
	var ek: Node3D = Meet.riser("erick")
	ek.state = "idle"
	ek._vs_player = false
	stand(Meet.main._bags["erick"]["at"] + Vector3(0.8, 0, 0), Meet.main._bags["erick"]["at"])
	ek.global_position = p.global_position + Vector3(2.0, 0, 0)
	var fe: float = ek.mind.feeling()
	Meet.heat = 0.0
	Meet.main._wallet_take("erick")
	check(ek.state == "confront" and ek.mind.feeling() < fe - 0.2 and Meet.heat >= 1.0, "caught in Erick's wallet: he comes for you and thinks far worse of you (%.2f -> %.2f)" % [fe, ek.mind.feeling()])
	ek.idle()
	Meet.heat = 0.0
	for r in Meet.risers:
		if r.is_riser:
			r.idle()
			r.global_position = Meet.main.ground(Vector3(randf_range(-4, 4), 0, randf_range(5, 8)))
	stand(Meet.main.TABLES[0] + Vector3(-1.1, 0, 0), Meet.main.TABLES[0])
	Meet.main._matches.clear()
	Meet.main._call_out(0)
	var came := false
	for i in 60:
		await wait(0.25)
		if Meet.table.active():
			came = true
			break
	check(came, "calling for a pull at an empty table brings somebody over")
	if came:
		Meet.table._finish(true)
		Meet.table._close()
	var st0: float = Meet.stamina
	Meet.stamina = 20.0
	Meet.main._buy_drink()
	check(Meet.stamina == 100.0, "a drink costs $3 and puts you right ($%d)" % Meet.money)
	Meet.stamina = st0

	# Two members pulling each other, with their own arms.
	for r in Meet.risers:
		if r.is_riser:
			r.idle()
	Meet.main._matches.clear()
	Meet.main.force_match("erick", "kelvin")
	Meet.riser("erick")._legs = ["seat"]
	Meet.riser("kelvin")._legs = ["seat"]
	Meet.riser("erick")._next_leg()
	Meet.riser("kelvin")._next_leg()
	var posed := false
	for i in 60:
		await wait(0.25)
		if Meet.riser("erick")._figure.has_meta("posed"):
			posed = true
			break
	stand(Meet.main.TABLES[Meet.main._matches[0]["table"]] + Vector3(0, 0, 3.4), Meet.main.TABLES[Meet.main._matches[0]["table"]]) if not Meet.main._matches.is_empty() else null
	await wait(1.5)
	await shot("07e_members_pull")
	check(posed, "two members pull each other with their own arms on the table")

	# The table.
	stand(Vector3(3.6, 0, 3.5), Vector3(3.6, 0, 1.2))
	var george: Node3D = Meet.riser("george")
	# Strapping in two people who are pulling.
	var done_hits := [-1]
	Meet.strapgame.start(func(h: int): done_hits[0] = h)
	for i in 3000:
		if done_hits[0] >= 0:
			break
		if absf(Meet.strapgame.pos - Meet.strapgame.zone) < Meet.strapgame.width * 0.3:
			Meet.strapgame.tap()
		Meet.strapgame.tick(0.016)
	check(done_hits[0] == 3, "the strap is three timed taps (%d of 3)" % done_hits[0])
	# A no can be turned round.
	phillip_no()
	george.stake = 5
	Meet.table.start(george)
	check(Meet.table.active() and Meet.table.phase == "ready" and Meet.table.move == "hook", "a pull is a grip fight, with George's hook")
	await wait(0.3)
	await shot("08_table")
	var t: Node = Meet.table
	for i in 6000:
		if t.phase == "done":
			break
		if t.phase == "go" and absf(t.pos - t.zone) < t.width * 0.3 and t._zone.visible:
			t.tap()
		t.tick(0.016)
	check(t.phase == "done", "the match ends (%s, wins %d losses %d)" % ["won" if t.won else "lost", Meet.wins, Meet.losses])
	check(not Meet.chalked, "the chalk is used up by the pull")
	check(george.stake == 0, "money on the pull changes hands ($%d)" % Meet.money)
	await shot("08b_result")
	await wait(0.2)
	await shot("08c_pinned")
	t._close()

	# The public.
	var seen_passer := false
	for i in 200:
		for r in Meet.risers:
			if r.passer:
				seen_passer = true
		if seen_passer:
			break
		await wait(0.25)
	check(seen_passer, "people walk past along the water")
	var pas: Node3D = null
	for r in Meet.risers:
		if r.passer:
			pas = r
	if pas:
		pas.position.x = 0.0
		pas._stops = false
		stand(pas.global_position + Vector3(0, 0, -3.5), pas.global_position)
		await wait(0.4)
		await shot("09_passer")
		pas.interact()
		check(Meet.menu.active(), "you can stop a passer-by to talk")
		Meet.menu.close()
		pas.interact()
		Meet.menu._pitches()
		Meet.menu._pitch({"key": pas.def["likes"], "say": "the right line"})
		if Meet.table.active():
			for i in 6000:
				if t.phase == "done":
					break
				if t.phase == "go" and absf(t.pos - t.zone) < t.width * 0.3 and t._zone.visible:
					t.tap()
				t.tick(0.016)
			t._close()
			check(pas.recruited and pas.guest and Meet.recruits == 1, "the right line talks a stranger into a pull, and they stay for the meet")
		else:
			Meet.menu.close()
			print("  note  the passer-by said no this time")

	# A scrap.
	var kelvin: Node3D = Meet.riser("kelvin")
	kelvin.state = "idle"
	kelvin._vs_player = false
	kelvin.composure = 100.0
	for r in Meet.risers:
		if r.is_riser:
			r.global_position = Meet.main.ground(Vector3(randf_range(2, 8), 0, randf_range(-4, 4)))
	kelvin.global_position = Meet.main.ground(Vector3(-4, 0, 11))
	stand(kelvin.global_position + Vector3(0, 0, 1.4), kelvin.global_position)
	var fk: float = kelvin.mind.feeling()
	Meet.heat = 0.0
	Meet.stamina = 100.0
	p._cooldown = 0.0
	p.slap()
	await wait(0.3)
	check(kelvin.state == "scrap" and kelvin.mind.feeling() < fk, "punch someone and they come for you")
	await wait(2.5)
	await shot("10_scrap")
	for i in 12:
		if kelvin.state == "winded":
			break
		stand(kelvin.global_position + Vector3(0, 0, 1.4), kelvin.global_position)
		p._cooldown = 0.0
		Meet.stamina = 100.0
		p.slap()
		await wait(0.2)
	check(kelvin.state == "winded", "enough of that and they sit down winded")
	var staring := 0
	var sour := 0
	for r in Meet.risers:
		if r.is_riser and r != kelvin:
			if r._stare > 0.0:
				staring += 1
			if r.mind.remembers("violence"):
				sour += 1
	check(staring >= 4 and sour >= 6, "everyone turns to stare (%d) and thinks worse of you (%d)" % [staring, sour])
	await wait(1.2)
	stand(kelvin.global_position + Vector3(0, 0, 5.0), kelvin.global_position)
	await wait(0.6)
	await shot("10b_stared_at")
	var warner: Node3D = null
	for i in 60:
		for r in Meet.risers:
			if r.state == "confront":
				warner = r
				stand(r.global_position + Vector3(0, 0, 1.6), r.global_position)
		if Meet.menu.active():
			break
		await wait(0.25)
	check(Meet.menu.active() and warner != null and warner.confront_kind == "warn", "someone comes over to warn you: do it again and you're out")
	await shot("10c_warned")
	check(Meet.stars() >= 2, "a beating puts stars on you (%d)" % Meet.stars())
	Meet.heat = 0.0
	Meet.warned = false
	Meet.menu._forced = false
	Meet.menu.close()
	if warner:
		warner.idle()

	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()
	Meet.menu._forced = false
	Meet.menu.close()
	Meet.heat = 0.0
	# Visitors.
	Meet.main.start_ufo()
	await wait(7.0)
	stand(Vector3(4, 0, 9), Vector3(0, 3, 16))
	await wait(0.5)
	await shot("11_ufo")
	check(Meet.main.aliens().size() == 4, "four visitors get out")
	for i in 220:
		var al: Array = Meet.main.aliens()
		if al.is_empty():
			break
		stand(al[0].global_position + Vector3(0, 0, 1.3), al[0].global_position)
		p._cooldown = 0.0
		p._down = 0.0
		Meet.stamina = 100.0
		p.slap()
		await wait(0.15)
	await wait(1.0)
	var got := false
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Pick up: Alien"):
			n.interact()
			got = true
	check(got and Meet.owned.has("antennae"), "a beaten visitor drops something to pick up")
	check(Meet.main._ufo_state == "open", "the ship stays, ramp down")
	Meet.main.board_ship()
	await wait(0.5)
	await shot("11b_aboard")
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Take the golden"):
			n.interact()
	await wait(0.3)
	check(Meet.owned.has("golden_grip") and Meet.ITEMS["golden_grip"]["atk"] == 10, "aboard the ship is the golden gauntlet, attack 10")
	Meet.main.leave_ship()
	await wait(0.5)
	check(Meet.main._ufo_state == "leave" and p.global_position.y < 5.0, "stepping off sends the ship away")
	Meet.heat = 0.0
	Meet.worn["hand"] = "golden_grip"
	stand(Vector3(5.2, 0, 20.4), Vector3(5.2, 0, 22.5))
	p._cooldown = 0.0
	Meet.stamina = 100.0
	p.slap()
	await wait(0.6)
	check(Meet.lions == 1 and Meet.main._pets.size() == 1, "an attack-10 item breaks a stone lion, and a living one comes out")
	await wait(2.5)
	stand(Vector3(4.0, 0, 16.0), Vector3(5.2, 0, 22.5))
	await wait(1.0)
	await shot("11c_lion")
	Meet.worn["hand"] = ""
	Meet.heat = 0.0
	Meet.menu._forced = false
	Meet.menu.close()
	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()
	Meet.wear("antennae")
	Meet.hud.toggle_bag()
	await wait(0.3)
	await shot("12_bag")
	var close_btn: Button = null
	for b in Meet.hud._bag.find_children("*", "Button", true, false):
		if b.text.begins_with("Close"):
			close_btn = b
	var cr: Rect2 = close_btn.get_global_rect()
	var panel_r: Rect2 = Meet.hud._bag.get_child(0).get_global_rect()
	check(panel_r.encloses(cr) and cr.end.x < Meet.hud._bag_people.get_global_rect().position.x, "the kit's Close button sits inside its own column, clear of everything else")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = cr.get_center()
	click.global_position = cr.get_center()
	click.pressed = true
	Input.parse_input_event(click)
	await wait(0.1)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = cr.get_center()
	click.global_position = cr.get_center()
	click.pressed = false
	Input.parse_input_event(click)
	await wait(0.3)
	check(not Meet.hud._bag.visible, "a real mouse click on Close shuts the kit")
	if not Meet.hud._bag.visible:
		Meet.hud.toggle_bag()
	Meet.hud.toggle_bag()
	Meet.menu.notes(0)
	await wait(0.2)
	await shot("13_notes")
	Meet.menu.close()

	# Other things from the sky.
	Meet.main.start_gulls()
	await wait(4.0)
	stand(Meet.main.SNACKS + Vector3(-3.5, 0, 3.5), Meet.main.SNACKS)
	await wait(0.5)
	await shot("14_gulls")
	stand(Meet.main.SNACKS + Vector3(0, 0, 1.5), Meet.main.SNACKS)
	await wait(1.0)
	check(Meet.main._gulls_off, "running at the seagulls sees them off")
	var chip := false
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().contains("golden chip"):
			stand(n.global_position + Vector3(0, 0, 1.0), n.global_position)
			await wait(0.3)
			p.use() if p.target == n else n.interact()
			chip = true
	await wait(4.0)
	check(chip and Meet.owned.has("golden_chip"), "the golden chip can be picked up and the night carries on")
	Meet.main.start_drone()
	await wait(11.5)
	stand(Meet.main._drone_to + Vector3(0, 0, 4), Meet.main._drone_to)
	await wait(0.4)
	await shot("15_drone")
	check(Meet.main._drone_t < 0.0, "the drone comes down")

	# The clipboard.
	var bh: Node3D = Meet.riser("bhavya")
	var f_b: float = bh.mind.feeling()
	var said: String = bh.read_clipboard("Bhavya is a legend")
	check(said.contains("legend") and Meet.player_name == "Sam", "they read what you wrote on the clipboard: %s" % said)
	check(bh.read_clipboard("pull me at the table") != "" and bh.calling > 0.0, "a written challenge is accepted")

	# A dog off the lead.
	var owner: Node3D = null
	for i in 240:
		for r in Meet.risers:
			if r._dog_node != null and r.state != "flee":
				owner = r
		if owner:
			break
		await wait(0.25)
	if owner:
		for c in owner._dog_node.get_children():
			if c.has_method("prompt") and c.prompt().begins_with("Unclip"):
				c.interact()
		await wait(2.0)
		stand(owner._dog_node.global_position + Vector3(0, 0, 5), owner._dog_node.global_position)
		await wait(0.3)
		await shot("15b_dog_loose")
		check(owner._dog_free > 0.0, "the dog can be let off its lead")
	else:
		print("  note  no dog walker came past in time")
	Meet.heat = 0.0

	# The evening's set pieces, and things that just happen.
	var ev: Node = Meet.main.evening
	Meet.heat = 0.0
	for name in ["fiver", "phone", "footy", "blackout", "conga", "balloon", "double", "possum", "feast", "sprinkler", "pushups", "sneeze"]:
		ev.call("_m_" + name)
		await wait(0.15)
	await wait(0.4)
	Meet.worn["hand"] = "glow_stick"
	await wait(0.3)
	await shot("15o_blackout")
	Meet.worn["hand"] = ""
	check(Meet.main._env.ambient_light_energy < 0.1 and p._lamp.visible, "a power cut is properly dark, and a glow stick lights your way")
	check(Meet.dark > 0.0 and Meet.main.watchers(p.global_position).is_empty(), "in a power cut nobody can see what you do")
	check(ev._possum != null and Meet.double_points, "moments happen: a possum on the snacks, double points called")
	Meet.dark = 0.01
	ev._m_wallet()
	ev._m_star()
	Meet.menu.close()
	ev._van()
	await wait(0.2)
	await shot("15c_van")
	Meet.menu.close()
	Meet.money = 30
	Meet.main.force_match("bhavya", "george")
	for r in [Meet.riser("bhavya"), Meet.riser("george")]:
		r._legs = ["seat"]
		r._next_leg()
	var m_bet: Dictionary = {}
	for i in 60:
		await wait(0.25)
		for i2 in 3:
			if not ev._match_at(i2).is_empty():
				m_bet = ev._match_at(i2)
		if not m_bet.is_empty():
			break
	if not m_bet.is_empty():
		m_bet["bet"] = {"on": m_bet["a"], "amt": 5, "pays": 9}
		var cash0: int = Meet.money
		ev.match_ended(m_bet, m_bet["a"])
		check(Meet.money == cash0 + 9, "a bet on someone else's pull pays out")
		m_bet.erase("bet")
	else:
		print("  note  no pull got going to bet on")
	Meet.bracket = "open"
	Meet.clock = 100.0
	ev._enter()
	check(Meet.bracket == "in", "you can enter the six o'clock bracket")
	Meet.clock = 361.0
	await wait(1.0)
	check(Meet.bracket == "semi" and ev._seat.is_in_group("interact"), "at six the bracket is drawn and your seat is waiting")
	ev._sit()
	for i in 6000:
		if t.phase == "done":
			break
		if t.phase == "go" and absf(t.pos - t.zone) < t.width * 0.3 and t._zone.visible:
			t.tap()
		t.tick(0.016)
	t._close()
	check(Meet.bracket in ["wait", "final", "out", "lost_wait", "npc_final"], "the semi-final is played (%s)" % Meet.bracket)
	Meet.bracket = "none"
	ev._photo = "done"
	ev._start_pack()
	var carried := 0
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Carry this table"):
			n.interact()
			carried += 1
	check(carried >= 1 and Meet.carrying >= 0, "a table goes over your head")
	for k in 3:
		p.global_position = Meet.main.ground(Vector3(0, 0, 22.5))
		await wait(0.3)
		Meet.carrying = -1
		for n in get_tree().get_nodes_in_group("interact"):
			if n.has_method("prompt") and n.prompt().begins_with("Carry this table") and Meet.carrying < 0:
				n.interact()
	p.global_position = Meet.main.ground(Vector3(0, 0, 22.5))
	await wait(0.3)
	check(ev._packed >= 1, "carrying it to the gate loads it (%d)" % ev._packed)
	Meet.carrying = -1
	var lu: Node3D = Meet.riser("luie")
	if lu.coned:
		check(lu.cone_off() != "" and Meet.cone_with == "", "the cone can be taken back")
	var ax: Dictionary = tommy.axes()
	check(tommy.attitude() != "", "Tommy's attitude: %s (trust %.2f, respect %.2f, fun %.2f)" % [tommy.attitude(), ax["trust"], ax["respect"], ax["fun"]])
	Meet.heat = 0.0

	# Using what's in your hand.
	Meet.owned["rubber_chicken"] = true
	Meet.worn["hand"] = "rubber_chicken"
	var geo: Node3D = Meet.riser("george")
	geo.state = "idle"
	geo.global_position = Meet.main.ground(Vector3(-12, 0, 16))
	stand(geo.global_position + Vector3(0, 0, 1.5), geo.global_position)
	p._cooldown = 0.0
	p.use_item()
	check(geo._asked.get("prank", 0) == 1, "the chicken can be squeaked at someone")
	Meet.worn["hand"] = ""
	Meet.stamina = 50.0
	await wait(2.0)
	check(Meet.stamina < 53.0, "stamina comes back slowly on its own (%.1f)" % Meet.stamina)

	# The cyclist.
	check(not Meet.hud._dares.get_child(1).text.contains("["), "dares are listed without tags: %s" % Meet.hud._dares.get_child(1).text)
	ev._m_cyclist()
	var parked := false
	for i in 100:
		await wait(0.25)
		if ev._bike_state == "parked":
			parked = true
			break
	check(parked, "a cyclist rides in and parks at the gate")
	stand(ev.bike.global_position + Vector3(0, 0, 3.5), ev.bike.global_position)
	await wait(0.4)
	await shot("15g_bike")
	Meet.heat = 0.0
	ev._steal()
	check(p.riding and ev._bike_state == "stolen", "the bike can be taken and ridden")
	var victim: Node3D = Meet.riser("bhavya")
	victim.state = "idle"
	victim.global_position = Meet.main.ground(Vector3(-14, 0, 12))
	p.global_position = Meet.main.ground(Vector3(-14, 0, 13.2))
	p._ride_v = Vector3(0, 0, -10)
	await wait(0.4)
	check(victim.state == "winded", "riding into someone at speed knocks them over")
	stand(p.global_position + Vector3(0, 0, 0.1), victim.global_position)
	await shot("15h_riding")
	p.use()
	check(not p.riding and ev._bike_state == "dropped", "getting off leaves the bike for its owner")
	Meet.heat = 0.0
	Meet.menu._forced = false
	Meet.menu.close()
	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()

	# Shouting, and throwing food.
	for r in Meet.risers:
		if r.is_riser:
			r.idle()
			r._vs_player = false
			r.global_position = Meet.main.ground(Vector3(randf_range(-5, 5), 0, randf_range(2, 8)))
	stand(Vector3(0, 0, 12), Vector3(0, 0, 4))
	Meet.main._shout_cd = 0.0
	Meet.main.shout("snacks", "FREE SNACKS AT THE GATE!")
	await wait(1.2)
	await shot("15i_shout")
	var running := 0
	for r in Meet.risers:
		if r._then == "fooled":
			running += 1
	check(running >= 6, "shout about free snacks and the whole club runs for the gate (%d)" % running)
	await wait(7.0)
	await shot("15j_fooled")
	Meet.heat = 0.0
	Meet.snacks = 5
	var tgt_r: Node3D = Meet.riser("tommy")
	tgt_r.idle()
	for i in 3:
		stand(tgt_r.global_position + Vector3(0, 0, 3.0), tgt_r.global_position)
		p._cooldown = 0.0
		p.throw_snack()
		await wait(0.7)
	check(Meet.main.food_fight() and Meet.snacks == 2, "three thrown snacks start a food fight")
	await wait(3.0)
	stand(Vector3(0, 0, 13), Vector3(0, 0, 4))
	await wait(1.5)
	await shot("15k_foodfight")
	Meet.main._fight = 0.1
	await wait(0.6)
	Meet.heat = 0.0
	Meet.menu._forced = false
	Meet.menu.close()

	# Every written moment runs without tripping over itself.
	var Mo = preload("res://scripts/moments.gd")
	var ran := 0
	Meet.money = 60
	for m in Mo.LIST:
		Meet.snacks = 3
		ev._last_choice = -99.0
		if ev.play(m):
			ran += 1
		await wait(0.12)
		if Meet.menu.active():
			var pick: Button = null
			for b in Meet.menu._list.get_children():
				if b is Button and pick == null:
					pick = b
			if pick:
				pick.pressed.emit()
			await wait(0.05)
			Meet.menu._forced = false
			Meet.menu.close()
	await wait(8.0)
	Meet.menu._forced = false
	Meet.menu.close()
	check(Mo.LIST.size() >= 54 and ran >= Mo.LIST.size() - 6, "%d of %d new moments played" % [ran, Mo.LIST.size()])
	for r in Meet.risers.duplicate():
		if r.id.begins_with("w_"):
			Meet.risers.erase(r)
			r.queue_free()
	Meet.heat = 0.0
	Meet.dark = 0.01
	ev._fog = 0.1
	Meet.money = 44
	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()
	await wait(0.5)

	# Kit put down, ripples, the boom box.
	Meet.owned["boom_box"] = true
	Meet.worn["hand"] = "boom_box"
	p._cooldown = 0.0
	p.use_item()
	check(Meet.audio.track == 1, "the boom box changes what's playing")
	Meet.hud._bag.visible = true
	Meet.modal = true
	Meet.hud._put_down("hand")
	check(Meet.away.has("boom_box") and Meet.worn["hand"] == "", "kit can be put down on the ground")
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Pick your"):
			n.interact()
	check(not Meet.away.has("boom_box"), "and picked up again")
	check(not Meet.ripples.is_empty(), "what you change is noted: %s" % " | ".join(Meet.ripples.slice(0, 3)))
	await wait(1.0)

	stand(Vector3(-8.5, 0, 26), Vector3(-8.5, 0, 40))
	p.global_position = Meet.main.clear(Vector3(-8.5, 0, 28.6))
	check(p.global_position.z > 28.5, "you can walk right up to the railing (z %.1f)" % p.global_position.z)
	# The people at their posts.
	var con: Node3D = Meet.riser("s_fisher")
	check(con != null and con.post and Meet.riser("s_kebab") != null and Meet.riser("s_busker") != null, "the busker, the fisherman and the kebab man are people you can talk to")
	stand(con.global_position + Vector3(0, 0, -1.6), con.global_position)
	con.interact()
	var th_topic: Dictionary = People2.TALK["s_fisher"].filter(func(t): return t["key"] == "thermos")[0]
	Meet.menu._topic(th_topic)
	Meet.menu._answer(th_topic["opts"][0])
	check(Meet.errands.get("s_fisher", "") == "open", "Old Con's thermos is a hidden errand")
	Meet.menu.close()
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().contains("thermos"):
			n.interact()
	con.interact()
	Meet.menu._errand_done()
	check(Meet.owned.has("catch_ball"), "returning it earns the catch-ball")
	Meet.menu.close()
	ev._m_critter()
	await wait(0.4)
	stand(ev._critter.position + Vector3(0, 0, 2.5), ev._critter.position)
	await wait(0.3)
	await shot("15l_gripling")
	ev._critter.interact()
	for i in 3000:
		if not Meet.strapgame.active():
			break
		if absf(Meet.strapgame.pos - Meet.strapgame.zone) < Meet.strapgame.width * 0.3:
			Meet.strapgame.tap()
		Meet.strapgame.tick(0.016)
	check(Meet.owned.has("gripling"), "with the catch-ball, the Gripling can be caught")
	Meet.owned["pool_noodle"] = true
	ev._m_swimmer()
	await wait(0.3)
	ev._rescue("test", 0.5, true)
	check(Meet.saved == 1, "someone in the water can be saved")
	ev._bite = 0.05
	await wait(0.6)
	check(ev._bite > 20.0, "Old Con lands a fish now and then")
	var cuz_def: Dictionary = People2.TALK["p_cousin"][0]
	check(cuz_def["key"] == "flirt" and People2.MORE.has("flirt3"), "the cousin can be flirted with over three rounds")
	Meet.menu._forced = false
	Meet.menu.close()
	Meet.heat = 0.0

	# Legends, and the thing from the bay.
	ev._m_legend_don()
	ev._m_legend_lasha()
	await wait(2.5)
	stand(Vector3(0, 0, 15.5), Vector3(0, 0, 9.5))
	await wait(0.5)
	await shot("15m_legends")
	check(ev._legends.size() == 2 and ev.legend_options(ev._legends[1]).size() == 4, "two visiting legends turn up, each with four things you can do")
	ev.legend_options(ev._legends[1])[3][1].call()
	await wait(0.4)
	check(p._jump > 1.0, "the giant lifts you clean off the ground (%.1f m)" % p._jump)
	await wait(2.0)
	Meet.menu.close()
	ev.start_kaiju()
	var dared := false
	for i in 140:
		await wait(0.25)
		if i == 30:
			stand(Vector3(-6, 0, 16), Vector3(0, 8, 40))
			await shot("15n_kaiju")
		if ev._kaiju_state == "dare":
			dared = true
			break
	check(dared, "the thing from the bay rises, sends a wave through, and offers its hand")
	var odds: Array = ev.kaiju_odds()
	check(odds[0] < 138.0 and not odds[1].is_empty(), "what you've gathered counts against it: strength %d with %s" % [odds[0], ", ".join(odds[1]).left(90)])
	ev.kaiju_result(true)
	await wait(1.0)
	check(ev._kaiju_state == "sink", "beaten, it goes back into the bay")
	Meet.menu._forced = false
	Meet.menu.close()
	for l in ev._legends:
		if is_instance_valid(l):
			Meet.risers.erase(l)
			l.queue_free()
	ev._legends.clear()
	Meet.heat = 0.0
	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()

	# Wind and the balloon; the possum; chalk as dust.
	Meet.owned["balloon"] = true
	Meet.worn["hand"] = "balloon"
	Meet.touch_state()
	ev._m_gale()
	stand(Vector3(0, 0, 14), Vector3(0, 0, 4))
	Input.action_press("jump")
	await wait(2.5)
	await shot("15p_flying")
	check(p.flying and p._jump > 2.0, "in a wind, a balloon in your hand lifts you off the ground (%.1f m)" % p._jump)
	Input.action_release("jump")
	Meet.wind = 0.01
	Meet.worn["hand"] = ""
	Meet.touch_state()
	await wait(2.5)
	ev._possum = null
	ev._m_possum()
	Meet.heat = 0.0
	ev._possum.take_hit(10, Vector3.ZERO)
	check(Meet.heat >= 1.5 and ev._possum == null, "hitting the possum raises your heat (%.1f)" % Meet.heat)
	Meet.heat = 0.0
	var sk: Skeleton3D = Meet.riser("luie")._figure.find_child("Skeleton3D", true, false)
	Meet.riser("luie").dusted(Meet.riser("tommy"))
	check(sk.get_node_or_null("Dust") != null, "chalk leaves dust on the shirt instead of turning them white")
	check(People2.PASSERS.size() >= 18, "%d kinds of stranger can walk past" % People2.PASSERS.size())
	Meet.menu._forced = false
	Meet.menu.close()
	for r in Meet.risers:
		if r.state in ["confront", "scrap"]:
			r._vs_player = false
			r.idle()

	# Twice the kit, where it comes from, and Oz.
	check(Meet.ITEMS.size() >= 72, "%d pieces of kit to find" % Meet.ITEMS.size())
	var W = preload("res://scripts/wear.gd")
	var built := 0
	for iid in Meet.ITEMS:
		var mdl: Node3D = W.model(iid)
		if mdl.get_child_count() > 0:
			built += 1
		mdl.free()
	check(built == Meet.ITEMS.size(), "every piece of kit has a model (%d of %d)" % [built, Meet.ITEMS.size()])
	Meet.money = 50
	ev._merch()
	var mb: Button = null
	for b in Meet.menu._list.get_children():
		if b is Button and mb == null:
			mb = b
	mb.pressed.emit()
	await wait(0.2)
	check(Meet.owned.has("club_cap") and Meet.money == 42, "the merch table sells kit for money")
	Meet.menu.close()
	Meet.main._gone_tables.clear()
	Meet.main._matches.clear()
	for r in Meet.risers:
		if r.is_riser and not r.dead:
			r._vs_player = false
			r.state = "idle"
	ev._m_oz()
	await wait(1.5)
	var oz: Node3D = ev._legends[-1]
	check(oz.legend == "oz" and Meet.main.match_on(), "Oz arrives and the tables fill")
	Meet.composure = 80.0
	ev.legend_options(oz)[0][1].call()
	check(absf(Meet.composure - 40.0) < 0.5, "shaking his hand costs half your health (%d)" % Meet.composure)
	stand(oz.global_position + Vector3(0, 0, 4.5), oz.global_position)
	await wait(0.5)
	await shot("15q_oz")
	Meet.composure = 100.0
	var ron: Node3D = null
	for r in Meet.risers:
		if r.guest and not r.recruited and r.legend == "":
			ron = r
	if ron:
		ron.idle()
		var fr: float = ron.mind.feeling()
		ron.dusted(p)
		ron.dusted(p)
		check(ron.mind.feeling() <= fr and ron.state == "confront", "chalk a guest twice and they think worse of you and come over about it (%.2f -> %.2f)" % [fr, ron.mind.feeling()])
		ron.idle()
	Meet.menu._forced = false
	Meet.menu.close()
	for l in ev._legends:
		if is_instance_valid(l):
			Meet.risers.erase(l)
			l.queue_free()
	ev._legends.clear()
	Meet.main._matches.clear()
	Meet.heat = 0.0
	for r in Meet.risers:
		if r.state in ["confront", "scrap", "pull", "to_table", "prep"]:
			r._vs_player = false
			r.idle()

	# Gone, grieved, and brought back.
	var gone_r: Node3D = Meet.riser("george")
	gone_r.idle()
	gone_r.zapped(999.0, "the visitors")
	await wait(0.4)
	check(gone_r.dead and not gone_r.visible and Meet.dead.has("george"), "a founder can be taken for the night")
	var hl: String = Meet.riser("harry").grief_line("george")
	check(hl.contains("George"), "Harry grieves his brother: %s" % hl.left(70))
	Meet.potions = 1
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("prompt") and n.prompt().begins_with("Stand over where George"):
			stand(n.global_position + Vector3(0, 0, 3), n.global_position)
			await wait(0.3)
			await shot("15r_memorial")
			n.interact()
	var pb: Button = null
	for b in Meet.menu._list.get_children():
		if b is Button and pb == null:
			pb = b
	if pb:
		pb.pressed.emit()
	await wait(0.4)
	check(not gone_r.dead and gone_r.visible and Meet.potions == 0, "a revival potion brings them back")
	Meet.menu.close()
	Meet.owned["raygun"] = true
	Meet.worn["hand"] = "raygun"
	p._cooldown = 0.0
	var beams0: int = Meet.main.get_child_count()
	p.use_item()
	check(Meet.main.get_child_count() > beams0, "the ray gun fires a visible beam")
	Meet.worn["hand"] = ""
	Meet.heat = 0.0
	await wait(0.4)

	# Sitting down, weights, and looking at yourself.
	p.sit(Vector3(9, 0.5, 20), PI)
	ev._join = 0.1
	var joined := false
	for i in 80:
		await wait(0.25)
		if Meet.menu.active():
			joined = true
			break
		if ev._join > 1.0 and not Meet.risers.any(func(r): return r._then == "bench"):
			ev._join = 0.1
	await shot("15d_bench")
	check(joined, "sit on the bench and somebody comes to sit with you")
	Meet.menu.close()
	p.stand_up()
	Meet.stamina = 100.0
	Meet.main._lift()
	await wait(1.5)
	await shot("15e_curls")
	await wait(2.2)
	check(Meet.pump == 1 and Meet.stamina < 70.0, "a set with the dumbbells costs stamina and pumps you up")
	p.toggle_view()
	await wait(0.8)
	await shot("15f_view")
	check(p._orbit, "the camera can swing round to look at you")
	p.toggle_view()

	# Friendly things.
	var tm: Node3D = Meet.riser("tommy")
	tm.state = "idle"
	tm._vs_player = false
	tm.interact()
	Meet.menu._dance()
	await wait(1.0)
	await shot("16_dance")
	check(tm._act_t > 0.0, "Tommy dances with you")
	await wait(2.5)
	tm.interact()
	Meet.menu._news()
	Meet.menu._favour("word")
	Meet.menu.close()

	# Five stars.
	Meet.heat = 4.9
	stand(Vector3(0, 0, 6), Vector3(0, 0, 0))
	Meet.add_heat(0.2, "test")
	await wait(2.4)
	await shot("17_ganged_up")
	await wait(4.0)
	check(Meet.hud._over.visible, "five stars: they close in on you, and the night is over")

	# Remembered.
	Meet.save()
	var before: float = tommy.mind.feeling()
	Meet.load_save()
	check(Meet.bonds.has("tommy") and Meet.owned.has("antennae"), "what happened is saved (Tommy at %.2f)" % before)
	print("SELFTEST %s (%d failed)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)

func phillip_no() -> void:
	var ph: Node3D = Meet.riser("phillip")
	ph.state = "idle"
	ph.mind.experience("heckle", -0.9, 3.0)
	ph.mind.experience("heckle", -0.9, 3.0)
	check(ph.reluctance() != "", "someone who dislikes you refuses a pull: %s" % ph.reluctance())
	var res: Array = ph.talk_into("goad")
	check(res[0] and ph.pull_angry, "goading a proud one gets them to the table, angry")
	ph.pull_angry = false
