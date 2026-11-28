extends Node
## Automated play-through used during development:  godot --path game -- --selftest [shots_dir]
## Plays the slice start to finish through the same calls the buttons make, and saves screenshots.

var _dir := ""
var _fails := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--selftest")
	if i >= 0 and i + 1 < args.size():
		_dir = args[i + 1]
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1

func _save(shot_name: String) -> void:
	if _dir == "":
		return
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])

func _shot(shot_name: String, at: Vector3, yaw_deg: float, pitch_deg := 0.0) -> void:
	Game.player.global_position = at
	Game.player.rotation.y = deg_to_rad(yaw_deg)
	Game.player.cam.rotation.x = deg_to_rad(pitch_deg)
	await _save(shot_name)

func _npc(id: String) -> Node:
	for n in Game.npcs:
		if n.id == id:
			return n
	return null

func _pinned(prefix: String) -> Node:
	for p in Game.pinned:
		if String(p.spirit["name"]).begins_with(prefix):
			return p
	return null

func _press(label_start: String) -> bool:
	for b in Game.battle._buttons.get_children():
		if b.is_queued_for_deletion():
			continue
		var t: String = b.text
		if t.substr(t.find(".") + 1).strip_edges().begins_with(label_start):
			b.pressed.emit()
			return true
	return false

func _beat_down() -> void:
	var guard := 0
	while Game.battle.foe_hp > 0 and Game.battle.result == "" and guard < 80:
		guard += 1
		Game.hp = Game.max_hp
		_press("Strike")

## Fight a Pinned to the ground and raise it, choosing only the true things to say.
func _raise(p: Node) -> String:
	Game.battle.start_pinned(p)
	_beat_down()
	_press("Throw chalk")
	_press("Bind it")
	for l in p.spirit["say"]:
		if l[2] and Game.battle.result == "":
			_press("Say: \"%s" % String(l[0]).substr(0, 20))
	_press("Say the Rite")
	var r: String = Game.battle.result
	_press("Continue")
	return r

func _run() -> void:
	await get_tree().process_frame
	await _shot("00_title", Game.RHODES_SPAWN, 25)
	Game.hud._begin()
	await _shot("01_rhodes_hall", Vector3(4, 0.1, 8), 25, -4)
	await _shot("02_wukhan", Vector3(-4, 0.1, 8), 75, 6)
	await _shot("03_gate", Vector3(24, 0.1, 0), -90, 4)

	var harry := _npc("harry")
	Game.player.global_position = Vector3(1.2, 0.1, 0.4)
	Game.player.rotation.y = atan2(1.2, 2.4)
	Game.player.look_level()
	for f in 5:
		await get_tree().physics_frame
	_check(Game.player.target == harry, "Standing in front of Harry offers to talk to him")
	await _save("03b_prompt")
	Game.player.target.interact()
	_check(Game.dialogue.active(), "Using him opens the conversation")
	Game.dialogue.close()
	Game.player.global_position = Vector3(1.5, 0.1, 1.2)
	Game.player.rotation.y = deg_to_rad(30)
	Game.dialogue.open(harry)
	Game.dialogue._ask("The Pilgrimage")
	Game.dialogue._act(harry._give_kit)
	await _save("04_dialogue")
	Game.dialogue.close()
	_check(Game.chalk == 4 and Game.straps == 3, "Harry hands over chalk and straps")
	_check(Game.journal.size() == 1, "Journal records Harry's directions")

	await _shot("05_road", Vector3(60, 0.1, 0), -90, 2)
	var carter := _pinned("Tobin")
	Game.player.global_position = carter.global_position + Vector3(-6, 0, 0)
	for f in 300:
		await get_tree().physics_frame
		if Game.battle.active():
			break
	_check(Game.battle.active(), "A Pinned on the road comes for the player and starts a fight")
	await _save("06_fight")
	Game.chalk = 10
	Game.straps = 10

	# Killing without raising: it comes back.
	_beat_down()
	_press("Leave it")
	_press("Continue")
	_check(carter.state == "down", "A Pinned that is only killed sinks, to return later")
	carter._timer = 0.1
	await get_tree().create_timer(0.4).timeout
	_check(carter.state == "roam", "...and it gets back up")

	_check(_raise(carter) == "raised", "Chalk, strap and rite raise the carter for good")
	_check(carter.state == "gone", "A raised Pinned does not return")
	_check(_raise(_pinned("Pip")) == "raised", "The child is raised")

	# A strap that runs out.
	Game.battle.start_pinned(_pinned("Edda"))
	_beat_down()
	_press("Throw chalk")
	_press("Bind it")
	await _save("07_rite")
	for n in 6:
		_press("Say the Rite")
	_check(Game.battle.result == "lost", "Saying the rite before the spirit is ready wastes the strap")
	_press("Continue")

	await _shot("08_village", Vector3(206, 0.1, 19), -92, 3)
	await _shot("09_village_square", Vector3(232, 0.1, 30), 150, 0)

	var wren := _npc("wren")
	_check(wren.can_join(), "Wren will join once two Pinned have been raised")
	wren.topic_text("Becoming a Riser")
	_check(wren.recruited, "Wren is recruited")

	var ned := _npc("ned")
	ned.topic_text("Becoming a Riser")
	_check(not ned.recruited, "Ned is willing but not yet capable")
	for n in 3:
		ned._train()
	ned.topic_text("Becoming a Riser")
	_check(ned.recruited, "Ned is recruited after training")

	var mara := _npc("mara")
	for n in 3:
		mara._persuade()
	mara.topic_text("Becoming a Riser")
	_check(not mara.recruited, "Mara cannot be talked round while her father is pinned")
	_check(_raise(_pinned("Oswin")) == "raised", "Oswin is raised at the jetty")
	mara.topic_text("Becoming a Riser")
	_check(mara.recruited, "Mara is recruited after her father rises")

	var ivo := _npc("ivo")
	for n in 3:
		ivo._persuade()
	ivo.topic_text("Becoming a Riser")
	_check(not ivo.recruited and not _npc("pell").can_join() and not _npc("hesper").can_join(), "The other three villagers cannot be recruited")
	_check(Game.register_count() == 11, "Register stands at 11")

	# Crime.
	Game.player.global_position = Vector3(236, 0.1, -4)
	Game.main._steal()
	_check(Game.flags.has("stolen"), "The strongbox can be robbed")
	var before: int = Game.rep["tallow"]
	Game.battle.start_npc(_npc("pell"))
	_beat_down()
	_press("Continue")
	_check(not _npc("pell").alive, "A villager can be killed")
	_check(Game.rep["tallow"] < before, "Witnesses turn the village against the player")
	_check(Game.pinned.size() == 7, "The victim will come back as one of the Pinned")

	_check(harry.topics().has("I've brought three from Tallow Ford"), "Harry can be told about the three recruits")
	harry.topic_text("I've brought three from Tallow Ford")
	await _shot("10_end", Game.RHODES_SPAWN, 25)
	_check(Game.flags.has("slice_done"), "The slice can be completed")

	print("SELFTEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)
