extends RefCounted
## Builds an animated person from the model packs: an outfit, a head, hair, and the shared animations.

const DIR := "res://assets/chars/"
const LOOPING := ["Idle", "Idle_Talking", "Walk", "Jog_Fwd", "Sitting_Idle", "Sword_Idle", "Crouch_Idle"]

static var _anims: AnimationLibrary
static var _cache := {}

static func _scene(name: String) -> PackedScene:
	if not _cache.has(name):
		_cache[name] = load(DIR + name)
	return _cache[name]

static func animations() -> AnimationLibrary:
	if _anims == null:
		var src: Node = _scene("UAL1_Standard.glb").instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		_anims = ap.get_animation_library("").duplicate()
		for n in LOOPING:
			if _anims.has_animation(n):
				_anims.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		src.free()
	return _anims

## spec: body (Male_Peasant, Female_Peasant, Male_Ranger, Female_Ranger), hair, beard, hood,
## cloth (alternative outfit texture), tint (multiplies the outfit colour), light (lighter skin).
static func make(parent: Node, spec: Dictionary) -> Node3D:
	var body: String = spec.get("body", "Male_Peasant")
	var male := body.begins_with("Male")
	var root: Node3D = _scene(body + ".gltf").instantiate()
	parent.add_child(root)
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false)

	for mi in skel.get_children():
		if not mi is MeshInstance3D:
			continue
		if String(mi.name).contains("Hood") and not spec.get("hood", false):
			mi.visible = false
		for s in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.mesh.surface_get_material(s)
			if m == null:
				continue
			var skin := m.resource_name.contains("Regular") or (m.albedo_texture and m.albedo_texture.resource_path.contains("Regular"))
			var o: BaseMaterial3D = m.duplicate()
			if skin:
				if spec.get("light", false):
					o.albedo_color = Color(1.5, 1.32, 1.2)
			else:
				if spec.has("cloth"):
					o.albedo_texture = load(DIR + String(spec["cloth"]))
				o.albedo_color = spec.get("tint", Color.WHITE)
			if spec.has("shade"):
				o = _shade(spec["shade"])
			mi.set_surface_override_material(s, o)

	var parts: Array = ["Head_Male.gltf" if male else "Head_Female.gltf"]
	if spec.has("hair") and not spec.get("hood", false):
		parts.append(String(spec["hair"]) + ".gltf")
	if spec.get("beard", false):
		parts.append("Hair_Beard.gltf")
	for p in parts:
		var src: Node = _scene(p).instantiate()
		for mi in src.find_children("*", "MeshInstance3D", true, false):
			mi.owner = null
			mi.get_parent().remove_child(mi)
			skel.add_child(mi)
			mi.skeleton = NodePath("..")
			for s in mi.mesh.get_surface_count():
				var m: BaseMaterial3D = mi.mesh.surface_get_material(s)
				if m == null:
					continue
				var o: BaseMaterial3D = m.duplicate()
				if spec.has("shade"):
					o = _shade(spec["shade"])
					if String(mi.name).contains("Eyes"):
						o.emission_enabled = true
						o.emission = Color(1.0, 0.7, 0.25)
						o.emission_energy_multiplier = 2.0
				elif p.begins_with("Head") and m.resource_name.contains("Superhero") and spec.get("light", false):
					o.albedo_texture = load(DIR + ("T_Superhero_Male_Ligh.jpg" if male else "T_Superhero_Female_Light_BaseColor.jpg"))
				elif p.begins_with("Hair") or String(mi.name).contains("Eyebrow"):
					o.albedo_color = spec.get("hair_tint", Color(0.16, 0.12, 0.1))
				mi.set_surface_override_material(s, o)
		src.free()

	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.add_animation_library("", animations())
	ap.playback_default_blend_time = 0.25
	ap.play("Idle")
	ap.seek(randf() * 2.0)
	root.set_meta("anim", ap)
	return root

static func _shade(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static func play(root: Node3D, anim: String) -> void:
	var ap: AnimationPlayer = root.get_meta("anim")
	if ap.current_animation != anim and ap.has_animation(anim):
		ap.play(anim)
