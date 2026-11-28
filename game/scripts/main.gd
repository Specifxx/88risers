extends Node3D
## Builds the slice: Rhodes inside the Ring, the east road, and Tallow Ford.

const Build = preload("res://scripts/build.gd")
const Data = preload("res://scripts/data.gd")
const NpcScript = preload("res://scripts/npc.gd")
const PinnedScript = preload("res://scripts/pinned.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const DialogueScript = preload("res://scripts/dialogue.gd")
const BattleScript = preload("res://scripts/battle.gd")
const Thing = preload("res://scripts/thing.gd")

const TerrainScript = preload("res://scripts/terrain.gd")
const Asia = preload("res://scripts/asia.gd")
const LootScript = preload("res://scripts/loot.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const PropScript = preload("res://scripts/prop.gd")

const R := Game.RING_RADIUS
const ROAD := [Vector3(30, 0, 0), Vector3(70, 0, 0), Vector3(120, 0, -18), Vector3(180, 0, 8), Vector3(228, 0, 20)]
const VILLAGE := Vector3(230, 0, 20)
const GOLD := Color(0.93, 0.72, 0.28)

var terrain: Node3D
var _register_label: Label3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _cloud_mat: ShaderMaterial

func _ready() -> void:
	Game.main = self
	seed(88)
	_sky()
	terrain = TerrainScript.new()
	add_child(terrain)
	terrain.setup(ROAD, VILLAGE, R)
	_rhodes()
	_road()
	_tallow_ford()
	_wilds()
	_people()
	_containers()
	_player_and_ui()
	Game.changed.connect(_on_changed)
	_on_changed()
	if OS.get_cmdline_user_args().has("--selftest"):
		var t: Node = load("res://scripts/selftest.gd").new()
		add_child(t)

func _process(dt: float) -> void:
	if not Game.modal:
		Game.hour = fposmod(Game.hour + dt * 24.0 / 720.0, 24.0)
	_light_for_hour()

## The sun crosses from east to west; nights are blue and lit by lanterns.
func _light_for_hour() -> void:
	var day: float = clamp(sin((Game.hour - 6.0) / 12.0 * PI), -0.25, 1.0)
	var up: float = max(day, 0.0)
	var low: float = 1.0 - smoothstep(0.0, 0.45, up)    # 1 near sunrise and sunset
	_sun.rotation_degrees = Vector3(-8.0 - up * 50.0, -90.0 - (Game.hour - 12.0) * 13.0, 0)
	_sun.light_energy = 0.12 + up * 1.05
	_sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.62, 0.36), low)
	var night: float = 1.0 - smoothstep(-0.1, 0.25, day)
	_env.ambient_light_color = Color(0.62, 0.6, 0.66).lerp(Color(0.2, 0.25, 0.42), night)
	_env.ambient_light_energy = lerp(0.62, 0.42, night)
	_env.fog_light_color = Color(0.66, 0.6, 0.56).lerp(Color(0.95, 0.6, 0.42), low * (1.0 - night)).lerp(Color(0.1, 0.13, 0.22), night)
	if _cloud_mat:
		_cloud_mat.set_shader_parameter("tint", Color(1.0, 0.98, 0.95).lerp(Color(1.0, 0.72, 0.55), low).lerp(Color(0.16, 0.19, 0.3), night))
	_sky_mat.sky_top_color = Color(0.2, 0.34, 0.6).lerp(Color(0.03, 0.05, 0.12), night)
	_sky_mat.sky_horizon_color = Color(0.74, 0.78, 0.84).lerp(Color(0.95, 0.6, 0.38), low).lerp(Color(0.1, 0.13, 0.22), night)

func _on_changed() -> void:
	if _register_label:
		_register_label.text = "THE REGISTER\n%d / %d" % [Game.register_count(), Game.QUOTA]

func height(x: float, z: float) -> float:
	return terrain.height(x, z)

## Move a walker from `from` towards `to` without passing through walls, trees or anything
## else solid. If the straight line is blocked it tries going round; if there is no way, it
## stays put. Returns where the walker ends up.
func walk(from: Vector3, to: Vector3) -> Vector3:
	var step := to - from
	step.y = 0
	var dist := step.length()
	if dist < 0.0001:
		return from
	var space := get_world_3d().direct_space_state
	var chest := Vector3(0, 0.95, 0)
	for turn in [0.0, 0.7, -0.7, 1.35, -1.35]:
		var dir := step.normalized().rotated(Vector3.UP, turn)
		var q := PhysicsRayQueryParameters3D.create(from + chest, ground(from + dir * (dist + 0.5)) + chest)
		if Game.player:
			q.exclude = [Game.player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return ground(from + dir * dist)
	return from

## The same point, dropped onto the ground.
func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.height(p.x, p.z), p.z)

# --- Sky -------------------------------------------------------------------------

func _sky() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	_sky_mat = sm
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.5, 0.42, 0.36)
	sm.ground_bottom_color = Color(0.12, 0.11, 0.1)
	sm.sun_angle_max = 12.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.68)
	env.ambient_light_energy = 0.62
	env.fog_enabled = true
	_env = env
	env.fog_density = 0.0052
	env.fog_sky_affect = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	add_child(sun)
	_sun = sun
	_light_for_hour()
	_mountains()
	_clouds()

## High cloud drifting over, so the sky is never a flat colour.
func _clouds() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;
uniform sampler2D n : repeat_enable, filter_linear_mipmap;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec2 uv = UV * 3.0 + vec2(TIME * 0.004, TIME * 0.0015);
	float c = texture(n, uv).r * 0.65 + texture(n, uv * 2.3 + 0.3).r * 0.35;
	float edge = 1.0 - smoothstep(0.25, 0.5, length(UV - 0.5));
	ALBEDO = tint;
	ALPHA = smoothstep(0.5, 0.78, c) * edge * 0.85;
}
"""
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = sh
	_cloud_mat.set_shader_parameter("n", tex)
	var pm := PlaneMesh.new()
	pm.size = Vector2(5000, 5000)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _cloud_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(100, 380, 0)

## Far peaks on every side, hazed by distance, so the island sits in a larger world.
func _mountains() -> void:
	var mats: Array = []
	for c in [Color(0.56, 0.64, 0.75), Color(0.44, 0.53, 0.63), Color(0.33, 0.42, 0.47)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_fog = true
		mats.append(m)
	for band in 3:
		var count: int = [16, 18, 20][band]
		for i in count:
			var a := TAU * i / count + randf_range(-0.12, 0.12)
			var r: float = [980.0, 760.0, 560.0][band] + randf_range(-50, 50)
			var h: float = [460.0, 300.0, 170.0][band] * randf_range(0.6, 1.15)
			var cm := CylinderMesh.new()
			cm.top_radius = randf_range(2, 14)
			cm.bottom_radius = h * randf_range(0.7, 1.1)
			cm.height = h
			cm.radial_segments = 9
			cm.rings = 1
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = mats[band]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.position = Vector3(100 + cos(a) * r, h / 2.0 - 40.0, sin(a) * r)
			mi.rotation.y = randf() * TAU
			mi.scale = Vector3(randf_range(0.9, 1.7), 1.0, randf_range(0.8, 1.3))

# --- Rhodes --------------------------------------------------------------------

func _rhodes() -> void:
	# The Ring: Wukhan's staff, bent into a circle. One gap, on the east side.
	var iron := Color(0.32, 0.31, 0.33)
	var n := 56
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a, -PI, PI)) < 0.085:
			continue
		var at := Vector3(cos(a) * R, 0, sin(a) * R)
		var seg := Build.tbox(self, Vector3(1.8, 8.0, TAU * R / n + 0.3), at + Vector3(0, 3.5, 0), "iron", iron, true, 0.22)
		seg.rotation.y = -a
		var band := Build.box(self, Vector3(1.95, 0.4, TAU * R / n + 0.3), at + Vector3(0, 6.3, 0), GOLD, false, 0.5)
		band.rotation.y = -a
	for z in [-4.3, 4.3]:
		Build.tbox(self, Vector3(2.6, 10.0, 1.8), Vector3(R, 4.5, z), "iron", iron, true, 0.22)
		Build.sphere(self, 0.65, Vector3(R, 9.9, z), GOLD, 1.2)
	# The east gate, its guardians, and the paved way to the hall.
	Asia.gate(self, Vector3(R - 3.5, 0, 0), PI / 2.0, 6.4)
	Asia.lion(self, Vector3(R - 7.0, 0, -5.2), -PI / 2.0 + 0.25, 1.15)
	Asia.lion(self, Vector3(R - 7.0, 0, 5.2), -PI / 2.0 - 0.25, 1.15)
	Build.tbox(self, Vector3(R - 6.0, 0.06, 4.6), Vector3((R + 6.0) / 2.0, 0.03, 0), "paving", Color(0.72, 0.7, 0.66), false, 0.3)
	Build.tbox(self, Vector3(4.0, 0.06, 24.0), Vector3(15.0, 0.03, -12.0), "paving", Color(0.72, 0.7, 0.66), false, 0.3)
	for x in [12.0, 22.0, 32.0]:
		Asia.banner(self, Vector3(x, 0, -3.4), PI / 2.0, 5.2)
		Asia.banner(self, Vector3(x, 0, 3.4), -PI / 2.0, 5.2)
	for at in [Vector3(8, 0, 3.2), Vector3(8, 0, -3.2), Vector3(27, 0, 3.2), Vector3(-7, 0, 4.5), Vector3(17.5, 0, -18)]:
		Asia.stone_lantern(self, at, at.x == 8.0 and at.z > 0.0)

	# Wukhan, slumped where he fell, sitting with his back to the west of the Ring.
	var w := Node3D.new()
	add_child(w)
	w.position = Vector3(-28, 0, 0)
	var plate := Color(0.62, 0.56, 0.5)
	var rust := Color(0.85, 0.75, 0.7)
	for sz in [-2.7, 2.7]:
		Build.tbox(w, Vector3(16, 2.6, 3.2), Vector3(9, 1.3, sz), "iron", plate, true, 0.18)
		Build.tbox(w, Vector3(2.2, 3.6, 3.2), Vector3(17.6, 1.8, sz), "rust", rust, true, 0.18)
		Build.tbox(w, Vector3(3.4, 3.0, 3.6), Vector3(8.5, 1.5, sz), "rust", rust, false, 0.18)
	Build.tbox(w, Vector3(5.5, 3.2, 9.4), Vector3(0, 1.6, 0), "rust", rust, true, 0.18)
	var torso := Build.tbox(w, Vector3(5.2, 9.5, 8.4), Vector3(-0.2, 7.4, 0), "iron", plate, true, 0.18)
	torso.rotation.z = -0.14
	Build.box(w, Vector3(0.5, 4.6, 1.3), Vector3(3.1, 7.4, 0), Color(0.05, 0.04, 0.04))
	Build.tbox(w, Vector3(3.4, 2.6, 12.6), Vector3(0.6, 11.6, 0), "rust", rust, false, 0.18)
	Build.tsphere(w, 2.7, Vector3(2.3, 14.0, 0), "iron", plate, 0.18)
	Build.tbox(w, Vector3(2.0, 1.6, 2.4), Vector3(4.5, 13.0, 0), "rust", rust, false, 0.18)
	Build.cyl(w, 2.8, 2.8, 0.55, Vector3(2.3, 15.2, 0), GOLD, 14)
	Build.sphere(w, 0.42, Vector3(4.5, 14.5, -1.0), Color(1.0, 0.5, 0.12), 1.2)
	Build.sphere(w, 0.42, Vector3(4.5, 14.5, 1.0), Color(0.07, 0.06, 0.06))
	Build.tbox(w, Vector3(2.3, 8.4, 2.3), Vector3(1.2, 7.2, 6.6), "iron", plate, false, 0.18)
	Build.tbox(w, Vector3(8.5, 2.1, 2.4), Vector3(5.6, 1.05, 7.4), "iron", plate, true, 0.18)
	Build.tbox(w, Vector3(2.3, 8.4, 2.3), Vector3(1.2, 7.2, -6.6), "iron", plate, false, 0.18)
	Build.tbox(w, Vector3(2.4, 2.1, 10.0), Vector3(2.0, 1.05, -11.5), "iron", plate, true, 0.18)
	# The ember, behind the split in his chest.
	Build.sphere(w, 0.9, Vector3(3.0, 7.4, 0), Color(1.0, 0.5, 0.14), 1.4)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.15)
	glow.light_energy = 2.2
	glow.omni_range = 22.0
	w.add_child(glow)
	glow.position = Vector3(5.5, 7.0, 0)
	var wt := Thing.new()
	wt.setup("Listen to Wukhan", _wukhan)
	wt.set_meta("reach", 4.0)
	add_child(wt)
	wt.position = Vector3(-21.5, 0.5, 0)

	# The Register pavilion: red posts under a tiled roof, open on all sides.
	var hall := Vector3(0, 0, -6)
	var timber := Color(0.55, 0.42, 0.32)
	Build.tbox(self, Vector3(12.5, 0.3, 10.5), hall + Vector3(0, 0.15, 0), "stone", Asia.STONE, true, 0.5)
	Build.tbox(self, Vector3(3.0, 0.15, 1.0), hall + Vector3(0, 0.07, 5.7), "stone", Asia.STONE, true, 0.5)
	for dx in [-5.0, 0.0, 5.0]:
		for dz in [-4.0, 4.0]:
			if dx == 0.0 and dz > 0.0:
				continue
			Build.tcyl(self, 0.24, 0.27, 4.4, hall + Vector3(dx, 2.5, dz), "lacquer", Color.WHITE, 10, true, 0.6)
	Build.tbox(self, Vector3(11.0, 0.4, 9.0), hall + Vector3(0, 4.5, 0), "lacquer", Color.WHITE, false, 0.6)
	Asia.roof(self, 11.0, 9.0, hall + Vector3(0, 4.7, 0), 3.0, 1.8)
	for sx in [-1.0, 1.0]:
		Asia.paper_lantern(self, hall + Vector3(sx * 4.2, 3.7, 4.6), sx > 0.0, 1.2)
		Asia.lion(self, hall + Vector3(sx * 7.6, 0, 6.0), 0.0, 0.85)
	Build.tbox(self, Vector3(4.4, 2.8, 0.25), hall + Vector3(0, 2.2, -3.6), "darkwood", Color.WHITE, true)
	Build.box(self, Vector3(4.7, 0.2, 0.3), hall + Vector3(0, 3.7, -3.6), GOLD, false, 0.4)
	Asia.quad(self, Vector2(1.5, 1.5), hall + Vector3(0, 5.6, 4.62), 0.0, "ui/emblem.png", true, 0.25)
	_register_label = Label3D.new()
	_register_label.font_size = 64
	_register_label.pixel_size = 0.008
	_register_label.modulate = GOLD
	_register_label.outline_size = 6
	add_child(_register_label)
	_register_label.position = hall + Vector3(0, 2.3, -3.45)
	var rt := Thing.new()
	rt.setup("Read the Register", _read_register)
	add_child(rt)
	rt.position = hall + Vector3(0, 0.9, -3.2)

	# Halls round the inside of the Ring, doors facing the middle.
	for h in [[-14, 26, 7, 5], [3, 32, 6, 4.5], [19, 27, 7, 5], [-8, -32, 6, 4.5], [30, 20, 5.5, 4.5]]:
		var at := Vector3(h[0], 0, h[1])
		Asia.house(self, at, atan2(-at.x, -at.z), h[2], h[3], "red")
	_tavern(Vector3(24, 0, -24))
	# Tommy's stall, a wagon, crates and a fire.
	Build.tbox(self, Vector3(3.2, 1.0, 1.2), Vector3(14, 0.5, -14), "planks", Color(0.7, 0.6, 0.5), true)
	for sx in [-1.5, 1.5]:
		Build.tcyl(self, 0.07, 0.07, 2.6, Vector3(14 + sx, 1.3, -14.5), "wood", timber, 6)
	Build.box(self, Vector3(3.6, 0.08, 1.8), Vector3(14, 2.6, -14), Color(0.2, 0.42, 0.5))
	Build.model(self, "village/Prop_Crate", Vector3(16.4, 0, -13.6), 0.4)
	Build.model(self, "village/Prop_Crate", Vector3(16.2, 0, -15.0), 1.1, 0.8)
	Build.model(self, "village/Prop_Wagon", Vector3(31, 0, -9), 2.2)
	for i in 6:
		Build.tbox(self, Vector3(1.3, 0.16, 0.16), Vector3(20, 0.1 + i * 0.05, 14), "wood", timber).rotation.y = i * 1.05
	Build.sphere(self, 0.35, Vector3(20, 0.4, 14), Color(1.0, 0.5, 0.1), 1.4)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.6, 0.25)
	fire.omni_range = 9.0
	add_child(fire)
	fire.position = Vector3(20, 1.2, 14)

func _wukhan() -> void:
	var n: int = Game.flags.get("wukhan", 0)
	var said := ["PROTECT THE RING.", "PROTECT THE RING.", "PROTECT... THE RING."]
	Game.say("Wukhan: \"%s\"" % said[n % 3])
	Game.flags["wukhan"] = n + 1
	if n == 2:
		Game.note("Wukhan only ever says one thing. The ember in his chest burns behind the split plate.")

func _read_register() -> void:
	Game.say("Above the names, cut deep: \"IF HE FAILS, GATHER THE 88.\"  Below it, %d names, and a great deal of empty board." % Game.register_count())

# --- The road ------------------------------------------------------------------

func _road() -> void:
	# The track itself is worn into the ground by the terrain. Here: what stands along it.
	Build.model(self, "village/Prop_Wagon", ground(Vector3(82, 0, -4.5)), 0.5).rotation.z = 0.5
	Build.model(self, "village/Prop_Crate", ground(Vector3(84.5, 0, -5.4)), 0.8)
	for p in [Vector3(48, 0, 3.4), Vector3(98, 0, -6.2), Vector3(150, 0, -8.5), Vector3(204, 0, 17.5)]:
		Build.tbox(self, Vector3(0.6, 1.5, 0.4), ground(p) + Vector3(0, 0.6, 0), "rock", Color.WHITE, true).rotation.z = randf_range(-0.12, 0.12)

# --- Tallow Ford -----------------------------------------------------------------

func _tallow_ford() -> void:
	for h in [[211, 33, 6, 4.5], [223, 45, 7, 5], [241, 43, 6, 4.5], [253, 24, 6, 4.5], [215, -4, 6, 4.5], [251, 3, 5.5, 4.5]]:
		var at := Vector3(h[0], 0, h[1])
		Asia.house(self, at, atan2(VILLAGE.x - at.x, VILLAGE.z + 2.0 - at.z), h[2], h[3], "plain", h[0] % 2 == 1)
	# Pell's shop, with the strongbox round the back.
	Asia.house(self, Vector3(236, 0, 0), 0.0, 8, 5.5, "plain")
	Build.model(self, "village/Prop_Crate", Vector3(240.6, 0, 3.4), 0.3)
	Build.tbox(self, Vector3(1.1, 0.7, 0.7), Vector3(236, 0.35, -5.4), "lacquer", Color.WHITE, true)
	Build.box(self, Vector3(1.15, 0.12, 0.75), Vector3(236, 0.72, -5.4), GOLD)
	var box := Thing.new()
	box.setup("Steal from Pell's strongbox", _steal)
	add_child(box)
	box.position = Vector3(236, 0.0, -6.0)
	# Well.
	Build.tcyl(self, 1.15, 1.15, 0.9, VILLAGE + Vector3(0, 0.45, 2), "stone", Color.WHITE, 12, true)
	Build.cyl(self, 0.95, 0.95, 0.05, VILLAGE + Vector3(0, 0.75, 2), Color(0.05, 0.08, 0.1), 12)
	for sx in [-1.0, 1.0]:
		Build.tcyl(self, 0.08, 0.08, 2.4, VILLAGE + Vector3(sx, 1.2, 2), "wood", Color(0.5, 0.4, 0.3), 6)
	Build.tbox(self, Vector3(2.4, 0.12, 0.12), VILLAGE + Vector3(0, 2.4, 2), "wood", Color(0.5, 0.4, 0.3))
	# Ivo's pyre.
	for i in 6:
		Build.tbox(self, Vector3(2.6, 0.25, 0.3), Vector3(209, 0.2 + i * 0.24, 6), "wood", Color(0.4, 0.3, 0.25)).rotation.y = i * 0.6
	Build.sphere(self, 0.35, Vector3(209, 1.8, 6), Color(1.0, 0.45, 0.1), 1.4)
	var pyre := OmniLight3D.new()
	pyre.light_color = Color(1.0, 0.55, 0.2)
	pyre.omni_range = 8.0
	add_child(pyre)
	pyre.position = Vector3(209, 2.2, 6)
	# A fence on the Rhodes side, with a gap for the road.
	for i in 16:
		var z := -14.0 + i * 2.06
		if absf(z - 17.5) < 3.2:
			continue
		Build.model(self, "village/Prop_WoodenFence_Single", ground(Vector3(203, 0, z)), PI / 2.0)
	# The old jetty, south along the river.
	var j := ground(Vector3(266, 0, 64))
	Build.tbox(self, Vector3(16, 0.22, 2.4), Vector3(271, max(j.y, -0.6) + 0.5, 64), "planks", Color(0.5, 0.42, 0.36), true)
	for x in [265.0, 270.0, 275.0, 278.5]:
		for dz in [-1.1, 1.1]:
			Build.tcyl(self, 0.14, 0.14, 3.4, Vector3(x, -0.9, 64 + dz), "wood", Color(0.35, 0.28, 0.22), 6)
	Asia.gate(self, Vector3(203, 0, 17.5), PI / 2.0, 5.6, false)
	Build.label(self, "TALLOW FORD", 0, Color(0.9, 0.85, 0.7), 44).position = Vector3(202.6, 4.3, 17.5)
	Asia.stone_lantern(self, Vector3(226.5, 0, 26.5), true)
	Asia.stone_lantern(self, Vector3(239, 0, 8.5), false)
	# The footbridge east over the river, and bamboo along the bank.
	Asia.bridge(self, Vector3(266, 0.05, 20), Vector3(304, 0.3, 20), 3.2, 2.4)
	for i in 16:
		var bz := -70.0 + i * 13.0 + randf_range(-3, 3)
		if absf(bz - 20.0) < 9.0 or absf(bz - 64.0) < 7.0:
			continue
		Asia.bamboo(self, ground(Vector3(268.0 + randf_range(-3, 3) + sin(bz * 0.02) * 6.0, 0, bz)), 5 + randi() % 4)

func _steal() -> void:
	if Game.flags.has("stolen"):
		Game.say("The strongbox is empty. You emptied it.")
		return
	Game.flags["stolen"] = true
	Game.coins += 30
	Game.straps += 2
	var seen := Game.deed("theft", -0.9, 2.5, Vector3(236, 0, -6.0), "tallow", "strongbox", 11.0)
	if seen.size() > 0:
		Game.say("%s saw you with your hands in the strongbox. Thirty coin and two straps, and they will tell the others." % seen[0].npc_name)
	else:
		Game.say("Thirty coin and two straps. Nobody saw. Pell will find it empty, and wonder.")
	for n in Game.npcs:
		if n.id == "pell" and n.alive and not seen.has(n):
			# He did not see who, so he suspects the stranger without being sure.
			n.mind.experience("theft", -0.5, 1.2, false, "")
	Game.note("You robbed Pell's strongbox at Tallow Ford.")
	Game.touch()

# --- Trees, rocks and grass ------------------------------------------------------

func _wilds() -> void:
	var pines := ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
	var leafy := ["CommonTree_1", "CommonTree_2", "CommonTree_3"]
	var dead := ["DeadTree_1", "DeadTree_2", "DeadTree_3"]
	var small := ["Fern_1", "Plant_1", "Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_1", "Mushroom_Common", "Flower_3_Group"]
	var trunks := StaticBody3D.new()
	add_child(trunks)
	# The stand of pines the road bends round.
	for i in 30:
		_plant(pines[i % 5], Vector3(118 + randf_range(-18, 18), 0, 10 + randf_range(-12, 16)), randf_range(0.9, 1.5), trunks)
	var placed := 0
	var tries := 0
	while placed < 330 and tries < 6000:
		tries += 1
		var p := Vector3(randf_range(-150, 330), 0, randf_range(-190, 200))
		if Vector2(p.x, p.z).length() < R + 6.0:
			continue
		if terrain.road_distance(p.x, p.z) < 6.0 or p.distance_to(VILLAGE) < 34.0 or absf(p.x - 284.0) < 16.0:
			continue
		var roll := randf()
		# Woodland thickens away from the road; near where the Pinned walk, the trees are dead.
		var haunted := false
		for e in Data.ROAD_PINNED:
			if p.distance_to(e[1]) < 20.0:
				haunted = true
		if haunted and roll < 0.75:
			_plant(dead[randi() % 3] if roll > 0.12 else "TwistedTree_%d" % (1 + randi() % 2), p, randf_range(0.8, 1.3), trunks)
		elif roll < 0.42:
			_plant(pines[randi() % 5], p, randf_range(0.8, 1.6), trunks)
		elif roll < 0.62:
			_plant(leafy[randi() % 3], p, randf_range(0.8, 1.4), trunks)
		elif roll < 0.68:
			_plant(dead[randi() % 3], p, randf_range(0.8, 1.2), trunks)
		else:
			_plant(small[randi() % small.size()], p, randf_range(0.8, 1.8), null)
		placed += 1
	for p in [Vector3(244, 0, 31), Vector3(218, 0, 22), Vector3(229, 0, 52), Vector3(258, 0, 12), Vector3(-10, 0, 14), Vector3(10, 0, 18), Vector3(33, 0, -8), Vector3(8, 0, -22)]:
		_cherry(p, randf_range(0.8, 1.1))
	_grass("Grass_Common_Tall", 1500)
	_grass("Grass_Wispy_Tall", 900)
	_grass("Grass_Common_Short", 1500)

func _plant(model_name: String, p: Vector3, s: float, trunks: StaticBody3D) -> void:
	var g := ground(p)
	var m := Build.model(self, "nature/" + model_name, g - Vector3(0, 0.08, 0), randf() * TAU, s)
	Build.foliage(m)
	if trunks:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.35 * s
		sh.height = 4.0
		cs.shape = sh
		trunks.add_child(cs)
		cs.position = g + Vector3(0, 2.0, 0)

func _cherry(p: Vector3, sc: float) -> void:
	var m := Build.model(self, "nature/CommonTree_%d" % (1 + randi() % 3), ground(p) - Vector3(0, 0.08, 0), randf() * TAU, sc)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat: BaseMaterial3D = mi.mesh.surface_get_material(i)
			if mat and mat.albedo_texture and mat.albedo_texture.resource_path.contains("Leaves"):
				var pink: BaseMaterial3D = mat.duplicate()
				pink.albedo_texture = load("res://assets/nature/Leaves_Cherry.png")
				pink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				pink.alpha_scissor_threshold = 0.45
				pink.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, pink)
	var petals := CPUParticles3D.new()
	petals.amount = 14
	petals.lifetime = 7.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	petals.emission_sphere_radius = 2.6 * sc
	petals.direction = Vector3(0.6, -1, 0.2)
	petals.spread = 25.0
	petals.gravity = Vector3(0.25, -0.5, 0.1)
	petals.initial_velocity_min = 0.2
	petals.initial_velocity_max = 0.7
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	var pq := QuadMesh.new()
	pq.size = Vector2(0.09, 0.06)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(1.0, 0.76, 0.84)
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pq.material = pmat
	petals.mesh = pq
	add_child(petals)
	petals.position = ground(p) + Vector3(0, 4.6 * sc, 0)

## The tavern: a long hall you can walk into, with tables, lanterns and the arm wrestling table.
func _tavern(at: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
	t.position = at
	t.rotation.y = atan2(-at.x, -at.z)
	var w := 13.0
	var d := 9.0
	var h := 3.6
	Build.tbox(t, Vector3(w + 1.6, 0.3, d + 1.6), Vector3(0, 0.15, 0), "stone", Asia.STONE, true, 0.5)
	Build.tbox(t, Vector3(w, 0.06, d), Vector3(0, 0.33, 0), "planks", Color(0.5, 0.4, 0.33), false, 0.5)
	Build.tbox(t, Vector3(3.2, 0.15, 1.0), Vector3(0, 0.07, d / 2.0 + 1.2), "stone", Asia.STONE, true, 0.5)
	# Walls, with a wide doorway in the front.
	Build.tbox(t, Vector3(w, h, 0.3), Vector3(0, 0.3 + h / 2.0, -d / 2.0), "plaster", Asia.CREAM, true, 0.3)
	for sx in [-1.0, 1.0]:
		Build.tbox(t, Vector3(0.3, h, d), Vector3(sx * w / 2.0, 0.3 + h / 2.0, 0), "plaster", Asia.CREAM, true, 0.3)
		Build.tbox(t, Vector3(w / 2.0 - 1.5, h, 0.3), Vector3(sx * (w / 4.0 + 0.75), 0.3 + h / 2.0, d / 2.0), "plaster", Asia.CREAM, true, 0.3)
		Asia.quad(t, Vector2(2.2, 1.4), Vector3(sx * (w / 4.0 + 0.75), 2.4, d / 2.0 + 0.17), 0.0, "tex/lattice.jpg", false, 0.4)
		Asia.quad(t, Vector2(2.2, 1.4), Vector3(sx * (w / 4.0 + 0.75), 2.4, d / 2.0 - 0.17), PI, "tex/lattice.jpg", false, 0.4)
		Asia.paper_lantern(t, Vector3(sx * 1.9, 3.3, d / 2.0 + 0.7), false, 1.1)
	Build.tbox(t, Vector3(3.2, 0.5, 0.34), Vector3(0, h + 0.05, d / 2.0), "lacquer", Color.WHITE, false, 0.6)
	Build.tbox(t, Vector3(w + 0.1, 1.0, d + 0.1), Vector3(0, 0.8, 0), "darkwood", Color.WHITE, false, 0.5).visible = false
	for i in 5:
		var x := -w / 2.0 + w * i / 4.0
		for sz in [-1.0, 1.0]:
			Build.tcyl(t, 0.18, 0.2, h, Vector3(x, 0.3 + h / 2.0, sz * (d / 2.0 + 0.22)), "lacquer", Color.WHITE, 8, false, 0.6)
		Build.tbox(t, Vector3(0.22, 0.26, d), Vector3(x, h + 0.2, 0), "darkwood")
	Asia.roof(t, w, d, Vector3(0, 0.3 + h, 0), 3.2, 1.6)
	Asia.quad(t, Vector2(1.3, 3.2), Vector3(0, 2.4, -d / 2.0 + 0.2), 0.0, "ui/banner.png", true)
	Asia.quad(t, Vector2(1.6, 1.6), Vector3(0, h + 1.2, d / 2.0 + 1.75), 0.0, "ui/emblem.png", true, 0.3)
	# Inside.
	Asia.table_set(t, Vector3(-4.2, 0.36, -2.2), 0.0)
	Asia.table_set(t, Vector3(4.2, 0.36, -2.2), 0.0)
	Asia.table_set(t, Vector3(-4.3, 0.36, 1.6), PI / 2.0, 2.2)
	Build.tbox(t, Vector3(1.3, 0.12, 0.8), Vector3(0, 1.08, 0.2), "darkwood", Color.WHITE, true)
	Build.tbox(t, Vector3(0.9, 0.72, 0.5), Vector3(0, 0.7, 0.2), "darkwood")
	for sx in [-1.0, 1.0]:
		Build.tcyl(t, 0.05, 0.05, 0.16, Vector3(sx * 0.52, 1.22, 0.2), "iron", Color(0.6, 0.6, 0.6), 6)
		Build.tbox(t, Vector3(0.3, 0.05, 0.3), Vector3(sx * 0.3, 1.16, 0.2), "cloth")
	for p in [Vector3(-4.2, 3.0, -1.5), Vector3(4.2, 3.0, -1.5), Vector3(0, 3.1, 1.0)]:
		Asia.paper_lantern(t, p, true, 1.0)
	for i in 3:
		Build.tcyl(t, 0.34, 0.3, 0.9, Vector3(5.3 - i * 0.75, 0.8, 3.4), "darkwood", Color(0.9, 0.8, 0.7), 10, true)
	var table := Thing.new()
	table.setup("Sit down at the arm wrestling table", _arm_wrestle)
	t.add_child(table)
	table.position = Vector3(0, 0.3, 0.9)

func _arm_wrestle() -> void:
	Game.battle.start_wrestle()

## Grass as one batched draw per kind, scattered where the player actually walks.
func _grass(model_name: String, count: int) -> void:
	var src: Node = Build.scene("nature/" + model_name).instantiate()
	Build.foliage(src)
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	mm.instance_count = count
	var i := 0
	var tries := 0
	while i < count and tries < count * 20:
		tries += 1
		var p := Vector3(randf_range(-110, 300), 0, randf_range(-130, 140))
		var rd: float = terrain.road_distance(p.x, p.z)
		if rd < 3.6 or rd > 70.0 and Vector2(p.x, p.z).length() > R + 50.0 and p.distance_to(VILLAGE) > 75.0:
			continue
		if Vector2(p.x, p.z).length() < R + 2.0 or p.distance_to(VILLAGE) < 26.0 or absf(p.x - 284.0) < 10.0:
			continue
		var s := randf_range(0.45, 0.95)
		var b := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, ground(p)))
		i += 1
	mm.visible_instance_count = i
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blade: BaseMaterial3D = mi.mesh.surface_get_material(0)
	if blade and blade.albedo_texture:
		var gs := Shader.new()
		gs.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 1.6 + w.x * 0.35 + w.z * 0.22) * 0.09 * bend;
	VERTEX.z += cos(TIME * 1.1 + w.z * 0.3) * 0.05 * bend;
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * vec3(0.8, 0.86, 0.66);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 1.0;
}
"""
		var gm := ShaderMaterial.new()
		gm.shader = gs
		gm.set_shader_parameter("tex", blade.albedo_texture)
		node.material_override = gm
	add_child(node)
	src.free()

# --- People and the Pinned -----------------------------------------------------

func _people() -> void:
	for d in Data.FOUNDERS:
		_add_npc(d, true)
	for d in Data.VILLAGERS:
		_add_npc(d, false)
	for e in Data.ROAD_PINNED:
		_add_pinned(Data.SPIRITS[e[0]], e[1], 0.0)

func _add_npc(d: Dictionary, founder: bool) -> void:
	var n: Node3D = NpcScript.new()
	add_child(n)
	n.setup(d, founder)
	n.position = ground(n.position)
	Game.npcs.append(n)

func _add_pinned(s: Dictionary, at: Vector3, delay: float) -> void:
	var p: Node3D = PinnedScript.new()
	add_child(p)
	p.setup(s, ground(at), delay)
	Game.pinned.append(p)

func drop_loot(title: String, items: Dictionary, coin: int, at: Vector3, owned_by := "", village := "", sack := true, lifetime := 180.0) -> Node3D:
	var l: Node3D = LootScript.new()
	add_child(l)
	l.setup(title, items, coin, owned_by, village, sack, lifetime)
	l.global_position = ground(at) if sack else at
	return l

func _prop(kind: String, at: Vector3) -> void:
	var p: RigidBody3D = PropScript.new()
	add_child(p)
	p.setup(kind)
	p.global_position = at

## Things lying about the island, some of them somebody's.
func _containers() -> void:
	for at in [Vector3(17.5, 0.5, -15.5), Vector3(18.3, 0.5, -14.6), Vector3(33.5, 0.5, 6.5), Vector3(-9.5, 0.5, 9.0), Vector3(10.8, 0.5, 21.5)]:
		_prop("barrel", at)
	for at in [Vector3(34.0, 0.45, -5.5), Vector3(19.0, 0.45, 23.0), Vector3(233.5, 0.45, 9.5), Vector3(241.0, 0.45, 26.0), Vector3(87.5, 0.9, -4.5)]:
		_prop("crate", ground(at) + Vector3(0, 0.45, 0))
	for at in [Vector3(239.5, 0.5, 6.5), Vector3(221.0, 0.5, 30.0)]:
		_prop("barrel", at)
	drop_loot("the Wall House chest", {"spear": 1, "cuirass": 1}, 0, Vector3(9.5, 0, -29.5), "phillip", "rhodes", false, -1.0)
	drop_loot("the carter's crate", {"coat": 1, "wine": 2}, 6, ground(Vector3(86.0, 0, -7.0)), "", "", false, -1.0)
	drop_loot("a bundle on the jetty", {"pole": 1}, 0, Vector3(274.5, 0.75, 64.0), "", "", true, -1.0)
	drop_loot("a chest behind the tavern bar", {"wine": 3, "bread": 2, "shield": 1}, 12, Vector3(27.5, 0.36, -26.5), "tommy", "rhodes", false, -1.0)

## Someone the player killed comes back where they fell. Inside the Ring they stay down.
func spawn_victim(who: String, at: Vector3) -> void:
	if Game.in_ring(at):
		Game.say("Inside the Ring, Wukhan gathers them. They will not come back.")
		return
	_add_pinned(Data.victim_spirit(who), at, 40.0)

func _player_and_ui() -> void:
	var pl: CharacterBody3D = PlayerScript.new()
	add_child(pl)
	pl.position = Game.RHODES_SPAWN
	pl.rotation.y = 0.45
	Game.player = pl
	Game.dialogue = DialogueScript.new()
	add_child(Game.dialogue)
	Game.battle = BattleScript.new()
	add_child(Game.battle)
	Game.inventory = InventoryScript.new()
	add_child(Game.inventory)
	Game.hud = HudScript.new()
	add_child(Game.hud)
