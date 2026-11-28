extends Node
## Shared state for Meet Night, and what is remembered between visits. Autoloaded as "Meet".

signal changed
signal toast(text: String)

const SAVE := "user://meet_night.json"

## Things to win, find and wear. None of them are sensible.
const ITEMS := {
	"foam_finger": {"name": "Giant foam finger", "slot": "hand", "how": "Win your first match at the table.", "hit": 1.6},
	"rubber_chicken": {"name": "Rubber chicken", "slot": "hand", "how": "Heckle five people.", "hit": 1.2},
	"pool_noodle": {"name": "Pool noodle", "slot": "hand", "how": "Somebody left it down by the water.", "hit": 1.4},
	"katana_88": {"name": "The 88 Risers katana (cardboard)", "slot": "hand", "how": "Beat every founder at the table.", "hit": 2.0},
	"cone": {"name": "Traffic cone", "slot": "head", "how": "It was just sitting there behind the steps."},
	"chef_hat": {"name": "Snack captain's hat", "slot": "head", "how": "Hand out five snacks."},
	"antennae": {"name": "Alien antennae", "slot": "head", "how": "The visitors from the sky leave them behind."},
	"lion_mask": {"name": "Paper lion mask", "slot": "head", "how": "Be on good terms with four founders."},
	"belt": {"name": "Cardboard champion's belt", "slot": "body", "how": "Beat Harry at the table."},
	"strap_scarf": {"name": "Scarf of other people's straps", "slot": "body", "how": "Lift three straps without being caught."},
	"clipboard": {"name": "Recruiter's clipboard", "slot": "hand", "how": "Talk three passers-by into having a go.", "hit": 1.3},
	"ghost": {"name": "Chalk ghost sheet", "slot": "body", "how": "Cover five people in chalk."},
	"raygun": {"name": "Toy ray gun (probably a toy)", "slot": "hand", "how": "Something from the sky leaves it behind.", "hit": 1.8},
	"prop_hat": {"name": "Propeller hat", "slot": "head", "how": "Fell off something that crashed."},
	"golden_chip": {"name": "The golden chip", "slot": "hand", "how": "The seagulls drop it, if you see them off.", "hit": 1.1},
	"medal": {"name": "Participation medal", "slot": "body", "how": "Lose three matches. It's the taking part."},
}

var modal := true
var main: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var menu: CanvasLayer
var table: CanvasLayer
var risers: Array = []
var stick := Vector2.ZERO      # touch joystick
var touch := false

# Remembered between visits.
var owned := {}
var worn := {"hand": "", "head": "", "body": ""}
var bonds := {}                # riser id -> saved mind
var beaten := {}               # riser id -> true
var notes: Array = []          # [{spot, a, b}]
var visits := 0
var wins := 0
var losses := 0
var heckles := 0
var snacks_given := 0
var moments := 0
var seen_ufo := false
var straps_lifted := 0
var recruits := 0
var dusted := 0
var flags := {}                # riser id -> {flag: true}: things said that are not forgotten
var ties := {}                 # "a|b" -> how two founders get on with each other (-1..1)
var tips := 0                  # coaching picked up; widens the gold zone a little

# Tonight only.
var snacks := 3
var composure := 100.0
var scraps := 0
var results: Array = []        # ["Harry beat Tommy", ...]
var stamina := 100.0
var clock := 0.0               # seconds into the night; 900 is half past seven
var chalk := 0                 # handfuls to throw
var chalked := false           # hands chalked for the next pull
var straps: Array = []         # ids of the people whose straps are in your pocket

func _ready() -> void:
	_action("forward", [KEY_W, KEY_UP])
	_action("back", [KEY_S, KEY_DOWN])
	_action("left", [KEY_A])
	_action("right", [KEY_D])
	_action("sprint", [KEY_SHIFT])
	_action("interact", [KEY_E])
	_action("jump", [KEY_SPACE])
	_action("slap", [KEY_F])
	_action("bag", [KEY_TAB, KEY_I])
	_action("photo", [KEY_P])
	_action("chalk", [KEY_G, KEY_Q])
	_action("eat", [KEY_R])
	touch = DisplayServer.is_touchscreen_available()
	if OS.get_cmdline_user_args().has("--selftest"):
		wipe()
	load_save()

func _action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func say(text: String) -> void:
	toast.emit(text)

func touch_state() -> void:
	changed.emit()

func riser(id: String) -> Node:
	for r in risers:
		if r.id == id:
			return r
	return null

## Give the player something. Returns true if it is new.
func grant(item: String) -> bool:
	if owned.has(item):
		return false
	owned[item] = true
	say("New: %s. It's in your bag." % ITEMS[item]["name"])
	save()
	changed.emit()
	return true

func wear(item: String) -> void:
	var slot: String = ITEMS[item]["slot"]
	worn[slot] = "" if worn[slot] == item else item
	save()
	changed.emit()

func hit_power() -> float:
	var h: String = worn["hand"]
	return ITEMS[h].get("hit", 1.0) if h != "" else 1.0

func strength() -> float:
	return min(84.0, 62.0 + wins * 1.5) + (3.0 if not straps.is_empty() else 0.0)

## Start a fresh night.
func new_night() -> void:
	snacks = 3
	composure = 100.0
	stamina = 100.0
	clock = 0.0
	scraps = 0
	results = []
	chalk = 0
	chalked = false
	straps = []
	modal = true

# --- Remembering ------------------------------------------------------------------

func save() -> void:
	for r in risers:
		if r.mind != null and r.is_riser:
			bonds[r.id] = r.mind.to_data()
	var data := {"owned": owned, "worn": worn, "bonds": bonds, "beaten": beaten, "notes": notes, "visits": visits,
		"wins": wins, "losses": losses, "heckles": heckles, "snacks_given": snacks_given, "moments": moments, "seen_ufo": seen_ufo,
		"flags": flags, "ties": ties, "tips": tips, "straps_lifted": straps_lifted, "recruits": recruits, "dusted": dusted}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_save() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	owned = data.get("owned", {})
	var w: Dictionary = data.get("worn", {})
	for slot in worn:
		worn[slot] = w.get(slot, "")
	bonds = data.get("bonds", {})
	beaten = data.get("beaten", {})
	notes = data.get("notes", [])
	visits = int(data.get("visits", 0))
	wins = int(data.get("wins", 0))
	losses = int(data.get("losses", 0))
	heckles = int(data.get("heckles", 0))
	snacks_given = int(data.get("snacks_given", 0))
	moments = int(data.get("moments", 0))
	seen_ufo = bool(data.get("seen_ufo", false))
	flags = data.get("flags", {})
	tips = int(data.get("tips", 0))
	ties = data.get("ties", {})
	straps_lifted = int(data.get("straps_lifted", 0))
	recruits = int(data.get("recruits", 0))
	dusted = int(data.get("dusted", 0))

func wipe() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)

func flag(id: String, key: String) -> void:
	if not flags.has(id):
		flags[id] = {}
	flags[id][key] = true

func has_flag(id: String, key: String) -> bool:
	return flags.has(id) and flags[id].has(key)

## The time on the clock: the meet runs Sunday 5:00pm to 7:30pm, ten minutes to the real minute.
func time_text() -> String:
	var mins := int(clock / 6.0)
	return "Sunday %d:%02dpm" % [5 + mins / 60, mins % 60]

## What the club as a whole makes of you, 0 to 100.
func reputation() -> int:
	var total := 0.0
	var n := 0
	for r in risers:
		if r.is_riser:
			total += r.mind.feeling()
			n += 1
	return int(clamp(50.0 + 50.0 * total / max(n, 1), 0.0, 100.0))

func standing() -> String:
	var r := reputation()
	if r < 25:
		return "Barred in all but name"
	if r < 42:
		return "On thin ice"
	if r < 58:
		return "New face"
	if r < 74:
		return "One of the regulars"
	return "Honorary Riser"

func eat() -> void:
	if snacks <= 0:
		say("No snacks on you. The table's by the lights.")
		return
	snacks -= 1
	composure = min(100.0, composure + 35.0)
	stamina = 100.0
	say("You eat a snack. Better.")
	changed.emit()

# --- How the founders get on with each other ---------------------------------------------

const TIES_START := {"george|harry": 0.6, "luie|tommy": 0.4, "erick|phillip": 0.4, "george|kelvin": 0.3, "bhavya|harry": 0.3, "bhavya|tommy": 0.05}

func _key(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])

func tie(a: String, b: String) -> float:
	var k := _key(a, b)
	if not ties.has(k):
		ties[k] = TIES_START.get(k, 0.12 + (hash(k) % 20) * 0.01)
	return float(ties[k])

## Nudge how two people get on. Small things add up over a night, and over many nights.
func bump(a: String, b: String, d: float) -> void:
	if a == b or a.begins_with("p_") or b.begins_with("p_") or a == "alien" or b == "alien":
		return
	ties[_key(a, b)] = clamp(tie(a, b) + d, -1.0, 1.0)

func tie_word(v: float) -> String:
	if v > 0.6:
		return "thick as thieves with"
	if v > 0.35:
		return "good mates with"
	if v < -0.3:
		return "not speaking to"
	if v < -0.05:
		return "cool with"
	return ""
