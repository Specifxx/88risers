extends RefCounted
## The building kit for the island's look: timber halls with sweeping tiled roofs,
## gates, lanterns, banners, guardian lions, bridges and bamboo. Everything is made
## from textured shapes generated here, so pieces can be any size.

const Build = preload("res://scripts/build.gd")

const CREAM := Color(0.93, 0.89, 0.8)
const STONE := Color(0.8, 0.8, 0.78)

static var _qmats := {}
static var _roof_mats := {}

## A flat textured panel facing +Z (doors, lattice windows, banners, plaques).
static func quad(parent: Node, size: Vector2, pos: Vector3, yaw: float, tex: String, alpha := false, glow := 0.0, two_sided := false) -> MeshInstance3D:
	var key := "%s|%s|%s|%s" % [tex, alpha, glow, two_sided]
	if not _qmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/" + tex)
		m.roughness = 0.9
		if alpha:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		if two_sided:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission_energy_multiplier = glow
		_qmats[key] = m
	var qm := QuadMesh.new()
	qm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = _qmats[key]
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = yaw
	return mi

## A tiled roof with a concave sweep and upturned corners. The ridge runs along X.
static func roof(parent: Node, w: float, d: float, pos: Vector3, rise := 2.4, over := 1.3, tint := Color.WHITE) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var half_w := w / 2.0 + over
	var half_d := d / 2.0 + over
	var nx := 12
	var nz := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var u := float(i) / nx * 2.0 - 1.0
			var v := float(j) / nz * 2.0 - 1.0
			var t := absf(v)
			var e := absf(u)
			var y := rise * pow(1.0 - t, 1.75) + 0.95 * pow(e, 3.0) * pow(t, 2.0) - 0.12 * t
			st.set_uv(Vector2(u * half_w * 0.42, t * (half_d + rise) * 0.42))
			st.add_vertex(Vector3(u * half_w, y, v * half_d))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + 1)
			st.add_index(a + nx + 2)
			st.add_index(a + nx + 1)
	st.generate_normals()
	var key := tint.to_html()
	if not _roof_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/tex/rooftile.jpg")
		m.normal_enabled = true
		m.normal_texture = load("res://assets/tex/rooftile_n.jpg")
		m.albedo_color = tint
		m.roughness = 0.55
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_roof_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _roof_mats[key]
	root.add_child(mi)
	# Ridge, with a raised end at each gable.
	var dark := Color(0.34, 0.38, 0.42) * tint
	Build.tbox(root, Vector3(half_w * 2.0 - 0.5, 0.32, 0.42), Vector3(0, rise + 0.08, 0), "stone", dark)
	for sx in [-1.0, 1.0]:
		var tip := Build.tbox(root, Vector3(0.9, 0.3, 0.38), Vector3(sx * (half_w - 0.35), rise + 0.3, 0), "stone", dark)
		tip.rotation.z = sx * 0.5
	return root

static func paper_lantern(parent: Node, pos: Vector3, lit := false, s := 1.0) -> void:
	var red := Color(0.95, 0.22, 0.12)
	var body := Build.sphere(parent, 0.3 * s, pos, red, 1.3)
	body.scale = Vector3(1.0, 1.25, 1.0)
	Build.cyl(parent, 0.14 * s, 0.14 * s, 0.07 * s, pos + Vector3(0, 0.38 * s, 0), Color(0.12, 0.09, 0.07), 8)
	Build.cyl(parent, 0.14 * s, 0.14 * s, 0.07 * s, pos - Vector3(0, 0.38 * s, 0), Color(0.12, 0.09, 0.07), 8)
	Build.cyl(parent, 0.02, 0.02, 0.35 * s, pos - Vector3(0, 0.58 * s, 0), Color(0.75, 0.6, 0.2), 4)
	if lit:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.32)
		l.light_energy = 1.6
		l.omni_range = 9.0
		parent.add_child(l)
		l.position = pos

static func stone_lantern(parent: Node, at: Vector3, lit := false) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	Build.tbox(root, Vector3(0.9, 0.25, 0.9), Vector3(0, 0.12, 0), "stone", STONE, true)
	Build.tcyl(root, 0.17, 0.22, 1.1, Vector3(0, 0.8, 0), "stone", STONE, 8)
	Build.tbox(root, Vector3(0.7, 0.12, 0.7), Vector3(0, 1.4, 0), "stone", STONE)
	Build.box(root, Vector3(0.44, 0.42, 0.44), Vector3(0, 1.67, 0), Color(1.0, 0.72, 0.35), false, 1.2)
	for i in 4:
		var a := i * PI / 2.0
		Build.tbox(root, Vector3(0.09, 0.44, 0.09), Vector3(cos(a + PI / 4) * 0.3, 1.67, sin(a + PI / 4) * 0.3), "stone", STONE)
	var cap := Build.tcyl(root, 0.0, 0.62, 0.42, Vector3(0, 2.1, 0), "stone", STONE, 4)
	cap.rotation.y = PI / 4.0
	Build.tsphere(root, 0.09, Vector3(0, 2.36, 0), "stone", STONE)
	if lit:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 1.2
		l.omni_range = 7.0
		root.add_child(l)
		l.position = Vector3(0, 1.7, 0)

## The club banner on a pole.
static func banner(parent: Node, at: Vector3, yaw: float, height := 5.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	Build.tcyl(root, 0.06, 0.08, height, Vector3(0, height / 2.0, 0), "darkwood", Color.WHITE, 6)
	Build.tbox(root, Vector3(1.3, 0.07, 0.07), Vector3(0.55, height - 0.2, 0), "darkwood")
	Build.sphere(root, 0.1, Vector3(0, height + 0.05, 0), Color(0.93, 0.72, 0.28), 0.5)
	quad(root, Vector2(1.0, 2.5), Vector3(0.6, height - 1.5, 0), 0.0, "ui/banner.png", true, 0.0, true)

## A hall on a stone plinth: lacquered posts, plaster walls, lattice windows, tiled roof.
## The door is on the +Z side. `style` is "red" (Rhodes) or "plain" (villages).
static func house(parent: Node, pos: Vector3, yaw: float, w: float, d: float, style := "red", lanterns := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var post_tex := "lacquer" if style == "red" else "darkwood"
	var wall := CREAM if style == "red" else Color(0.82, 0.76, 0.64)
	var tile := Color.WHITE if style == "red" else Color(1.0, 0.82, 0.68)
	var y0 := 0.45
	var h := 3.0
	Build.tbox(root, Vector3(w + 1.5, y0, d + 1.5), Vector3(0, y0 / 2.0, 0), "stone", STONE, true, 0.5)
	Build.tbox(root, Vector3(2.4, y0 / 2.0, 0.8), Vector3(0, y0 / 4.0, d / 2.0 + 1.1), "stone", STONE, true, 0.5)
	Build.tbox(root, Vector3(w, h, d), Vector3(0, y0 + h / 2.0, 0), "plaster", wall, true, 0.3)
	Build.tbox(root, Vector3(w + 0.08, 0.9, d + 0.08), Vector3(0, y0 + 0.45, 0), "darkwood", Color.WHITE, false, 0.5)
	Build.tbox(root, Vector3(w + 0.34, 0.3, d + 0.34), Vector3(0, y0 + h - 0.15, 0), post_tex, Color.WHITE, false, 0.5)
	# Posts at the corners and along the long sides.
	var nx: int = max(1, int(round(w / 2.4)))
	for i in nx + 1:
		var x := -w / 2.0 + w * i / nx
		for sz in [-1.0, 1.0]:
			Build.tcyl(root, 0.16, 0.18, h, Vector3(x, y0 + h / 2.0, sz * (d / 2.0 + 0.08)), post_tex, Color.WHITE, 8, false, 0.6)
	# Door and windows.
	quad(root, Vector2(1.5, 2.3), Vector3(0, y0 + 1.15, d / 2.0 + 0.05), 0.0, "tex/door.jpg")
	for sx in [-1.0, 1.0]:
		if w >= 5.5:
			quad(root, Vector2(1.3, 1.2), Vector3(sx * (w / 2.0 - 1.25), y0 + 1.95, d / 2.0 + 0.05), 0.0, "tex/lattice.jpg", false, 0.35)
		quad(root, Vector2(1.5, 1.2), Vector3(sx * (w / 2.0 + 0.05), y0 + 1.95, 0), sx * PI / 2.0, "tex/lattice.jpg", false, 0.35)
	quad(root, Vector2(1.5, 1.2), Vector3(0, y0 + 1.95, -d / 2.0 - 0.05), PI, "tex/lattice.jpg", false, 0.35)
	# Roof and the gable walls under it.
	var rise := 1.7 + d * 0.16
	roof(root, w, d, Vector3(0, y0 + h, 0), rise, 1.3, tile)
	for sx in [-1.0, 1.0]:
		Build.tbox(root, Vector3(0.14, rise * 0.62, d * 0.46), Vector3(sx * (w / 2.0 - 0.1), y0 + h + rise * 0.31, 0), "plaster", wall, false, 0.3)
		Build.tbox(root, Vector3(0.16, rise * 0.3, d * 0.2), Vector3(sx * (w / 2.0 - 0.1), y0 + h + rise * 0.72, 0), "plaster", wall, false, 0.3)
	if lanterns:
		for sx in [-1.0, 1.0]:
			paper_lantern(root, Vector3(sx * (w / 2.0 - 0.3), y0 + h - 0.75, d / 2.0 + 0.85))
	return root

## A ceremonial gate: two great posts, a tiled lintel, the club crest, lanterns.
static func gate(parent: Node, at: Vector3, yaw: float, width := 7.0, crest := true) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	var hw := width / 2.0
	for sx in [-1.0, 1.0]:
		Build.tbox(root, Vector3(1.0, 0.7, 1.0), Vector3(sx * hw, 0.35, 0), "stone", STONE, true, 0.5)
		Build.tcyl(root, 0.26, 0.3, 6.2, Vector3(sx * hw, 3.6, 0), "lacquer", Color.WHITE, 10, true, 0.6)
		paper_lantern(root, Vector3(sx * (hw - 0.9), 4.2, 0), true, 1.2)
	Build.tbox(root, Vector3(width + 2.4, 0.45, 0.5), Vector3(0, 5.15, 0), "lacquer", Color.WHITE, false, 0.6)
	Build.tbox(root, Vector3(width + 1.2, 0.4, 0.45), Vector3(0, 6.2, 0), "lacquer", Color.WHITE, false, 0.6)
	Build.tbox(root, Vector3(2.2, 0.7, 0.2), Vector3(0, 5.68, 0), "darkwood")
	if crest:
		for sz in [-1.0, 1.0]:
			quad(root, Vector2(0.9, 0.9), Vector3(0, 5.68, sz * 0.11), 0.0 if sz > 0 else PI, "ui/emblem.png", true, 0.3)
	roof(root, width + 2.0, 1.2, Vector3(0, 6.45, 0), 0.9, 0.8)

## A stone guardian lion, seated, facing +Z, with a red sash.
static func lion(parent: Node, at: Vector3, yaw: float, s := 1.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	root.scale = Vector3(s, s, s)
	var c := Color(0.72, 0.72, 0.68)
	Build.tbox(root, Vector3(1.7, 0.9, 2.3), Vector3(0, 0.45, 0), "stone", STONE, true, 0.6)
	Build.tbox(root, Vector3(1.9, 0.16, 2.5), Vector3(0, 0.95, 0), "stone", STONE, false, 0.6)
	var body := Build.tsphere(root, 0.58, Vector3(0, 1.72, -0.28), "rock", c, 0.9)
	body.scale = Vector3(1.0, 1.1, 1.35)
	Build.tsphere(root, 0.52, Vector3(0, 1.98, 0.32), "rock", c, 0.9)
	for sx in [-1.0, 1.0]:
		Build.tsphere(root, 0.4, Vector3(sx * 0.44, 1.42, -0.5), "rock", c, 0.9)
		Build.tcyl(root, 0.15, 0.19, 0.95, Vector3(sx * 0.3, 1.48, 0.66), "rock", c, 8, false, 0.9)
		Build.tsphere(root, 0.22, Vector3(sx * 0.3, 1.14, 0.8), "rock", c, 0.9)
		Build.tsphere(root, 0.13, Vector3(sx * 0.34, 3.02, 0.42), "rock", c, 0.9)
		Build.sphere(root, 0.06, Vector3(sx * 0.19, 2.72, 0.93), Color(0.08, 0.08, 0.08))
	Build.tsphere(root, 0.28, Vector3(0.3, 1.22, 1.0), "rock", c * 0.85, 0.9)
	Build.tsphere(root, 0.47, Vector3(0, 2.62, 0.52), "rock", c, 0.9)
	Build.tbox(root, Vector3(0.46, 0.3, 0.36), Vector3(0, 2.5, 0.94), "rock", c, false, 0.9)
	Build.tbox(root, Vector3(0.5, 0.1, 0.3), Vector3(0, 2.8, 0.88), "rock", c, false, 0.9)
	Build.box(root, Vector3(0.3, 0.07, 0.06), Vector3(0, 2.4, 1.13), Color(0.1, 0.08, 0.08))
	# Mane: rows of curls round the head and down the back of the neck.
	for i in 11:
		var a := -0.5 + i * (PI + 1.0) / 10.0
		Build.tsphere(root, 0.2, Vector3(cos(a) * 0.52, 2.6 + sin(a) * 0.5, 0.38), "rock", c, 0.9)
		Build.tsphere(root, 0.19, Vector3(cos(a) * 0.46, 2.52 + sin(a) * 0.44, 0.1), "rock", c, 0.9)
	for i in 4:
		Build.tsphere(root, 0.2, Vector3(0, 2.75 - i * 0.26, -0.12 - i * 0.14), "rock", c, 0.9)
	Build.tsphere(root, 0.24, Vector3(0, 1.95, -1.0), "rock", c, 0.9)
	# Sash.
	var sash := Build.tcyl(root, 0.5, 0.56, 0.16, Vector3(0, 2.22, 0.36), "cloth", Color.WHITE, 12)
	sash.rotation.x = 0.35
	Build.tsphere(root, 0.15, Vector3(0, 2.1, 0.92), "cloth")
	quad(root, Vector2(0.24, 0.5), Vector3(0.08, 1.8, 0.93), 0.0, "tex/cloth.jpg", false, 0.0, true)

## An arched footbridge with red rails, from `a` to `b`.
static func bridge(parent: Node, a: Vector3, b: Vector3, width := 3.2, arch := 1.8) -> void:
	var n := 12
	var dir := (b - a)
	var side := Vector3(-dir.z, 0, dir.x).normalized()
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3(0, sin(t * PI) * arch, 0)
		var mid := (prev + p) / 2.0
		var seg := p - prev
		var deck := Build.tbox(parent, Vector3(seg.length() + 0.1, 0.22, width), mid, "planks", Color(0.6, 0.48, 0.4), true)
		deck.look_at_from_position(mid, mid + seg, Vector3.UP)
		deck.rotate_object_local(Vector3.UP, PI / 2.0)
		for sgn in [-1.0, 1.0]:
			var edge: Vector3 = mid + side * sgn * (width / 2.0 - 0.1)
			var rail := Build.tbox(parent, Vector3(seg.length() + 0.1, 0.12, 0.12), edge + Vector3(0, 1.0, 0), "lacquer", Color.WHITE, true)
			rail.look_at_from_position(edge + Vector3(0, 1.0, 0), edge + Vector3(0, 1.0, 0) + seg, Vector3.UP)
			rail.rotate_object_local(Vector3.UP, PI / 2.0)
			Build.tcyl(parent, 0.09, 0.09, 1.25, p + side * sgn * (width / 2.0 - 0.1) + Vector3(0, 0.55, 0), "lacquer", Color.WHITE, 6)
		prev = p

## A clump of bamboo.
static func bamboo(parent: Node, at: Vector3, stalks := 7) -> void:
	var green := Color(0.42, 0.56, 0.24)
	for i in stalks:
		var p := at + Vector3(randf_range(-1.1, 1.1), 0, randf_range(-1.1, 1.1))
		var h := randf_range(5.0, 8.5)
		var stalk := Build.cyl(parent, 0.045, 0.07, h, p + Vector3(0, h / 2.0, 0), green, 5)
		stalk.rotation = Vector3(randf_range(-0.07, 0.07), 0, randf_range(-0.07, 0.07))
		for j in 3:
			var leaf := Build.cyl(parent, 0.0, randf_range(0.5, 0.8), randf_range(1.2, 1.8), p + Vector3(randf_range(-0.2, 0.2), h * (0.62 + j * 0.15), randf_range(-0.2, 0.2)), Color(0.3, 0.48, 0.18), 5)
			leaf.scale = Vector3(1.0, 1.0, 0.45)
			leaf.rotation.y = randf() * TAU

## A long table with two benches.
static func table_set(parent: Node, at: Vector3, yaw: float, length := 2.6) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = yaw
	Build.tbox(root, Vector3(length, 0.1, 0.9), Vector3(0, 0.78, 0), "darkwood", Color.WHITE, true)
	for sx in [-1.0, 1.0]:
		Build.tbox(root, Vector3(0.12, 0.74, 0.8), Vector3(sx * (length / 2.0 - 0.25), 0.37, 0), "darkwood")
	for sz in [-1.0, 1.0]:
		Build.tbox(root, Vector3(length * 0.9, 0.08, 0.32), Vector3(0, 0.45, sz * 0.85), "planks", Color(0.5, 0.4, 0.32))
		for sx in [-1.0, 1.0]:
			Build.tbox(root, Vector3(0.1, 0.42, 0.28), Vector3(sx * length * 0.38, 0.21, sz * 0.85), "darkwood")
