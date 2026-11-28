extends Node
## Shared state for Meet Night, and what is remembered between visits. Autoloaded as "Meet".

signal changed
signal toast(text: String)

const SAVE := "user://meet_night.json"

## Things to win, find and wear. None of them are sensible.
const ITEMS := {
	"foam_finger": {"name": "Giant foam finger", "slot": "hand", "how": "Win your first match at the table.", "atk": 3},
	"rubber_chicken": {"name": "Rubber chicken", "slot": "hand", "how": "Heckle five people.", "atk": 2},
	"pool_noodle": {"name": "Pool noodle", "slot": "hand", "how": "Somebody left it down by the water.", "atk": 3},
	"katana_88": {"name": "The 88 Risers katana (cardboard)", "slot": "hand", "how": "Beat every founder at the table.", "atk": 7},
	"cone": {"name": "Traffic cone", "slot": "head", "how": "It was just sitting there behind the steps."},
	"chef_hat": {"name": "Snack captain's hat", "slot": "head", "how": "Hand out five snacks."},
	"antennae": {"name": "Alien antennae", "slot": "head", "how": "The visitors from the sky leave them behind."},
	"lion_mask": {"name": "Paper lion mask", "slot": "head", "how": "Be on good terms with four founders."},
	"belt": {"name": "Cardboard champion's belt", "slot": "body", "how": "Beat Harry at the table."},
	"strap_scarf": {"name": "Scarf of other people's straps", "slot": "body", "how": "Lift three straps without being caught."},
	"clipboard": {"name": "Recruiter's clipboard", "slot": "hand", "how": "Talk three passers-by into having a go.", "atk": 4},
	"ghost": {"name": "Chalk ghost sheet", "slot": "body", "how": "Cover five people in chalk."},
	"raygun": {"name": "Toy ray gun (probably a toy)", "slot": "hand", "how": "Something from the sky leaves it behind.", "atk": 8},
	"prop_hat": {"name": "Propeller hat", "slot": "head", "how": "Fell off something that crashed."},
	"golden_chip": {"name": "The golden chip", "slot": "hand", "how": "The seagulls drop it, if you see them off.", "atk": 1},
	"dare_sash": {"name": "Sash of the Dared", "slot": "body", "how": "Finish all three of a night's dares."},
	"sweatband": {"name": "Retro sweatband", "slot": "head", "how": "This week's find. Somewhere at the meet."},
	"boom_box": {"name": "Tiny boom box", "slot": "hand", "how": "This week's find. Somewhere at the meet.", "atk": 6},
	"gold_chalk": {"name": "Block of golden chalk", "slot": "hand", "how": "This week's find. Somewhere at the meet.", "atk": 3},
	"cape": {"name": "Banner cape", "slot": "body", "how": "This week's find. Somewhere at the meet."},
	"bracket_cup": {"name": "The Six O'Clock Cup", "slot": "hand", "how": "Win the six o'clock bracket.", "atk": 7},
	"fish": {"name": "A fish", "slot": "hand", "how": "Borrow the fisherman's rod.", "atk": 5},
	"sunnies": {"name": "Servo sunnies", "slot": "head", "how": "Lucky dip at the kebab van."},
	"snag": {"name": "Sausage on a fork", "slot": "hand", "how": "Lucky dip at the kebab van.", "atk": 3},
	"footy": {"name": "Somebody's football", "slot": "hand", "how": "It came over from the park.", "atk": 4},
	"balloon": {"name": "A child's balloon", "slot": "hand", "how": "It drifts through, some nights.", "atk": 1},
	"possum_hat": {"name": "Possum (asleep) on your head", "slot": "head", "how": "Be kind to the possum."},
	"glow_stick": {"name": "Glow stick", "slot": "hand", "how": "Handed out when the lights go.", "atk": 3},
	"harmonica": {"name": "Dee's spare harmonica", "slot": "hand", "how": "Do the busker a favour.", "atk": 2},
	"catch_ball": {"name": "A catch-ball (dented)", "slot": "hand", "how": "Old Con pulled it up in a net once. Do him a favour.", "atk": 4},
	"gripling": {"name": "A Gripling, on your shoulder", "slot": "body", "how": "Catch the one that comes hopping through. You'll need something to catch it with."},
	"golden_grip": {"name": "The Golden Grip", "slot": "hand", "how": "It is aboard the ship, if you dare go up the ramp.", "atk": 10},
	"signed_band": {"name": "Headband signed by Big Don", "slot": "head", "how": "Meet a legend. Ask nicely."},
	"giant_band": {"name": "The giant's wristband (fits your thigh)", "slot": "body", "how": "Earn a nod from Lasha."},
	"kaiju_claw": {"name": "A claw the size of a door", "slot": "hand", "how": "Beat what comes out of the bay.", "atk": 9},
	"club_cap": {"name": "88 Risers cap", "slot": "head", "shape": "cap", "col": Color(0.75, 0.1, 0.12), "src": "merch", "how": "George's merch table, $8.", "price": 8},
	"club_beanie": {"name": "88 Risers beanie", "slot": "head", "shape": "beanie", "col": Color(0.1, 0.1, 0.12), "src": "merch", "how": "George's merch table, $10.", "price": 10},
	"club_scarf": {"name": "Supporter's scarf", "slot": "body", "shape": "scarf", "col": Color(0.75, 0.1, 0.12), "src": "merch", "how": "George's merch table, $12.", "price": 12},
	"club_flag": {"name": "Club flag on a stick", "slot": "hand", "shape": "flag", "col": Color(0.75, 0.1, 0.12), "src": "merch", "how": "George's merch table, $15.", "price": 15, "atk": 4},
	"club_mug": {"name": "'World's Okayest Puller' mug", "slot": "hand", "shape": "mug", "col": Color(0.95, 0.95, 0.9), "src": "merch", "how": "George's merch table, $9.", "price": 9, "atk": 3},
	"visor": {"name": "Poker visor", "slot": "head", "shape": "visor", "col": Color(0.1, 0.6, 0.3), "src": "merch", "how": "George's merch table, $14.", "price": 14},
	"gold_chain": {"name": "A chain, definitely real gold", "slot": "body", "shape": "chain", "col": Color(1.0, 0.82, 0.25), "src": "merch", "how": "George's merch table, $25.", "price": 25},
	"megaphone": {"name": "Megaphone", "slot": "hand", "shape": "horn", "col": Color(0.9, 0.9, 0.9), "src": "merch", "how": "George's merch table, $30.", "price": 30, "atk": 5},
	"top_hat": {"name": "Top hat", "slot": "head", "shape": "tophat", "col": Color(0.08, 0.08, 0.1), "src": "merch", "how": "George's merch table, $40.", "price": 40},
	"tux_tie": {"name": "Bow tie", "slot": "body", "shape": "tie", "col": Color(0.08, 0.08, 0.1), "src": "merch", "how": "George's merch table, $18.", "price": 18},
	"bin_lid": {"name": "Bin lid (shield)", "slot": "hand", "shape": "lid", "col": Color(0.3, 0.45, 0.35), "src": "bin", "how": "Rummage in the bins. Often.", "atk": 4},
	"old_boot": {"name": "One left boot", "slot": "hand", "shape": "boot", "col": Color(0.35, 0.22, 0.12), "src": "bin", "how": "Rummage in the bins. Often.", "atk": 5},
	"pizza_box": {"name": "Pizza box hat", "slot": "head", "shape": "box", "col": Color(0.85, 0.75, 0.6), "src": "bin", "how": "Rummage in the bins. Often."},
	"banana": {"name": "A banana skin", "slot": "hand", "shape": "banana", "col": Color(0.98, 0.88, 0.2), "src": "bin", "how": "Rummage in the bins. Often.", "atk": 1},
	"lost_sock": {"name": "Somebody's sock, worn as a mitten", "slot": "hand", "shape": "sock", "col": Color(0.9, 0.9, 0.95), "src": "bin", "how": "Rummage in the bins. Often.", "atk": 2},
	"tin_crown": {"name": "Crown made of a tin", "slot": "head", "shape": "crown", "col": Color(0.7, 0.72, 0.75), "src": "bin", "how": "Rummage in the bins. Often."},
	"jandal": {"name": "The jandal that fought", "slot": "hand", "shape": "jandal", "col": Color(0.2, 0.6, 0.9), "src": "fish", "how": "Keep fishing with Old Con's rod.", "atk": 3},
	"bottle_msg": {"name": "Message in a bottle", "slot": "hand", "shape": "bottle", "col": Color(0.5, 0.8, 0.6), "src": "fish", "how": "Keep fishing with Old Con's rod.", "atk": 4},
	"trolley_wheel": {"name": "Shopping trolley wheel", "slot": "hand", "shape": "wheel", "col": Color(0.6, 0.6, 0.65), "src": "fish", "how": "Keep fishing with Old Con's rod.", "atk": 6},
	"sea_crown": {"name": "Crown from the deep", "slot": "head", "shape": "crown", "col": Color(0.3, 0.8, 0.75), "src": "fish", "how": "Keep fishing with Old Con's rod."},
	"life_ring": {"name": "Life ring", "slot": "body", "shape": "ring", "col": Color(0.95, 0.4, 0.1), "src": "fish", "how": "Keep fishing with Old Con's rod."},
	"alien_helm": {"name": "Visitor's helmet (too small)", "slot": "head", "shape": "helmet", "col": Color(0.4, 0.9, 0.6), "src": "alien", "how": "The visitors drop them when beaten."},
	"probe": {"name": "A probe. Don't ask.", "slot": "hand", "shape": "stick", "col": Color(0.6, 0.9, 1.0), "src": "alien", "how": "The visitors drop them when beaten.", "atk": 7},
	"space_wings": {"name": "Little jet wings", "slot": "body", "shape": "wings", "col": Color(0.75, 0.8, 0.85), "src": "alien", "how": "The visitors drop them when beaten."},
	"halo": {"name": "Hovering ring, origin unknown", "slot": "head", "shape": "halo", "col": Color(1.0, 0.95, 0.5), "src": "alien", "how": "The visitors drop them when beaten."},
	"regular_pin": {"name": "'Regular' badge", "slot": "body", "shape": "bib", "col": Color(0.2, 0.5, 0.9), "src": "milestone", "how": "Come to three meets."},
	"veteran_sash": {"name": "Veteran's sash", "slot": "body", "shape": "scarf", "col": Color(0.3, 0.2, 0.5), "src": "milestone", "how": "Come to eight meets."},
	"ten_wins": {"name": "Ten-pin trophy (for ten wins)", "slot": "hand", "shape": "trophy", "col": Color(0.8, 0.5, 0.2), "src": "milestone", "how": "Win ten pulls.", "atk": 6},
	"ladder_crown": {"name": "Ladder crown", "slot": "head", "shape": "crown", "col": Color(1.0, 0.82, 0.25), "src": "milestone", "how": "Reach 40 ladder points."},
	"dare_horns": {"name": "Daredevil horns", "slot": "head", "shape": "horns", "col": Color(0.85, 0.1, 0.1), "src": "milestone", "how": "Finish fifteen dares."},
	"lifesaver": {"name": "Lifesaver's whistle", "slot": "hand", "shape": "whistle", "col": Color(0.95, 0.85, 0.2), "src": "milestone", "how": "Pull two people out of the bay.", "atk": 2},
	"umbrella": {"name": "Someone's umbrella", "slot": "hand", "shape": "umbrella", "col": Color(0.15, 0.3, 0.6), "src": "lost", "how": "Lost property. It turns up.", "atk": 5},
	"backpack": {"name": "A kid's backpack", "slot": "body", "shape": "backpack", "col": Color(0.95, 0.4, 0.6), "src": "lost", "how": "Lost property. It turns up."},
	"wig": {"name": "A wig", "slot": "head", "shape": "wig", "col": Color(0.95, 0.85, 0.3), "src": "lost", "how": "Lost property. It turns up."},
	"plunger": {"name": "A plunger", "slot": "hand", "shape": "plunger", "col": Color(0.75, 0.2, 0.15), "src": "lost", "how": "Lost property. It turns up.", "atk": 6},
	"apron": {"name": "'Kiss the Cook' apron", "slot": "body", "shape": "apron", "col": Color(0.95, 0.95, 0.95), "src": "lost", "how": "Lost property. It turns up."},
	"medal": {"name": "Participation medal", "slot": "body", "how": "Lose three matches. It's the taking part."},
}

var modal := true
var main: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var menu: CanvasLayer
var table: CanvasLayer
var strapgame: CanvasLayer
var audio: Node
var muted := false
var quality := 0               # 0 sharpest .. 3 smoothest
var quality_auto := true
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
var player_name := ""           # what you told them to call you
var money := 10                # dollars in your pocket
var leads := {}                # things you have been told and can raise with someone else
var used := {}                 # leads already raised
var said: Array = []           # [{by, about, tone, told}]: what one founder said of another
var paid := {}                 # reputation rewards George has already handed over
var joined: Array = []          # strangers you talked into the club; they come back
var lions := 0                 # stone lions you have let out; they come with you
var saved_total := 0
var potions := 0               # revival potions in your pocket
var sets := 0                  # dumbbell sets, ever: slow real strength
var points := 0                # ladder points
var dares_done := 0
var last_recap := ""
var tips := 0                  # coaching picked up; widens the gold zone a little

# Tonight only.
var snacks := 3
var composure := 100.0
var scraps := 0
var results: Array = []        # ["Harry beat Tommy", ...]
var stamina := 100.0
var clock := 0.0               # seconds into the night; 900 is half past seven
var chalk := 0                 # handfuls to throw
var heat := 0.0                # 0..5: how much trouble you are in with the club tonight
var dares: Array = []          # tonight's three: [{text, event, arg, need, have, done}]
var night_cash := 0
var cone_with := ""             # who is wearing your traffic cone
var errands := {}              # founder id -> "open" | "ready" | "done"
var buzz := 0.0                # seconds of energy drink left
var fish := 0
var saved := 0
var bracket := "open"          # open | in | semi | wait | final | out | won | none
var dark := 0.0                # seconds the lights are out: nobody can see what you do
var ripples: Array = []         # what you changed tonight
var away := {}                 # kit you have put down somewhere tonight
var wind := 0.0                # seconds of proper wind left
var carrying := -1             # the table you have hold of, or -1
var dead := {}                 # who has been taken tonight, and by what
var pump := 0                  # sets of curls done tonight, up to 4
var double_points := false
var peak_heat := 0
var planted := {}              # strap owner id -> whose bag you put it in
var chalk_hidden := 0.0
var told_peace := false
var warned := false            # told once tonight: do it again and you are out
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
	_action("item", [KEY_X])
	_action("view", [KEY_C])
	_action("shout", [KEY_V])
	_action("throw", [KEY_T])
	_action("mute", [KEY_M])
	touch = DisplayServer.is_touchscreen_available()
	if OS.get_cmdline_user_args().has("--selftest") or OS.get_cmdline_user_args().has("--soakfresh"):
		wipe()
	load_save()

## The first finger on the glass switches the game to touch controls, whatever the browser claimed.
func _input(ev: InputEvent) -> void:
	if not touch and ev is InputEventScreenTouch:
		touch = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		changed.emit()

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
	sfx("item")
	say("New: %s. It's in your bag." % ITEMS[item]["name"])
	save()
	changed.emit()
	return true

## Something in the world is different because of you. Shown as it happens and in the night's summary.
func ripple(text: String, quiet := false) -> void:
	if ripples.has(text):
		return
	ripples.append(text)
	if not quiet:
		say("↳ " + text)
	else:
		say("↳ " + text)

func wear(item: String) -> void:
	if away.has(item):
		say("You put that down somewhere. Go and pick it up.")
		return
	if item == "cone" and cone_with != "":
		say("%s is wearing it. Go and ask for it back." % riser(cone_with).first_name)
		return
	var slot: String = ITEMS[item]["slot"]
	worn[slot] = "" if worn[slot] == item else item
	save()
	changed.emit()

## How hard what you are holding hits, 1 to 10. Bare hands are a 2.
func attack() -> int:
	var h: String = worn["hand"]
	return int(ITEMS[h].get("atk", 2)) if h != "" else 2

func hit_power() -> float:
	return 0.55 + attack() * 0.22

func strength() -> float:
	return min(84.0, 62.0 + wins * 1.5) + (3.0 if not straps.is_empty() else 0.0) + min(6.0, sets * 0.2) + pump * 1.5

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
	heat = 0.0
	cone_with = ""
	errands = {}
	buzz = 0.0
	fish = 0
	bracket = "open"
	dark = 0.0
	dead = {}
	wind = 0.0
	carrying = -1
	ripples = []
	away = {}
	pump = 0
	peak_heat = 0
	double_points = false
	night_cash = 0
	planted = {}
	chalk_hidden = 0.0
	warned = false
	straps = []
	modal = true

# --- Remembering ------------------------------------------------------------------

func save() -> void:
	for r in risers:
		if r.mind != null and r.is_riser:
			bonds[r.id] = r.mind.to_data()
	var data := {"owned": owned, "worn": worn, "bonds": bonds, "beaten": beaten, "notes": notes, "visits": visits,
		"wins": wins, "losses": losses, "heckles": heckles, "snacks_given": snacks_given, "moments": moments, "seen_ufo": seen_ufo,
		"joined": joined, "lions": lions, "saved_total": saved_total, "potions": potions, "sets": sets, "points": points, "dares_done": dares_done, "last_recap": last_recap, "muted": muted, "quality": quality, "quality_auto": quality_auto, "flags": flags, "player_name": player_name, "money": money, "leads": leads, "used": used, "said": said, "paid": paid, "ties": ties, "tips": tips, "straps_lifted": straps_lifted, "recruits": recruits, "dusted": dusted}
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
	points = int(data.get("points", 0))
	sets = int(data.get("sets", 0))
	potions = int(data.get("potions", 0))
	saved_total = int(data.get("saved_total", 0))
	lions = int(data.get("lions", 0))
	joined = data.get("joined", [])
	dares_done = int(data.get("dares_done", 0))
	last_recap = String(data.get("last_recap", ""))
	muted = bool(data.get("muted", false))
	quality = int(data.get("quality", 0))
	quality_auto = bool(data.get("quality_auto", true))
	tips = int(data.get("tips", 0))
	ties = data.get("ties", {})
	money = int(data.get("money", 10))
	player_name = String(data.get("player_name", ""))
	leads = data.get("leads", {})
	used = data.get("used", {})
	said = data.get("said", [])
	paid = data.get("paid", {})
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
	sfx("crunch")
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
	if a == b or a.begins_with("p_") or b.begins_with("p_") or a.begins_with("g_") or b.begins_with("g_") or a == "alien" or b == "alien":
		return
	var before := tie(a, b)
	var now: float = clamp(before + d, -1.0, 1.0)
	ties[_key(a, b)] = now
	# Say so when a friendship or a feud crosses a line.
	if riser(a) != null and riser(b) != null and absf(d) >= 0.1:
		var na: String = riser(a).first_name
		var nb: String = riser(b).first_name
		if before >= 0.0 and now < 0.0:
			ripple("%s and %s aren't speaking any more." % [na, nb])
		elif before < 0.0 and now >= 0.0:
			ripple("%s and %s have patched it up." % [na, nb])
		elif before <= 0.6 and now > 0.6:
			ripple("%s and %s are thick as thieves now." % [na, nb])
		elif before <= 0.35 and now > 0.35:
			ripple("%s and %s are getting on better than before." % [na, nb])

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

func pay(amount: int, why := "") -> void:
	money = max(0, money + amount)
	if amount > 0:
		night_cash += amount
		sfx("coin")
		dare("cash")
	if why != "":
		say("%s%s$%d. You have $%d." % [why, " +" if amount >= 0 else " -", absi(amount), money])
	changed.emit()

## What people call you: your name if you gave one.
func you(fallback := "the new one") -> String:
	return player_name if player_name != "" else fallback

func sfx(name: String, db := 0.0, pitch := 1.0, gap := 0.0) -> void:
	if audio != null:
		audio.play(name, db, pitch, gap)

# --- The real week -------------------------------------------------------------------------------

## Which real-world week it is. A new guest, find and rumour every Monday.
func week() -> int:
	return int(Time.get_unix_time_from_system() / 604800.0)

# --- Tonight's dares -----------------------------------------------------------------------------

const DARE_POOL := [
	# Ordinary.
	{"text": "Beat %s at the table", "event": "win", "who": true, "tier": 0},
	{"text": "Get %s to like you", "event": "like", "who": true, "tier": 0},
	{"text": "Win two pulls", "event": "win", "need": 2, "tier": 0},
	{"text": "Talk a stranger into a pull", "event": "recruit", "tier": 0},
	{"text": "Pet a dog", "event": "pet", "tier": 0},
	{"text": "Land a high five", "event": "five", "tier": 0},
	{"text": "Strap in a pull cleanly", "event": "strapin", "tier": 0},
	{"text": "Run an errand for a founder", "event": "errand", "tier": 0},
	{"text": "Be in the group photo", "event": "photo", "tier": 0},
	{"text": "Buy someone a drink", "event": "round", "tier": 0},
	{"text": "Catch a fish", "event": "fish", "tier": 0},
	{"text": "Carry all three tables at pack-down", "event": "pack", "tier": 0},
	# Cheeky.
	{"text": "Get chalk on %s", "event": "chalk", "who": true, "tier": 1},
	{"text": "Get someone to dance with you", "event": "dance", "tier": 1},
	{"text": "Carry a message between two founders", "event": "carry", "tier": 1},
	{"text": "Make $25 tonight", "event": "cash", "cash": 25, "tier": 1},
	{"text": "Win a bet on someone else's pull", "event": "bet", "tier": 1},
	{"text": "Lift a strap without being seen", "event": "strap", "tier": 1},
	{"text": "Talk your way out of a confrontation", "event": "talkdown", "tier": 1},
	{"text": "See off the seagulls", "event": "gulls", "tier": 1},
	{"text": "Squeak, bonk or zap three people with what you're holding", "event": "item", "need": 3, "tier": 1},
	# Unhinged.
	{"text": "Put the traffic cone on %s's head", "event": "cone", "who": true, "tier": 2},
	{"text": "Recruit a stranger, then chalk them", "event": "recruit_chalk", "tier": 2},
	{"text": "Plant a strap in the wrong bag", "event": "plant", "tier": 2},
	{"text": "Hide the chalk bucket", "event": "hide", "tier": 2},
	{"text": "Let a dog off its lead", "event": "dog", "tier": 2},
	{"text": "Slap someone with a fish", "event": "fishslap", "tier": 2},
	{"text": "Lift a wallet without being seen", "event": "wallet", "tier": 2},
	{"text": "Hit three stars of heat and still be here at 7:30", "event": "survive", "tier": 2},
	{"text": "Make two founders fall out", "event": "feud", "tier": 2},
	{"text": "Lose a scrap. On purpose or otherwise.", "event": "floored", "tier": 2},
	{"text": "Send a lost tourist through the middle of the meet", "event": "tourist", "tier": 2},
	{"text": "Steal the cyclist's bike and go for a ride", "event": "bike", "tier": 2},
	{"text": "Start a food fight", "event": "foodfight", "tier": 2},
	{"text": "Kiss Kelvin's cousin", "event": "kiss", "tier": 2},
	{"text": "Pull someone out of the bay", "event": "rescue", "tier": 0},
	{"text": "Fly on the balloon", "event": "fly", "tier": 2},
	{"text": "Shout something at the whole meet", "event": "shout", "tier": 1},
	{"text": "Knock someone over with a bicycle", "event": "bowl", "tier": 2},
]
const TIER_NAME := ["", "cheeky", "unhinged"]
const TIER_PAY := [5, 8, 12]

## One ordinary, one cheeky, one unhinged, every night.
func new_dares() -> void:
	var names := ["harry", "george", "phillip", "bhavya", "kelvin", "tommy", "luie", "erick"]
	names.shuffle()
	dares = []
	for tier in 3:
		var pool := DARE_POOL.filter(func(d): return d["tier"] == tier)
		var d: Dictionary = pool[randi() % pool.size()]
		var who: String = names.pop_back() if d.get("who", false) else ""
		var label: String = d["text"] % who.capitalize() if who != "" else d["text"]
		dares.append({"text": label, "event": d["event"], "arg": who, "need": int(d.get("need", 1)), "have": 0, "done": false, "cash": int(d.get("cash", 0)), "tier": tier})

## Something happened that a dare might be about.
func dare(event: String, arg := "") -> void:
	for d in dares:
		if d["done"] or d["event"] != event or (d["arg"] != "" and d["arg"] != arg):
			continue
		if event == "cash":
			if night_cash < d["cash"]:
				continue
		else:
			d["have"] += 1
			if d["have"] < d["need"]:
				changed.emit()
				continue
		d["done"] = true
		dares_done += 1
		var paid: int = TIER_PAY[int(d.get("tier", 0))]
		money += paid
		sfx("dare")
		say("Dare done: %s. +$%d." % [d["text"], paid])
		if dares.all(func(x): return x["done"]):
			money += 10
			say("All three dares done tonight. +$10, and the club is impressed.")
			grant("dare_sash")
			for r in risers:
				if r.is_riser:
					r.mind.experience("helped", 0.2, 0.5, false, "the dares")
		changed.emit()

# --- Heat ---------------------------------------------------------------------------------------

func stars() -> int:
	return int(floor(heat + 0.001))

## Mischief raises it. Time, apologies and drinks bring it down. Five stars and you are out.
func add_heat(x: float, why := "") -> void:
	var before := stars()
	heat = clamp(heat + x, 0.0, 5.0)
	var now := stars()
	peak_heat = max(peak_heat, now)
	if now > before:
		sfx("heat")
		say("Heat %s%s%s" % ["★".repeat(now), "☆".repeat(5 - now), ("  " + why) if why != "" else ""])
		if main != null:
			main.heat_rose(now)
	changed.emit()

## A founder's errand moves on a step.
func errand(id: String, state: String) -> void:
	if errands.get(id, "") in ["open", "ready"] or state == "open":
		errands[id] = state
		changed.emit()

## Things earned by turning up and by sticking at it.
func milestones() -> void:
	for m in [["regular_pin", visits >= 3], ["veteran_sash", visits >= 8], ["ten_wins", wins >= 10], ["ladder_crown", points >= 40], ["dare_horns", dares_done >= 15], ["lifesaver", saved_total >= 2]]:
		if m[1] and not owned.has(m[0]):
			grant(m[0])

## A random thing you don't yet own from one of the places kit comes from.
func unowned(src: String) -> String:
	var pool: Array = []
	for id in ITEMS:
		if ITEMS[id].get("src", "") == src and not owned.has(id):
			pool.append(id)
	return pool[randi() % pool.size()] if not pool.is_empty() else ""
