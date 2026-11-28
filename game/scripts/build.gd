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

# --- Textured materials and imported models ---------------------------------------

static var _tmats := {}
static var _scenes := {}

## A world-space (triplanar) textured material, so any box or cylinder tiles correctly.
static func tmat(tex: String, tint := Color.WHITE, scale := 0.4) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex, tint.to_html(), scale]
	if _tmats.has(key):
		return _tmats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s.jpg" % tex)
	m.albedo_color = tint
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	var n := "res://assets/tex/%s_n.jpg" % tex
	if ResourceLoader.exists(n):
		m.normal_enabled = true
		m.normal_texture = load(n)
		m.normal_scale = 1.2
	_tmats[key] = m
	return m

static func tbox(parent: Node, size: Vector3, pos: Vector3, tex: String, tint := Color.WHITE, solid := false, scale := 0.4) -> MeshInstance3D:
	var mi := box(parent, size, pos, Color.WHITE, solid)
	mi.material_override = tmat(tex, tint, scale)
	return mi

static func tcyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, tex: String, tint := Color.WHITE, sides := 10, solid := false, scale := 0.4) -> MeshInstance3D:
	var mi := cyl(parent, r_top, r_bot, h, pos, Color.WHITE, sides, solid)
	mi.material_override = tmat(tex, tint, scale)
	return mi

static func tsphere(parent: Node, r: float, pos: Vector3, tex: String, tint := Color.WHITE, scale := 0.4) -> MeshInstance3D:
	var mi := sphere(parent, r, pos, Color.WHITE)
	mi.material_override = tmat(tex, tint, scale)
	return mi

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load("res://assets/" + path + ".gltf")
	return _scenes[path]

static func model(parent: Node, path: String, pos := Vector3.ZERO, yaw := 0.0, s := 1.0) -> Node3D:
	var n: Node3D = scene(path).instantiate()
	parent.add_child(n)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3(s, s, s)
	return n

## Leaves and grass: cut-out transparency, visible from both sides.
static func foliage(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.mesh.surface_get_material(i)
			if m and m.albedo_texture and m.albedo_texture.resource_path.ends_with(".png") and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.45
				m.cull_mode = BaseMaterial3D.CULL_DISABLED

## A house put together from the village kit: 2 m wall pieces round a w x d footprint
## (w is 4 or 6, d is 6 or 8), a tiled roof, a door on the front (+Z) and windows.
static func kit_house(parent: Node, pos: Vector3, yaw: float, w: int, d: int, brick := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = yaw
	var kind := "UnevenBrick" if brick else "Plaster"
	var plain := "village/Wall_%s_Straight" % kind
	var window := "village/Wall_%s_Window_Wide_Flat" % kind
	var door := "village/Wall_%s_Door_Flat" % kind
	var hw := w / 2.0
	var hd := d / 2.0
	var nx := int(w / 2.0)
	var nz := int(d / 2.0)
	for i in nx:
		var x := -hw + 1.0 + i * 2.0
		var is_door := i == int(nx / 2.0)
		model(root, door if is_door else window, Vector3(x, 0, hd), 0.0)
		if is_door:
			model(root, "village/Door_1_Flat", Vector3(x - 0.52, 0, hd - 0.1), 0.0)
		else:
			_window(root, Vector3(x, 0, hd), 0.0)
		model(root, plain if nx > 2 and i != 1 else ("village/Wall_Plaster_WoodGrid" if not brick else plain), Vector3(x, 0, -hd), PI)
	for j in nz:
		var z := -hd + 1.0 + j * 2.0
		var win := j % 2 == 1
		model(root, window if win else plain, Vector3(hw, 0, z), PI / 2.0)
		if win:
			_window(root, Vector3(hw, 0, z), PI / 2.0)
		model(root, plain, Vector3(-hw, 0, z), -PI / 2.0)
	var corner := "village/Corner_Exterior_Brick" if brick else "village/Corner_Exterior_Wood"
	model(root, corner, Vector3(hw, 0, hd), 0.0)
	model(root, corner, Vector3(-hw, 0, hd), -PI / 2.0)
	model(root, corner, Vector3(-hw, 0, -hd), PI)
	model(root, corner, Vector3(hw, 0, -hd), PI / 2.0)
	model(root, "village/Roof_Front_Brick%d" % w, Vector3(0, 3.0, hd), 0.0)
	model(root, "village/Roof_Front_Brick%d" % w, Vector3(0, 3.0, -hd), PI)
	model(root, "village/Roof_RoundTiles_%dx%d" % [w, d], Vector3(0, 3.0, 0), 0.0)
	model(root, "village/Prop_Chimney", Vector3(hw - 1.3, 3.0 + (hw - 1.3) * 0.45, -hd * 0.4), 0.0)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w + 0.4, 6.0, d + 0.4)
	cs.shape = sh
	sb.add_child(cs)
	root.add_child(sb)
	sb.position.y = 3.0
	return root

static func _window(root: Node, at: Vector3, yaw: float) -> void:
	model(root, "village/Window_Wide_Flat1", at, yaw)
	model(root, "village/WindowShutters_Wide_Flat_Open", at, yaw)

static func tree(parent: Node, pos: Vector3, s: float, dark := false) -> void:
	var trunk := Color(0.26, 0.19, 0.13)
	var leaf := Color(0.13, 0.27, 0.16) if not dark else Color(0.1, 0.17, 0.14)
	cyl(parent, 0.14 * s, 0.22 * s, 2.0 * s, pos + Vector3(0, 1.0 * s, 0), trunk, 6, true)
	cyl(parent, 0.0, 1.5 * s, 3.2 * s, pos + Vector3(0, 3.2 * s, 0), leaf, 7)
	cyl(parent, 0.0, 1.1 * s, 2.4 * s, pos + Vector3(0, 4.6 * s, 0), leaf, 7)
