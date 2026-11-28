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
	var topic: Dictionary = preload("res://scripts/people.gd").TALK["bhavya"][0]
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
	check(not Meet.menu.active() and harry2.state == "scrap" and Meet.has_flag("harry", "sore"), "the sore spot ends the conversation and starts a scrap")
	harry2._vs_player = false
	harry2.idle()
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

	# The table.
	stand(Vector3(3.6, 0, 3.5), Vector3(3.6, 0, 1.2))
	var george: Node3D = Meet.riser("george")
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

	# Remembered.
	Meet.save()
	var before: float = tommy.mind.feeling()
	Meet.load_save()
	check(Meet.bonds.has("tommy") and Meet.owned.has("antennae"), "what happened is saved (Tommy at %.2f)" % before)
	print("SELFTEST %s (%d failed)" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)
