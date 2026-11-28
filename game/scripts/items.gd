extends RefCounted
## Everything that can be carried, worn, wielded, eaten, bought or stolen.

const SLOTS := ["weapon", "shield", "head", "body", "hands", "feet"]
const SLOT_NAMES := {"weapon": "Weapon", "shield": "Off hand", "head": "Head", "body": "Body", "hands": "Hands", "feet": "Feet"}
const SKILL_NAMES := {"blade": "Blade", "blunt": "Blunt weapon", "spear": "Spear", "hand": "Hand-to-hand", "block": "Block", "athletics": "Athletics", "acrobatics": "Acrobatics", "speech": "Speechcraft"}

const ITEMS := {
	"fists": {"name": "Bare hands", "type": "weapon", "skill": "hand", "dmg": [1, 3], "reach": 1.7, "speed": 0.5, "weight": 0.0, "value": 0, "desc": "What you were born with."},
	"staff": {"name": "Pilgrim's staff", "type": "weapon", "skill": "blunt", "dmg": [3, 6], "reach": 2.4, "speed": 0.7, "weight": 3.0, "value": 8, "desc": "Ash, shod with iron. Every pilgrim is given one at the gate."},
	"sword": {"name": "Iron sword", "type": "weapon", "skill": "blade", "dmg": [5, 9], "reach": 2.1, "speed": 0.62, "weight": 5.0, "value": 40, "desc": "A plain single-edged blade. Rhodes makes them for the Wall."},
	"spear": {"name": "Wall spear", "type": "weapon", "skill": "spear", "dmg": [4, 10], "reach": 3.0, "speed": 0.9, "weight": 6.0, "value": 35, "desc": "Long enough to keep one of the Pinned off you. Slow to bring round."},
	"axe": {"name": "Woodcutter's axe", "type": "weapon", "skill": "blunt", "dmg": [4, 11], "reach": 2.0, "speed": 0.95, "weight": 6.0, "value": 22, "desc": "Made for pine, not for the dead. It does not know the difference."},
	"pole": {"name": "Ferry pole", "type": "weapon", "skill": "spear", "dmg": [2, 7], "reach": 3.3, "speed": 1.0, "weight": 5.0, "value": 6, "desc": "Oswin Quill's pole, river-worn smooth."},
	"old_sword": {"name": "Pilgrim's old sword", "type": "weapon", "skill": "blade", "dmg": [7, 12], "reach": 2.2, "speed": 0.6, "weight": 4.0, "value": 120, "desc": "Carried out of Rhodes 134 years ago. The crest on the guard is the one on your back."},
	"shield": {"name": "Wooden shield", "type": "shield", "slot": "shield", "armor": 2, "block": 0.75, "weight": 5.0, "value": 20, "desc": "Planks, hide and a boss. Hold your block and most of a blow stops here."},
	"hat": {"name": "Straw hat", "type": "armor", "slot": "head", "armor": 1, "weight": 0.5, "value": 6, "desc": "Keeps off rain and, occasionally, a glancing hit."},
	"coat": {"name": "Padded coat", "type": "armor", "slot": "body", "armor": 3, "weight": 4.0, "value": 18, "desc": "Quilted cotton. Warm, and something between you and their hands."},
	"cuirass": {"name": "Wall House cuirass", "type": "armor", "slot": "body", "armor": 7, "weight": 10.0, "value": 70, "desc": "Lacquered plates laced with red cord. Property of the Wall."},
	"bracers": {"name": "Leather bracers", "type": "armor", "slot": "hands", "armor": 1, "weight": 1.0, "value": 10, "desc": "Every puller in Rhodes owns a pair."},
	"boots": {"name": "Travel boots", "type": "armor", "slot": "feet", "armor": 1, "weight": 2.0, "value": 10, "desc": "Good for the road."},
	"bread": {"name": "Bread", "type": "food", "heal": 12, "weight": 0.5, "value": 3, "desc": "Restores 12 health."},
	"wine": {"name": "Rice wine", "type": "food", "fatigue": 45, "weight": 1.0, "value": 4, "desc": "Puts the wind back in you."},
	"poultice": {"name": "Healer's poultice", "type": "food", "heal": 30, "weight": 0.3, "value": 12, "desc": "Bhavya's making. Restores 30 health."},
	"chalk": {"name": "Chalk", "type": "rite", "weight": 0.2, "value": 4, "desc": "Thrown over the fallen, it shows the spirit inside."},
	"strap": {"name": "Riser's strap", "type": "rite", "weight": 0.3, "value": 10, "desc": "Binds a spirit against the dark for a little while."},
}

## What the traders keep, and what they ask.
const STOCK := {
	"tommy": {"chalk": 4, "strap": 10, "bread": 3, "wine": 4, "hat": 7, "coat": 20, "shield": 24, "sword": 45},
	"pell": {"chalk": 5, "strap": 12, "bread": 3, "wine": 5, "boots": 12, "bracers": 12, "axe": 26},
	"bhavya": {"poultice": 10},
}

## What people have on them if they are killed.
const CARRIED := {
	"phillip": {"spear": 1, "cuirass": 1}, "kelvin": {"sword": 1, "coat": 1}, "tommy": {"wine": 2, "bread": 2},
	"pell": {"axe": 1, "wine": 1}, "wren": {"sword": 1, "bracers": 1}, "ivo": {"axe": 1}, "bhavya": {"poultice": 2},
}

static func label(id: String) -> String:
	var it: Dictionary = ITEMS[id]
	match it["type"]:
		"weapon":
			return "%d-%d damage, reach %.1f, %s" % [it["dmg"][0], it["dmg"][1], it["reach"], SKILL_NAMES[it["skill"]]]
		"armor", "shield":
			return "armour %d, %s" % [it["armor"], SLOT_NAMES[it["slot"]].to_lower()]
		"food":
			return "restores %s" % ("%d health" % it["heal"] if it.has("heal") else "%d fatigue" % it["fatigue"])
	return "for the rite"
