extends Node3D
## Something in the world that holds things: a chest, a crate, a sack dropped by the dead.
## If it belongs to someone living, taking from it is theft, and anyone near enough sees.

const Build = preload("res://scripts/build.gd")

var title := ""
var contents := {}
var coins := 0
var owner_id := ""
var village := ""
var _lifetime := -1.0

func setup(name_text: String, items: Dictionary, coin: int, owned_by := "", in_village := "", sack := false, lifetime := -1.0) -> void:
	title = name_text
	contents = items.duplicate()
	coins = coin
	owner_id = owned_by
	village = in_village
	_lifetime = lifetime
	if sack:
		Build.tsphere(self, 0.32, Vector3(0, 0.22, 0), "cloth", Color(0.6, 0.55, 0.45)).scale = Vector3(1.0, 0.75, 1.0)
	else:
		Build.tbox(self, Vector3(1.0, 0.6, 0.6), Vector3(0, 0.3, 0), "darkwood", Color.WHITE, true)
		Build.tbox(self, Vector3(1.04, 0.1, 0.64), Vector3(0, 0.62, 0), "lacquer")
		Build.box(self, Vector3(0.12, 0.16, 0.04), Vector3(0, 0.42, 0.31), Color(0.93, 0.72, 0.28))
	add_to_group("interact")

func _owner() -> Node:
	for n in Game.npcs:
		if n.id == owner_id and n.alive:
			return n
	return null

func empty() -> bool:
	return contents.is_empty() and coins == 0

func prompt() -> String:
	if empty():
		return "%s (empty)" % title
	return ("Steal from %s" if _owner() != null else "Search %s") % title

func interact() -> void:
	if empty():
		return
	var got: Array = []
	for id in contents:
		Game.add_item(id, contents[id])
		got.append("%s%s" % [Game.Items.ITEMS[id]["name"], " x%d" % contents[id] if contents[id] > 1 else ""])
	if coins > 0:
		Game.coins += coins
		got.append("%d coin" % coins)
	contents.clear()
	coins = 0
	Game.say("You take: %s." % ", ".join(got))
	var owner := _owner()
	if owner != null:
		var seen := Game.deed("theft", -0.9, 2.5, global_position, village, title, 11.0)
		if seen.size() > 0:
			Game.say("%s saw you. They will tell the others." % seen[0].npc_name)
		elif not seen.has(owner):
			owner.mind.experience("theft", -0.5, 1.2, false, "")
		Game.note("You stole from %s." % title)
	Game.touch()

func _process(dt: float) -> void:
	if _lifetime > 0.0 and not Game.modal:
		_lifetime -= dt
		if _lifetime <= 0.0:
			queue_free()
