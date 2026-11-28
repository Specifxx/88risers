extends RefCounted
## The prizes: what they look like, and putting them on a figure.

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")

const COLORS := {"foam_finger": Color(0.15, 0.35, 0.95), "rubber_chicken": Color(1.0, 0.85, 0.2), "pool_noodle": Color(0.2, 0.85, 0.9),
	"katana_88": Color(0.72, 0.6, 0.42), "cone": Color(1.0, 0.45, 0.1), "chef_hat": Color(0.97, 0.97, 0.97), "antennae": Color(0.3, 0.9, 0.4),
	"lion_mask": Color(0.93, 0.72, 0.28), "belt": Color(0.5, 0.35, 0.15), "medal": Color(0.2, 0.4, 0.9), "strap_scarf": Color(0.9, 0.15, 0.15),
	"clipboard": Color(0.45, 0.3, 0.18), "ghost": Color(0.9, 0.9, 0.92), "raygun": Color(1.0, 0.4, 0.9), "prop_hat": Color(0.9, 0.2, 0.2), "golden_chip": Color(1.0, 0.82, 0.25),
	"dare_sash": Color(0.93, 0.72, 0.28), "sweatband": Color(0.95, 0.2, 0.3), "boom_box": Color(0.3, 0.3, 0.35), "gold_chalk": Color(1.0, 0.85, 0.3), "cape": Color(0.7, 0.1, 0.12),
	"bracket_cup": Color(1.0, 0.82, 0.25), "fish": Color(0.55, 0.7, 0.8), "sunnies": Color(0.1, 0.1, 0.12), "snag": Color(0.7, 0.35, 0.2),
	"footy": Color(0.75, 0.3, 0.15), "balloon": Color(0.95, 0.2, 0.3), "possum_hat": Color(0.5, 0.48, 0.45), "glow_stick": Color(0.3, 1.0, 0.5),
	"harmonica": Color(0.75, 0.75, 0.8), "catch_ball": Color(0.2, 0.75, 0.6), "gripling": Color(0.95, 0.6, 0.2), "golden_grip": Color(1.0, 0.82, 0.25),
	"signed_band": Color(0.9, 0.1, 0.1), "giant_band": Color(0.2, 0.2, 0.25), "kaiju_claw": Color(0.15, 0.5, 0.45)}

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
	if Meet.ITEMS.has(item) and Meet.ITEMS[item].has("shape"):
		_shape(n, Meet.ITEMS[item]["shape"], Meet.ITEMS[item]["col"])
		return n
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
				Build.cyl(n, 0.01, 0.015, 0.32, Vector3(sx * 0.08, 0.34, 0), Color(0.3, 0.9, 0.4), 4).material_override = Build.mat(Color(0.3, 0.9, 0.4), 0.7)
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
			# A crinkle-cut crisp the size of a saucer, bent like one, and glowing.
			for k in 5:
				var seg := Build.box(n, Vector3(0.056, 0.26 - absf(k - 2) * 0.05, 0.014), Vector3((k - 2) * 0.052, 0.28, absf(k - 2) * 0.016), Color(1.0, 0.82, 0.25), false, 0.9)
				seg.rotation.y = (k - 2) * -0.28
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
		"bracket_cup":
			Build.cyl(n, 0.11, 0.05, 0.2, Vector3(0, 0.34, 0), Color(1.0, 0.82, 0.25), 12).material_override = Build.mat(Color(1.0, 0.82, 0.25), 0.5)
			Build.cyl(n, 0.02, 0.02, 0.14, Vector3(0, 0.17, 0), Color(1.0, 0.82, 0.25), 6)
			Build.cyl(n, 0.08, 0.09, 0.04, Vector3(0, 0.09, 0), Color(0.2, 0.15, 0.1), 10)
		"fish":
			Build.sphere(n, 0.09, Vector3(0, 0.3, 0), Color(0.55, 0.7, 0.8)).scale = Vector3(0.5, 2.4, 1.0)
			Build.box(n, Vector3(0.02, 0.12, 0.16), Vector3(0, 0.55, 0), Color(0.4, 0.55, 0.7))
			Build.sphere(n, 0.018, Vector3(0.04, 0.16, 0.03), Color(0.05, 0.05, 0.05))
		"sunnies":
			for sx in [-1.0, 1.0]:
				Build.box(n, Vector3(0.09, 0.05, 0.02), Vector3(sx * 0.06, 0.08, 0.13), Color(0.08, 0.08, 0.1))
			Build.box(n, Vector3(0.24, 0.012, 0.02), Vector3(0, 0.1, 0.13), Color(0.9, 0.9, 0.9))
		"snag":
			Build.cyl(n, 0.008, 0.008, 0.4, Vector3(0, 0.22, 0), Color(0.75, 0.75, 0.78), 5)
			Build.cyl(n, 0.035, 0.035, 0.2, Vector3(0, 0.44, 0), Color(0.7, 0.35, 0.2), 8).rotation.z = PI / 2.0
		"footy":
			Build.sphere(n, 0.12, Vector3(0, 0.22, 0), Color(0.75, 0.3, 0.15)).scale = Vector3(0.75, 1.3, 0.75)
		"balloon":
			# The string and balloon hang from a pivot the holder keeps upright and lets sway.
			var bal := Node3D.new()
			bal.name = "Sway"
			n.add_child(bal)
			Build.cyl(bal, 0.004, 0.004, 0.9, Vector3(0, 0.45, 0), Color(0.9, 0.9, 0.9), 4)
			Build.sphere(bal, 0.2, Vector3(0, 1.08, 0), Color(0.95, 0.2, 0.3)).scale = Vector3(1, 1.2, 1)
			Build.cyl(bal, 0.0, 0.03, 0.05, Vector3(0, 0.84, 0), Color(0.8, 0.15, 0.25), 6)
		"possum_hat":
			Build.sphere(n, 0.13, Vector3(0, 0.22, 0), Color(0.5, 0.48, 0.45)).scale = Vector3(1.2, 0.7, 1.5)
			Build.sphere(n, 0.07, Vector3(0, 0.22, 0.17), Color(0.55, 0.53, 0.5))
			Build.cyl(n, 0.012, 0.02, 0.3, Vector3(0.1, 0.16, -0.18), Color(0.3, 0.28, 0.27), 5).rotation.x = 1.2
			for sx in [-1.0, 1.0]:
				Build.sphere(n, 0.025, Vector3(sx * 0.05, 0.29, 0.17), Color(0.4, 0.38, 0.36))
		"glow_stick":
			Build.cyl(n, 0.018, 0.018, 0.4, Vector3(0, 0.25, 0), Color(0.3, 1.0, 0.5), 6).material_override = Build.mat(Color(0.3, 1.0, 0.5), 2.0)
		"harmonica":
			Build.box(n, Vector3(0.18, 0.05, 0.05), Vector3(0, 0.12, 0.02), Color(0.78, 0.78, 0.82))
			Build.box(n, Vector3(0.16, 0.02, 0.055), Vector3(0, 0.12, 0.02), Color(0.5, 0.1, 0.1))
		"catch_ball":
			Build.sphere(n, 0.09, Vector3(0, 0.14, 0.02), Color(0.2, 0.75, 0.6))
			Build.cyl(n, 0.092, 0.092, 0.02, Vector3(0, 0.14, 0.02), Color(0.1, 0.1, 0.12), 12)
			Build.sphere(n, 0.025, Vector3(0, 0.14, 0.11), Color(0.95, 0.95, 0.95))
		"gripling":
			var g := gripling()
			n.add_child(g)
			g.position = Vector3(0.24, 0.22, 0.0)
			g.scale = Vector3(0.55, 0.55, 0.55)
		"golden_grip":
			# A plated gauntlet with a clenched fist and a wrist guard: a puller's glove, in gold.
			var gold := Build.mat(Color(1.0, 0.82, 0.25), 0.55)
			Build.cyl(n, 0.075, 0.095, 0.26, Vector3(0, -0.04, 0), Color(1.0, 0.82, 0.25), 10).material_override = gold
			Build.box(n, Vector3(0.17, 0.15, 0.13), Vector3(0, 0.15, 0.01), Color(1.0, 0.82, 0.25)).material_override = gold
			for i in 4:
				Build.box(n, Vector3(0.035, 0.07, 0.11), Vector3(-0.06 + i * 0.04, 0.24, 0.02), Color(0.95, 0.75, 0.2)).material_override = gold
			Build.box(n, Vector3(0.05, 0.1, 0.05), Vector3(0.1, 0.16, 0.05), Color(0.95, 0.75, 0.2)).material_override = gold
			Build.cyl(n, 0.1, 0.1, 0.03, Vector3(0, 0.07, 0), Color(0.7, 0.5, 0.1), 10)
			Asia.quad(n, Vector2(0.11, 0.11), Vector3(0, 0.15, 0.08), 0.0, "ui/emblem.png", true, 0.4)
		"signed_band":
			Build.cyl(n, 0.125, 0.125, 0.06, Vector3(0, 0.14, 0.0), Color(0.9, 0.1, 0.1), 12)
			Build.box(n, Vector3(0.1, 0.03, 0.01), Vector3(0, 0.14, 0.126), Color(0.05, 0.05, 0.05))
		"giant_band":
			Build.cyl(n, 0.2, 0.2, 0.14, Vector3(0, -0.34, 0.0), Color(0.2, 0.2, 0.25), 12)
			Build.cyl(n, 0.205, 0.205, 0.03, Vector3(0, -0.34, 0.0), Color(0.9, 0.1, 0.1), 12)
		"kaiju_claw":
			var cc := Color(0.15, 0.5, 0.45)
			Build.cyl(n, 0.06, 0.1, 0.5, Vector3(0, 0.3, 0), cc, 8)
			Build.cyl(n, 0.0, 0.1, 0.5, Vector3(0.07, 0.75, 0), cc * 1.2, 6).rotation.z = -0.25
			Build.cyl(n, 0.0, 0.08, 0.4, Vector3(-0.08, 0.7, 0), cc * 0.9, 6).rotation.z = 0.35
		"medal":
			Build.box(n, Vector3(0.03, 0.2, 0.01), Vector3(0, 0.02, 0.16), Color(0.2, 0.4, 0.9))
			Build.cyl(n, 0.05, 0.05, 0.012, Vector3(0, -0.1, 0.16), Color(0.93, 0.72, 0.28), 10).rotation.x = PI / 2.0
	return n


## A Gripling: round, orange, two stubby legs, and one arm far too big for it.
static func gripling() -> Node3D:
	var n := Node3D.new()
	var c := Color(0.95, 0.6, 0.2)
	Build.sphere(n, 0.2, Vector3(0, 0.26, 0), c)
	for sx in [-1.0, 1.0]:
		Build.sphere(n, 0.045, Vector3(sx * 0.08, 0.34, 0.16), Color(1, 1, 1))
		Build.sphere(n, 0.022, Vector3(sx * 0.08, 0.34, 0.2), Color(0.05, 0.05, 0.05))
		Build.box(n, Vector3(0.07, 0.1, 0.09), Vector3(sx * 0.09, 0.05, 0.02), c * 0.8)
		Build.cyl(n, 0.0, 0.035, 0.12, Vector3(sx * 0.1, 0.5, 0), c * 0.85, 5)
	Build.cyl(n, 0.07, 0.11, 0.3, Vector3(0.27, 0.3, 0.02), c * 0.9, 8).rotation.z = -0.9
	Build.sphere(n, 0.11, Vector3(0.4, 0.44, 0.02), c * 0.9)
	Build.cyl(n, 0.03, 0.03, 0.12, Vector3(-0.2, 0.26, 0), c * 0.8, 6).rotation.z = 1.3
	return n

## Chalk on someone: white dust across the chest and shoulders, not a coat of paint.
static func dust(figure: Node3D, seconds: float, c := Color(0.97, 0.97, 0.97)) -> void:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var blob := Build.sphere(n, rng.randf_range(0.05, 0.11), Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.22, 0.2), 0.13 + rng.randf_range(-0.02, 0.03)), c)
		blob.scale = Vector3(1.0, rng.randf_range(0.6, 1.1), 0.22)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-1.0, 1.0]:
		Build.sphere(n, 0.08, Vector3(sx * 0.2, 0.22, 0.04), c).scale = Vector3(1.2, 0.35, 1.0)
	hold(figure, n, "spine_03", "Dust")
	figure.get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(figure):
			drop(figure, "Dust"))

## Kit that is one of a family of shapes in a given colour.
static func _shape(n: Node3D, shape: String, c: Color) -> void:
	match shape:
		# Heads.
		"cap":
			Build.sphere(n, 0.13, Vector3(0, 0.16, 0), c).scale = Vector3(1, 0.7, 1.05)
			Build.box(n, Vector3(0.2, 0.015, 0.14), Vector3(0, 0.13, 0.17), c * 0.8)
		"beanie":
			Build.sphere(n, 0.135, Vector3(0, 0.17, 0), c).scale = Vector3(1, 0.95, 1)
			Build.cyl(n, 0.135, 0.135, 0.05, Vector3(0, 0.1, 0), c * 1.6 + Color(0.15, 0.15, 0.15), 12)
			Build.sphere(n, 0.04, Vector3(0, 0.31, 0), c * 1.6 + Color(0.2, 0.2, 0.2))
		"visor":
			Build.cyl(n, 0.13, 0.13, 0.04, Vector3(0, 0.13, 0), c, 12)
			Build.box(n, Vector3(0.22, 0.012, 0.16), Vector3(0, 0.12, 0.18), Color(c.r, c.g, c.b, 1.0) * 0.9)
		"tophat":
			Build.cyl(n, 0.2, 0.2, 0.015, Vector3(0, 0.16, 0), c, 14)
			Build.cyl(n, 0.12, 0.125, 0.3, Vector3(0, 0.31, 0), c, 14)
			Build.cyl(n, 0.127, 0.127, 0.03, Vector3(0, 0.19, 0), Color(0.75, 0.1, 0.12), 14)
		"crown":
			Build.cyl(n, 0.125, 0.125, 0.07, Vector3(0, 0.2, 0), c, 12).material_override = Build.mat(c, 0.4)
			for i in 6:
				var a := TAU * i / 6.0
				Build.cyl(n, 0.0, 0.03, 0.09, Vector3(cos(a) * 0.115, 0.28, sin(a) * 0.115), c, 4).material_override = Build.mat(c, 0.4)
		"helmet":
			Build.sphere(n, 0.17, Vector3(0, 0.12, 0), Color(c.r, c.g, c.b, 1.0)).scale = Vector3(1, 1.05, 1)
			Build.box(n, Vector3(0.18, 0.06, 0.02), Vector3(0, 0.1, 0.16), Color(0.05, 0.05, 0.08))
		"box":
			Build.box(n, Vector3(0.34, 0.05, 0.34), Vector3(0, 0.2, 0), c)
			Build.cyl(n, 0.09, 0.09, 0.005, Vector3(0, 0.23, 0), Color(0.8, 0.2, 0.15), 10)
		"halo":
			for i in 12:
				var a := TAU * i / 12.0
				Build.sphere(n, 0.022, Vector3(cos(a) * 0.14, 0.42, sin(a) * 0.14), c, 2.0)
		"horns":
			for sx in [-1.0, 1.0]:
				Build.cyl(n, 0.0, 0.035, 0.16, Vector3(sx * 0.09, 0.26, 0.02), c, 6).rotation.z = -sx * 0.4
		"wig":
			Build.sphere(n, 0.16, Vector3(0, 0.14, -0.02), c).scale = Vector3(1.1, 1.0, 1.1)
			for sx in [-1.0, 1.0]:
				Build.sphere(n, 0.08, Vector3(sx * 0.14, 0.0, -0.02), c).scale = Vector3(0.8, 1.6, 0.9)
		# Bodies.
		"scarf":
			Build.cyl(n, 0.13, 0.13, 0.07, Vector3(0, 0.24, 0.0), c, 10)
			Build.box(n, Vector3(0.08, 0.4, 0.03), Vector3(0.08, 0.02, 0.15), c)
		"chain":
			for i in 12:
				var a := PI * i / 11.0
				Build.sphere(n, 0.025, Vector3(cos(a) * 0.14, 0.2 - sin(a) * 0.22, 0.15), c, 0.5)
			Build.cyl(n, 0.05, 0.05, 0.012, Vector3(0, -0.06, 0.16), c, 10).rotation.x = PI / 2.0
		"tie":
			for sx in [-1.0, 1.0]:
				Build.box(n, Vector3(0.09, 0.07, 0.02), Vector3(sx * 0.055, 0.22, 0.14), c).rotation.z = sx * 0.3
			Build.box(n, Vector3(0.035, 0.04, 0.03), Vector3(0, 0.22, 0.145), c)
		"ring":
			for i in 14:
				var a := TAU * i / 14.0
				Build.sphere(n, 0.07, Vector3(cos(a) * 0.3, -0.2, sin(a) * 0.3), c if i % 2 else Color(0.97, 0.97, 0.97))
		"wings":
			for sx in [-1.0, 1.0]:
				Build.box(n, Vector3(0.45, 0.16, 0.03), Vector3(sx * 0.32, 0.1, -0.17), c).rotation.z = sx * 0.35
				Build.cyl(n, 0.035, 0.05, 0.14, Vector3(sx * 0.12, -0.05, -0.2), Color(1.0, 0.5, 0.1), 6, false)
		"bib":
			Build.cyl(n, 0.06, 0.06, 0.012, Vector3(0.1, 0.12, 0.16), c, 10).rotation.x = PI / 2.0
			Build.cyl(n, 0.035, 0.035, 0.014, Vector3(0.1, 0.12, 0.165), Color(1.0, 0.85, 0.3), 10).rotation.x = PI / 2.0
		"backpack":
			Build.box(n, Vector3(0.3, 0.36, 0.16), Vector3(0, 0.02, -0.22), c)
			Build.box(n, Vector3(0.2, 0.12, 0.05), Vector3(0, -0.06, -0.31), c * 0.8)
		"apron":
			Build.box(n, Vector3(0.36, 0.6, 0.02), Vector3(0, -0.2, 0.16), c)
			Build.box(n, Vector3(0.2, 0.06, 0.01), Vector3(0, -0.02, 0.172), Color(0.85, 0.1, 0.15))
		# Hands.
		"flag":
			Build.cyl(n, 0.012, 0.012, 1.1, Vector3(0, 0.5, 0), Color(0.6, 0.5, 0.35), 5)
			Build.box(n, Vector3(0.45, 0.28, 0.01), Vector3(0.23, 0.9, 0), c)
		"mug":
			Build.cyl(n, 0.055, 0.05, 0.11, Vector3(0, 0.14, 0), c, 10)
			Build.box(n, Vector3(0.015, 0.06, 0.05), Vector3(0.065, 0.14, 0), c)
		"horn":
			Build.cyl(n, 0.11, 0.03, 0.28, Vector3(0, 0.2, 0.14), c, 10).rotation.x = PI / 2.0
			Build.box(n, Vector3(0.04, 0.1, 0.04), Vector3(0, 0.1, 0.04), Color(0.2, 0.2, 0.22))
		"lid":
			Build.cyl(n, 0.3, 0.3, 0.03, Vector3(0, 0.2, 0.08), c, 14).rotation.x = PI / 2.0
			Build.sphere(n, 0.04, Vector3(0, 0.2, 0.11), c * 0.7)
		"boot":
			Build.box(n, Vector3(0.1, 0.24, 0.1), Vector3(0, 0.28, 0), c)
			Build.box(n, Vector3(0.1, 0.08, 0.24), Vector3(0, 0.14, 0.07), c)
		"banana":
			for i in 5:
				Build.sphere(n, 0.035, Vector3(0, 0.12 + i * 0.05, sin(i * 0.5) * 0.06), c)
		"sock":
			Build.cyl(n, 0.055, 0.06, 0.22, Vector3(0, 0.12, 0), c, 8)
			Build.sphere(n, 0.06, Vector3(0, 0.25, 0.02), c)
		"jandal":
			Build.box(n, Vector3(0.11, 0.3, 0.02), Vector3(0, 0.25, 0), c)
			Build.box(n, Vector3(0.08, 0.02, 0.03), Vector3(0, 0.32, 0.02), Color(0.1, 0.1, 0.1))
		"bottle":
			Build.cyl(n, 0.045, 0.045, 0.2, Vector3(0, 0.2, 0), c, 8)
			Build.cyl(n, 0.018, 0.03, 0.08, Vector3(0, 0.34, 0), c, 8)
			Build.box(n, Vector3(0.03, 0.12, 0.03), Vector3(0, 0.2, 0), Color(0.95, 0.9, 0.75))
		"wheel":
			Build.cyl(n, 0.11, 0.11, 0.04, Vector3(0, 0.22, 0), c, 12).rotation.z = PI / 2.0
			Build.cyl(n, 0.012, 0.012, 0.22, Vector3(0, 0.1, 0), c, 5)
		"stick":
			Build.cyl(n, 0.015, 0.02, 0.6, Vector3(0, 0.35, 0), c, 6)
			Build.sphere(n, 0.05, Vector3(0, 0.68, 0), c, 2.0)
		"trophy":
			Build.cyl(n, 0.035, 0.07, 0.3, Vector3(0, 0.25, 0), Color(0.97, 0.97, 0.97), 8)
			Build.cyl(n, 0.02, 0.035, 0.08, Vector3(0, 0.43, 0), Color(0.9, 0.1, 0.1), 8)
		"whistle":
			Build.box(n, Vector3(0.04, 0.03, 0.09), Vector3(0, 0.12, 0.04), c)
			Build.sphere(n, 0.03, Vector3(0, 0.12, -0.01), c)
		"umbrella":
			Build.cyl(n, 0.01, 0.01, 0.8, Vector3(0, 0.4, 0), Color(0.2, 0.2, 0.2), 5)
			Build.cyl(n, 0.0, 0.42, 0.18, Vector3(0, 0.85, 0), c, 8)
		"plunger":
			Build.cyl(n, 0.014, 0.014, 0.5, Vector3(0, 0.3, 0), Color(0.75, 0.6, 0.4), 5)
			Build.cyl(n, 0.02, 0.09, 0.09, Vector3(0, 0.58, 0), c, 10)
		_:
			Build.box(n, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.2, 0), c)
