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

const R := Game.RING_RADIUS
const ROAD := [Vector3(30, 0, 0), Vector3(70, 0, 0), Vector3(120, 0, -18), Vector3(180, 0, 8), Vector3(228, 0, 20)]
const VILLAGE := Vector3(230, 0, 20)
const IRON := Color(0.17, 0.16, 0.17)
const GOLD := Color(0.93, 0.72, 0.28)

var _register_label: Label3D

func _ready() -> void:
	Game.main = self
	seed(88)
	_sky()
	_ground()
	_rhodes()
	_road()
	_tallow_ford()
	_wilds()
	_people()
	_player_and_ui()
	Game.changed.connect(_on_changed)
	_on_changed()
	if OS.get_cmdline_user_args().has("--selftest"):
		var t: Node = load("res://scripts/selftest.gd").new()
		add_child(t)

func _on_changed() -> void:
	if _register_label:
		_register_label.text = "THE REGISTER\n%d / %d" % [Game.register_count(), Game.QUOTA]

# --- Sky and ground ----------------------------------------------------------

func _sky() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.13, 0.2, 0.4)
	sm.sky_horizon_color = Color(0.86, 0.6, 0.4)
	sm.sky_curve = 0.09
	sm.sun_angle_max = 12.0
	sm.ground_horizon_color = Color(0.4, 0.37, 0.33)
	sm.ground_bottom_color = Color(0.12, 0.11, 0.1)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.54, 0.56)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.5, 0.43)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -118, 0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	add_child(sun)

func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	Build.mesh(self, pm, Vector3(100, 0, 0), Color(0.2, 0.24, 0.17))
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	sb.add_child(cs)
	add_child(sb)
	for i in 260:
		var p := Vector3(randf_range(-160, 330), 0.012 + i * 0.00004, randf_range(-200, 220))
		if Vector2(p.x, p.z).length() < R + 8.0:
			continue
		var g := Color(0.2, 0.24, 0.17).lerp(Color(0.3, 0.3, 0.16) if i % 3 == 0 else Color(0.13, 0.19, 0.15), randf_range(0.4, 1.0))
		Build.cyl(self, 1.0, 1.0, 0.01, p, g, 9).scale = Vector3(randf_range(4, 13), 1, randf_range(4, 13))
	# The safe ground inside the Ring is paler and worn.
	Build.cyl(self, R, R, 0.04, Vector3(0, 0.02, 0), Color(0.45, 0.4, 0.3), 48)
	Build.cyl(self, 9.0, 9.0, 0.04, Vector3(0, 0.05, -5), Color(0.53, 0.48, 0.38), 24)

# --- Rhodes --------------------------------------------------------------------

func _rhodes() -> void:
	# The Ring: Wukhan's staff, bent into a circle. One gap, on the east side.
	var n := 56
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a, -PI, PI)) < 0.085:
			continue
		var seg := Build.box(self, Vector3(1.6, 7.0, TAU * R / n + 0.25), Vector3(cos(a) * R, 3.5, sin(a) * R), IRON, true)
		seg.rotation.y = -a
		var band := Build.box(self, Vector3(1.7, 0.35, TAU * R / n + 0.25), Vector3(cos(a) * R, 6.2, sin(a) * R), GOLD, false, 0.5)
		band.rotation.y = -a
	for z in [-4.2, 4.2]:
		Build.box(self, Vector3(2.4, 9.0, 1.6), Vector3(R, 4.5, z), IRON, true)
		Build.sphere(self, 0.6, Vector3(R, 9.4, z), GOLD, 1.2)

	# Wukhan, slumped where he fell, sitting with his back to the west of the Ring.
	var w := Node3D.new()
	add_child(w)
	w.position = Vector3(-28, 0, 0)
	var plate := Color(0.33, 0.29, 0.23)
	var rust := Color(0.42, 0.24, 0.15)
	for sz in [-2.7, 2.7]:
		Build.box(w, Vector3(16, 2.6, 3.2), Vector3(9, 1.3, sz), plate, true)
		Build.box(w, Vector3(2.2, 3.6, 3.2), Vector3(17.6, 1.8, sz), rust, true)
		Build.box(w, Vector3(3.4, 3.0, 3.6), Vector3(8.5, 1.5, sz), rust)
	Build.box(w, Vector3(5.5, 3.2, 9.4), Vector3(0, 1.6, 0), rust, true)
	var torso := Build.box(w, Vector3(5.2, 9.5, 8.4), Vector3(-0.2, 7.4, 0), plate, true)
	torso.rotation.z = -0.14
	Build.box(w, Vector3(0.5, 4.6, 1.3), Vector3(3.1, 7.4, 0), Color(0.08, 0.06, 0.05))
	Build.box(w, Vector3(3.4, 2.6, 12.6), Vector3(0.6, 11.6, 0), rust)
	Build.sphere(w, 2.7, Vector3(2.3, 14.0, 0), plate)
	Build.box(w, Vector3(2.0, 1.6, 2.4), Vector3(4.5, 13.0, 0), rust)
	Build.cyl(w, 2.8, 2.8, 0.55, Vector3(2.3, 15.2, 0), GOLD, 14)
	Build.sphere(w, 0.42, Vector3(4.5, 14.5, -1.0), Color(1.0, 0.5, 0.12), 1.2)
	Build.sphere(w, 0.42, Vector3(4.5, 14.5, 1.0), Color(0.07, 0.06, 0.06))
	Build.box(w, Vector3(2.3, 8.4, 2.3), Vector3(1.2, 7.2, 6.6), plate)
	Build.box(w, Vector3(8.5, 2.1, 2.4), Vector3(5.6, 1.05, 7.4), plate, true)
	Build.box(w, Vector3(2.3, 8.4, 2.3), Vector3(1.2, 7.2, -6.6), plate)
	Build.box(w, Vector3(2.4, 2.1, 10.0), Vector3(2.0, 1.05, -11.5), plate, true)
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

	# The hall: an open roof over the Register.
	var hall := Vector3(0, 0, -6)
	for dx in [-5.0, 5.0]:
		for dz in [-4.0, 4.0]:
			Build.cyl(self, 0.3, 0.36, 4.4, hall + Vector3(dx, 2.2, dz), Color(0.3, 0.2, 0.13), 8, true)
	var roof := Build.cyl(self, 0.0, 9.2, 3.0, hall + Vector3(0, 5.9, 0), Color(0.42, 0.14, 0.1), 4)
	roof.rotation.y = PI / 4.0
	Build.box(self, Vector3(4.4, 2.8, 0.25), hall + Vector3(0, 1.9, -3.6), Color(0.13, 0.1, 0.08), true)
	Build.box(self, Vector3(4.7, 0.2, 0.3), hall + Vector3(0, 3.4, -3.6), GOLD, false, 0.4)
	_register_label = Label3D.new()
	_register_label.font_size = 64
	_register_label.pixel_size = 0.008
	_register_label.modulate = GOLD
	_register_label.outline_size = 6
	add_child(_register_label)
	_register_label.position = hall + Vector3(0, 2.0, -3.45)
	var rt := Thing.new()
	rt.setup("Read the Register", _read_register)
	add_child(rt)
	rt.position = hall + Vector3(0, 0.6, -3.2)

	# Houses round the inside of the Ring.
	var wall := Color(0.6, 0.54, 0.44)
	var tile := Color(0.4, 0.15, 0.11)
	for h in [[-16, 22, 0.6], [-2, 30, 0.1], [16, 26, -0.5], [27, -14, 2.2], [14, -30, 2.9], [-8, -31, 3.3], [28, 22, -1.0]]:
		Build.house(self, Vector3(h[0], 0, h[1]), Vector3(6, 3.4, 5), wall, tile, h[2])
	# Tommy's stall and a fire.
	Build.box(self, Vector3(3.2, 1.0, 1.2), Vector3(14, 0.5, -14), Color(0.35, 0.24, 0.14), true)
	Build.box(self, Vector3(3.6, 0.1, 1.8), Vector3(14, 2.6, -14), Color(0.2, 0.42, 0.5))
	Build.sphere(self, 0.4, Vector3(20, 0.3, 14), Color(1.0, 0.5, 0.1), 1.4)
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
	var dirt := Color(0.36, 0.3, 0.22)
	for i in ROAD.size() - 1:
		var a: Vector3 = ROAD[i]
		var b: Vector3 = ROAD[i + 1]
		var mid := (a + b) / 2.0
		var seg := Build.box(self, Vector3(4.2, 0.06, a.distance_to(b) + 3.0), mid + Vector3(0, 0.03, 0), dirt)
		seg.rotation.y = atan2(b.x - a.x, b.z - a.z)
	# The pines the road bends round, and a broken cart.
	for i in 26:
		Build.tree(self, Vector3(118 + randf_range(-16, 16), 0, 8 + randf_range(-12, 14)), randf_range(1.0, 1.6), true)
	Build.box(self, Vector3(2.4, 1.0, 1.4), Vector3(82, 0.6, -4.5), Color(0.3, 0.22, 0.14), true).rotation.z = 0.35
	Build.cyl(self, 0.6, 0.6, 0.15, Vector3(83.5, 0.4, -5.6), Color(0.2, 0.15, 0.1), 10).rotation.x = 1.2
	# Marker stones along the way.
	for p in [Vector3(48, 0, 3.2), Vector3(98, 0, -6), Vector3(150, 0, -8), Vector3(204, 0, 17)]:
		Build.box(self, Vector3(0.6, 1.3, 0.4), p + Vector3(0, 0.65, 0), Color(0.5, 0.5, 0.48), true)

# --- Tallow Ford -----------------------------------------------------------------

func _tallow_ford() -> void:
	var wall := Color(0.5, 0.47, 0.4)
	var thatch := Color(0.5, 0.42, 0.22)
	Build.cyl(self, 24, 24, 0.04, VILLAGE + Vector3(0, 0.02, 2), Color(0.34, 0.3, 0.22), 28)
	for h in [[214, 30, 0.4], [222, 42, 0.0], [238, 40, -0.3], [250, 22, -1.4], [218, -2, 2.6], [248, 4, -2.2]]:
		Build.house(self, Vector3(h[0], 0, h[1]), Vector3(5.5, 3.0, 4.6), wall, thatch, h[2])
	# Pell's shop, with the strongbox round the back.
	Build.house(self, Vector3(236, 0, 2), Vector3(7, 3.4, 5), Color(0.44, 0.4, 0.46), Color(0.25, 0.22, 0.3), 0.0)
	Build.box(self, Vector3(1.1, 0.7, 0.7), Vector3(236, 0.35, -2.4), Color(0.3, 0.2, 0.1), true)
	Build.box(self, Vector3(1.15, 0.12, 0.75), Vector3(236, 0.72, -2.4), GOLD)
	var box := Thing.new()
	box.setup("Steal from Pell's strongbox", _steal)
	add_child(box)
	box.position = Vector3(236, 0.0, -3.0)
	# Well.
	Build.cyl(self, 1.1, 1.1, 0.9, VILLAGE + Vector3(0, 0.45, 2), Color(0.45, 0.45, 0.43), 10, true)
	# Ivo's pyre.
	for i in 5:
		Build.box(self, Vector3(2.6, 0.25, 0.3), Vector3(211, 0.2 + i * 0.26, 4), Color(0.25, 0.17, 0.1)).rotation.y = i * 0.6
	Build.sphere(self, 0.35, Vector3(211, 1.6, 4), Color(1.0, 0.45, 0.1), 2.5)
	# Fences on the Rhodes side.
	for i in 9:
		Build.box(self, Vector3(0.15, 1.1, 0.15), Vector3(204, 0.55, 2 + i * 4.0), Color(0.3, 0.22, 0.14))
	Build.box(self, Vector3(0.1, 0.1, 32), Vector3(204, 0.9, 18), Color(0.3, 0.22, 0.14))
	# The river, east of the village, and the old jetty to the south.
	Build.box(self, Vector3(22, 0.05, 420), Vector3(282, 0.04, 20), Color(0.16, 0.26, 0.33))
	Build.box(self, Vector3(12, 0.25, 2.2), Vector3(268, 0.5, 64), Color(0.3, 0.22, 0.14), true)
	for x in [263.0, 268.0, 273.0]:
		Build.cyl(self, 0.15, 0.15, 1.4, Vector3(x, 0.2, 65.2), Color(0.2, 0.15, 0.1), 6)
	Build.label(self, "TALLOW FORD", 0, Color(0.9, 0.85, 0.7), 60).position = Vector3(206, 3.2, 19)

func _steal() -> void:
	if Game.flags.has("stolen"):
		Game.say("The strongbox is empty. You emptied it.")
		return
	Game.flags["stolen"] = true
	Game.coins += 30
	Game.straps += 2
	var seen := Game.witnesses(Vector3(236, 0, -3), null, 9.0)
	if seen.size() > 0:
		Game.rep["tallow"] -= 35
		Game.say("%s saw you with your hands in the strongbox. Thirty coin and two straps, and the whole village will know by dark." % seen[0].npc_name)
	else:
		Game.say("Thirty coin and two straps. Nobody saw.")
		Game.flags["unseen_theft"] = true
	for n in Game.npcs:
		if n.id == "pell":
			n.disp -= 40
	Game.note("You robbed Pell's strongbox at Tallow Ford.")
	Game.touch()

# --- Trees and rocks ---------------------------------------------------------

func _near_road(p: Vector3, margin: float) -> bool:
	for i in ROAD.size() - 1:
		var a := Vector2(ROAD[i].x, ROAD[i].z)
		var b := Vector2(ROAD[i + 1].x, ROAD[i + 1].z)
		var q := Vector2(p.x, p.z)
		var t: float = clamp((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if q.distance_to(a + (b - a) * t) < margin:
			return true
	return false

func _wilds() -> void:
	var placed := 0
	var tries := 0
	while placed < 230 and tries < 4000:
		tries += 1
		var p := Vector3(randf_range(-120, 300), 0, randf_range(-170, 190))
		if Vector2(p.x, p.z).length() < R + 5.0:
			continue
		if _near_road(p, 5.5) or p.distance_to(VILLAGE) < 30.0 or (p.x > 268 and p.x < 296):
			continue
		if randf() < 0.22:
			Build.sphere(self, randf_range(0.6, 1.6), p + Vector3(0, 0.2, 0), Color(0.4, 0.4, 0.38)).scale.y = 0.6
		else:
			Build.tree(self, p, randf_range(0.8, 1.7), randf() < 0.4)
		placed += 1

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
	Game.npcs.append(n)

func _add_pinned(s: Dictionary, at: Vector3, delay: float) -> void:
	var p: Node3D = PinnedScript.new()
	add_child(p)
	p.setup(s, at, delay)
	Game.pinned.append(p)

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
	Game.hud = HudScript.new()
	add_child(Game.hud)
