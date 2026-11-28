extends Node
## Plays a night through by calling the game's own functions, and takes pictures along the way.

var _dir := ""
var _fails := 0

func _ready() -> void:
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
	Meet.hud._name_box.text = "Sam"
	Meet.hud._begin()
	var p: Node3D = Meet.player
	await wait(2.0)
	await shot("01_arrive")
	stand(Vector3(0, 0, 9.5), Vector3(0, 0, 0))
	await wait(14.0)
	await shot("02_plaza")
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
	check(harry2.mood_level() < 0 and harry2._name_label.text.contains("you"), "his name now reads: %s" % harry2._name_label.text.replace("\n", " "))
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

	# Talk that carries from one person to the next.
	var People2 = preload("res://scripts/people.gd")
	tommy.state = "idle"
	tommy.interact()
	var jokes: Dictionary = People2.TALK["tommy"].filter(func(t): return t["key"] == "jokes")[0]
	Meet.menu._topic(jokes)
	Meet.menu._answer(jokes["opts"][0])
	check(Meet.leads.has("joke_bhavya"), "laughing at Tommy's joke gives you something to raise with Bhavya")
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
	Meet.warned = false
	Meet.menu._forced = false
	Meet.menu.close()
	if warner:
		warner.idle()

	# Visitors.
	Meet.main.start_ufo()
	await wait(7.0)
	stand(Vector3(4, 0, 9), Vector3(0, 3, 16))
	await wait(0.5)
	await shot("11_ufo")
	check(Meet.main.aliens().size() == 3, "three visitors get out")
	for i in 80:
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
	check(got and Meet.owned.has("antennae"), "the visitors leave something behind to pick up")
	Meet.wear("antennae")
	Meet.hud.toggle_bag()
	await wait(0.3)
	await shot("12_bag")
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
