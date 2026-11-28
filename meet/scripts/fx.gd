extends RefCounted
## Short-lived effects: blood, dust, stains on the ground, a flash on what was hit.

static var _stain_mat: StandardMaterial3D
static var _flash := {}

## A burst where a blow landed. Living people bleed; the Pinned shed dark ash.
static func burst(world: Node, at: Vector3, away: Vector3, living := true, amount := 18) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.6
	p.direction = (away + Vector3(0, 0.6, 0)).normalized()
	p.spread = 38.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.035
	m.height = 0.07
	m.radial_segments = 4
	m.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.02, 0.02) if living else Color(0.04, 0.04, 0.06)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	world.add_child(p)
	p.global_position = at
	p.emitting = true
	world.get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## Blood left on the ground. It fades after a couple of minutes.
static func stain(world: Node, at: Vector3, size := 0.5) -> void:
	if _stain_mat == null:
		_stain_mat = StandardMaterial3D.new()
		_stain_mat.albedo_color = Color(0.32, 0.02, 0.02, 0.85)
		_stain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stain_mat.roughness = 0.4
	for i in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = size * randf_range(0.3, 0.7)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.004
		cm.radial_segments = 7
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = _stain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		mi.global_position = at + Vector3(randf_range(-size, size) * 0.6, 0.03 + i * 0.002, randf_range(-size, size) * 0.6)
		mi.scale = Vector3(randf_range(0.7, 1.4), 1, randf_range(0.7, 1.4))
		world.get_tree().create_timer(150.0).timeout.connect(mi.queue_free)

static func _overlay(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _flash.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash[key] = m
	return _flash[key]

## Tint a whole figure for a moment (a hit), or leave a lasting tint (wounds).
static func tint(figure: Node3D, c: Color, seconds := 0.12, after := Color(0, 0, 0, 0)) -> void:
	var meshes := figure.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		mi.material_overlay = _overlay(c)
	if seconds > 0.0:
		figure.get_tree().create_timer(seconds).timeout.connect(func():
			if is_instance_valid(figure):
				for mi in figure.find_children("*", "MeshInstance3D", true, false):
					mi.material_overlay = _overlay(after) if after.a > 0.0 else null)

## A health bar as text, for showing above something that has been hurt.
static func bar(frac: float) -> String:
	var n: int = clamp(int(round(frac * 10.0)), 0, 10)
	return "█".repeat(n) + "░".repeat(10 - n)
