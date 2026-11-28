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
	"antennae": {"name": "Alien antennae", "slot": "head", "how": "See off the visitors from the sky."},
	"lion_mask": {"name": "Paper lion mask", "slot": "head", "how": "Be on good terms with four founders."},
	"belt": {"name": "Cardboard champion's belt", "slot": "body", "how": "Beat Harry at the table."},
	"strap_scarf": {"name": "Scarf of other people's straps", "slot": "body", "how": "Lift three straps without being caught."},
	"clipboard": {"name": "Recruiter's clipboard", "slot": "hand", "how": "Talk three passers-by into having a go.", "hit": 1.3},
	"ghost": {"name": "Chalk ghost sheet", "slot": "body", "how": "Cover five people in chalk."},
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

# Tonight only.
var snacks := 3
var composure := 100.0
var scraps := 0
var results: Array = []        # ["Harry beat Tommy", ...]
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
	touch = DisplayServer.is_touchscreen_available()
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
		"straps_lifted": straps_lifted, "recruits": recruits, "dusted": dusted}
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
	straps_lifted = int(data.get("straps_lifted", 0))
	recruits = int(data.get("recruits", 0))
	dusted = int(data.get("dusted", 0))

func wipe() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
