extends RefCounted
## The prizes: what they look like, and putting them on a figure.

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")

const COLORS := {"foam_finger": Color(0.15, 0.35, 0.95), "rubber_chicken": Color(1.0, 0.85, 0.2), "pool_noodle": Color(0.2, 0.85, 0.9),
	"katana_88": Color(0.72, 0.6, 0.42), "cone": Color(1.0, 0.45, 0.1), "chef_hat": Color(0.97, 0.97, 0.97), "antennae": Color(0.3, 0.9, 0.4),
	"lion_mask": Color(0.93, 0.72, 0.28), "belt": Color(0.5, 0.35, 0.15), "medal": Color(0.2, 0.4, 0.9), "strap_scarf": Color(0.9, 0.15, 0.15),
	"clipboard": Color(0.45, 0.3, 0.18), "ghost": Color(0.9, 0.9, 0.92), "raygun": Color(1.0, 0.4, 0.9), "prop_hat": Color(0.9, 0.2, 0.2), "golden_chip": Color(1.0, 0.82, 0.25),
	"dare_sash": Color(0.93, 0.72, 0.28), "sweatband": Color(0.95, 0.2, 0.3), "boom_box": Color(0.3, 0.3, 0.35), "gold_chalk": Color(1.0, 0.85, 0.3), "cape": Color(0.7, 0.1, 0.12)}

static func dress(figure: Node3D, worn: Dictionary) -> void:
	var skel: Skeleton3D = figure.find_child("Skeleton3D", true, false)
	for slot in ["hand", "head", "body"]:
		var old := skel.get_node_or_null("Worn_" + slot)
		if old:
			skel.remove_child(old)
			old.queue_free()
		var item: String = worn.get(slot, "")
		if item == "":
			continue
		var m := model(item)
		hold(figure, m, {"hand": "hand_r", "head": "Head", "body": "spine_03"}[slot], "Worn_" + slot)
		if slot == "hand":
			m.rotation.x = PI / 2.0
			m.position = Vector3(0, 0.1, 0.03)

## Fix something to a bone.
static func hold(figure: Node3D, thing: Node3D, bone := "hand_r", name := "Held") -> void:
	var skel: Skeleton3D = figure.find_child("Skeleton3D", true, false)
	drop(figure, name)
	var ba := BoneAttachment3D.new()
	ba.name = name
	ba.bone_name = bone
	skel.add_child(ba)
	ba.add_child(thing)

static func drop(figure: Node3D, name := "Held") -> void:
	var skel: Skeleton3D = figure.find_child("Skeleton3D", true, false)
	var old := skel.get_node_or_null(name)
	if old:
		skel.remove_child(old)
		old.queue_free()

## The things you can win. Built from simple shapes, like everything worth owning.
static func model(item: String) -> Node3D:
	var n := Node3D.new()
	match item:
		"foam_finger":
			Build.box(n, Vector3(0.3, 0.42, 0.1), Vector3(0, 0.25, 0), Color(0.15, 0.35, 0.95))
			Build.box(n, Vector3(0.1, 0.5, 0.1), Vector3(0.02, 0.68, 0), Color(0.15, 0.35, 0.95))
			Asia.quad(n, Vector2(0.22, 0.22), Vector3(0, 0.26, 0.052), 0.0, "ui/emblem.png", true)
		"rubber_chicken":
			Build.sphere(n, 0.11, Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.2)).scale = Vector3(1, 2.2, 1)
			Build.sphere(n, 0.08, Vector3(0, 0.5, 0.02), Color(1.0, 0.85, 0.2))
			Build.box(n, Vector3(0.03, 0.08, 0.1), Vector3(0, 0.6, 0.02), Color(0.9, 0.1, 0.1))
			Build.cyl(n, 0.0, 0.03, 0.09, Vector3(0, 0.5, 0.11), Color(1.0, 0.5, 0.1), 5).rotation.x = PI / 2.0
		"pool_noodle":
			Build.cyl(n, 0.05, 0.05, 1.5, Vector3(0, 0.6, 0), Color(0.2, 0.85, 0.9), 8)
		"katana_88":
			Build.box(n, Vector3(0.06, 0.95, 0.015), Vector3(0, 0.55, 0), Color(0.72, 0.6, 0.42))
			Build.box(n, Vector3(0.18, 0.03, 0.05), Vector3(0, 0.07, 0), Color(0.93, 0.72, 0.28), false, 0.3)
			Build.cyl(n, 0.022, 0.022, 0.18, Vector3(0, -0.03, 0), Color(0.6, 0.1, 0.1), 6)
		"cone":
			Build.cyl(n, 0.03, 0.2, 0.46, Vector3(0, 0.36, 0), Color(1.0, 0.45, 0.1), 10)
			Build.cyl(n, 0.11, 0.14, 0.08, Vector3(0, 0.36, 0), Color(0.95, 0.95, 0.95), 10)
		"chef_hat":
			Build.cyl(n, 0.15, 0.15, 0.2, Vector3(0, 0.26, 0), Color(0.97, 0.97, 0.97), 10)
			Build.sphere(n, 0.19, Vector3(0, 0.42, 0), Color(0.97, 0.97, 0.97))
		"antennae":
			for sx in [-1.0, 1.0]:
				Build.cyl(n, 0.01, 0.015, 0.32, Vector3(sx * 0.08, 0.34, 0), Color(0.3, 0.9, 0.4), 4)
				Build.sphere(n, 0.045, Vector3(sx * 0.08, 0.52, 0), Color(1.0, 0.4, 0.9), 1.5)
		"lion_mask":
			Build.box(n, Vector3(0.3, 0.32, 0.04), Vector3(0, 0.05, 0.19), Color(0.93, 0.72, 0.28))
			for sx in [-1.0, 1.0]:
				Build.sphere(n, 0.07, Vector3(sx * 0.14, 0.22, 0.18), Color(0.93, 0.72, 0.28))
				Build.box(n, Vector3(0.06, 0.03, 0.05), Vector3(sx * 0.07, 0.09, 0.2), Color(0.1, 0.08, 0.06))
			Build.box(n, Vector3(0.08, 0.05, 0.06), Vector3(0, 0.0, 0.21), Color(0.75, 0.2, 0.15))
		"belt":
			Build.box(n, Vector3(0.5, 0.12, 0.32), Vector3(0, -0.26, 0.0), Color(0.3, 0.2, 0.12))
			Build.box(n, Vector3(0.2, 0.17, 0.03), Vector3(0, -0.26, 0.17), Color(0.93, 0.72, 0.28), false, 0.4)
		"strap_scarf":
			var cols := [Color(0.9, 0.15, 0.15), Color(0.93, 0.72, 0.28), Color(0.2, 0.5, 0.95), Color(0.15, 0.6, 0.3)]
			for i in 4:
				Build.box(n, Vector3(0.34 - i * 0.02, 0.05, 0.3), Vector3(0, 0.3 - i * 0.05, 0.0), cols[i])
			Build.box(n, Vector3(0.07, 0.4, 0.03), Vector3(0.1, 0.02, 0.16), cols[0])
			Build.box(n, Vector3(0.07, 0.32, 0.03), Vector3(-0.08, 0.06, 0.16), cols[2])
		"clipboard":
			Build.box(n, Vector3(0.26, 0.36, 0.02), Vector3(0, 0.22, 0), Color(0.45, 0.3, 0.18))
			Build.box(n, Vector3(0.22, 0.3, 0.01), Vector3(0, 0.21, 0.015), Color(0.96, 0.96, 0.92))
			Build.box(n, Vector3(0.1, 0.04, 0.03), Vector3(0, 0.39, 0.015), Color(0.7, 0.7, 0.72))
		"ghost":
			Build.cyl(n, 0.3, 0.5, 1.2, Vector3(0, -0.25, 0), Color(0.97, 0.97, 0.97), 12)
		"raygun":
			Build.box(n, Vector3(0.07, 0.16, 0.07), Vector3(0, 0.05, 0), Color(0.75, 0.75, 0.8))
			Build.cyl(n, 0.05, 0.07, 0.34, Vector3(0, 0.2, 0.12), Color(0.3, 0.9, 0.5), 10).rotation.x = PI / 2.0
			Build.sphere(n, 0.07, Vector3(0, 0.2, 0.32), Color(1.0, 0.4, 0.9), 1.6)
			for i in 3:
				Build.cyl(n, 0.075, 0.075, 0.015, Vector3(0, 0.2, 0.02 + i * 0.08), Color(1.0, 0.85, 0.3), 10).rotation.x = PI / 2.0
		"prop_hat":
			Build.sphere(n, 0.16, Vector3(0, 0.24, 0), Color(0.9, 0.2, 0.2)).scale = Vector3(1, 0.6, 1)
			Build.box(n, Vector3(0.18, 0.02, 0.14), Vector3(0, 0.2, 0.17), Color(0.95, 0.8, 0.2))
			Build.cyl(n, 0.012, 0.012, 0.1, Vector3(0, 0.38, 0), Color(0.3, 0.3, 0.3), 5)
			Build.box(n, Vector3(0.4, 0.012, 0.05), Vector3(0, 0.43, 0), Color(0.2, 0.5, 0.95)).rotation.y = 0.6
		"golden_chip":
			Build.box(n, Vector3(0.05, 0.42, 0.05), Vector3(0, 0.28, 0), Color(1.0, 0.82, 0.25), false, 0.6).rotation.z = 0.12
		"dare_sash":
			var sash := Build.box(n, Vector3(0.09, 0.62, 0.3), Vector3(0, 0.02, 0.0), Color(0.93, 0.72, 0.28), false, 0.3)
			sash.rotation.z = 0.7
		"sweatband":
			Build.cyl(n, 0.125, 0.125, 0.05, Vector3(0, 0.13, 0.0), Color(0.95, 0.2, 0.3), 12)
			Build.cyl(n, 0.127, 0.127, 0.015, Vector3(0, 0.13, 0.0), Color(1, 1, 1), 12)
		"boom_box":
			Build.box(n, Vector3(0.34, 0.2, 0.1), Vector3(0, 0.2, 0), Color(0.25, 0.25, 0.3))
			for sx in [-1.0, 1.0]:
				Build.cyl(n, 0.06, 0.06, 0.02, Vector3(sx * 0.1, 0.2, 0.055), Color(0.1, 0.1, 0.1), 10).rotation.x = PI / 2.0
			Build.box(n, Vector3(0.26, 0.02, 0.02), Vector3(0, 0.34, 0), Color(0.7, 0.7, 0.75))
		"gold_chalk":
			Build.box(n, Vector3(0.12, 0.12, 0.08), Vector3(0, 0.14, 0), Color(1.0, 0.85, 0.3), false, 0.7)
		"cape":
			Build.box(n, Vector3(0.46, 0.75, 0.03), Vector3(0, -0.12, -0.17), Color(0.7, 0.1, 0.12))
			Asia.quad(n, Vector2(0.26, 0.26), Vector3(0, 0.0, -0.19), PI, "ui/emblem.png", true)
		"medal":
			Build.box(n, Vector3(0.03, 0.2, 0.01), Vector3(0, 0.02, 0.16), Color(0.2, 0.4, 0.9))
			Build.cyl(n, 0.05, 0.05, 0.012, Vector3(0, -0.1, 0.16), Color(0.93, 0.72, 0.28), 10).rotation.x = PI / 2.0
	return n

