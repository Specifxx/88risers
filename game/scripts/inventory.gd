extends CanvasLayer
## The pilgrim's pack: what is worn and wielded, what is carried, and how skilled you are.
## Click something to equip it, take it off, or use it.

const UI = preload("res://scripts/ui.gd")
const Items = preload("res://scripts/items.gd")

var _root: Control
var _stats: Label
var _worn: VBoxContainer
var _skills: Label
var _list: VBoxContainer
var _about: Label
var _filter := "all"
var _tabs: HBoxContainer

func _ready() -> void:
	layer = 18
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0, 0.45)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 110)
	m.add_theme_constant_override("margin_top", 40)
	m.add_theme_constant_override("margin_bottom", 30)
	_root.add_child(m)
	var p := UI.panel(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	p.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	UI.text(left, "The pilgrim", 26, UI.GOLD)
	_stats = UI.text(left, "", 16)
	UI.text(left, "Worn and wielded", 17, UI.GOLD)
	_worn = VBoxContainer.new()
	_worn.add_theme_constant_override("separation", 4)
	left.add_child(_worn)
	UI.text(left, "Skills", 17, UI.GOLD)
	_skills = UI.text(left, "", 15, Color(0.82, 0.8, 0.72))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	right.add_child(_tabs)
	for f in ["all", "weapon", "armor", "food", "rite"]:
		var names := {"all": "Everything", "weapon": "Weapons", "armor": "Armour", "food": "Food and drink", "rite": "For the rite"}
		UI.button(_tabs, names[f], _set_filter.bind(f), 15).autowrap_mode = TextServer.AUTOWRAP_OFF
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_about = UI.text(right, "", 15, Color(0.82, 0.8, 0.72))
	_about.custom_minimum_size = Vector2(0, 44)
	UI.button(right, "Close (Tab)", toggle, 16)
	_root.visible = false
	Game.changed.connect(_refresh)

func active() -> bool:
	return _root.visible

func toggle() -> void:
	if active():
		_root.visible = false
		UI.close_modal()
		return
	if Game.modal:
		return
	_root.visible = true
	UI.open_modal()
	_refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if active() and (ev.is_action_pressed("inventory") or ev.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		toggle()

func _set_filter(f: String) -> void:
	_filter = f
	_refresh()

func _refresh() -> void:
	if not active():
		return
	var w := Game.weapon()
	_stats.text = "Health %d / %d      Fatigue %d / %d\nArmour %d      Coin %d\nCarrying %.1f of %d%s\nStrikes for %d-%d with %s" % [
		max(Game.hp, 0), Game.max_hp, int(Game.fatigue), int(Game.max_fatigue), Game.armor(), Game.coins,
		Game.weight(), int(Game.CAPACITY), "  (slowed)" if Game.weight() > Game.CAPACITY * 0.5 else "",
		w["dmg"][0], w["dmg"][1], String(w["name"]).to_lower()]
	UI.clear(_worn)
	for slot in Items.SLOTS:
		var id: String = Game.equip[slot]
		var text := "%s:  %s" % [Items.SLOT_NAMES[slot], Items.ITEMS[id]["name"] if id != "" else ("bare hands" if slot == "weapon" else "nothing")]
		var b := UI.button(_worn, text, _use.bind(id) if id != "" else _nothing, 14)
		if id == "":
			b.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	var lines: Array = []
	var pair: Array = []
	for sk in Items.SKILL_NAMES:
		pair.append("%s %d" % [Items.SKILL_NAMES[sk], Game.skills[sk]])
		if pair.size() == 2:
			lines.append("      ".join(pair))
			pair.clear()
	_skills.text = "\n".join(lines)
	UI.clear(_list)
	var ids: Array = Game.items.keys()
	ids.sort_custom(func(a, b): return String(Items.ITEMS[a]["name"]) < String(Items.ITEMS[b]["name"]))
	for id in ids:
		var it: Dictionary = Items.ITEMS[id]
		var kind: String = "armor" if it["type"] == "shield" else it["type"]
		if _filter != "all" and kind != _filter:
			continue
		var worn: bool = Game.equip.values().has(id)
		var row := "%s%s%s      %s      weight %.1f, worth %d" % [
			"● " if worn else "", it["name"], "  x%d" % Game.items[id] if Game.items[id] > 1 else "", Items.label(id), it["weight"], it["value"]]
		var b := UI.button(_list, row, _use.bind(id), 16)
		b.mouse_entered.connect(_describe.bind(id))
		if worn:
			b.add_theme_color_override("font_color", UI.GOLD)
	if _list.get_child_count() == 0:
		UI.text(_list, "Nothing of that kind.", 16, Color(0.6, 0.58, 0.52))

func _nothing() -> void:
	pass

func _describe(id: String) -> void:
	var it: Dictionary = Items.ITEMS[id]
	var act := "Click to eat or drink." if it["type"] == "food" else ("Click to wear, wield or take off." if it["type"] in ["weapon", "armor", "shield"] else "Used during the rite.")
	_about.text = "%s  %s" % [it["desc"], act]

## Wield, wear, take off, eat or drink, depending on what it is.
func _use(id: String) -> void:
	var it: Dictionary = Items.ITEMS[id]
	if it["type"] == "food":
		Game.use_item(id)
	elif it["type"] in ["weapon", "armor", "shield"]:
		Game.toggle_equip(id)
	_refresh()
