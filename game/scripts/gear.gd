extends RefCounted
## Models for things that are carried and worn, and the code that hangs them on a body.
## Weapons are built with the grip at the origin and the business end along +Y.

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")

const STEEL := Color(0.78, 0.8, 0.84)
const GOLD := Color(0.93, 0.72, 0.28)

static func weapon(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"staff":
			Build.tcyl(n, 0.024, 0.028, 1.75, Vector3(0, 0.35, 0), "darkwood", Color.WHITE, 6)
			Build.tcyl(n, 0.032, 0.032, 0.1, Vector3(0, 1.2, 0), "iron", STEEL, 6)
			Build.tcyl(n, 0.032, 0.032, 0.1, Vector3(0, -0.5, 0), "iron", STEEL, 6)
		"pole":
			Build.tcyl(n, 0.022, 0.03, 2.6, Vector3(0, 0.6, 0), "wood", Color(0.75, 0.7, 0.6), 6)
		"spear":
			Build.tcyl(n, 0.022, 0.026, 2.2, Vector3(0, 0.5, 0), "darkwood", Color.WHITE, 6)
			Build.tcyl(n, 0.0, 0.045, 0.32, Vector3(0, 1.76, 0), "iron", STEEL, 4)
			Build.tcyl(n, 0.05, 0.03, 0.1, Vector3(0, 1.55, 0), "cloth", Color.WHITE, 6)
		"axe":
			Build.tcyl(n, 0.022, 0.026, 0.95, Vector3(0, 0.28, 0), "wood", Color(0.7, 0.6, 0.5), 6)
			Build.tbox(n, Vector3(0.2, 0.17, 0.03), Vector3(0.1, 0.66, 0), "iron", STEEL)
			Build.tbox(n, Vector3(0.07, 0.11, 0.05), Vector3(-0.03, 0.66, 0), "iron", STEEL * 0.8)
		"sword", "old_sword":
			var fine := id == "old_sword"
			Build.tbox(n, Vector3(0.05, 0.82, 0.012), Vector3(0, 0.5, 0), "iron", STEEL if not fine else Color(0.9, 0.9, 0.95))
			Build.tbox(n, Vector3(0.035, 0.1, 0.012), Vector3(0.006, 0.95, 0), "iron", STEEL).rotation.z = 0.25
			Build.box(n, Vector3(0.2, 0.03, 0.05), Vector3(0, 0.08, 0), GOLD if fine else Color(0.35, 0.3, 0.25), false, 0.3 if fine else 0.0)
			Build.tcyl(n, 0.02, 0.02, 0.16, Vector3(0, -0.01, 0), "cloth" if fine else "darkwood", Color.WHITE, 6)
			Build.sphere(n, 0.03, Vector3(0, -0.1, 0), GOLD if fine else Color(0.35, 0.3, 0.25))
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

static func shield() -> Node3D:
	var n := Node3D.new()
	Build.tcyl(n, 0.36, 0.36, 0.045, Vector3.ZERO, "planks", Color(0.6, 0.48, 0.4), 14)
	Build.tcyl(n, 0.38, 0.38, 0.03, Vector3.ZERO, "iron", STEEL * 0.7, 14)
	Build.tsphere(n, 0.09, Vector3(0, 0.03, 0), "iron", STEEL).scale = Vector3(1, 0.6, 1)
	var crest := Asia.quad(n, Vector2(0.5, 0.5), Vector3(0, 0.026, 0), 0.0, "ui/emblem.png", true)
	crest.rotation.x = -PI / 2.0
	return n

static func hat() -> Node3D:
	var n := Node3D.new()
	Build.tcyl(n, 0.02, 0.42, 0.17, Vector3(0, 0.02, 0), "thatch", Color(1.0, 0.92, 0.7), 12)
	return n

static func cuirass() -> Node3D:
	var n := Node3D.new()
	Build.tbox(n, Vector3(0.46, 0.4, 0.3), Vector3(0, 0.0, 0.0), "lacquer", Color(0.75, 0.75, 0.75))
	for row in 3:
		Build.box(n, Vector3(0.47, 0.025, 0.31), Vector3(0, -0.12 + row * 0.12, 0), GOLD, false, 0.2)
	for sx in [-1.0, 1.0]:
		Build.tsphere(n, 0.11, Vector3(sx * 0.25, 0.2, 0), "lacquer", Color(0.75, 0.75, 0.75)).scale = Vector3(1.1, 0.7, 1.2)
	return n

static func coat() -> Node3D:
	var n := Node3D.new()
	Build.tbox(n, Vector3(0.44, 0.44, 0.29), Vector3(0, -0.03, 0.0), "cloth", Color(0.75, 0.72, 0.6))
	Build.tbox(n, Vector3(0.45, 0.05, 0.3), Vector3(0, -0.2, 0), "darkwood")
	return n

static func bracer() -> Node3D:
	var n := Node3D.new()
	Build.tcyl(n, 0.052, 0.058, 0.17, Vector3(0, 0.13, 0), "darkwood", Color(0.9, 0.7, 0.55), 8)
	Build.cyl(n, 0.06, 0.06, 0.02, Vector3(0, 0.2, 0), GOLD, 8)
	return n

static func boot() -> Node3D:
	var n := Node3D.new()
	Build.tcyl(n, 0.07, 0.065, 0.2, Vector3(0, 0.18, 0), "darkwood", Color(0.7, 0.55, 0.45), 8)
	return n

## Hang a model on a bone. Replaces whatever was in that slot before.
static func _attach(figure: Node3D, slot: String, bone: String, model: Node3D, at: Vector3, rot: Vector3) -> void:
	var skel: Skeleton3D = figure.find_child("Skeleton3D", true, false)
	var name := "Gear_" + slot
	var old := skel.get_node_or_null(name)
	if old:
		skel.remove_child(old)
		old.queue_free()
	if model == null:
		return
	var ba := BoneAttachment3D.new()
	ba.name = name
	ba.bone_name = bone
	skel.add_child(ba)
	ba.add_child(model)
	model.position = at
	model.rotation = rot

## Dress a figure in a set of equipment: {"weapon": id, "shield": id, "head": id, ...}.
static func dress(figure: Node3D, worn: Dictionary) -> void:
	var w: String = worn.get("weapon", "")
	_attach(figure, "weapon", "hand_r", weapon(w) if w != "" and w != "fists" else null, Vector3(0.0, 0.1, 0.03), Vector3(PI / 2.0, 0, 0))
	_attach(figure, "shield", "lowerarm_l", shield() if worn.get("shield", "") != "" else null, Vector3(0.07, 0.14, 0.0), Vector3(0, 0, -PI / 2.0))
	_attach(figure, "head", "Head", hat() if worn.get("head", "") != "" else null, Vector3(0, 0.2, 0.01), Vector3.ZERO)
	var body: String = worn.get("body", "")
	_attach(figure, "body", "spine_03", cuirass() if body == "cuirass" else (coat() if body == "coat" else null), Vector3(0, 0.02, 0.01), Vector3.ZERO)
	var hands: bool = worn.get("hands", "") != ""
	_attach(figure, "hand_l", "lowerarm_l", bracer() if hands else null, Vector3.ZERO, Vector3.ZERO)
	_attach(figure, "hand_r", "lowerarm_r", bracer() if hands else null, Vector3.ZERO, Vector3.ZERO)
	var feet: bool = worn.get("feet", "") != ""
	_attach(figure, "foot_l", "calf_l", boot() if feet else null, Vector3.ZERO, Vector3.ZERO)
	_attach(figure, "foot_r", "calf_r", boot() if feet else null, Vector3.ZERO, Vector3.ZERO)
