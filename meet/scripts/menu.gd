extends CanvasLayer
## What you can do with someone at the meet, and the notes people leave at the lanterns.

const UI = preload("res://scripts/ui.gd")
const People = preload("res://scripts/people.gd")
const Web = preload("res://scripts/web.gd")

var who: Node = null
var _root: Control
var _name: Label
var _sub: Label
var _text: RichTextLabel
var _list: VBoxContainer
var _card: TextureRect
var _dots: HBoxContainer
var _chats := {}
var _photos := {}
var _pick_a := ""
var _forced := false

func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	m.add_theme_constant_override("margin_top", 250)
	m.add_theme_constant_override("margin_bottom", 30)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	_card = TextureRect.new()
	_card.custom_minimum_size = Vector2(230, 0)
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(_card)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	h.add_child(left)
	_name = UI.text(left, "", 28, UI.GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 3)
	row.add_child(_dots)
	for i in 10:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(11, 11)
		_dots.add_child(d)
	_sub = UI.text(row, "", 15, Color(0.75, 0.72, 0.62))
	_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text = UI.rich(left, 20)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_list)
	_root.visible = false

func active() -> bool:
	return _root.visible

func _show() -> void:
	if not active():
		_root.visible = true
		UI.open_modal()

func close() -> void:
	if active() and _forced and who != null:
		# Turning your back on someone who came over to have it out.
		_forced = false
		who.mind.experience("heckle", -0.2, 0.7)
		who.say_aloud(["Yeah. Walk away.", "We're not done.", "Typical."][randi() % 3], 3.5)
		who.idle()
	if active():
		_root.visible = false
		who = null
		UI.close_modal()

func _unhandled_input(ev: InputEvent) -> void:
	if active() and ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# --- People ------------------------------------------------------------------------

func open(r: Node) -> void:
	who = r
	_name.text = r.riser_name
	var pic: String = r.portrait()
	_card.visible = pic != ""
	if pic != "":
		_card.texture = load("res://assets/portraits/%s.jpg" % pic)
	_dots.visible = true
	_text.clear()
	var lines: Array = People.BARKS[r.bond()]
	var first: String = lines[randi() % lines.size()]
	if r.state == "search":
		first = "Have you seen my strap? It was in my bag."
	elif r.calling > 0.0:
		first = "There you are. Table. Now."
	elif r.passer or r.guest:
		first = r.def["chat"][0]
	elif not _chats.has(r.id):
		# First words of the night: what they remember of you, or how tonight finds them.
		var mem: String = r.memory_line() if Meet.visits > 1 else ""
		if mem != "":
			first = mem
		elif r.tonight.get("line", "") != "":
			first = r.tonight["line"]
		if Meet.has_flag(r.id, "errand_done"):
			first = "The red-snack legend returns."
	_chats[r.id] = _chats.get(r.id, 0) + 1
	_text.append_text("[i]%s[/i]\n\n\"%s\"\n" % [r.role, first])
	_show()
	_options()

func _header() -> void:
	var m = who.mind
	m.feeling()
	for i in _dots.get_child_count():
		var a: float = m.activity[i]
		(_dots.get_child(i) as ColorRect).color = Color(0.25, 0.22, 0.2).lerp(Color(0.95, 0.75, 0.3) if a > 0.0 else Color(0.45, 0.6, 0.95), absf(a))
	var extra := ""
	if who.is_riser:
		var bm: Array = who.best_mate()
		var word: String = Meet.tie_word(bm[1])
		if bm[0] != null and word != "":
			extra = "  ·  %s %s" % [word, bm[0].first_name]
	var mw: String = who.mood_word()
	_sub.text = "%s%s" % [("%s %s" % [who.first_name.capitalize() if who.is_riser else "They", "is your " + mw if mw == "close mate" else (mw if mw.ends_with("you") else "is " + mw)]) if mw != "" else who.bond_text().capitalize(), extra]
	_sub.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35) if who.mood_level() < 0 else Color(0.75, 0.72, 0.62))

func _options() -> void:
	_header()
	UI.clear(_list)
	var gold := UI.GOLD
	var blue := Color(0.65, 0.85, 1.0)
	if who.is_riser:
		# Things other people told you that concern this one come first.
		if Meet.has_flag("harry", "harry_job") and Meet.recruits >= 3:
			Meet.leads["job_done"] = true
		for id in Meet.leads:
			if not Meet.used.has(id) and Web.LEADS.has(id) and Web.LEADS[id]["to"] == who.id:
				UI.button(_list, Web.LEADS[id]["ask"], _lead.bind(id), 18).add_theme_color_override("font_color", blue)
		for e in Meet.said:
			if e["about"] == who.id and not e.get("told", false) and Meet.riser(e["by"]) != null:
				UI.button(_list, "\"%s was talking about you.\"" % Meet.riser(e["by"]).first_name, _carry.bind(e), 18).add_theme_color_override("font_color", blue)
	if who.mood_level() < 0:
		UI.button(_list, "Apologise", _sorry.bind(false), 18).add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
		UI.button(_list, "Apologise, with a snack as a peace offering  (%d)" % Meet.snacks, _sorry.bind(true), 18).add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	if Meet.straps.has(who.id):
		UI.button(_list, "\"Found this. Yours?\"  (hand back the strap)", _strap, 18)
	UI.button(_list, "Talk...", _menu_talk, 18)
	UI.button(_list, "Be friendly...", _menu_friendly, 18)
	if who.is_riser or who.guest:
		UI.button(_list, "Pull...", _menu_pull, 18).add_theme_color_override("font_color", gold)
	else:
		UI.button(_list, "Talk them into a pull...", _pitches, 18).add_theme_color_override("font_color", gold)
	if who.is_riser:
		UI.button(_list, "Ask a favour...", _menu_favour, 18)
	UI.button(_list, "Be difficult...", _insults, 18).add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	UI.button(_list, "See you later", close, 18)

func _back() -> void:
	UI.button(_list, "(Back.)", _options, 17)

func _menu_talk() -> void:
	UI.clear(_list)
	if who.is_riser:
		for t in People.TALK.get(who.id, []):
			if not who.done_topics.has(t["key"]):
				UI.button(_list, t["ask"], _topic.bind(t), 18)
		UI.button(_list, "Ask what they make of someone...", _about_who, 18)
		UI.button(_list, "\"What's the news tonight?\"", _news, 18)
	UI.button(_list, "Small talk", _chat, 18)
	UI.button(_list, "Ask who's winning tonight", _results, 18)
	_back()

func _menu_friendly() -> void:
	UI.clear(_list)
	UI.button(_list, "Pay them a compliment...", _compliments, 18)
	UI.button(_list, "Tell them a joke...", _jokes, 18)
	UI.button(_list, "High five", _high_five, 18)
	UI.button(_list, "\"Dance with me.\"", _dance, 18)
	UI.button(_list, "Offer a snack  (%d)" % Meet.snacks, _snack, 18)
	if who.is_riser:
		UI.button(_list, "Buy them a drink  ($3)", _drink, 18)
		UI.button(_list, "Slip them five dollars  ($%d)" % Meet.money, _give, 18)
	UI.button(_list, "Take a photo together", _photo, 18)
	if Meet.worn["hand"] == "clipboard":
		UI.button(_list, "Write something on the clipboard and hand it over", _clip, 18).add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	_back()

func _menu_pull() -> void:
	UI.clear(_list)
	UI.button(_list, "\"Fancy a pull?\"" if who.is_riser else "\"Another pull?\"", _challenge, 18).add_theme_color_override("font_color", UI.GOLD)
	if who.is_riser:
		UI.button(_list, "Put money on a pull...", _stakes, 18).add_theme_color_override("font_color", UI.GOLD)
		UI.button(_list, "\"Left arms. Loser buys the drinks.\"  ($3)", _lefts, 18)
	_back()

func _menu_favour() -> void:
	UI.clear(_list)
	UI.button(_list, "\"Lend me five dollars?\"", _favour.bind("lend"), 18)
	UI.button(_list, "\"Teach me your move.\"", _favour.bind("teach"), 18)
	UI.button(_list, "\"Watch my back tonight?\"", _favour.bind("back"), 18)
	UI.button(_list, "\"Put in a word for me with the others?\"", _favour.bind("word"), 18)
	_back()

# --- Being friendly --------------------------------------------------------------------------------

func _compliments() -> void:
	UI.clear(_list)
	for c in People.COMPLIMENTS:
		UI.button(_list, c["say"], _compliment.bind(c), 18)
	_back()

func _compliment(c: Dictionary) -> void:
	if who._asked.has("compliment"):
		_line("[color=#b9b3a0]%s[/color]\n\"You've already buttered me up once tonight.\"" % c["say"])
		return
	who._asked["compliment"] = true
	if People.FLATTER.get(who.id, "role") == c["key"] and who.mood_level() > -2:
		who.mind.experience("talk", 0.5, 1.2, true, "the compliment")
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"" % [c["say"], People.FLATTERED[c["key"]][randi() % 2]])
	else:
		who.mind.experience("talk", 0.1, 0.3)
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"" % [c["say"], People.FLATTER_MEH[randi() % People.FLATTER_MEH.size()]])

func _jokes() -> void:
	UI.clear(_list)
	for j in People.JOKES:
		UI.button(_list, j["say"], _joke.bind(j), 17)
	_back()

func _joke(j: Dictionary) -> void:
	var taste: String = People.HUMOUR.get(who.id, "dad")
	if who._asked.has("joke"):
		_line("[color=#b9b3a0]%s[/color]\n\"One joke a night. Club rule. I just made it up.\"" % j["say"])
		return
	who._asked["joke"] = true
	if j["key"] == "roast" and who.is_riser and Meet.tie(who.id, "tommy") > 0.35 and who.id != "tommy":
		who.mind.experience("heckle", -0.3, 0.8)
		_line("[color=#b9b3a0]%s[/color]\n\"That's my mate you're talking about.\"" % j["say"])
	elif who.id == "tommy" and j["key"] == "roast":
		who.mind.experience("talk", 0.4, 1.0)
		_line("[color=#b9b3a0]%s[/color]\n\"I'M RIGHT HERE. ...It's good, though. Annoyingly.\"" % j["say"])
	elif taste == j["key"] and who.mood_level() > -2:
		who.mind.experience("talk", 0.45, 1.1, true, "the joke")
		Meet.main.stir(who.global_position, ["Ha!", "What was the joke?", "Tell us!"], 6.0, 0.3, false)
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"" % [j["say"], People.LAUGHS[randi() % People.LAUGHS.size()]])
	else:
		who.mind.experience("talk", -0.05 if taste == "none" else 0.05, 0.3)
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"" % [j["say"], "..." if taste == "none" else People.NO_LAUGH[randi() % People.NO_LAUGH.size()]])

func _high_five() -> void:
	var r := who
	var lvl: int = r.mood_level()
	var kind := "yes" if lvl >= 1 else ("meh" if lvl == 0 and randf() < 0.6 else "no")
	close()
	Meet.player.act("Punch_Jab", 0.6)
	r.say_aloud(People.HIGH_FIVE[kind][randi() % People.HIGH_FIVE[kind].size()], 3.0)
	if kind == "no":
		r.mind.experience("nagged", -0.05, 0.3)
		Meet.say("You are left hanging. People saw.")
		Meet.main.stir(r.global_position, People.LEFT_HANGING, 9.0, 0.5, false)
	else:
		r.gesture("Punch_Jab", 0.6)
		if not r._asked.has("five"):
			r._asked["five"] = true
			r.mind.experience("talk", 0.25 if kind == "yes" else 0.1, 0.6)

func _dance() -> void:
	var r := who
	var yes: bool = r.id == "tommy" or r.mood_level() >= 1 or (r.mood_level() == 0 and r.mind.chatty > 0.65)
	close()
	Meet.player.act("Dance", 3.2)
	r.say_aloud(People.DANCE["yes" if yes else "no"][randi() % 3], 3.5)
	Meet.main.stir(Meet.player.global_position, People.WATCHING_DANCE, 12.0, 0.6, true)
	if yes:
		r.gesture("Dance", 3.2)
		if not r._asked.has("dance"):
			r._asked["dance"] = true
			r.mind.experience("talk", 0.4, 1.0, true, "the dancing")
		Meet.say("You and %s are dancing at an arm wrestling meet. Nobody can look away." % r.first_name)
	else:
		Meet.say("You dance alone. With commitment.")

func _give() -> void:
	if Meet.money < 5:
		_line("[i]You don't have five dollars.[/i]")
		return
	Meet.pay(-5)
	var proud: bool = who.mind.grudge >= 1.0 and who.id != "kelvin"
	if who.id == "george":
		who.mind.experience("gift", 0.5, 1.2)
		_line("[i]You hold out a five.[/i] \"For the tin? You're a good one. It goes straight in.\"")
	elif proud:
		who.mind.experience("gift", -0.1, 0.5)
		_line("[i]You hold out a five.[/i] \"What's this for? I'm not a charity. ...I'll keep it. But I'm not a charity.\"")
	else:
		who.mind.experience("gift", 0.4, 1.0)
		_line("[i]You hold out a five.[/i] \"%s\"" % ["Snack money. Accepted.", "No strings? Cheers.", "I'll get the next one."][randi() % 3])

# --- Favours ------------------------------------------------------------------------------------------

func _favour(kind: String) -> void:
	var lvl: int = who.mood_level()
	if who._asked.has(kind):
		_line("\"You've asked me that already.\"")
		return
	who._asked[kind] = true
	match kind:
		"lend":
			if lvl >= 1:
				Meet.pay(5)
				_line("[color=#b9b3a0]\"Lend me five dollars?\"[/color]\n\"Here. Don't make it a habit.\"")
			else:
				who.mind.experience("nagged", -0.1, 0.4)
				_line("[color=#b9b3a0]\"Lend me five dollars?\"[/color]\n\"%s\"" % ("We've known each other ten minutes." if lvl == 0 else "You've got some front, asking me."))
		"teach":
			if lvl >= 1:
				Meet.tips = min(4, Meet.tips + 1)
				_line("[color=#b9b3a0]\"Teach me your move.\"[/color]\n\"Alright. Hand here. No, here. Feel that? That's it. That's the whole secret.\"\n[i]The gold zone will be a little wider for you, for good.[/i]")
			else:
				_line("[color=#b9b3a0]\"Teach me your move.\"[/color]\n\"I don't hand that out to people I barely know. Earn it.\"")
		"back":
			if lvl >= 2 or (lvl == 1 and who.mind.grudge < 1.0):
				who.backing = true
				_line("[color=#b9b3a0]\"Watch my back tonight?\"[/color]\n\"If anyone squares up to you, I'll step in. Once. Don't start anything.\"")
			else:
				_line("[color=#b9b3a0]\"Watch my back tonight?\"[/color]\n\"Why, what have you done?\"")
		"word":
			if lvl >= 1:
				for r in Meet.risers:
					if r.is_riser and r != who and Meet.tie(who.id, r.id) > 0.3:
						r.mind.experience("helped", 0.3, 0.9, false, "what %s said" % who.first_name)
				_line("[color=#b9b3a0]\"Put in a word for me?\"[/color]\n\"I'll tell my lot you're alright. Can't speak for the rest.\"\n[i]%s's friends will hear good things about you.[/i]" % who.first_name)
			else:
				_line("[color=#b9b3a0]\"Put in a word for me?\"[/color]\n\"I'd have to have a good word first.\"")
	Meet.save()

## What's going on tonight, as they see it: who's close, who's fallen out, who's winning.
func _news() -> void:
	var best := ["", "", -2.0]
	var worst := ["", "", 2.0]
	var ids: Array = []
	for r in Meet.risers:
		if r.is_riser:
			ids.append(r)
	for a in ids:
		for b in ids:
			if a.id < b.id:
				var t: float = Meet.tie(a.id, b.id)
				if t > best[2]:
					best = [a.first_name, b.first_name, t]
				if t < worst[2]:
					worst = [a.first_name, b.first_name, t]
	var bits: Array = []
	if worst[2] < -0.05:
		bits.append("%s and %s aren't speaking. Don't ask either of them why." % [worst[0], worst[1]])
	bits.append("%s and %s are thick as thieves tonight." % [best[0], best[1]])
	if not Meet.results.is_empty():
		bits.append("Last pull: %s." % Meet.results[-1])
	for r in ids:
		if r.tonight.get("id", "") != "" and r != who:
			bits.append({"sore": "%s's elbow is gone, so that's one less.", "hungry": "%s hasn't eaten. Guard your snacks.", "fired": "%s is on one tonight. Wants to pull everyone.", "tired": "%s looks wrecked. Long shift.", "chatty": "%s is in a great mood. Suspiciously great."}[r.tonight["id"]] % r.first_name)
			break
	if Meet.reputation() >= 65:
		bits.append("And people are saying good things about you, for what it's worth.")
	elif Meet.reputation() < 40:
		bits.append("And honestly? People are talking about you. Not kindly.")
	_line("[color=#b9b3a0]\"What's the news tonight?\"[/color]\n\"%s\"" % " ".join(bits))

func _lefts() -> void:
	var no: String = who.reluctance()
	if no != "":
		_refused(no)
		return
	if Meet.money < 3:
		_line("[i]Loser buys, and you can't afford to lose.[/i]")
		return
	var r := who
	r.stake = 3
	r.lefts = true
	close()
	r.say_aloud("Left arms? You're braver than you look.", 3.0)
	Meet.table.start(r)

func _line(t: String) -> void:
	_text.append_text("\n%s\n" % t)
	if active() and who != null:
		_options()

## One of their own subjects: what they say, and the ways you can take it.
func _topic(t: Dictionary) -> void:
	who.done_topics[t["key"]] = true
	_text.append_text("\n\"%s\"\n" % t["reply"])
	UI.clear(_list)
	for o in t["opts"]:
		UI.button(_list, o["say"], _answer.bind(o), 18)

## Something you heard elsewhere, raised with the person it concerns.
func _lead(id: String) -> void:
	Meet.used[id] = true
	var l: Dictionary = Web.LEADS[id]
	_text.append_text("\n[color=#b9b3a0]%s[/color]\n" % l["ask"])
	if l.has("opts"):
		_text.append_text("\"%s\"\n" % l["reply"])
		UI.clear(_list)
		for o in l["opts"]:
			UI.button(_list, o["say"], _answer.bind(o), 18)
	else:
		_answer(l, false)

## Everything an answer sets in motion.
func _effects(o: Dictionary) -> void:
	var r := who
	if o.has("v_other"):
		var ot: Node = Meet.riser(o["v_other"][0])
		if ot:
			ot.mind.experience("helped" if o["v_other"][1] > 0.0 else "heckle", o["v_other"][1], 1.4, false, "what you told %s" % r.first_name)
	if o.has("tie"):
		Meet.bump(o["tie"][0], o["tie"][1], o["tie"][2])
	var lead: String = o.get("lead", Web.GRANTS.get(o.get("say", ""), ""))
	if lead != "" and not Meet.leads.has(lead) and Web.LEADS.has(lead):
		Meet.leads[lead] = true
		var to: Node = Meet.riser(Web.LEADS[lead]["to"])
		_text.append_text("[i]Something to bring up with %s.[/i]\n" % (to.first_name if to else "someone"))
	var act: PackedStringArray = String(o.get("do", "")).split(":")
	match act[0]:
		"match":
			if Meet.main.force_match(act[1], act[2]):
				_text.append_text("[i]They are heading for a table.[/i]\n")
		"tell":
			Meet.main.send(act[1], act[2], "chat")
		"prank":
			Meet.main.send(act[1], act[2], "prank")
		"pay":
			Meet.pay(int(act[1]), "%s hands you some cash." % r.first_name)

func _answer(o: Dictionary, show_say := true) -> void:
	var r := who
	if o.has("cost"):
		if Meet.money < int(o["cost"]):
			_line("[i]You don't have $%d on you.[/i]" % o["cost"])
			return
		Meet.pay(-int(o["cost"]))
	var v: float = o.get("v", 0.0)
	if v != 0.0:
		r.mind.experience(o.get("kind", "talk"), v, 0.6 + absf(v) * 1.6, true, "")
	if o.has("flag"):
		Meet.flag(r.id, o["flag"])
		if o["flag"] == "bet":
			r.bet = true
	if show_say:
		_text.append_text("\n[color=#b9b3a0]%s[/color]\n" % o["say"])
	_text.append_text("\"%s\"\n" % o["reply"])
	_effects(o)
	match o.get("do", ""):
		"tip":
			Meet.tips = min(4, Meet.tips + 1)
			_text.append_text("[i]That will make the gold zone a little wider for you, for good.[/i]\n")
		"photo":
			close()
			r.say_aloud("And... posted.", 3.0)
			Meet.hud.photo()
			return
		"prank_harry":
			var harry: Node = Meet.riser("harry")
			if harry and harry.state != "winded":
				r._partner = harry
				r._qlines = People.QUIRK["prank"]
				r._go(harry.global_position + Vector3(1.6, 0, 1.0), "prank")
				harry.mind.experience("chalk", -0.3, 0.9, false, "the prank")
				Meet.bump("harry", "tommy", -0.15)
				close()
				Meet.say("Tommy heads for Harry with a fistful of chalk. You said you'd take the blame.")
				return
		"snitch":
			var h: Node = Meet.riser("harry")
			if h:
				h.mind.experience("helped", 0.35, 0.8, true, "the tip-off")
				h.say_aloud("Tommy. Put the chalk DOWN.", 4.0)
				Meet.bump("harry", "tommy", -0.1)
	Meet.save()
	if v <= -0.55 and r.mind.feeling() < -0.45:
		close()
		r.confront()
		return
	_options()

func _insults() -> void:
	UI.clear(_list)
	for ins in People.INSULTS:
		UI.button(_list, ins["say"], _insult.bind(ins), 18)
	UI.button(_list, "(Think better of it.)", _options, 18)

func _insult(ins: Dictionary) -> void:
	var reply: String = who.insult(ins["key"])
	if reply != "" and active():
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"" % [ins["say"], reply])

func _chat() -> void:
	var lines: Array = who.def["chat"] if who.def.has("chat") else People.CHAT[who.bond()]
	if who.is_riser and who.mood_level() >= 0:
		# Their own small talk, one line at a time, in order.
		var own: Array = People.SMALL[who.id]
		lines = [own[_chats.get(who.id, 0) % own.size()]]
	if _chats.get(who.id, 0) <= 4 and who.bond() != "gone":
		who.mind.experience("talk", 0.2, 0.3, true, "")
	_chats[who.id] = _chats.get(who.id, 0) + 1
	_line("\"%s\"" % lines[randi() % lines.size()])
	_mates_check()

# --- Being confronted ---------------------------------------------------------------------------

## Someone has walked up and made you talk. How it ends is up to what you say.
func confrontation(r: Node) -> void:
	open(r)
	_forced = true
	_text.clear()
	var warn: bool = r.confront_kind == "warn"
	var opener: String = r.confront_text if warn else ["You've been at me all night. What is your problem?", "I've had enough of you. Say what you've got to say to my face.", "One chance. Explain yourself."][randi() % 3]
	_text.append_text("[i]%s has walked straight up to you.[/i]\n\n\"%s\"\n" % [r.riser_name, opener])
	if warn:
		_text.append_text("\"Do it again and you're out of this club. Understood?\"\n")
	UI.clear(_list)
	var end := func(line: String):
		_forced = false
		r.idle()
		_text.append_text("\n%s\n" % line)
		UI.clear(_list)
		UI.button(_list, "(Carry on with your night.)", close, 18)
		Meet.save()
	if warn:
		UI.button(_list, "\"Understood. I'm sorry. It won't happen again.\"", func():
			Meet.warned = true
			r.mind.experience("helped", 0.15, 0.6)
			end.call("\"Good. I'm watching you.\"\n[i]That was your one warning for tonight.[/i]"), 18).add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
		UI.button(_list, "\"They had it coming.\"", func():
			Meet.warned = true
			r.mind.experience("heckle", -0.3, 1.0)
			end.call("\"Nobody has it coming at my meet. Last warning.\"\n[i]That was your one warning for tonight.[/i]"), 18)
		UI.button(_list, "\"Make me leave.\"", func():
			Meet.warned = true
			_forced = false
			close()
			r.square_up(), 18).add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
		return
	UI.button(_list, "\"You're right. I was out of order. I'm sorry.\"", func():
		end.call("\"%s\"" % r.apologise(false)), 18).add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	if Meet.money >= 3:
		UI.button(_list, "\"Let me buy you a drink and we call it even.\"  ($3)", func():
			Meet.pay(-3)
			end.call("\"%s\"" % r.apologise(true)), 18).add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	UI.button(_list, "\"Let's settle it at the table. Winner drops it.\"", func():
		_forced = false
		r.settle = true
		r.pull_angry = true
		close()
		r.say_aloud("Fine. Table. Now.", 3.0)
		Meet.table.start(r), 18).add_theme_color_override("font_color", UI.GOLD)
	UI.button(_list, "\"What are you going to do about it?\"", func():
		_forced = false
		close()
		r.square_up(), 18).add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	UI.button(_list, "(Turn your back and walk off.)", close, 18)

# --- What they think of each other, and carrying it between them ---------------------------------

func _about_who() -> void:
	UI.clear(_list)
	for r in Meet.risers:
		if r.is_riser and r != who and not who.done_topics.has("about:" + r.id):
			UI.button(_list, "\"What do you make of %s?\"" % r.first_name, _about.bind(r), 18)
	UI.button(_list, "(Never mind.)", _options, 18)

func _about(other: Node) -> void:
	who.done_topics["about:" + other.id] = true
	var t: float = Meet.tie(who.id, other.id)
	var tone := "good" if t > 0.35 else ("bad" if t < 0.0 else "mid")
	_text.append_text("\n[color=#b9b3a0]\"What do you make of %s?\"[/color]\n\"%s\"\n" % [other.first_name, Web.OPINION[other.id][tone]])
	UI.clear(_list)
	var entry := {"by": who.id, "about": other.id, "tone": "bad" if tone == "bad" else "good"}
	if tone != "mid":
		UI.button(_list, "\"I'll tell them you said that.\"", func():
			Meet.said.append(entry)
			who.mind.experience("talk", 0.1 if tone == "good" else -0.2, 0.6)
			_line("\"%s\"\n[i]Something to bring up with %s.[/i]" % ["Go on, then." if tone == "good" else "I'd rather you didn't.", other.first_name]), 18)
		UI.button(_list, "(Keep it to yourself, but remember it.)", func():
			Meet.said.append(entry)
			_line("[i]You nod. It might be worth passing on to %s. Or not.[/i]" % other.first_name), 18)
	if tone == "bad":
		UI.button(_list, "\"That's harsh. They're alright.\"", func():
			who.mind.experience("talk", -0.1, 0.4)
			Meet.bump(who.id, other.id, 0.08)
			_line("\"...Maybe. Maybe I'm being hard on them.\""), 18)
		UI.button(_list, "\"Couldn't agree more.\"", func():
			who.mind.experience("talk", 0.3, 0.8)
			Meet.bump(who.id, other.id, -0.06)
			_line("\"Right? Somebody gets it.\""), 18)
	else:
		UI.button(_list, "(Nod.)", func():
			who.mind.experience("talk", 0.12, 0.4)
			_options(), 18)

## Passing on what one of them said about another: straight, softened, or made worse.
func _carry(e: Dictionary) -> void:
	var by: Node = Meet.riser(e["by"])
	_text.append_text("\n[color=#b9b3a0]\"%s was talking about you.\"[/color]\n\"Oh yeah? Saying what?\"\n" % by.first_name)
	UI.clear(_list)
	var done := func(kind: String, d_tie: float, v_who: float, v_by: float):
		e["told"] = true
		Meet.bump(e["by"], e["about"], d_tie)
		who.mind.experience("talk", v_who, 0.9)
		if v_by != 0.0:
			by.mind.experience("heckle" if v_by < 0.0 else "helped", v_by, 1.2, false, "what you passed on")
		var lines: Array = Web.TOLD[kind]
		_text.append_text("\"%s\"\n" % lines[randi() % lines.size()])
		if kind == "worse":
			Meet.main.send(who.id, by.id, "chat")
			_text.append_text("[i]They are going over there to have it out. %s will work out who stirred it.[/i]\n" % by.first_name)
		Meet.save()
		_options()
	if e["tone"] == "good":
		UI.button(_list, "Tell it straight: they spoke well of you.", done.bind("good", 0.15, 0.25, 0.15), 18)
		UI.button(_list, "Twist it: say they were running you down.", done.bind("worse", -0.3, 0.1, -0.55), 18)
	else:
		UI.button(_list, "Tell it straight: they were running you down.", done.bind("bad", -0.15, 0.15, -0.3), 18)
		UI.button(_list, "Soften it: say it was only a grumble.", done.bind("soft", 0.04, 0.12, 0.0), 18)
		UI.button(_list, "Make it worse than it was.", done.bind("worse", -0.3, 0.1, -0.55), 18)
	UI.button(_list, "\"Nothing. Forget it.\"", _options, 18)

# --- Pulls, money on them, and getting a no turned round -------------------------------------------

func _drink() -> void:
	if Meet.money < 3:
		_line("[i]Drinks are $3 and you have $%d.[/i]" % Meet.money)
		return
	Meet.pay(-3)
	who.mind.experience("gift", 0.5, 1.0, true, "the drink")
	_line("[i]Three dollars in the tin.[/i] \"%s\"" % ["Oh, nice one. Cheers.", "You didn't have to. But thanks.", "First drink anyone's bought me here."][randi() % 3])

func _stakes() -> void:
	var no: String = who.reluctance()
	if no != "":
		_refused(no)
		return
	UI.clear(_list)
	for amt in [5, 10, 20]:
		if Meet.money >= amt:
			UI.button(_list, "\"$%d says I pin you.\"" % amt, func():
				var r := who
				r.stake = amt
				close()
				r.say_aloud("You're on. $%d." % amt, 3.0)
				Meet.table.start(r), 18)
	if Meet.money < 5:
		UI.text(_list, "You need at least $5. There's change lying about, and other ways.", 15, Color(0.75, 0.72, 0.62))
	UI.button(_list, "(Keep your money.)", _options, 18)

## They said no. There are ways round a no, some kinder than others.
func _refused(why: String) -> void:
	_text.append_text("\n\"%s\"\n" % why)
	UI.clear(_list)
	UI.button(_list, "Goad them: \"What's the matter? Scared?\"", _talk_into.bind("goad"), 18).add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	UI.button(_list, "Sweeten it: \"Ten dollars says you can't.\"", _talk_into.bind("money"), 18).add_theme_color_override("font_color", UI.GOLD)
	UI.button(_list, "Ask properly: \"One pull. Then I'll leave you be.\"", _talk_into.bind("nice"), 18)
	UI.button(_list, "(Leave it.)", _options, 18)

func _talk_into(kind: String) -> void:
	var res: Array = who.talk_into(kind)
	if res[0]:
		var r := who
		close()
		r.say_aloud(res[1], 3.5)
		Meet.table.start(r)
	else:
		_text.append_text("\n\"%s\"\n" % res[1])
		_refused("I said no.")

func _challenge() -> void:
	var no: String = who.reluctance() if who.is_riser else ""
	if no != "":
		_refused(no)
		return
	if who.state in ["pull", "to_table", "prep"]:
		# They were on their way to pull someone else. You asked; you go first.
		who.say_aloud(["Alright. You first.", "Fine, you're up. They can wait.", "Go on then. Now."][randi() % 3], 3.0)
	var r := who
	close()
	Meet.table.start(r)

## Talking a stranger into their first pull: pick your line.
func _pitches() -> void:
	if who.recruited:
		_line("\"I'm already in! Don't push it.\"")
		return
	UI.clear(_list)
	for p in People.PITCH:
		UI.button(_list, p["say"], _pitch.bind(p), 18)
	UI.button(_list, "(Leave it.)", _options, 18)

func _pitch(p: Dictionary) -> void:
	if p["key"] == "food":
		if Meet.snacks <= 0:
			_line("[i]You have no snack to wave at them.[/i]")
			return
		Meet.snacks -= 1
		who.mind.experience("gift", 0.4, 0.8)
		Meet.touch_state()
	var res: Array = who.pitch(p["key"])
	if not active():
		return
	if res[0]:
		var r := who
		close()
		r.say_aloud(res[1], 3.5)
		Meet.table.start(r)
	else:
		_line("[color=#b9b3a0]%s[/color]\n\"%s\"\n[i]Wrong line for this one. Try another, but they won't stand here all night.[/i]" % [p["say"], res[1]])

func _clip() -> void:
	UI.clear(_list)
	UI.text(_list, "Write on the clipboard:", 16, UI.GOLD)
	var box := LineEdit.new()
	box.placeholder_text = "Anything. They'll read it."
	box.max_length = 80
	box.add_theme_font_size_override("font_size", 18)
	box.custom_minimum_size = Vector2(0, 44)
	_list.add_child(box)
	var hand := func(_t := ""):
		var reply: String = who.read_clipboard(box.text)
		if reply != "" and active():
			_line("[i]You hand over the clipboard. They read it.[/i]\n%s" % reply)
		Meet.save()
	box.text_submitted.connect(hand)
	UI.button(_list, "Hand it over", hand, 18).add_theme_color_override("font_color", UI.GOLD)
	UI.button(_list, "(Keep it.)", _options, 18)
	if not Meet.touch:
		box.grab_focus.call_deferred()

func _sorry(with_snack: bool) -> void:
	if with_snack:
		if Meet.snacks <= 0:
			_line("[i]You have no snack to offer. The table's by the lights.[/i]")
			return
		Meet.snacks -= 1
		Meet.touch_state()
	_line("[color=#b9b3a0]\"I was out of line. I'm sorry.\"[/color]\n\"%s\"" % who.apologise(with_snack))
	Meet.save()

func _strap() -> void:
	_line("\"%s\"" % who.strap_returned())

func _snack() -> void:
	if Meet.snacks <= 0:
		_line("[i]You pat your pockets. No snacks. The table's over by the lights.[/i]")
		return
	Meet.snacks -= 1
	Meet.snacks_given += 1
	if Meet.snacks_given >= 5:
		Meet.grant("chef_hat")
	Meet.touch_state()
	if Meet.has_flag(who.id, "errand") and not Meet.has_flag(who.id, "errand_done"):
		Meet.flag(who.id, "errand_done")
		who.mind.experience("helped", 0.8, 2.0, true, "the snack run")
		_line("[i]You hand it over.[/i] \"RED. You remembered red. I'd take a bullet for you.\"")
	else:
		who.mind.experience("gift", 0.6, 1.0, true, "")
		_line("[i]You hand it over.[/i] \"%s\"" % ["Oh, cheers.", "You're a legend.", "I was about to go and get one.", "Don't mind if I do."][randi() % 4])
	_mates_check()

func _results() -> void:
	if Meet.results.is_empty():
		_line("\"Nobody's pulled yet. Give it a minute.\"")
		return
	var recent: Array = Meet.results.slice(max(0, Meet.results.size() - 5))
	_line("\"So far? %s.\"" % ". ".join(recent))

func _photo() -> void:
	var r := who
	if not _photos.has(r.id) and r.bond() != "gone":
		_photos[r.id] = true
		r.mind.experience("photo", 0.3, 0.5, true, "")
	close()
	r.say_aloud("Cheese." if r.bond() != "gone" else "Seriously?", 3.0)
	Meet.hud.photo()

## Being on good terms with four founders is worth something.
func _mates_check() -> void:
	var n := 0
	for r in Meet.risers:
		if r.is_riser and r.bond() in ["mates", "close"]:
			n += 1
	if n >= 4:
		Meet.grant("lion_mask")

# --- Notes at the lanterns ---------------------------------------------------------------

func notes(spot: int) -> void:
	who = null
	_name.text = "Notes left at this lantern"
	_card.visible = false
	_dots.visible = false
	_sub.text = "Write anything. For now, only you can see the ones you leave."
	_text.clear()
	var any := false
	for n in People.SEEDED + Meet.notes:
		if int(n["spot"]) == spot:
			any = true
			_text.append_text("•  %s\n" % (n["text"] if n.has("text") else "%s %s." % [n["a"], n["b"]]))
	if not any:
		_text.append_text("[i]Nobody has left anything here yet.[/i]\n")
	_show()
	UI.clear(_list)
	UI.text(_list, "Leave a note of your own:", 16, UI.GOLD)
	var box := LineEdit.new()
	box.placeholder_text = "Type anything, then press Enter"
	box.max_length = 120
	box.add_theme_font_size_override("font_size", 18)
	box.custom_minimum_size = Vector2(0, 44)
	_list.add_child(box)
	var leave := func(_t := ""):
		var t := box.text.strip_edges()
		if t == "":
			return
		Meet.notes.append({"spot": spot, "text": t})
		Meet.save()
		notes(spot)
	box.text_submitted.connect(leave)
	UI.button(_list, "Leave it here", leave, 18).add_theme_color_override("font_color", UI.GOLD)
	UI.button(_list, "Walk on", close, 18)
	if not Meet.touch:
		box.grab_focus.call_deferred()
