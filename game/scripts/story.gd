extends Node
## The Tallow Ford chapter: four people who might become Risers, what each one needs,
## and what it costs. Choices here are remembered in Game.flags, change the village, can
## be lied about and found out, and are read back to the player in the epilogue.

const Data = preload("res://scripts/data.gd")

var _lie_clock := -1.0

func has(k: String) -> bool:
	return Game.flags.has(k)

func mark(k: String) -> void:
	Game.flags[k] = true

func who(id: String) -> Node:
	for n in Game.npcs:
		if n.id == id and n.alive:
			return n
	return null

func pinned(id: String) -> Node:
	for p in Game.pinned:
		if p.spirit.get("id", "") == id:
			return p
	return null

func show(title: String, sub: String, text: String, choices: Array, portrait := "") -> void:
	Game.dialogue.scene(title, sub, text, choices, portrait)

func done(text := "") -> Callable:
	return func():
		if text != "":
			show("", "", text, [["Continue", Game.dialogue.close]])
		else:
			Game.dialogue.close()

func join(id: String, how: String) -> void:
	var n := who(id)
	if n == null or n.recruited:
		return
	n.recruited = true
	Game.recruits.append(n.npc_name)
	mark(id + "_joined")
	mark(id + "_" + how)
	Game.say("%s will become a Riser. The Register stands at %d of %d." % [n.npc_name, Game.register_count(), Game.QUOTA])
	Game.note("%s of Tallow Ford agreed to become a Riser." % n.npc_name)
	Game.touch()

func leave(id: String) -> void:
	var n := who(id)
	if n and n.recruited:
		n.recruited = false
		Game.recruits.erase(n.npc_name)
		Game.touch()

func feel(id: String, kind: String, valence: float, weight: float) -> void:
	var n := who(id)
	if n:
		n.mind.experience(kind, valence, weight, true, "")

# --- What each person offers, depending on where things stand -----------------------

func actions(n: Node) -> Array:
	match n.id:
		"mara":
			return _mara()
		"ned":
			return _ned()
		"hesper":
			return _hesper()
		"ivo":
			return _ivo()
		"pell":
			return _pell()
		"wren":
			return _wren()
		"harry":
			return _harry()
	return []

# --- Mara, Oswin and the weir ---------------------------------------------------------

func _mara() -> Array:
	var out: Array = []
	if has("mara_joined") or has("mara_gone"):
		return out
	if has("oswin_willing") and not has("mara_told"):
		out.append(["Tell her about her father and her mother", _mara_best])
	elif has("oswin_forced") and not has("mara_told"):
		out.append(["Tell her that her father has risen", _mara_forced])
	elif has("oswin_left") and not has("mara_told"):
		out.append(["Tell her what her father asked", _mara_left])
	elif not has("mara_asked"):
		out.append(["Ask her to become a Riser", func():
			mark("mara_asked")
			Game.note("Mara Quill will go nowhere while her father Oswin is pinned on the old jetty, south of the village along the river.")
			show("Mara Quill", "Ferrywoman", "\"My father's on the old jetty, south along the bank. Two winters. He walks the planks like he's waiting on a fare.\n\nWhile he's down there I go nowhere. You people say you raise the dead. Go and look at him. Then come and tell me what you saw.\"", [["Leave it there", Game.dialogue.close]])])
	return out

func _mara_best() -> void:
	mark("mara_told")
	feel("mara", "raised_kin", 1.0, 5.0)
	show("Mara Quill", "Ferrywoman", "You tell her all of it: that he would not go while her mother lay under the weir, that you went down and raised her, that he laid the pole on the planks himself.\n\nShe is quiet for a long time.\n\n\"He never said. Two winters I thought he was waiting on a fare.\" She wipes her face with her wrist. \"He said the ferry was mine?\"\n\n\"Then put my name on your board. Somebody did that for mine. I can do it for somebody's.\"", [["Welcome her", func():
		join("mara", "willing")
		Game.dialogue.close()]])

func _mara_forced() -> void:
	show("Mara Quill", "Ferrywoman", "She is already looking past you, down the bank.\n\n\"He's gone? You did it?\"", [
		["\"He went gladly.\"  (lie)", func():
			mark("mara_told")
			mark("mara_lied")
			feel("mara", "raised_kin", 1.0, 4.0)
			_lie_clock = 150.0
			show("Mara Quill", "Ferrywoman", "\"Gladly.\" She breathes out. \"Then that's what I'll do. Put my name down.\"\n\nYou can still hear the way he said her name.", [["Say nothing more", func():
				join("mara", "lied")
				Game.dialogue.close()]])],
		["\"He begged me not to. I did it anyway.\"", func():
			mark("mara_told")
			mark("mara_gone")
			feel("mara", "violence", -1.0, 5.0)
			show("Mara Quill", "Ferrywoman", "She does not shout. That is worse.\n\n\"He asked you. And you had the strap on him, so you did as you liked.\" She steps back from you. \"That's Rhodes. That's what Ivo always said you were.\n\nGet off my bank.\"", [["Go", Game.dialogue.close]])],
	])

func _mara_left() -> void:
	show("Mara Quill", "Ferrywoman", "\"Well? Did you see him?\"", [
		["Tell her the truth: he is waiting for her mother, and asked to be left", func():
			mark("mara_told")
			mark("mara_watch")
			feel("mara", "helped", 0.8, 3.0)
			Game.note("Oswin's wife lies under the weir, downstream to the south. He will not rise while she is there.")
			show("Mara Quill", "Ferrywoman", "\"Mother.\" She sits down on the mooring post. \"They never found her. I never thought...\"\n\n\"No. I'll not have my name on your board, pilgrim. Somebody has to keep the bank while he keeps his watch. But you could have said the words and walked off, and you didn't.\"\n\n\"If you ever go down to the weir, I'll hear of it.\"", [["Leave her to it", Game.dialogue.close]])],
		["\"He has risen. He's at peace.\"  (lie)", func():
			mark("mara_told")
			mark("mara_lied")
			mark("mara_lied_left")
			feel("mara", "raised_kin", 1.0, 4.0)
			_lie_clock = 120.0
			show("Mara Quill", "Ferrywoman", "\"At peace.\" She closes her eyes. \"Then I've nothing keeping me. Put my name down.\"\n\nA quarter of a mile south, he is still walking the planks.", [["Say nothing more", func():
				join("mara", "lied")
				Game.dialogue.close()]])],
	])

## The rite over Oswin, once chalk and strap are on him.
func _oswin_rite(p: Node) -> void:
	p.reveal()
	if has("ysolt_raised"):
		_oswin_goes(p)
		return
	show("Oswin Quill", "Ferryman, two winters dead", "The chalk settles on an old man with a ferry pole, wet through. He looks at the strap on him, and then at you.\n\n\"Rhodes. I know what you've come to do. Don't.\"\n\n\"My wife went into the river the winter before I did. They never found her. She's down at the weir, under the water, where the dark holds her. If I go up, she's alone down there. So I wait.\"\n\n\"Take your strap off me, and say nothing to my girl.\"", [
		["\"Where is the weir?\"", func():
			mark("oswin_promise")
			p.passive = true
			p.stand_up()
			Game.note("Oswin will not rise while his wife Ysolt lies under the weir. Downstream, south of the jetty, where the river breaks over old stones. She will not know you.")
			show("Oswin Quill", "Ferryman", "\"Downstream. South, where the river breaks over the old stones. You'll see her before she sees you, if you're careful.\"\n\n\"She won't know you. She'll fight. But she was Ysolt Quill and she poled this river thirty years, and if you tell her I'm on the jetty she'll hear it.\"\n\n\"Raise her, and I'll go gladly.\"", [["Let the strap go", Game.dialogue.close]])],
		["Say the rite over his refusal", func():
			mark("oswin_forced")
			p.raise_up()
			show("Oswin Quill", "", "You say the words.\n\nHe does not go up the way the others did. He is dragged. His hands close on the planks and the planks will not hold him.\n\n\"Mara—\"\n\nThen the chalk falls, and the jetty is empty. It is done. He is risen. You can tell yourself that.", [["Walk back", Game.dialogue.close]])],
		["Let the strap go, and leave him to his watch", func():
			mark("oswin_left")
			p.passive = true
			p.stand_up()
			show("Oswin Quill", "Ferryman", "He watches you coil the strap.\n\n\"That's more than I expected from the Ring.\" He turns back to the water. \"Go on. I've a crossing to mind.\"", [["Leave him", Game.dialogue.close]])],
	])

func _oswin_goes(p: Node) -> void:
	mark("oswin_willing")
	Game.flags.erase("oswin_left")
	p.raise_up()
	Game.add_item("pole")
	show("Oswin Quill", "Ferryman", "He already knows. You can see it in how he stands.\n\n\"She went up? She heard you?\"\n\nHe lays the pole down along the planks, carefully, the way a man puts down a thing he has carried all his life.\n\n\"Tell Mara the ferry's hers. Tell her I wasn't waiting on a fare.\"\n\nYou say the words, and he goes up like a man stepping off a boat.", [["Take up the pole", Game.dialogue.close]])

# --- Ned, Hesper and the east field -----------------------------------------------------

func _ned() -> Array:
	var out: Array = []
	if has("ned_joined"):
		return out
	if not has("ned_asked"):
		out.append(["Ask him to become a Riser", func():
			mark("ned_asked")
			show("Ned Harrow", "Farmhand", "\"Me? In Rhodes? Inside the Ring?\" He is already half out of his boots. \"I've never been past the last fence. Yes. Today. Now, if you like.\"\n\nBehind him, in the doorway, Old Hesper is watching you both. She does not look pleased.", [["Tell him to wait a moment", Game.dialogue.close]])])
	elif has("hale_raised"):
		out.append(["\"The east field is free. Come with me.\"", func():
			show("Ned Harrow", "Farmhand", "\"Uncle Hale's gone up? You did that?\" He looks east, toward the barley. \"He said I was stronger than I think. He never said that when he was alive.\"\n\n\"Gran says I can go once it's cut. And it'll be cut. Put my name down, pilgrim. I'll come up the road with the harvest money.\"", [["Welcome him", func():
				join("ned", "blessed")
				Game.dialogue.close()]])])
	elif not has("ned_waits"):
		out.append(["\"Come now. The field is not your problem.\"", func():
			feel("hesper", "violence", -0.8, 4.0)
			show("Ned Harrow", "Farmhand", "He looks at the house, and at the road, and the road wins.\n\n\"She'll manage. She always has.\" He does not sound sure. \"Put my name down.\"\n\nFrom the doorway Hesper says nothing at all. She just goes in, and shuts the door.", [["Take him", func():
				join("ned", "taken")
				Game.dialogue.close()]])])
		out.append(["\"Stay until the field is cut. I'll come back for you.\"", func():
			mark("ned_waits")
			feel("ned", "nagged", -0.4, 1.5)
			feel("hesper", "helped", 0.6, 2.0)
			show("Ned Harrow", "Farmhand", "His face falls like a boy's.\n\n\"Until it's cut. And who's cutting it, with him out there?\" He kicks the step. \"Fine. Fine. I'll be here. I'm always here.\"", [["Leave him", Game.dialogue.close]])])
	return out

func _hesper() -> Array:
	var out: Array = []
	if has("ned_asked") and not has("hesper_spoke") and not has("ned_joined"):
		out.append(["She wants a word about Ned", func():
			mark("hesper_spoke")
			Game.note("Hesper's son Hale is pinned in the east field, between the village and the river, cutting at barley nobody dares harvest. She will not let Ned go while the field stands.")
			show("Old Hesper", "Elder", "\"He's my daughter's boy, and the only back on this farm.\"\n\n\"The barley's standing in the east field, between here and the river, and nobody will cut it. My son Hale is out there with a scythe handle and no blade, cutting at nothing, and he goes for anyone who comes near. If Ned leaves, that field rots, and so do I, before spring.\"\n\n\"You want a Riser out of this house? Then give me my field back first.\"", [["\"I'll see what can be done.\"", Game.dialogue.close]])])
	if has("hale_raised") and not has("hesper_thanked"):
		out.append(["Tell her the east field is free", func():
			mark("hesper_thanked")
			feel("hesper", "raised_kin", 1.0, 5.0)
			Game.add_item("coat")
			Game.add_item("hat")
			show("Old Hesper", "Elder", "She takes it standing up, which costs her.\n\n\"Hale. Well.\" She looks at her hands. \"He was a stubborn child and a stubborn man and I suppose he was stubborn after.\"\n\n\"Take the boy. He was never going to stay. And take these: they were Hale's, for the road. He'd not have wanted them rotting on a peg.\"", [["Take the coat and hat", Game.dialogue.close]])])
	if not has("camp_told"):
		out.append(["Ask where the last pilgrims camped", func():
			mark("camp_told")
			Game.note("Hesper: the last pilgrims camped north of the road, in the hills, beyond where it bends round the pines. Look for the two dead trees.")
			show("Old Hesper", "Elder", "\"My grandmother carried water up to them. North of the road, in the hills, past where it bends round the pines. Two dead trees stand over the place.\"\n\n\"Nobody goes. What they left is still there, I'd think. And what they left to guard it.\"", [["Thank her", Game.dialogue.close]])])
	return out

# --- Ivo, Pell and the body on the pyre -------------------------------------------------

func _pell() -> Array:
	var out: Array = []
	if not has("tam_asked") and not has("tam_raised") and not has("tam_burned"):
		out.append(["He has something to ask you", func():
			mark("tam_asked")
			Game.note("Pell's father Tam lies wrapped on the pyre at the west of the village. Pell wants the rite said over him before Ivo burns him. He says to look at what stands on the far bank, over the footbridge.")
			show("Pell", "Shopkeeper", "He comes round the counter, which you suspect he does not often do.\n\n\"My father died in the night. He's on Ivo's pyre now, wrapped. Ivo means to burn him, like all of ours.\"\n\n\"I watched my mother burn. Go over the footbridge some time, pilgrim, and look at what stands on the far bank where the smoke comes down. Then tell me fire sets anyone free.\"\n\n\"Forty coin. Say your words over him before the fire. Ivo will hate you for it. I don't care.\"", [["\"I'll go and look at him.\"", Game.dialogue.close]])])
	if has("tam_raised") and not has("pell_paid"):
		out.append(["Tell him it is done", func():
			mark("pell_paid")
			Game.coins += 40
			feel("pell", "raised_kin", 1.0, 5.0)
			Game.touch()
			show("Pell", "Shopkeeper", "He counts out forty coin and then, after a moment, pushes the whole purse across.\n\n\"No. Take the forty. A deal's a deal.\" He takes most of it back. \"But you'll never pay full price in here again.\"", [["Take the forty", Game.dialogue.close]])])
	return out

func _ivo() -> Array:
	var out: Array = []
	if has("ivo_joined") or has("ivo_shamed"):
		return out
	if not has("ivo_warned") and not has("tam_raised") and not has("tam_burned"):
		out.append(["Ask about the body on the pyre", func():
			mark("ivo_warned")
			show("Ivo Brand", "Pyre-keeper", "\"Tam is ours. We burn ours.\"\n\n\"Rhodes had a hundred and thirty-four years to walk up that road and say its words over our dead, and it sat behind its wall. Now it wants them. You will not start with him.\"\n\n\"Touch that shroud and you and I are finished, pilgrim.\"", [["Leave it", Game.dialogue.close]])])
	if has("ash_seen"):
		out.append(["Tell him what stands on the far bank", _ivo_truth])
	return out

func _ivo_truth() -> void:
	show("Ivo Brand", "Pyre-keeper", "You tell him. The grey ground over the footbridge. The figures standing in it, thin as smoke, facing the village. One of them is Anwen Pell.\n\nHe does not call you a liar. You realise he has never once crossed that bridge.\n\n\"Thirty years,\" he says. \"Thirty years I've stood at that fire.\"", [
		["\"It was the best anyone here could do. Nobody came to teach you better.\"", func():
			feel("ivo", "helped", 1.0, 6.0)
			var n := who("ivo")
			if n:
				n.mind.forgive()
			show("Ivo Brand", "Pyre-keeper", "He is silent long enough that you think he will not answer.\n\n\"Then teach me. The words, the chalk, all of it. I put them there. I'll be the one to bring them back across.\"\n\n\"Put my name on your board. And stay out of my way while I do it.\"", [["Welcome him", func():
				join("ivo", "taught")
				Game.dialogue.close()]])],
		["Say it where the whole village can hear", func():
			mark("ivo_shamed")
			for id in ["pell", "hesper", "ned", "wren", "mara"]:
				feel(id, "helped", 0.5, 1.5)
			var n := who("ivo")
			if n:
				n.mind.experience("violence", -1.0, 6.0, true, "")
			show("Ivo Brand", "Pyre-keeper", "You raise your voice. Doors open. Pell comes out of the shop.\n\nBy the time you have finished, nobody is looking at you. They are all looking at Ivo.\n\nHe puts down the torch he was carrying. He does not pick it up again. Tallow Ford will listen to Rhodes now. It cost one old man everything he was.", [["Walk away", Game.dialogue.close]])],
	])

## The body on the pyre.
func tam() -> void:
	if has("tam_raised") or has("tam_burned"):
		Game.say("The pyre is cold." if has("tam_raised") else "Ash, and the smell of it.")
		return
	var choices: Array = []
	if Game.chalk > 0 and Game.straps > 0:
		choices.append(["Say the rite over him  (one chalk, one strap)", func():
			Game.chalk -= 1
			Game.straps -= 1
			mark("tam_raised")
			Game.raised += 1
			if not has("ivo_joined"):
				feel("ivo", "violence", -0.9, 5.0)
			Game.main.pyre_out()
			show("Tam Pell", "", "There is no fight in it. He is hours dead, not years. The chalk shows an old man with flour on his hands, a little puzzled to be looked at.\n\nYou tell him his son sent you. He nods as if that settles a small argument, and goes.\n\n" + ("Ivo watches from the pyre and says nothing. He taught himself the words this morning." if has("ivo_joined") else "When you turn round, Ivo is standing at the edge of the square. He has seen all of it."), [["Step back from the pyre", Game.dialogue.close]])])
	choices.append(["Leave him to the fire", func():
		mark("tam_burned")
		feel("ivo", "helped", 0.6, 3.0)
		feel("pell", "nagged", -0.6, 3.0)
		Game.main.pyre_lit()
		show("The pyre", "", "It is not your village and he is not your dead.\n\nAt dusk Ivo lights it. Pell watches from the shop door and does not come out. The smoke goes up white, leans east, and comes down on the far bank.", [["Watch it burn", Game.dialogue.close]])])
	choices.append(["Not yet", Game.dialogue.close])
	show("The pyre", "", "A body lies on the stacked wood, wrapped in clean linen and tied at the ankles and the chest. Tam Pell. Someone has tucked a sprig of barley under the cord." + ("" if Game.chalk > 0 and Game.straps > 0 else "\n\nYou would need chalk and a strap to say the rite."), choices)

# --- Wren and the porter -----------------------------------------------------------------

func _wren() -> Array:
	var out: Array = []
	if has("wren_joined") or has("wren_refused"):
		return out
	if not has("wren_asked"):
		out.append(["Ask her to become a Riser", func():
			mark("wren_asked")
			Game.note("Wren Calloway will put her name down the day the tall Pinned with the pack, north of the road past the pines, is finished. Finished, she says. Not raised.")
			show("Wren Calloway", "Hunter", "\"I'll put my name on your board the day that thing on the north side of the road is finished. The tall one, bent over, like it's carrying a pack. Past the pines.\"\n\n\"It killed Aldous. I've put it down nine times and it's up again by morning.\"\n\n\"Not raised, pilgrim. I don't want it at peace. I want it to stop.\"", [["\"I'll find it.\"", Game.dialogue.close]])])
	elif has("porter_raised"):
		out.append(["Tell her about the tall one", _wren_answer])
	return out

func _wren_answer() -> void:
	var choices: Array = [
		["\"It's destroyed. Burned out. Nothing rose.\"  (lie)", func():
			mark("wren_lied")
			feel("wren", "helped", 0.9, 4.0)
			show("Wren Calloway", "Hunter", "\"Good.\" She says it like spitting. \"Good. Then Aldous can lie easy, and so can I.\"\n\n\"Put my name down.\"", [["Say nothing more", func():
				join("wren", "lied")
				Game.dialogue.close()]])],
		["\"I raised it. It's at peace, and it will not be back.\"", func():
			var n := who("wren")
			if n and n.mind.feeling() >= 0.25:
				show("Wren Calloway", "Hunter", "Her hand goes to her knife and stays there.\n\n\"You gave it peace.\" A long breath. \"I've watched you on that road. You don't do things the easy way.\" She lets go of the hilt.\n\n\"I don't forgive it. But it's stopped, and you didn't lie to me about how. Put my name down before I think better of it.\"", [["Welcome her", func():
					join("wren", "truth")
					Game.dialogue.close()]])
			else:
				mark("wren_refused")
				feel("wren", "violence", -0.7, 3.0)
				show("Wren Calloway", "Hunter", "\"You gave it peace.\" She looks at you as though you had done it to her. \"I asked you for one thing.\"\n\n\"You'll fill your board without me.\"", [["Go", Game.dialogue.close]])],
	]
	if has("gornn_testimony"):
		choices.insert(1, ["\"It asked whether the others got home. They left it behind, too.\"", func():
			feel("wren", "helped", 0.8, 4.0)
			show("Wren Calloway", "Hunter", "She had the next thing ready to say, and it goes out of her.\n\n\"A hundred and thirty-four years. Waiting to hear if they made it.\" She looks north, toward the pines. \"Aldous waited for me once, at the high ford, two nights in the snow. I was late.\"\n\n\"All right, pilgrim. It's stopped, and it didn't deserve what it got either. Put my name down.\"", [["Welcome her", func():
				join("wren", "truth")
				Game.dialogue.close()]])])
	show("Wren Calloway", "Hunter", "\"The road's been quiet on the north side. Tell me why.\"", choices)

## The rite over the porter of the last Pilgrimage.
func _porter_rite(p: Node) -> void:
	p.reveal()
	var raise := func():
		mark("porter_raised")
		p.raise_up()
		show("A porter of the last Pilgrimage", "", "\"Then it was carried.\"\n\nThe bent back straightens, slowly, for the first time in a hundred and thirty-four years. You say the words, and what stood there goes up without looking back.\n\nWhere it stood, a sword lies in the grass, the crest on its guard the same as the one on your back.", [["Take up the sword", Game.dialogue.close]])
	var first: Array = [
		["\"What happened to the Pilgrimage?\"", func():
			mark("gornn_testimony")
			Game.note("The porter: in the eastern mountains a voice told the last Pilgrimage that Wukhan was the cause of everything, and to go home and end it. They believed it.")
			show("A porter of the last Pilgrimage", "", "\"We went east full of kindness. Five, and the one who carried the words, and me with the pack.\"\n\n\"In the mountains there was a voice like weather. It knew our names. It told us the machine was the cause of all of it: every one of these, standing in every field. It said: go home and end it.\"\n\n\"They believed it. They turned round that night. I could not keep up. They said they would send someone back.\"\n\n\"Did they get home?\"", [
				["\"They got home. All five reached the Ring.\"", raise],
				["Let the strap go", func():
					mark("porter_left")
					p.put_down()
					Game.dialogue.close()],
			])],
		["\"They got home. You can put the pack down.\"", raise],
		["Let the strap go, and let the dark have it back", func():
			mark("porter_left")
			p.put_down()
			show("", "", "It sinks without a sound. It will be up again by morning, bent under a pack that rotted away before your grandfather was born.", [["Walk on", Game.dialogue.close]])],
	]
	show("A porter of the last Pilgrimage", "134 years dead", "The chalk settles on an old, old shape under a pack frame that rotted away long ago. It is still bent as if carrying it.\n\nIt does not fight the strap. It looks at the crest on your back for a long time.\n\n\"Rhodes sent someone. They said they would.\"", first)

# --- Rites and risings that belong to the story -------------------------------------------

## Called when the player begins the rite over a fallen Pinned. Returns true if the story takes it from here.
func rite(p: Node) -> bool:
	var id: String = p.spirit.get("id", "")
	if id == "oswin" and p.passive:
		if has("ysolt_raised"):
			_oswin_goes(p)
		else:
			show("Oswin Quill", "Ferryman", "He does not turn from the water.\n\n\"" + ("Downstream. South. Where the river breaks over the old stones." if has("oswin_promise") else "I've a crossing to mind, pilgrim.") + "\"", [["Leave him", Game.dialogue.close]])
		return true
	if id not in ["oswin", "porter"]:
		return false
	if Game.chalk <= 0 or Game.straps <= 0:
		return false
	Game.chalk -= 1
	Game.straps -= 1
	if id == "oswin":
		_oswin_rite(p)
	else:
		_porter_rite(p)
	return true

func on_raised(p: Node) -> void:
	match p.spirit.get("id", ""):
		"ysolt":
			mark("ysolt_raised")
			Game.note("Ysolt Quill has risen from the weir. Oswin should be told.")
		"farmer":
			mark("hale_raised")
			feel("ned", "raised_kin", 0.9, 3.0)
			Game.note("Hale Harrow has risen. The east field can be cut. Hesper and Ned should be told.")
		"anwen":
			mark("anwen_raised")
			feel("pell", "raised_kin", 1.0, 3.0)

# --- Places ---------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if Game.player == null or Game.modal:
		return
	var p: Vector3 = Game.player.global_position
	if not has("ash_seen") and p.distance_to(Vector3(326, p.y, 20)) < 16.0:
		mark("ash_seen")
		Game.note("On the far bank, over the footbridge, the burnt dead of Tallow Ford stand in grey ground, thin as smoke. Burning does not free them.")
		Game.say("The ground here is grey. The figures in it are facing the village.")
	if not has("weir_seen") and p.distance_to(Vector3(280, p.y, 134)) < 16.0:
		mark("weir_seen")
		Game.say("The river breaks over a line of old cut stones. Something is standing in the water.")
	if not has("camp_seen") and p.distance_to(Vector3(150, p.y, -112)) < 14.0:
		mark("camp_seen")
		Game.say("Rotted canvas, a cold fire ring, and the crest of Rhodes on a fallen banner.")
	# A lie about Oswin holds only until she walks down to the jetty.
	if _lie_clock > 0.0:
		_lie_clock -= dt
		if _lie_clock <= 0.0 and has("mara_lied") and not has("mara_found_out"):
			_mara_finds_out()

func _mara_finds_out() -> void:
	mark("mara_found_out")
	var forced := has("oswin_forced")
	if forced:
		Game.say("Word comes up the bank: Mara has been down to the jetty. Someone who was fishing there saw how he went.")
	else:
		Game.say("Word comes up the bank: Mara walked down to the jetty. Her father is still there.")
	leave("mara")
	mark("mara_gone")
	feel("mara", "violence", -1.0, 6.0)
	for id in ["hesper", "wren", "ned", "pell"]:
		var n := who(id)
		if n:
			n.mind.experience("theft", -0.6, 2.0, false, "Mara's father")
	Game.note("Mara found out the truth about her father. She has taken her name off the Register, and the village knows why.")

## The pilgrims' journal, at their camp.
func journal() -> void:
	mark("camp_journal")
	Game.note("The pilgrims' journal: in the eastern mountains something that called itself the oldest of all told them Wukhan is why the dead do not rise. Their last entry: \"We go home to end it.\"")
	show("A pilgrim's journal", "134 years old", "Most of it is rot. The last pages were wrapped in oilcloth.\n\n\"...taller than the pass itself, and winged, and it knew each of us by name. It said it was the oldest thing living. It said the monks' machine is the cause: that while it runs, nothing can rise on its own, anywhere.\"\n\n\"Ryel asked how it could know. It laughed, and the snow came down off the peaks.\"\n\n\"We have talked all night. We go home to end it. May the Lion forgive us if we are wrong.\"\n\nThe rest is blank.", [["Close it", Game.dialogue.close]])

# --- Harry, and how it ends -----------------------------------------------------------------

func _harry() -> Array:
	var out: Array = []
	if has("slice_done"):
		return out
	if Game.recruits.size() >= Game.SLICE_GOAL:
		out.append(["\"I've brought three from Tallow Ford.\"", _report])
	elif Game.recruits.size() >= 1 and (has("camp_journal") or has("gornn_testimony") or Game.recruits.size() >= 2):
		out.append(["\"This is all Tallow Ford will give.\"", _report])
	return out

func _report() -> void:
	var n := Game.recruits.size()
	var open := "Three, from one village, and you walked that road to get them. Then it can be done." if n >= 3 else "%s. From a whole village.\" He looks at the board, and the empty lines on it. \"It's more than we had." % ("Two" if n == 2 else "One")
	if has("camp_journal") or has("gornn_testimony"):
		show("Harry Lu", "Head Riser", "\"%s\"\n\nYou have not told him the rest." % open, [
			["Tell him what the last Pilgrimage was told", func():
				show("Harry Lu", "Head Riser", "He hears you out without moving.\n\n\"A voice in the mountains said Wukhan is the cause. And they came home to end him.\" He glances, once, at the great slumped shape behind the hall. \"That is why none of them came out of the Ring again.\"\n\n\"Who else have you told?\"", [
					["\"Nobody. And I'll keep it that way.\"", func():
						mark("kept_quiet")
						_finish()],
					["\"Nobody yet. But people should know.\"", func():
						mark("will_tell")
						_finish()],
				])],
			["Keep it to yourself", func():
				mark("kept_secret")
				_finish()],
		], "harry")
	else:
		show("Harry Lu", "Head Riser", "\"%s\"" % open, [["Hear what became of it all", _finish]], "harry")

func _finish() -> void:
	mark("slice_done")
	Game.hud.show_end(epilogue())

## What became of everyone, because of what the player did.
func epilogue() -> String:
	var out: Array = []
	# Mara and Oswin
	if has("mara_willing"):
		out.append("Mara Quill poles the ferry by day and says the rite by night. On the old jetty a ferry pole lies along the planks where her father left it. Nobody moves it.")
	elif has("mara_found_out"):
		out.append("Mara Quill walked down to the jetty and learned what you had told her was not true. Her name is scratched off the Register. In Tallow Ford they say Rhodes lies as easily as it prays.")
	elif has("mara_lied"):
		out.append("Mara Quill's name is on the Register. She has not yet walked down to the jetty.")
	elif has("mara_watch"):
		out.append("Mara Quill keeps the bank while her father keeps his watch. Every evening she takes a lamp down to the jetty. She did not join you. She speaks well of you.")
	elif has("oswin_forced"):
		out.append("Oswin Quill is risen. He did not want to be. His daughter knows it, and will not look toward Rhodes again.")
	else:
		out.append("Oswin Quill still walks the old jetty, waiting. His daughter still cannot go near him.")
	if has("ysolt_raised") and not has("oswin_willing"):
		out.append("Ysolt Quill has risen from the weir. Her husband has not been told.")
	# Ned, Hesper, Hale
	if has("ned_blessed"):
		out.append("The east field was cut in three days. Ned Harrow came up the road with the harvest money in his coat and his grandmother's blessing, and stood under the Ring with his mouth open.")
	elif has("ned_taken"):
		out.append("Ned Harrow went up the road the same day. Nobody cut the east field. Old Hesper bars her door at night now, and Hale still swings at the barley as it rots.")
	elif has("hale_raised"):
		out.append("Hale Harrow is risen and the east field is being cut. Ned is still on the farm, watching the road.")
	elif has("ned_waits"):
		out.append("Ned Harrow is waiting for you to come back, as you said you would. The field is not cut.")
	else:
		out.append("Ned Harrow has still never been past the last fence.")
	# Tam, Pell, Ivo
	if has("ivo_taught"):
		out.append("Ivo Brand crossed the footbridge for the first time in thirty years, with chalk in a flour bag. He is bringing them back across one at a time. He will not let anyone help.")
	elif has("ivo_shamed"):
		out.append("Tallow Ford no longer burns its dead. Ivo Brand's pyre stands cold, and he sits beside it. Nobody speaks to him. You made that happen in front of everyone.")
	if has("tam_raised"):
		out.append("Tam Pell rose with flour on his hands. His son gives Rhodes a fair price now, and tells anyone who will listen why." + ("" if has("ivo_joined") or has("ivo_shamed") else " Ivo Brand has not forgiven it."))
	elif has("tam_burned"):
		out.append("Tam Pell was burned at dusk. His smoke came down on the far bank, where his wife was already standing." + (" She is not there any more." if has("anwen_raised") else ""))
	else:
		out.append("Tam Pell still lies wrapped on the pyre. Ivo and Pell are no longer speaking.")
	# Wren and the porter
	if has("wren_truth"):
		out.append("Wren Calloway put her name down knowing exactly what you did on the north road, and why. She has started leaving a lamp at the high ford.")
	elif has("wren_lied"):
		out.append("Wren Calloway believes the thing that killed Aldous was destroyed. It was raised, gently, by you. She has not found out.")
	elif has("wren_refused"):
		out.append("Wren Calloway asked you for one thing. She hunts alone.")
	elif has("porter_left") or not has("porter_raised"):
		out.append("North of the road, something tall still bends under a pack that is not there, waiting to hear whether they got home.")
	if has("porter_raised"):
		out.append("You carry a sword that left Rhodes 134 years ago.")
	# What is known
	if has("will_tell"):
		out.append("Harry Lu told you to say nothing about the voice in the mountains. You did not promise. He has started having you watched.")
	elif has("kept_quiet"):
		out.append("You and Harry Lu are the only two in Rhodes who know why the last Pilgrimage never came out of the Ring. He intends to keep it that way.")
	elif has("kept_secret"):
		out.append("You know something about the last Pilgrimage that nobody in Rhodes knows. Not even Harry.")
	else:
		out.append("You never learned what turned the last Pilgrimage round.")
	return "\n\n".join(out)
