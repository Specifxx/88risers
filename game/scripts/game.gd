extends Node
## Shared game state. Autoloaded as "Game".

signal changed
signal message(text: String)

const RING_RADIUS := 42.0
const QUOTA := 88
const SLICE_GOAL := 3
const RHODES_SPAWN := Vector3(4, 0.1, 6)

const Items = preload("res://scripts/items.gd")
const Data = preload("res://scripts/data.gd")
const Fx = preload("res://scripts/fx.gd")
const CAPACITY := 60.0

var hp := 30
var max_hp := 30
var fatigue := 60.0
var max_fatigue := 60.0
var blocking := false
var power := 5   # used by the turn-based fights until real-time combat replaces them
var coins := 20
## Everything carried, by item id. Chalk, straps and bread are items like any other.
var items := {"staff": 1, "bread": 1}
var equip := {"weapon": "staff", "shield": "", "head": "", "body": "", "hands": "", "feet": ""}
var skills := {"blade": 15, "blunt": 20, "spear": 15, "hand": 15, "block": 10, "athletics": 20, "acrobatics": 15, "speech": 20}
var _progress := {}

var chalk: int:
	get: return count("chalk")
	set(v): _set_count("chalk", v)
var straps: int:
	get: return count("strap")
	set(v): _set_count("strap", v)
var bread: int:
	get: return count("bread")
	set(v): _set_count("bread", v)
var raised := 0
var recruits: Array = []
var founders_alive := 8
var journal: Array = []
## Hour of the day, 0-24. A full day takes about twelve minutes.
var hour := 9.0
var flags := {}
var modal := true
## What the law in each place holds against the player, in coin.
var bounty := {"rhodes": 0, "tallow": 0}

var main: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var dialogue: CanvasLayer
var battle: CanvasLayer
var inventory: CanvasLayer
var story: Node
var npcs: Array = []
var pinned: Array = []

func _ready() -> void:
	_action("forward", [KEY_W, KEY_UP])
	_action("back", [KEY_S, KEY_DOWN])
	_action("left", [KEY_A])
	_action("right", [KEY_D])
	_action("sprint", [KEY_SHIFT])
	_action("interact", [KEY_E])
	_action("journal", [KEY_J])
	_action("eat", [KEY_H])
	_action("jump", [KEY_SPACE])
	_action("inventory", [KEY_TAB, KEY_I])
	_action("attack", [KEY_F])
	_action("block", [KEY_C])

func _action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func register_count() -> int:
	return founders_alive + recruits.size()

func say(text: String) -> void:
	message.emit(text)

func note(text: String) -> void:
	if not journal.has(text):
		journal.append(text)
		message.emit("Journal updated (J).")

func touch() -> void:
	changed.emit()

func in_ring(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < RING_RADIUS

func heal_full() -> void:
	hp = max_hp
	touch()

func eat() -> bool:
	if count("bread") <= 0 or hp >= max_hp:
		return false
	return use_item("bread")

# --- Carrying, wearing, wielding ----------------------------------------------

func count(id: String) -> int:
	return items.get(id, 0)

func _set_count(id: String, n: int) -> void:
	if n <= 0:
		items.erase(id)
	else:
		items[id] = n

func add_item(id: String, n := 1) -> void:
	items[id] = count(id) + n
	touch()

func remove_item(id: String, n := 1) -> void:
	_set_count(id, count(id) - n)
	for slot in equip:
		if equip[slot] == id and count(id) == 0:
			equip[slot] = ""
	touch()

func weight() -> float:
	var w := 0.0
	for id in items:
		w += Items.ITEMS[id]["weight"] * items[id]
	return w

func weapon() -> Dictionary:
	var id: String = equip["weapon"]
	return Items.ITEMS[id if id != "" else "fists"]

func armor() -> int:
	var a := 0
	for slot in equip:
		if slot != "weapon" and equip[slot] != "":
			a += Items.ITEMS[equip[slot]].get("armor", 0)
	return a

## Wear or wield it, or take it off if it is already on.
func toggle_equip(id: String) -> void:
	var it: Dictionary = Items.ITEMS[id]
	var slot: String = "weapon" if it["type"] == "weapon" else it.get("slot", "")
	if slot == "" or count(id) <= 0:
		return
	equip[slot] = "" if equip[slot] == id else id
	touch()

func use_item(id: String) -> bool:
	var it: Dictionary = Items.ITEMS[id]
	if it["type"] != "food" or count(id) <= 0:
		return false
	hp = min(max_hp, hp + int(it.get("heal", 0)))
	fatigue = min(max_fatigue, fatigue + float(it.get("fatigue", 0)))
	remove_item(id)
	return true

# --- Skill, which only comes from doing ---------------------------------------

func train(skill: String, amount := 1.0) -> void:
	_progress[skill] = _progress.get(skill, 0.0) + amount
	var need: float = 4.0 + skills[skill] * 0.25
	if _progress[skill] >= need:
		_progress[skill] = 0.0
		skills[skill] += 1
		say("Your %s is now %d." % [Items.SKILL_NAMES[skill].to_lower(), skills[skill]])
		touch()

## The chance a blow lands: skill, and how much wind you have left.
func hit_chance(skill: String) -> float:
	return clamp(0.42 + skills[skill] * 0.009 + (fatigue / max_fatigue - 0.5) * 0.3, 0.15, 0.97)

func spend(amount: float) -> void:
	fatigue = max(0.0, fatigue - amount)

## Something hits the player. Blocking and armour take their share. Returns the damage done.
func hurt_player(raw: int, from: Vector3) -> int:
	var dmg := float(raw)
	if blocking and player != null:
		var to := from - player.global_position
		to.y = 0
		var facing: Vector3 = -player.global_transform.basis.z
		if to.length() > 0.01 and facing.dot(to.normalized()) > 0.2:
			var soak: float = 0.5 + skills["block"] * 0.004
			if equip["shield"] != "":
				soak = max(soak, Items.ITEMS[equip["shield"]]["block"] + skills["block"] * 0.002)
			dmg *= 1.0 - min(soak, 0.92)
			spend(6.0)
			train("block", 1.0)
	dmg *= 12.0 / (12.0 + armor())
	var dealt: int = max(1, int(round(dmg)))
	hp -= dealt
	if hud:
		hud.hurt_flash()
	if player:
		var away := player.global_position - from
		away.y = 0
		player.recoil(away.normalized() * (2.0 + dealt * 0.35), 0.12 + dealt * 0.015)
		Fx.burst(main, player.global_position + Vector3(0, 1.2, 0), away, true, 10)
		if dealt >= 4:
			Fx.stain(main, player.global_position, 0.35)
	touch()
	if hp <= 0:
		fall()
	return dealt

func villagers(village: String) -> Array:
	var out: Array = []
	for n in npcs:
		if n.alive and n.village == village:
			out.append(n)
	return out

## Average feeling towards the player in a village (-1..1).
func standing(village: String) -> float:
	var v := villagers(village)
	if v.is_empty():
		return 0.0
	var t := 0.0
	for n in v:
		t += n.mind.feeling()
	return t / v.size()

## Something the player did. Those close enough saw it; the rest of the village
## only learns of it if somebody tells them.
func deed(kind: String, valence: float, weight: float, at: Vector3, village: String, about: String, radius := 22.0) -> Array:
	var seen: Array = []
	for n in villagers(village):
		if n.global_position.distance_to(at) < radius:
			n.mind.experience(kind, valence, weight, true, about)
			seen.append(n)
			# Those whose job it is to keep the peace do not just remember it.
			if kind == "violence" and n.def.get("guard", false):
				n.aggro = true
	if seen.size() > 0 and valence < 0.0 and bounty.has(village):
		# Seen is reported. The price depends on what it was.
		bounty[village] += 25 if kind == "theft" else (40 if weight < 6.0 else 120)
		var lines: Array = Data.SHOUTS.get(kind, [])
		if not lines.is_empty():
			var who: Node = seen[randi() % seen.size()]
			var line: String = lines[randi() % lines.size()]
			who.say_aloud(line % about if line.contains("%s") else line, 4.0)
	return seen

## News that reaches a whole village by word of mouth, such as a quiet road.
func word(kind: String, valence: float, weight: float, village: String, about: String) -> void:
	for n in villagers(village):
		n.mind.experience(kind, valence, weight, false, about)

func is_night() -> bool:
	return hour < 5.5 or hour > 20.5

## Anyone alive and near enough to see what the player just did.
func witnesses(at: Vector3, except: Node = null, radius := 22.0) -> Array:
	var out: Array = []
	for n in npcs:
		if n != except and n.alive and n.global_position.distance_to(at) < radius:
			out.append(n)
	return out

func fall() -> void:
	hp = int(max_hp / 2.0)
	fatigue = max_fatigue
	for n in npcs:
		n.aggro = false
	# Whoever carried you back also settled what you owed, out of your purse.
	for v in bounty:
		bounty[v] = 0
	coins = int(coins / 2.0)
	player.global_position = RHODES_SPAWN
	player.velocity = Vector3.ZERO
	say("You wake inside the Ring. Someone carried you back. Half your coin is gone.")
	touch()
