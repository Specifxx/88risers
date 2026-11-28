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
	Game.player.global_position = Game.main.ground(at) + Vector3(0, 0.15, 0)
	Game.player.velocity = Vector3.ZERO
	Game.player.rotation.y = deg_to_rad(yaw_deg)
	Game.player.look_level(deg_to_rad(pitch_deg))
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

## Click the choice whose text starts with `label` in the open scene or conversation.
func _choose(label: String) -> bool:
	for b in Game.dialogue._list.get_children():
		if b.is_queued_for_deletion():
			continue
		var t: String = String(b.text).trim_prefix("◆  ")
		if t.begins_with(label):
			b.pressed.emit()
			return true
	return false

## Take one of the story's offers from a person, as if choosing it in conversation.
func _offer(id: String, label: String) -> bool:
	for a in Game.story.actions(_npc(id)):
		if String(a[0]).begins_with(label):
			a[1].call()
			return true
	return false

## Put a Pinned on the ground, begin the rite, and say only the true things.
func _raise(p: Node) -> String:
	p.take_hit(999, Game.player.global_position)
	p.interact()
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
	# Real-time fighting. First, being attacked.
	var carter := _pinned("Tobin")
	Game.player.global_position = Game.main.ground(carter.global_position + Vector3(-6, 0, 0)) + Vector3(0, 0.15, 0)
	var hp_before := Game.hp
	for f in 420:
		await get_tree().physics_frame
		if Game.hp < hp_before:
			break
	_check(Game.hp < hp_before, "A Pinned on the road comes for the player and strikes them")
	await _save("06_fight")
	# Armour and blocking reduce what gets through.
	Game.hp = Game.max_hp
	var bare: int = Game.hurt_player(10, Game.player.global_position + Vector3(0, 0, -1))
	Game.add_item("cuirass")
	Game.toggle_equip("cuirass")
	Game.hp = Game.max_hp
	var armoured: int = Game.hurt_player(10, Game.player.global_position + Vector3(0, 0, -1))
	Game.blocking = true
	Game.player.rotation.y = 0.0
	Game.hp = Game.max_hp
	var blocked: int = Game.hurt_player(10, Game.player.global_position + Vector3(0, 0, -1))
	Game.blocking = false
	print("    A blow of 10 does %d bare, %d in a cuirass, %d blocked as well" % [bare, armoured, blocked])
	_check(armoured < bare and blocked < armoured, "Armour and blocking each reduce damage")
	_check(Game.armor() == 7, "Worn armour counts towards the armour rating")
	Game.toggle_equip("cuirass")
	Game.remove_item("cuirass")
	_check(Game.armor() == 0, "Taking it off removes it")
	# Striking back: skill decides whether blows land.
	Game.hp = Game.max_hp
	carter.global_position = Game.main.ground(Game.player.global_position + Vector3(0, 0, -1.6))
	Game.player.rotation.y = 0.0
	Game.skills["blunt"] = 100
	var blows := 0
	while carter.can_be_hit() and blows < 40:
		blows += 1
		Game.hp = Game.max_hp
		Game.fatigue = Game.max_fatigue
		Game.player._cooldown = 0.0
		Game.player.swing()
		Game.player._land_blow()
	print("    The carter (14 health) went down in %d blows of the staff" % blows)
	_check(carter.state == "fallen", "Blows from the equipped weapon put a Pinned on the ground")
	_check(carter.is_in_group("interact"), "A fallen Pinned can have the rite begun over it")
	Game.skills["blunt"] = 20
	var better := Game.hit_chance("blunt")
	Game.fatigue = 0.0
	_check(Game.hit_chance("blunt") < better, "Exhaustion makes blows less likely to land")
	Game.fatigue = Game.max_fatigue
	Game.chalk = 10
	Game.straps = 10

	# Killing without raising: it comes back.
	carter.interact()
	_press("Leave it")
	_press("Continue")
	_check(carter.state == "down", "A Pinned that is only beaten sinks, to return later")
	carter._timer = 0.1
	await get_tree().create_timer(0.4).timeout
	_check(carter.state == "roam" and carter.hp == carter.max_hp, "...and it gets back up, whole")

	# Blows knock things back.
	Game.player.global_position = Game.main.ground(Vector3(60, 0, 0)) + Vector3(0, 0.1, 0)
	Game.player.rotation.y = 0.0
	var child := _pinned("Pip")
	child.global_position = Game.main.ground(Game.player.global_position + Vector3(0, 0, -1.5))
	var z0: float = child.global_position.z
	child.max_hp = 500
	child.hp = 500
	child.take_hit(6, Game.player.global_position)
	var thrown := 0.0
	for f in 20:
		await get_tree().process_frame
		thrown = max(thrown, z0 - child.global_position.z)
	print("    A blow of 6 threw the small Pinned back %.2f m" % thrown)
	_check(thrown > 0.4, "A blow knocks its target back")
	child.max_hp = 10
	child.hp = 10

	# Equipment shows on the body.
	for item in ["sword", "shield", "hat", "cuirass", "bracers", "boots"]:
		Game.add_item(item)
		Game.toggle_equip(item)
	await get_tree().process_frame
	var skel: Node = Game.player._figure.find_child("Skeleton3D", true, false)
	var shown := 0
	for slot in ["weapon", "shield", "head", "body", "hand_l", "foot_l"]:
		if skel.get_node_or_null("Gear_" + slot) != null:
			shown += 1
	_check(shown == 6, "Weapon, shield, hat, armour, bracers and boots all appear on the pilgrim")
	Game.player.third = true
	Game.player.global_position = Game.main.ground(Vector3(14, 0, 4)) + Vector3(0, 0.1, 0)
	Game.player.rotation.y = deg_to_rad(200)
	Game.player.look_level(-0.1)
	await _save("06b_gear")
	for item in ["sword", "shield", "hat", "cuirass", "bracers", "boots"]:
		Game.toggle_equip(item)
		Game.remove_item(item)
	Game.toggle_equip("staff")
	await get_tree().process_frame
	_check(skel.get_node_or_null("Gear_shield") == null and skel.get_node_or_null("Gear_weapon") != null, "Taking things off removes them from the body")

	# Jumping.
	Game.player.global_position = Game.main.ground(Vector3(60, 0, 0)) + Vector3(0, 0.1, 0)
	for f in 20:
		await get_tree().physics_frame
	var y0: float = Game.player.global_position.y
	Game.player.jump()
	var top := y0
	for f in 40:
		await get_tree().physics_frame
		top = max(top, Game.player.global_position.y)
	print("    A jump clears %.2f m" % (top - y0))
	_check(top - y0 > 0.8, "The pilgrim can jump")

	_check(_raise(carter) == "raised", "Chalk, strap and rite raise the carter for good")
	_check(carter.state == "gone", "A raised Pinned does not return")
	_check(_raise(_pinned("Pip")) == "raised", "The child is raised")

	# A strap that runs out.
	var edda := _pinned("Edda")
	edda.take_hit(999, Game.player.global_position)
	edda.interact()
	_press("Throw chalk")
	_press("Bind it")
	await _save("07_rite")
	for n in 6:
		_press("Say the Rite")
	_check(Game.battle.result == "lost", "Saying the rite before the spirit is ready wastes the strap")
	_press("Continue")

	Game.add_item("sword")
	Game.toggle_equip("sword")
	Game.inventory.toggle()
	await _save("07a_inventory")
	Game.inventory.toggle()

	await _shot("07b_tavern", Vector3(22.2, 0.4, -22.2), 135, -4)
	await _shot("08_village", Vector3(198, 0.1, 17), -92, 3)
	await _shot("09_village_square", Vector3(238, 0.1, 32), 120, 0)
	await _shot("09b_ned", Vector3(223.2, 0.1, 31.2), 157, 0)
	await _shot("09c_jetty", Vector3(252, 0.1, 58), -115, -2)
	await _shot("09d_hills", Vector3(150, 0.1, -6), -60, 2)

	# ---- The Tallow Ford chapter, played through one set of choices ----
	var story: Node = Game.story
	Game.chalk = 20
	Game.straps = 20
	# Mara will not leave while her father is pinned.
	_check(_offer("mara", "Ask her to become"), "Mara can be asked")
	Game.dialogue.close()
	_check(not _npc("mara").recruited and story.has("mara_asked"), "She will not come while her father is on the jetty")
	# Oswin refuses the rite, and says why.
	var oswin := _pinned("Oswin")
	oswin.take_hit(999, Game.player.global_position)
	oswin.interact()
	_check(Game.dialogue.active(), "The rite over Oswin becomes a scene with a choice")
	Game.player.global_position = Game.main.ground(oswin.global_position + Vector3(-2.5, 0, 1.5)) + Vector3(0, 0.1, 0)
	await _save("09e_oswin")
	_choose("\"Where is the weir?\"")
	Game.dialogue.close()
	_check(story.has("oswin_promise") and oswin.passive and not oswin.can_be_hit(), "Promised, he stands and waits instead of fighting")
	oswin.interact()
	_check(Game.dialogue.active(), "He can be spoken to while he waits")
	Game.dialogue.close()
	# His wife, under the weir.
	await _shot("09f_weir", Vector3(266, 0.1, 126), -120, -4)
	_check(_raise(_pinned("Ysolt")) == "raised" and story.has("ysolt_raised"), "Ysolt is raised from the weir")
	oswin.interact()
	_check(story.has("oswin_willing") and oswin.state == "gone" and Game.count("pole") == 1, "Then Oswin goes gladly, and leaves his pole")
	Game.dialogue.close()
	_offer("mara", "Tell her about her father")
	_choose("Welcome her")
	_check(_npc("mara").recruited and story.has("mara_willing"), "Told the truth, Mara joins")
	# Ned, Hesper and the east field.
	_offer("ned", "Ask him to become")
	Game.dialogue.close()
	_offer("hesper", "She wants a word")
	Game.dialogue.close()
	_check(story.has("hesper_spoke") and not _npc("ned").recruited, "Hesper asks for her field back before Ned goes")
	await _shot("09g_field", Vector3(244, 0.1, -10), -115, 0)
	_check(_raise(_pinned("Hale")) == "raised" and story.has("hale_raised"), "Hale is raised from the east field")
	_offer("hesper", "Tell her the east field")
	Game.dialogue.close()
	_check(Game.count("hat") >= 1, "Hesper gives her son's coat and hat")
	_offer("ned", "\"The east field is free")
	_choose("Welcome him")
	_check(_npc("ned").recruited and story.has("ned_blessed"), "Ned goes with her blessing")
	# Wren and the porter.
	_offer("wren", "Ask her to become")
	Game.dialogue.close()
	var porter := _pinned("A porter")
	porter.take_hit(999, Game.player.global_position)
	porter.interact()
	_choose("\"What happened to the Pilgrimage?\"")
	_check(story.has("gornn_testimony"), "The porter tells what the last Pilgrimage was told")
	_choose("\"They got home. All five")
	Game.dialogue.close()
	_check(story.has("porter_raised") and Game.count("old_sword") == 1, "Raised, it leaves the old sword")
	_offer("wren", "Tell her about the tall one")
	_check(_choose("\"It asked whether the others got home"), "Knowing its story opens a third thing to say to Wren")
	_choose("Welcome her")
	_check(_npc("wren").recruited and story.has("wren_truth"), "Wren joins knowing the truth")
	# The pyre, the far bank, and Ivo.
	_offer("pell", "He has something to ask")
	Game.dialogue.close()
	story.tam()
	_choose("Leave him to the fire")
	Game.dialogue.close()
	_check(story.has("tam_burned"), "Tam can be left to the fire")
	_check(Game.story.actions(_npc("ivo")).filter(func(a): return String(a[0]).begins_with("Tell him what stands")).is_empty(), "Ivo cannot be told about the far bank before it has been seen")
	await _shot("09h_ash", Vector3(308, 0.1, 20), -90, 0)
	Game.player.global_position = Game.main.ground(Vector3(322, 0, 20)) + Vector3(0, 0.1, 0)
	for f in 5:
		await get_tree().process_frame
	_check(story.has("ash_seen"), "Crossing the footbridge shows what burning does")
	_offer("ivo", "Tell him what stands")
	_choose("\"It was the best anyone here could do")
	_choose("Welcome him")
	_check(_npc("ivo").recruited and story.has("ivo_taught"), "Told gently, Ivo asks to be taught")
	# The camp.
	await _shot("09i_camp", Vector3(140, 0.1, -104), -130, -2)
	story.journal()
	Game.dialogue.close()
	_check(story.has("camp_journal"), "The pilgrims' journal can be read")
	_check(Game.register_count() == 12, "Register stands at 12")
	var tale: String = story.epilogue()
	_check(tale.contains("ferry pole lies along the planks") and tale.contains("harvest money") and tale.contains("lamp at the high ford") and tale.contains("flour bag") and tale.contains("smoke came down"), "The epilogue tells what these choices led to")
	# A different choice reads differently.
	Game.flags.erase("ned_blessed")
	Game.flags["ned_taken"] = true
	_check(story.epilogue().contains("Nobody cut the east field"), "A different choice gives a different epilogue")
	Game.flags.erase("ned_taken")
	Game.flags["ned_blessed"] = true

	# Minds: the same act lands differently on different people, and word spreads.
	var MindScript = load("res://scripts/mind.gd")
	var Data = load("res://scripts/data.gd")
	var guarded = MindScript.new()
	guarded.setup("ivo", Data.MINDS["ivo"])
	var easy = MindScript.new()
	easy.setup("ned", Data.MINDS["ned"])
	var g0: float = guarded.feeling()
	var e0: float = easy.feeling()
	guarded.experience("gift", 0.7, 1.0)
	easy.experience("gift", 0.7, 1.0)
	print("    The same gift moves guarded Ivo by %.2f and open Ned by %.2f" % [guarded.feeling() - g0, easy.feeling() - e0])
	_check(easy.feeling() - e0 > (guarded.feeling() - g0) * 1.3, "The same gift warms an open person more than a guarded one")
	guarded.experience("theft", -0.9, 2.5)
	easy.experience("theft", -0.9, 2.5)
	print("    After also being robbed: Ivo %.2f, Ned %.2f" % [guarded.feeling(), easy.feeling()])
	_check(guarded.feeling() < easy.feeling(), "A wrong sinks deeper into someone who holds grudges")
	_check(easy.expects("trade") > easy.expects("theft"), "They expect different things from you in different situations")

	# Trade, looting, and things that belong to someone.
	var pell := _npc("pell")
	Game.coins = 40
	var axes := Game.count("axe")
	pell._buy("axe", 26)
	_check(Game.count("axe") == axes + 1 and Game.coins == 14, "Goods can be bought")
	pell._sell("axe", 11)
	_check(Game.count("axe") == axes and Game.coins == 25, "...and sold")
	var crate: Node = null
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("empty") and n.title == "the carter's crate":
			crate = n
	crate.interact()
	_check(Game.count("coat") >= 1 and crate.empty(), "An unowned crate can be searched without offence")

	# Crime.
	Game.player.global_position = Vector3(236, 0.1, -6.5)
	Game.main._steal()
	_check(Game.flags.has("stolen"), "The strongbox can be robbed")
	var before: float = Game.standing("tallow")
	# A first blow turns them; guards who see it come for the player.
	var wren_guard := _npc("wren")
	wren_guard.global_position = pell.global_position + Vector3(3, 0, 0)
	pell.take_hit(1, Game.player.global_position)
	_check(pell.aggro and pell._flee, "A shopkeeper who is struck turns and runs")
	_check(wren_guard.aggro and not wren_guard._flee, "A guard who sees it comes for the player")
	pell.take_hit(999, Game.player.global_position)
	_check(not pell.alive, "A villager can be killed")
	_check(Game.standing("tallow") < before - 0.2, "Those who saw it turn against the player")
	_check(Game.pinned.size() == 13, "The victim will come back as one of the Pinned")
	var sack: Node = null
	for n in get_tree().get_nodes_in_group("interact"):
		if n.has_method("empty") and String(n.title).begins_with("Pell"):
			sack = n
	_check(sack != null and not sack.empty(), "The dead leave their belongings behind")
	# What witnessing it did to them.
	var changed: Node = null
	for n in Game.villagers("tallow"):
		if n.mind.scars > 0 and changed == null:
			changed = n
	_check(changed != null, "Someone who saw the killing is changed by it")
	var D = load("res://scripts/data.gd")
	print("    %s: openness %.2f (was %.2f), grudge %.2f (was %.2f), fear %.2f, now seems %s" % [changed.npc_name, changed.mind.open, D.MINDS[changed.id]["open"], changed.mind.grudge, D.MINDS[changed.id]["grudge"], changed.mind.fear, changed.mind.state_word()])
	_check(changed.mind.open < D.MINDS[changed.id]["open"] and changed.mind.grudge > D.MINDS[changed.id]["grudge"], "Their temperament itself has shifted, not only their opinion")
	_check(Game.bounty["tallow"] > 0, "What was seen is reported, and a price is put on it")
	print("    Tallow Ford now holds %d coin against the player" % Game.bounty["tallow"])
	# A guard walks up about it.
	wren_guard.aggro = false
	wren_guard._confront_cd = 0.0
	wren_guard.global_position = Game.player.global_position + Vector3(1.5, 0, 0)
	wren_guard._crowd_check()
	_check(Game.dialogue.active(), "A guard who knows confronts the player")
	Game.coins = 500
	Game.dialogue._pay(Game.bounty["tallow"])
	_check(Game.bounty["tallow"] == 0, "Paying settles the law")
	Game.dialogue.close()
	# Nobody walks through walls: someone sent straight at a house goes round it or stops.
	var walker := _npc("ned")
	walker.aggro = false
	var house := Vector3(211, 0, 33)
	walker.global_position = Game.main.ground(house + Vector3(0, 0, 9))
	var inside := false
	walker._state = "walk"
	for f in 400:
		walker._step_towards(house + Vector3(0, 0, -9), 0.05)
		var rel: Vector3 = walker.global_position - house
		# The house is 6 by 4.5, turned to face the square; well inside its footprint is inside the wall.
		if Vector2(rel.x, rel.z).length() < 1.6:
			inside = true
	print("    Sent at a house, Ned ended %.1f m from its centre" % Vector2(walker.global_position.x - house.x, walker.global_position.z - house.z).length())
	_check(not inside, "A person sent straight at a house does not pass through it")
	var ring_edge := Vector3(28, 0, 22)
	var kel := _npc("kelvin")
	kel.global_position = Game.main.ground(ring_edge)
	kel._state = "avoid"
	for f in 200:
		kel._step_towards(ring_edge + Vector3(30, 0, 12), 0.05)
	print("    Run at the Ring wall, Kelvin ended %.1f m from the centre (the wall is at %.0f)" % [Vector2(kel.global_position.x, kel.global_position.z).length(), Game.RING_RADIUS])
	_check(Game.in_ring(kel.global_position), "Someone running at the Ring wall stays inside it")
	# And how they speak changes with it.
	var luie := _npc("luie")
	luie.mind.fear = 0.9
	luie.mind.experience("violence", -0.6, 1.0, false, "someone")
	print("    Luie, frightened, seems %s" % luie.mind.state_word())
	_check(luie.mind.state_word() == "afraid" and luie.topic_text("Dangerous dead") != luie.def["topics"]["Dangerous dead"], "A frightened person answers differently")
	_check(luie.greeting().contains("flinch"), "...and greets the player differently")
	luie.mind.forgive()
	luie.mind.fear = 0.0
	var tommy := _npc("tommy")
	var fair: int = tommy.price(10)
	tommy.mind.experience("theft", -0.9, 3.0)
	_check(tommy.price(10) > fair, "A trader who distrusts the player charges them more")
	tommy.mind.forgive()

	# Amends.
	var grieved: Node = null
	for n in Game.villagers("tallow"):
		if n.mind.remembers("violence") and (grieved == null or n.mind.feeling() < grieved.mind.feeling()):
			grieved = n
	Game.coins = 100
	grieved.aggro = false
	var sore: float = grieved.mind.feeling()
	grieved._amends(60)
	print("    Amends moved %s from %.2f to %.2f" % [grieved.npc_name, sore, grieved.mind.feeling()])
	_check(grieved.mind.feeling() > sore and not grieved.hostile(), "Paying amends lets someone speak to the player again")
	var seen_it := 0
	var hostile_now := 0
	for n in Game.villagers("tallow"):
		if n.mind.remembers("violence"):
			seen_it += 1
		if n.hostile():
			hostile_now += 1
	print("    %d villagers know about the killing; %d are now hostile" % [seen_it, hostile_now])
	_check(seen_it >= 2, "More than one person saw the killing")
	# Word of mouth: someone who knows tells someone who does not.
	var teller: Node = null
	var hearer: Node = null
	for n in Game.villagers("tallow"):
		if n.mind.remembers("violence") and teller == null:
			teller = n
	for n in Game.villagers("rhodes"):
		if hearer == null:
			hearer = n
	var h_before: float = hearer.mind.feeling()
	_check(hearer.mind.hear(teller.mind.gossip()), "News can be passed from one person to another")
	_check(hearer.mind.feeling() < h_before, "Hearing of a killing lowers their opinion without having seen it")

	# The tavern table.
	Game.coins = 20
	Game.battle.start_wrestle()
	_check(Game.battle.active(), "The arm wrestling table can be sat at")
	var rounds := 0
	while Game.battle.result == "" and rounds < 60:
		rounds += 1
		_press(["Toproll", "Hook", "Press"][rounds % 3])
	_check(Game.battle.result == "wrestled" and Game.coins != 20, "A match is pulled to three pins and coin changes hands")
	_press("Continue")

	_check(_offer("harry", "\"I've brought three"), "Harry can be told")
	_choose("Tell him what the last Pilgrimage was told")
	_choose("\"Nobody yet. But people should know.\"")
	await _shot("10_end", Game.RHODES_SPAWN, 25)
	_check(Game.flags.has("slice_done") and Game.flags.has("will_tell"), "The chapter ends with the epilogue, and what was said to Harry is remembered")
	# A lie holds only until it is found out.
	var before_n: int = Game.recruits.size()
	Game.flags["mara_lied"] = true
	story._mara_finds_out()
	_check(Game.recruits.size() == before_n - 1 and story.has("mara_gone"), "A lie about Oswin costs Mara when she finds out")

	print("SELFTEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)
