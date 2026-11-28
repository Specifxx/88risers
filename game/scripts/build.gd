extends RefCounted
## Helpers for building the low-poly world out of primitive shapes.

static var _mats := {}

static func mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	if glow > 0.0:
		m.albedo_color = c * 0.3
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = min(glow, 1.5) * 0.75
	_mats[key] = m
	return m

static func mesh(parent: Node, m: Mesh, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c, glow)
	parent.add_child(mi)
	mi.position = pos
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, c: Color, solid := false, glow := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := mesh(parent, bm, pos, c, glow)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, sides := 10, solid := false) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	var mi := mesh(parent, cm, pos, c)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = max(r_top, r_bot)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

static func sphere(parent: Node, r: float, pos: Vector3, c: Color, glow := 0.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return mesh(parent, sm, pos, c, glow)

static func label(parent: Node, text: String, y: float, c := Color(1, 0.95, 0.8), size := 40) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = c
	l.outline_modulate = Color(0, 0, 0, 0.85)
	parent.add_child(l)
	l.position = Vector3(0, y, 0)
	return l

## A simple standing figure: body, head, and a name floating above.
static func person(parent: Node, body: Color, skin := Color(0.82, 0.66, 0.52)) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	cyl(root, 0.2, 0.4, 1.35, Vector3(0, 0.68, 0), body, 8)
	box(root, Vector3(0.62, 0.2, 0.3), Vector3(0, 1.32, 0), body)
	for sx in [-1.0, 1.0]:
		var arm := cyl(root, 0.07, 0.08, 0.75, Vector3(sx * 0.36, 0.98, 0.03), body.darkened(0.15), 6)
		arm.rotation.z = sx * 0.12
		sphere(root, 0.07, Vector3(sx * 0.4, 0.6, 0.03), skin)
	box(root, Vector3(0.84, 0.09, 0.84), Vector3(0, 0.74, 0), body.darkened(0.45))
	sphere(root, 0.2, Vector3(0, 1.62, 0), skin)
	var hair := sphere(root, 0.21, Vector3(0, 1.67, -0.035), Color(0.1, 0.08, 0.07))
	hair.scale = Vector3(1.0, 0.85, 1.0)
	return root

static func house(parent: Node, pos: Vector3, size: Vector3, wall: Color, roof: Color, yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	box(root, size, Vector3(0, size.y / 2.0, 0), wall, true)
	var r := cyl(root, 0.0, max(size.x, size.z) * 0.78, 2.2, Vector3(0, size.y + 1.1, 0), roof, 4)
	r.rotation.y = PI / 4.0
	box(root, Vector3(0.9, 1.8, 0.1), Vector3(0, 0.9, size.z / 2.0 + 0.03), Color(0.22, 0.15, 0.1))
	return root

static func tree(parent: Node, pos: Vector3, s: float, dark := false) -> void:
	var trunk := Color(0.26, 0.19, 0.13)
	var leaf := Color(0.13, 0.27, 0.16) if not dark else Color(0.1, 0.17, 0.14)
	cyl(parent, 0.14 * s, 0.22 * s, 2.0 * s, pos + Vector3(0, 1.0 * s, 0), trunk, 6, true)
	cyl(parent, 0.0, 1.5 * s, 3.2 * s, pos + Vector3(0, 3.2 * s, 0), leaf, 7)
	cyl(parent, 0.0, 1.1 * s, 2.4 * s, pos + Vector3(0, 4.6 * s, 0), leaf, 7)
