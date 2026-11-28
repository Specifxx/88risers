extends Node3D
## Meet Night at Rhodes Amphitheatre: the place, who is here, what they get up to,
## and the things that occasionally go wrong.

const Build = preload("res://scripts/build.gd")
const Asia = preload("res://scripts/asia.gd")
const Fx = preload("res://scripts/fx.gd")
const Character = preload("res://scripts/character.gd")
const People = preload("res://scripts/people.gd")
const RiserScript = preload("res://scripts/riser.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const MenuScript = preload("res://scripts/menu.gd")
const TableScript = preload("res://scripts/table.gd")
const Thing = preload("res://scripts/thing.gd")
const Wear = preload("res://scripts/wear.gd")
const Pose = preload("res://scripts/pose.gd")
const SKIN := Color(0.82, 0.64, 0.5)
const NIGHT := 900.0

const PLAZA := 9.0
const TIERS := 8
const TIER_H := 0.3
const TABLES := [Vector3(-3.6, 0, 1.2), Vector3(0, 0, -2.2), Vector3(3.6, 0, 1.2)]
const SNACKS := Vector3(6.2, 0, 5.6)
const CHALK := Vector3(0.0, 0, 3.4)
const NOTE_SPOTS := [Vector3(-7.5, 0, 6.5), Vector3(8.0, 0, -1.0), Vector3(2.6, 0, 13.5), Vector3(-10.5, 0, 16)]

var _matches: Array = []        # [{table, a, b, time}]
var _director := 6.0
var _ufo_at := -1.0
var _ufo: Node3D
var _ufo_state := ""
var _aliens: Array = []
var _clock := 0.0
var _bags := {}                 # riser id -> {at, strap}
var _rigs: Array = []
var _match_cam: Camera3D
var _player_table := -1
var _events: Array = []         # [{at, kind}]
var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _drone: Node3D
var _drone_t := 0.0
var _drone_to := Vector3.ZERO
var _gulls: Node3D
var _gulls_t := 0.0
var _gulls_off := false
var _bucket: Array = []
var _lions: Array = []           # the statues at the gate
var _pets: Array = []            # lions that got out
var _ramp: Node3D
var _aboard := false
var _ufo_wait := 0.0
var _cabin: Node3D
var _board_from := Vector3.ZERO
var _alien_drops := 0
var _ganging := false
var evening: Node3D
var _table_roots: Array = []
var _gone_tables := {}
var _free_snacks := 3
var _reward := 3.0
var _passer := 4.0
var _passer_pool: Array = []

func _ready() -> void:
	Meet.main = self
	Meet.risers = []
	Meet.visits += 1
	seed(Time.get_ticks_usec())
	_sky()
	_place()
	_people()
	Meet.player = PlayerScript.new()
	add_child(Meet.player)
	Meet.player.position = Vector3(0, 0, 15)
	Meet.menu = MenuScript.new()
	add_child(Meet.menu)
	Meet.table = TableScript.new()
	add_child(Meet.table)
	Meet.audio = load("res://scripts/sfx.gd").new()
	add_child(Meet.audio)
	Meet.new_dares()
	Meet.strapgame = load("res://scripts/strapgame.gd").new()
	add_child(Meet.strapgame)
	Meet.hud = HudScript.new()
	add_child(Meet.hud)
	# The first time, something comes down a couple of minutes in. After that it is rare.
	if not Meet.seen_ufo:
		_events = [{"at": 75.0, "kind": "gulls"}, {"at": 330.0, "kind": "ufo"}, {"at": 600.0, "kind": "drone"}]
	else:
		var kinds := ["gulls", "drone", "gulls", "drone"]
		if Meet.visits >= 3 and randf() < 0.3:
			_events.append({"at": randf_range(520.0, 740.0), "kind": "kaiju"})
		if randf() < 0.55:
			kinds.insert(0, "ufo")
		var first: String = kinds.pop_front() if kinds[0] == "ufo" else ""
		kinds.shuffle()
		if first != "":
			kinds.insert(0, first)
		var had := {}
		for i in 2 + randi() % 2:
			if not had.has(kinds[i]):
				had[kinds[i]] = true
				_events.append({"at": randf_range(60.0, 800.0), "kind": kinds[i]})
	evening = load("res://scripts/evening.gd").new()
	add_child(evening)
	evening.setup(self)
	apply_quality()
	Meet.changed.connect(func():
		if _sun.shadow_enabled and Meet.touch:
			apply_quality())
	if OS.get_cmdline_user_args().has("--selftest") or OS.get_cmdline_user_args().has("--soak"):
		add_child(load("res://scripts/selftest.gd").new())

# --- The ground ----------------------------------------------------------------

## Height of the ground: flat plaza and lawn, stepped seating behind, water beyond the path.
func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if z < -0.5 and r > PLAZA:
		return min(TIERS, int(r - PLAZA) + 1) * TIER_H
	return 0.0

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height(p.x, p.z), p.z)

## Keep a walker out of the tables and inside the grounds.
func clear(p: Vector3) -> Vector3:
	if p.y > 200.0:
		# Aboard the ship: a round room.
		var flat := Vector2(p.x, p.z)
		if flat.length() > 4.7:
			flat = flat.normalized() * 4.7
		return Vector3(flat.x, 300.0, flat.y)
	for t in TABLES + [SNACKS, CHALK]:
		var d := Vector2(p.x - t.x, p.z - t.z)
		if d.length() < 1.15 and d.length() > 0.001:
			d = d.normalized() * 1.15
			p.x = t.x + d.x
			p.z = t.z + d.y
	p.x = clamp(p.x, -24.0, 24.0)
	p.z = clamp(p.z, -20.0, 28.75)   # right up to the railing
	return ground(p)

# --- The place -------------------------------------------------------------------

func _sky() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.1, 0.13, 0.32)
	sm.sky_horizon_color = Color(0.98, 0.56, 0.34)
	sm.sky_curve = 0.14
	sm.ground_horizon_color = Color(0.5, 0.36, 0.3)
	sm.ground_bottom_color = Color(0.08, 0.08, 0.1)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.46, 0.6)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.45, 0.4)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env = env
	_sky_mat = sm
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -150, 0)
	sun.light_color = Color(1.0, 0.68, 0.45)
	sun.light_energy = 0.85
	sun.shadow_enabled = not Meet.touch
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	_sun = sun

func _place() -> void:
	var stone := Color(0.78, 0.76, 0.72)
	# Lawn, plaza, path, water.
	var lawn := PlaneMesh.new()
	lawn.size = Vector2(400, 400)
	# The lawn stops at the sea wall; beyond the railing it is water.
	var lm := Build.mesh(self, lawn, Vector3(0, 0, 29.3 - 200.0), Color.WHITE)
	lm.material_override = Build.tmat("grass", Color(0.5, 0.6, 0.42), 0.12)
	Build.tcyl(self, PLAZA, PLAZA, 0.06, Vector3(0, 0.03, 0), "paving", Color(0.74, 0.7, 0.66), 40, false, 0.28)
	Build.tbox(self, Vector3(60, 0.05, 3.6), Vector3(0, 0.03, 27.2), "paving", Color(0.66, 0.63, 0.6), false, 0.28)
	Build.tbox(self, Vector3(3.4, 0.05, 17), Vector3(0, 0.03, 17.5), "paving", Color(0.66, 0.63, 0.6), false, 0.28)
	var water := PlaneMesh.new()
	water.size = Vector2(600, 400)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.16, 0.26)
	wm.roughness = 0.05
	wm.metallic = 0.6
	var wmi := Build.mesh(self, water, Vector3(0, -0.35, 229.5), Color.WHITE)
	wmi.material_override = wm
	Build.tbox(self, Vector3(60, 0.7, 0.5), Vector3(0, 0.0, 29.3), "stone", stone, false, 0.5)
	for i in 21:
		Build.tcyl(self, 0.05, 0.05, 1.1, Vector3(-30 + i * 3.0, 0.9, 29.3), "iron", Color(0.35, 0.35, 0.38), 6)
	Build.tbox(self, Vector3(60, 0.06, 0.06), Vector3(0, 1.4, 29.3), "iron", Color(0.35, 0.35, 0.38))
	# The seating: curved stone tiers behind the plaza.
	# Two batches (alternate tiers are a shade apart) rather than a couple of hundred separate blocks.
	var n := 26
	for parity in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = n * TIERS / 2
		var k := 0
		for t in TIERS:
			if t % 2 != parity:
				continue
			var radius := PLAZA + 0.5 + t
			for i in n:
				var a := PI + 0.12 + (PI - 0.24) * (i + 0.5) / n
				var hgt := (t + 1) * TIER_H
				var bs: Basis = Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(1.0, hgt, (PI - 0.24) * radius / n + 0.06))
				mm.set_instance_transform(k, Transform3D(bs, Vector3(cos(a) * radius, hgt / 2.0, sin(a) * radius)))
				k += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Build.tmat("stone", stone * (0.92 + 0.04 * parity), 0.5)
		add_child(mmi)
	for sx in [-1.0, 1.0]:
		Build.tbox(self, Vector3(9.0, TIERS * TIER_H + 0.5, 0.6), Vector3(sx * (PLAZA + 4.5), (TIERS * TIER_H + 0.5) / 2.0, -0.6), "stone", stone * 0.9, true, 0.5)
	# Arm wrestling tables.
	for t in TABLES:
		_table(t)
	# Snacks.
	var sn := Node3D.new()
	add_child(sn)
	sn.position = SNACKS
	Build.tbox(sn, Vector3(2.4, 0.08, 0.9), Vector3(0, 0.82, 0), "planks", Color(0.75, 0.65, 0.55), true)
	for sx in [-1.0, 1.0]:
		Build.tbox(sn, Vector3(0.08, 0.8, 0.8), Vector3(sx * 1.1, 0.4, 0), "darkwood")
	for i in 5:
		Build.box(sn, Vector3(0.28, 0.14, 0.22), Vector3(-0.9 + i * 0.42, 0.93, randf_range(-0.2, 0.2)), [Color(0.9, 0.3, 0.2), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.9)][i % 3])
	Build.box(sn, Vector3(0.9, 0.5, 0.55), Vector3(1.9, 0.25, 0.1), Color(0.15, 0.4, 0.75))
	Build.box(sn, Vector3(0.94, 0.08, 0.59), Vector3(1.9, 0.54, 0.1), Color(0.95, 0.95, 0.95))
	var snt := Thing.new()
	snt.setup("Grab a snack", _grab_snack)
	add_child(snt)
	snt.position = SNACKS + Vector3(0, 0, 0.9)
	# The chalk bucket.
	_bucket = [Build.tcyl(self, 0.28, 0.22, 0.5, CHALK + Vector3(0, 0.55, 0), "iron", Color(0.5, 0.52, 0.56), 12),
		Build.cyl(self, 0.25, 0.25, 0.04, CHALK + Vector3(0, 0.8, 0), Color(0.97, 0.97, 0.97), 12)]
	Build.tcyl(self, 0.05, 0.2, 0.3, CHALK + Vector3(0, 0.15, 0), "iron", Color(0.3, 0.3, 0.33), 8)
	var hide := Thing.new()
	hide.setup("Hide the chalk bucket", _hide_chalk)
	add_child(hide)
	hide.position = CHALK + Vector3(0, 0, -0.6)
	var ch := Thing.new()
	ch.setup("Chalk your hands", _chalk_up)
	add_child(ch)
	ch.position = CHALK + Vector3(0.45, 0, 0.45)
	var ch2 := Thing.new()
	ch2.setup("Take a handful of chalk", _chalk_take)
	add_child(ch2)
	ch2.position = CHALK + Vector3(-0.45, 0, 0.45)
	# Everyone's kit bag, with their strap in it.
	var fi := 0
	for d in People.FOUNDERS:
		var a := 2.0 + fi * 0.13
		_bag(d, Vector3(cos(a) * 8.3, 0, sin(a) * 8.3))
		fi += 1
	var tr := Thing.new()
	tr.setup("Throw a snack in the air", _bait_gulls)
	add_child(tr)
	tr.position = SNACKS + Vector3(-1.7, 0, 0.9)
	# The club ladder, on a board by the way in.
	Build.tbox(self, Vector3(1.6, 1.1, 0.06), Vector3(3.6, 1.5, 21.0), "darkwood")
	Build.tbox(self, Vector3(0.08, 2.1, 0.08), Vector3(3.6, 1.05, 21.05), "iron", Color(0.3, 0.3, 0.33))
	Build.box(self, Vector3(1.4, 0.9, 0.01), Vector3(3.6, 1.5, 20.96), Color(0.93, 0.9, 0.82))
	var lad := Thing.new()
	lad.setup("Read the club ladder", func(): Meet.menu.ladder())
	add_child(lad)
	lad.position = Vector3(3.6, 0, 20.2)
	# Drinks: an esky with an honesty tin.
	var dr := Thing.new()
	dr.setup("Buy a cold drink ($3)", _buy_drink)
	add_child(dr)
	dr.position = SNACKS + Vector3(1.9, 0, 0.9)
	# Loose change people have dropped.
	for i in 2:
		var a := randf() * TAU
		var r := randf_range(6.0, 20.0)
		_coin(clear(Vector3(cos(a) * r, 0, absf(sin(a)) * r + 2.0)), 2)
	if randf() < 0.25:
		_coin(Vector3(-9, 0, 20.6), 20)
	# The way in from the water, the club's guardians, and its banners.
	Asia.gate(self, Vector3(0, 0, 24.5), 0.0, 6.0)
	for sx in [-1.0, 1.0]:
		var holder := Node3D.new()
		add_child(holder)
		holder.position = Vector3(sx * 5.2, 0, 22.5)
		Asia.lion(holder, Vector3.ZERO, -sx * 0.2, 1.0)
		_lions.append(holder)
	for i in Meet.lions:
		_free_lion(Vector3(randf_range(-2, 2), 0, 18.0))
	for i in 6:
		var a := -0.25 + i * (PI + 0.5) / 5.0
		var at := Vector3(cos(a) * (PLAZA + 0.6), 0, sin(a) * (PLAZA + 0.6))
		if at.z > -0.5:
			Asia.banner(self, at, atan2(-at.x, -at.z), 5.0)
	# Festoon lights strung round the plaza.
	var poles: Array = []
	for i in 8:
		var a := TAU * i / 8.0 + 0.39
		var at := Vector3(cos(a) * (PLAZA + 0.2), 0, sin(a) * (PLAZA + 0.2))
		at.y = height(at.x, at.z)
		Build.tcyl(self, 0.06, 0.08, 5.0, at + Vector3(0, 2.5, 0), "iron", Color(0.25, 0.25, 0.28), 6)
		poles.append(at + Vector3(0, 5.0, 0))
	# The bulbs: three batches by colour.
	var bulbs := [[], [], []]
	for i in poles.size():
		var a: Vector3 = poles[i]
		var b: Vector3 = poles[(i + 1) % poles.size()]
		for k in range(1, 7):
			var f := k / 7.0
			bulbs[k % 3].append(a.lerp(b, f) - Vector3(0, sin(f * PI) * 0.8, 0))
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.09
	bulb_mesh.height = 0.18
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	for c in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bulb_mesh
		mm.instance_count = bulbs[c].size()
		for j in bulbs[c].size():
			mm.set_instance_transform(j, Transform3D(Basis(), bulbs[c][j]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Build.mat([Color(1.0, 0.8, 0.45), Color(1.0, 0.45, 0.3), Color(1.0, 0.9, 0.7)][c], 1.5)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	for lp in [Vector3(-4, 4.2, 0), Vector3(4, 4.2, 0), Vector3(0, 4.2, 5), Vector3(6, 3.0, 6)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.5)
		l.light_energy = 1.3
		l.omni_range = 11.0
		add_child(l)
		l.position = lp
	# Trees on the lawn.
	for tp in [Vector3(-17, 0, 9), Vector3(17, 0, 10), Vector3(-20, 0, 20), Vector3(20, 0, 21), Vector3(-13, 0, 24), Vector3(13, 0, 18)]:
		var tree := Build.model(self, "nature/CommonTree_%d" % (1 + randi() % 2), tp, randf() * TAU, randf_range(1.0, 1.5))
		Build.foliage(tree)
	for bp in [Vector3(-9, 0, 20), Vector3(9, 0, 20)]:
		Build.tbox(self, Vector3(2.0, 0.08, 0.5), bp + Vector3(0, 0.45, 0), "planks", Color(0.6, 0.5, 0.42), true)
		for sx in [-0.8, 0.8]:
			Build.tbox(self, Vector3(0.08, 0.45, 0.45), bp + Vector3(sx, 0.22, 0), "iron", Color(0.3, 0.3, 0.33))
	for bp in [Vector3(-9, 0, 20), Vector3(9, 0, 20)]:
		_seat_spot("Sit on the bench", bp + Vector3(0, 0.5, 0), PI)
	for a in [PI + 0.9, PI * 1.5, TAU - 0.9]:
		_seat_spot("Sit on the steps", Vector3(cos(a) * 11.6, 0.9, sin(a) * 11.6), atan2(-cos(a), -sin(a)) + PI)
	for dp in [Vector3(-6.5, 0, -5.5), Vector3(7.5, 0, 9.5)]:
		var db := Thing.new()
		add_child(db)
		db.position = ground(dp)
		for sx in [-0.35, 0.35]:
			var bar := Build.cyl(db, 0.025, 0.025, 0.36, Vector3(sx, 0.12, 0), Color(0.6, 0.6, 0.65), 6)
			bar.rotation.x = PI / 2.0
			for sz in [-0.16, 0.16]:
				Build.cyl(db, 0.11, 0.11, 0.07, Vector3(sx, 0.12, sz), Color(0.12, 0.12, 0.14), 10).rotation.x = PI / 2.0
		db.setup("Do a set with the dumbbells", _lift)
	Build.tbox(self, Vector3(60, 1.6, 0.4), Vector3(0, -0.8, 29.6), "stone", Color(0.6, 0.6, 0.62), false, 0.5)
	_skyline()
	# Lanterns where people leave each other notes.
	for i in NOTE_SPOTS.size():
		Asia.stone_lantern(self, NOTE_SPOTS[i], false)
		var nt := Thing.new()
		var spot := i
		nt.setup("Read the notes left here", func(): Meet.menu.notes(spot))
		add_child(nt)
		nt.position = NOTE_SPOTS[i] + Vector3(0, 0, 0.7)
	# Things somebody left lying about.
	_find("pool_noodle", "Pick up the pool noodle", Vector3(14.5, 0.1, 28.0), Color(0.2, 0.85, 0.9))
	_find("cone", "Take the traffic cone", Vector3(-12.5, TIERS * TIER_H, -15.0), Color(1.0, 0.45, 0.1))

func hide_table(i: int) -> void:
	_table_roots[i].visible = false
	_gone_tables[i] = true

func _table(at: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
	_table_roots.append(t)
	t.position = at
	Build.tbox(t, Vector3(0.95, 0.07, 0.7), Vector3(0, 1.02, 0), "darkwood", Color.WHITE, false)
	Build.tcyl(t, 0.07, 0.3, 1.0, Vector3(0, 0.5, 0), "iron", Color(0.3, 0.3, 0.33), 8)
	for sx in [-1.0, 1.0]:
		Build.tbox(t, Vector3(0.24, 0.05, 0.24), Vector3(sx * 0.2, 1.08, 0.05), "cloth")
		Build.tcyl(t, 0.025, 0.025, 0.2, Vector3(sx * 0.42, 1.15, -0.2), "iron", Color(0.7, 0.7, 0.72), 6)
	Asia.quad(t, Vector2(0.3, 0.3), Vector3(0, 1.06, 0.2), 0.0, "ui/emblem.png", true).rotation.x = -PI / 2.0
	# Two arms locked over the table, shown whenever a pull is on here.
	var rig := Node3D.new()
	t.add_child(rig)
	rig.visible = false
	_rigs.append({"root": rig, "lean": 0.0, "target": 0.0, "a": null, "b": null})
	var call := Thing.new()
	call.setup("Stand at the table and call for a pull", _call_out.bind(_rigs.size() - 1))
	add_child(call)
	call.position = at + Vector3(-1.1, 0, 0)
	var idx := _rigs.size() - 1
	var st := Thing.new()
	st.setup("Strap their hands in", _strap_in.bind(idx))
	st.remove_from_group("interact")
	add_child(st)
	st.position = at + Vector3(0, 0, 1.3)
	_rigs[idx]["helper"] = st

## Stand at an empty table and shout for a taker. Somebody willing comes over, if anyone is.
func _call_out(i: int) -> void:
	if table_busy(i) or _gone_tables.has(i):
		Meet.say("This table's in use.")
		return
	Meet.player.act("Punch_Jab", 0.6)
	Meet.sfx("whistle", -12.0, 0.8)
	var pool: Array = Meet.risers.filter(func(r): return (r.is_riser or r.guest) and r.is_free() and r.state != "huddle" and r.reluctance() == "")
	stir(TABLES[i], ["Somebody take that!", "Go on, someone.", "Not me, I've just eaten.", "Fresh meat at table %d." % (i + 1)], 14.0, 0.4, false)
	if pool.is_empty():
		Meet.say("\"WHO WANTS A PULL?\" Nobody does. Either they're busy or they've had enough of you.")
		return
	var r: Node = pool[0]
	var top := -99.0
	for c in pool:
		var sc: float = (1.0 if c.wants_pull else 0.0) + c.mind.feeling() + randf() * 0.6
		if sc > top:
			top = sc
			r = c
	r.say_aloud(["I'll have that.", "Me. I'm coming.", "Go on, then. Don't move.", "Finally. Stay there."][randi() % 4], 4.0)
	Meet.say("\"WHO WANTS A PULL?\" %s is on the way over. Stay by the table." % r.riser_name)
	r._convo = {}
	r._partner = null
	r._face_at = TABLES[i]
	r._go(TABLES[i] + Vector3(1.2, 0, 0), "answer")

## Offer to strap in the two people pulling at this table.
func _strap_in(i: int) -> void:
	var m: Dictionary = {}
	for x in _matches:
		if x["table"] == i:
			m = x
	if m.is_empty() or m.get("strapped", false):
		return
	m["strapped"] = true
	m["time"] += 6.0
	_rigs[i]["helper"].remove_from_group("interact")
	Meet.strapgame.start(func(hits: int):
		var a: Node = m["a"]
		var b: Node = m["b"]
		Meet.sfx("strap")
		if hits == 3:
			Meet.dare("strapin")
		if hits >= 2:
			for r in [a, b]:
				r.mind.experience("helped", 0.45 if hits == 3 else 0.3, 1.2, true, "the strap")
			a.say_aloud(["Cheers. That's tight.", "Good strap.", "Nice. Thanks."][randi() % 3], 3.5)
			Meet.say("Strapped in clean (%d of 3). Both of them think better of you for it." % hits)
			stir(TABLES[i], ["Good strap.", "Look at that. A proper wrap.", "Useful, this one."], 7.0, 0.5, false)
		else:
			a.say_aloud("That's falling off. Harry! Can you redo this?", 4.0)
			for r in [a, b]:
				r.mind.experience("nagged", -0.1, 0.4)
			Meet.say("The strap slides straight off. They get someone else to do it."))

## Put the two people at this table into their stance: leaning in, elbows down, hands locked,
## with the grip tipping one way or the other as the pull goes.
func _pose_rig(i: int, dt: float) -> void:
	var r: Dictionary = _rigs[i]
	r["lean"] = lerp(float(r["lean"]), float(r["target"]), min(1.0, dt * 4.0))
	var a: float = r["lean"] + sin(_clock * 9.0 + i) * 0.03
	var t: Vector3 = TABLES[i]
	var grip := t + Vector3(0, 1.1 + 0.27 * cos(a), 0.27 * sin(a))
	for side in [[-1.0, r["a"]], [1.0, r["b"]]]:
		var fig: Node3D = side[1]
		if fig == null or not is_instance_valid(fig):
			continue
		var sx: float = side[0]
		Pose.pull(fig, t + Vector3(sx * 0.15, 1.1, -sx * 0.07), grip + Vector3(sx * 0.03, 0, 0), t + Vector3(sx * 0.36, 1.2, sx * 0.24), 0.9 + 0.12 * sx * sin(a))

func _rig_off(i: int) -> void:
	var r: Dictionary = _rigs[i]
	for k in ["a", "b"]:
		if r[k] != null and is_instance_valid(r[k]):
			Pose.stop(r[k])
		r[k] = null
	r["root"].visible = false

func rig_lean(i: int, frac: float) -> void:
	if i >= 0:
		_rigs[i]["target"] = clamp(frac, -1.0, 1.0) * 1.15

## Sit the player down opposite someone at the nearest table that is free.
func seat_player(r: Node3D) -> int:
	var best := -1
	for i in TABLES.size():
		if table_busy(i):
			continue
		if best < 0 or TABLES[i].distance_to(Meet.player.global_position) < TABLES[best].distance_to(Meet.player.global_position):
			best = i
	if best < 0:
		best = 0
		for m in _matches.duplicate():
			if m["table"] == 0:
				drop_match(m["a"])
	_player_table = best
	var t: Vector3 = TABLES[best]
	Meet.player.global_position = t + Vector3(-0.66, 0, 0)
	Meet.player.rotation.y = -PI / 2.0
	r.global_position = t + Vector3(0.66, 0, 0)
	r.rotation.y = -PI / 2.0
	r.state = "pull"
	r._face_at = t
	Wear.drop(r._figure)
	# Watch the pull from the side, framed above the panel.
	if _match_cam == null:
		_match_cam = Camera3D.new()
		_match_cam.fov = 50
		add_child(_match_cam)
	_match_cam.position = t + Vector3(0, 1.75, 3.3)
	_match_cam.look_at(t + Vector3(0, 0.55, 0))
	_match_cam.current = true
	_rigs[best]["lean"] = 0.0
	_rigs[best]["target"] = 0.0
	_rigs[best]["root"].visible = true
	_rigs[best]["a"] = Meet.player._figure
	_rigs[best]["b"] = r._figure
	_pose_rig(best, 1.0)
	return best

func unseat_player(i: int) -> void:
	_player_table = -1
	Meet.player.cam.current = true
	if i >= 0:
		_rig_off(i)
	for r in Meet.risers:
		if r.state == "pull" and not _in_match(r):
			r.idle()

func _in_match(r: Node) -> bool:
	for m in _matches:
		if m["a"] == r or m["b"] == r:
			return true
	return false

func _bag(d: Dictionary, at: Vector3) -> void:
	var b := Node3D.new()
	add_child(b)
	b.position = at
	b.rotation.y = randf() * TAU
	var col: Color = d["strap"]
	Build.box(b, Vector3(0.6, 0.28, 0.32), Vector3(0, 0.14, 0), Color(0.16, 0.16, 0.2) if d["id"] != "tommy" else Color(0.5, 0.15, 0.15))
	Build.box(b, Vector3(0.5, 0.03, 0.05), Vector3(0, 0.3, 0), Color(0.3, 0.3, 0.34))
	var strap := Node3D.new()
	b.add_child(strap)
	Build.box(strap, Vector3(0.42, 0.03, 0.07), Vector3(0.05, 0.3, 0.1), col)
	Build.box(strap, Vector3(0.07, 0.03, 0.2), Vector3(-0.14, 0.3, 0.17), col)
	var who: String = d["name"].split(" ")[0]
	var th := Thing.new()
	th.setup("Take the strap from %s's bag" % who, _strap_take.bind(d["id"]))
	add_child(th)
	th.position = at
	_bags[d["id"]] = {"at": at, "strap": strap, "thing": th, "who": who}
	var pt := Thing.new()
	pt.setup("Plant another strap in %s's bag" % who, _strap_plant.bind(d["id"]))
	add_child(pt)
	pt.position = at * 0.93 + Vector3(0.3, 0, 0)
	var wt := Thing.new()
	wt.setup("Go through %s's wallet" % who, _wallet_take.bind(d["id"]))
	add_child(wt)
	wt.position = at * 1.07

## Something lying about that somebody asked for, or that just turned up.
func pickup(label: String, at: Vector3, c: Color, got: Callable) -> Node3D:
	var th := Thing.new()
	add_child(th)
	th.position = ground(at)
	Build.box(th, Vector3(0.18, 0.05, 0.24), Vector3(0, 0.08, 0), c, false, 0.4)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.2
	l.omni_range = 2.5
	l.position.y = 0.5
	th.add_child(l)
	th.setup("Pick up %s" % label, func():
		th.remove_from_group("interact")
		Meet.player.target = null
		Meet.player.act("PickUp_Table", 0.8)
		th.queue_free()
		got.call())
	return th

func _seat_spot(label: String, at: Vector3, yaw: float) -> void:
	var th := Thing.new()
	add_child(th)
	th.position = Vector3(at.x, 0, at.z)
	th.position.y = height(at.x, at.z)
	th.setup(label, func(): Meet.player.sit(Vector3(at.x, at.y if at.y > 0.6 else at.y, at.z), yaw))

## A set of curls: tiring, a little painful, and it shows up at the table.
func _lift() -> void:
	if Meet.stamina < 30.0:
		Meet.say("You're too spent for another set. Eat something first.")
		return
	Meet.player.gesture("curl", 3.2, Vector3.ZERO, func():
		Meet.stamina = max(0.0, Meet.stamina - 35.0)
		Meet.composure = max(10.0, Meet.composure - 8.0)
		Meet.sets += 1
		if Meet.pump < 4:
			Meet.pump += 1
			Meet.say("One set done. Your forearms are on fire. Pump %d of 4: the gold zone is wider for your pulls tonight." % Meet.pump)
		else:
			Meet.say("You're as pumped as you'll get tonight. That one was just for show.")
		for r in watchers(Meet.player.global_position, 8.0):
			if randf() < 0.4:
				r.say_aloud(["Light weight!", "Form's alright, actually.", "Leave some for the rest of us.", "Elbows in."][randi() % 4], 3.0)
				break
		Meet.touch_state()
		Meet.save())

func _coin(at: Vector3, amount: int) -> void:
	var th := Thing.new()
	add_child(th)
	th.position = ground(at)
	if amount >= 20:
		Build.box(th, Vector3(0.16, 0.01, 0.08), Vector3(0, 0.07, 0), Color(0.9, 0.5, 0.25), false, 0.3)
	else:
		Build.cyl(th, 0.035, 0.035, 0.012, Vector3(0, 0.07, 0), Color(1.0, 0.82, 0.25), 10).material_override = Build.mat(Color(1.0, 0.82, 0.25), 0.8)
	th.setup("Pick up the $%d %s" % [amount, "note" if amount >= 20 else "coin"], func():
		Meet.player.act("PickUp_Table", 0.7)
		Meet.pay(amount, "Finders keepers.")
		Meet.save()
		th.queue_free())

func _buy_drink() -> void:
	if Meet.money < 3:
		Meet.say("Drinks are $3 and you have $%d." % Meet.money)
		return
	Meet.pay(-3)
	Meet.sfx("sip")
	Meet.stamina = 100.0
	Meet.composure = min(100.0, Meet.composure + 20.0)
	Meet.player.act("PickUp_Table", 0.8)
	Meet.say("Three dollars in the tin. Cold drink. You feel a lot better. $%d left." % Meet.money)

## Hand in someone's wallet. Same rules as the strap: it depends who is looking.
func _wallet_take(id: String) -> void:
	var bag: Dictionary = _bags[id]
	var owner: Node = Meet.riser(id)
	if owner.wallet <= 0:
		Meet.say("%s's wallet is empty. You did that." % bag["who"])
		return
	var p: Vector3 = Meet.player.global_position
	Meet.player.act("Fixing_Kneeling", 1.0)
	var seen: Array = watchers(p)
	if seen.has(owner):
		owner.mind.experience("theft", -0.9, 3.0, true, "my wallet")
		owner._mood_check = 0.0
		owner.say_aloud("That's my WALLET. Get out of it!", 4.0)
		Meet.add_heat(1.5, "caught in a wallet")
		Meet.say("%s saw exactly what you were doing, and is coming over." % owner.riser_name)
		stir(p, ["Seriously?", "From a wallet?", "Unreal."], 12.0, 0.6, false)
		for r in seen:
			if r != owner:
				r.mind.experience("theft", -0.45, 1.2, true, bag["who"])
		owner.confront()
		return
	var got: int = owner.wallet
	owner.wallet = 0
	owner.wallet_taken = got
	for r in seen:
		r.saw_theft[id + "$"] = true
		r.mind.experience("theft", -0.4, 1.0, false, bag["who"])
	if seen.is_empty():
		Meet.dare("wallet")
		Meet.pay(got, "You lift $%d from %s's wallet. Nobody saw." % [got, bag["who"]])
	else:
		# Whoever saw it goes straight to the owner, and the owner comes for you.
		var w: Node = seen[0]
		w.say_aloud("%s! Your bag! I just watched them go through it!" % owner.first_name.to_upper(), 5.0)
		Meet.pay(got, "You lift $%d from %s's wallet. %s saw you and is shouting for them." % [got, bag["who"], w.first_name])
		Meet.add_heat(1.0, "seen thieving")
		owner.mind.experience("theft", -0.85, 2.5, true, "my wallet")
		owner._mood_check = 0.0
		owner.confront("beef", "")
	Meet.save()

## Two founders are sent to a free table to settle something.
func force_match(a_id: String, b_id: String, tag := "") -> bool:
	var a: Node = Meet.riser(a_id)
	var b: Node = Meet.riser(b_id)
	if a == null or b == null or not a.is_free() or not b.is_free():
		return false
	for i in TABLES.size():
		if table_busy(i) or i == _player_table or _gone_tables.has(i):
			continue
		var total := randf_range(10.0, 16.0)
		_matches.append({"table": i, "a": a, "b": b, "time": total, "total": total, "tag": tag,
			"a_wins": randf() < 1.0 / (1.0 + pow(10.0, (b.strength - a.strength) / 12.0))})
		a.go_pull(TABLES[i] + Vector3(-0.66, 0, 0), TABLES[i])
		b.go_pull(TABLES[i] + Vector3(0.66, 0, 0), TABLES[i])
		a.say_aloud("%s! Table!" % b.first_name, 3.0)
		return true
	return false

## One founder goes over to have a word with, or throw chalk at, another.
func send(a_id: String, b_id: String, then: String) -> void:
	var a: Node = Meet.riser(a_id)
	var b: Node = Meet.riser(b_id)
	if a == null or b == null or not a.is_free() or a.state == "huddle":
		return
	a._partner = b
	a._qlines = People.QUIRK["prank"]
	a._go(b.global_position + Vector3(1.4, 0, 0.8), then)

func bag_spot(id: String) -> Vector3:
	var at: Vector3 = _bags[id]["at"]
	return at * (1.0 - 0.9 / at.length())

func strap_back(id: String) -> void:
	_bags[id]["strap"].visible = true
	_bags[id]["thing"]._text = "Take the strap from %s's bag" % _bags[id]["who"]

## Hand in someone's bag. Whether it works depends on who is looking this way.
## Who is looking at the player right now. In the dark, nobody.
func watchers(p: Vector3, radius := 10.0) -> Array:
	if Meet.dark > 0.0:
		return []
	return Meet.risers.filter(func(r): return r.is_riser and r.state != "winded" and (r.global_position.distance_to(p) < 3.5 or (r.global_position.distance_to(p) < radius + 2.0 and r.facing(p))))

func _strap_take(id: String) -> void:
	var bag: Dictionary = _bags[id]
	var owner: Node = Meet.riser(id)
	if Meet.straps.has(id):
		Meet.straps.erase(id)
		strap_back(id)
		Meet.say("You drop the strap back in %s's bag. Nobody need ever know." % bag["who"])
		if owner.strap_known_gone:
			owner.strap_known_gone = false
			owner.strength += 5.0
		Meet.touch_state()
		return
	var p: Vector3 = Meet.player.global_position
	Meet.player.act("Fixing_Kneeling", 1.0)
	var seen: Array = watchers(p)
	if seen.has(owner):
		owner.mind.experience("theft", -0.7, 2.2, true, "my strap")
		owner._mood_check = 0.0
		owner.say_aloud("Oi! Out of my bag!", 4.0)
		Meet.add_heat(0.8, "caught in a bag")
		Meet.say("%s is looking right at you. You take your hand out of the bag. They're coming over." % owner.riser_name)
		owner.confront()
		return
	Meet.straps.append(id)
	bag["strap"].visible = false
	bag["thing"]._text = "Put %s's strap back" % bag["who"]
	if seen.is_empty():
		Meet.dare("strap")
		Meet.straps_lifted += 1
		Meet.say("%s's strap is in your pocket. Nobody saw. It'll help your grip at the table." % bag["who"])
		if Meet.straps_lifted >= 3:
			Meet.grant("strap_scarf")
	else:
		for r in seen:
			r.saw_theft[id] = true
			r.mind.experience("theft", -0.25, 0.6, false, bag["who"])
		seen[0].say_aloud("...Hm.", 3.0)
		Meet.say("%s's strap is in your pocket. %s watched you do it and said nothing. For now." % [bag["who"], seen[0].first_name])
	Meet.save()
	Meet.touch_state()

func _hide_chalk() -> void:
	if Meet.chalk_hidden > 0.0:
		Meet.say("It's already gone. You did that.")
		return
	var p: Vector3 = Meet.player.global_position
	for r in Meet.risers:
		if r.is_riser and r.state != "winded" and r.global_position.distance_to(p) < 9.0 and r.facing(p):
			r.say_aloud("Oi. Leave the chalk where it is.", 4.0)
			r.mind.experience("nagged", -0.15, 0.6)
			Meet.add_heat(0.5, "caught at the chalk")
			return
	Meet.player.act("PickUp_Table", 0.9)
	Meet.chalk_hidden = 50.0
	Meet.dare("hide")
	for m in _bucket:
		m.visible = false
	Meet.add_heat(0.3)
	Meet.say("You tuck the chalk bucket behind a banner. Nobody saw. This will cause problems.")

func _bait_gulls() -> void:
	if Meet.snacks <= 0:
		Meet.say("You've no snack to throw.")
		return
	Meet.snacks -= 1
	Meet.player.act("Punch_Jab", 0.6)
	Meet.touch_state()
	if _gulls != null:
		Meet.say("They're already here.")
		return
	Meet.add_heat(0.4, "feeding the gulls")
	Meet.say("You lob a snack straight up. Somewhere over the water, something notices.")
	start_gulls()

## Put a strap you are carrying into somebody else's bag.
func _strap_plant(id: String) -> void:
	var mine: Array = Meet.straps.filter(func(x): return x != id)
	if mine.is_empty():
		Meet.say("You've no strap on you to plant. Lift one from another bag first.")
		return
	var whose: String = mine[0]
	var p: Vector3 = Meet.player.global_position
	Meet.player.act("Fixing_Kneeling", 1.0)
	Meet.straps.erase(whose)
	Meet.planted[whose] = id
	var seen := false
	for r in Meet.risers:
		if r.is_riser and r.state != "winded" and r.global_position.distance_to(p) < 10.0 and r.facing(p):
			r.saw_theft[whose] = true
			seen = true
	Meet.dare("plant")
	Meet.say("%s's strap is now in %s's bag.%s" % [_bags[whose]["who"], _bags[id]["who"], " Somebody was looking this way." if seen else " Nobody saw. Wait for it."])
	Meet.touch_state()

func _chalk_up() -> void:
	if Meet.chalk_hidden > 0.0:
		Meet.say("There's no chalk. Somebody hid the bucket. You.")
		return
	Meet.player.gesture("chalk", 2.2, CHALK + Vector3(0, 1, 0), func():
		Meet.chalked = true
		Fx.burst(self, Meet.player.global_position - Meet.player.global_transform.basis.z * 0.35 + Vector3(0, 1.25, 0), Vector3.UP, false, 14)
		Meet.say("You chalk your hands. The gold zone will be wider in your next pull.")
		Meet.touch_state())

func _chalk_take() -> void:
	if Meet.chalk_hidden > 0.0:
		Meet.say("There's no chalk. Somebody hid the bucket. You.")
		return
	if Meet.chalk >= 3:
		Meet.say("That's as much chalk as two hands can hold.")
		return
	Meet.chalk += 1
	Meet.say("A handful of chalk. Throw it at somebody (%s)." % ("CHALK" if Meet.touch else "G"))
	Meet.touch_state()

## A thrown handful: a white ball that bursts where it lands.
func puff(from: Vector3, to: Vector3, landed: Callable, time := 0.35) -> void:
	var ball := Build.sphere(self, 0.12, from, Color(1, 1, 1))
	var tw := create_tween()
	tw.tween_property(ball, "position", to, time)
	tw.tween_callback(func():
		Meet.sfx("puff", -2.0, randf_range(0.9, 1.1))
		Fx.burst(self, ball.position, Vector3.UP, false, 16)
		ball.queue_free()
		landed.call())

## The player has hit a member of the public.
func public_hit(who: Node) -> void:
	Meet.scraps += 1
	Meet.say("%s runs for it. The whole meet saw that." % who.riser_name)
	Meet.add_heat(2.0, "hitting the public")
	stir(who.global_position, ["Did you see that?", "That's a member of the public!", "What is WRONG with them?"], 16.0, 0.7, false)
	warn("Why did you do that? That was a member of the PUBLIC. We lose this venue if someone complains.")
	if Meet.scraps >= 3:
		Meet.hud.night_over("That's three. Harry walks you to the gate himself.\n\n\"Go home. Come back next week with your head on straight.\"")

func _find(item: String, label: String, at: Vector3, c: Color) -> void:
	if Meet.owned.has(item):
		return
	var th := Thing.new()
	add_child(th)
	th.position = at
	if item == "cone":
		Build.cyl(th, 0.03, 0.2, 0.5, Vector3(0, 0.25, 0), c, 10)
		Build.box(th, Vector3(0.42, 0.03, 0.42), Vector3(0, 0.02, 0), c)
	else:
		Build.cyl(th, 0.045, 0.045, 1.5, Vector3(0, 0.05, 0), c, 8).rotation.z = PI / 2.0
	th.setup(label, func():
		Meet.grant(item)
		th.queue_free())

## Rhodes behind the seating: apartment towers with their lights coming on, and the bridge.
func _skyline() -> void:
	var img := Image.create(16, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 16:
			var lit := randf() < 0.45 and x % 4 == 1 and y % 3 == 1
			img.set_pixel(x, y, Color(1.0, 0.82, 0.5) if lit else Color(0.08, 0.1, 0.16))
	var tex := ImageTexture.create_from_image(img)
	for i in 14:
		var w := randf_range(12, 22)
		var h := randf_range(35, 95)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.14, 0.16, 0.24)
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 1.1
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_scale = Vector3(w / 14.0, h / 16.0, 1)
		m.disable_fog = true
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, w * 0.8)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = Vector3(-130 + i * 20 + randf_range(-5, 5), h / 2.0 - 1.0, randf_range(-70, -120))
	var dark := Color(0.12, 0.13, 0.18)
	Build.box(self, Vector3(260, 1.2, 6), Vector3(0, 9, 150), dark)
	for i in 9:
		Build.box(self, Vector3(3, 12, 5), Vector3(-120 + i * 30, 3, 150), dark)

# --- People ----------------------------------------------------------------------------

func _people() -> void:
	for d in People.FOUNDERS:
		_add(d, true)
	for d in People.STAFF:
		var st: Node3D = RiserScript.new()
		add_child(st)
		st.setup(d, false, d["at"])
		st.set_post(ground(d["at"]), d["yaw"])
		Meet.risers.append(st)
	# This week's visitor.
	var g: Dictionary = People.GUESTS[Meet.week() % People.GUESTS.size()]
	_add(g, false)
	Meet.risers[-1].join_meet()
	Meet.risers[-1].wants_pull = false
	# Strangers you talked into it on earlier visits are members now.
	for pid in Meet.joined:
		for d in People.PASSERS:
			if d["id"] == pid:
				var m: Dictionary = d.duplicate()
				m["role"] = "Joined because of you"
				_add(m, false)
				Meet.risers[-1].recruited = true
				Meet.risers[-1].join_meet()
				Meet.risers[-1].wants_pull = false
	var rumour: String = People.RUMOURS[Meet.week() % People.RUMOURS.size()]
	if not _events.any(func(e): return e["kind"] == rumour):
		_events.append({"at": randf_range(200.0, 520.0), "kind": rumour})
	var f: Dictionary = People.FINDS[Meet.week() % People.FINDS.size()]
	if not Meet.owned.has(f["item"]):
		drop([f["item"]], f["at"])

func _add(d: Dictionary, is_riser: bool) -> void:
	var r: Node3D = RiserScript.new()
	add_child(r)
	var a := randf() * TAU
	r.setup(d, is_riser, ground(Vector3(cos(a) * randf_range(3, 8), 0, sin(a) * randf_range(3, 8) + 2.0)))
	Meet.risers.append(r)

func free_risers() -> Array:
	var out: Array = []
	for r in Meet.risers:
		if r.is_free():
			out.append(r)
	return out

func table_busy(i: int) -> bool:
	for m in _matches:
		if m["table"] == i:
			return true
	return false

func match_on() -> bool:
	return not _matches.is_empty()

func nearest_match(p: Vector3) -> int:
	var best := -1
	for m in _matches:
		if best < 0 or TABLES[m["table"]].distance_to(p) < TABLES[best].distance_to(p):
			best = m["table"]
	return best

func _process(dt: float) -> void:
	if Meet.modal:
		return
	_clock += dt
	Meet.clock += dt
	_dusk()
	if Meet.clock >= NIGHT:
		Meet.clock = NIGHT
		Meet.last_recap = "Last time: %d won, %d lost, standing %s, $%d in your pocket." % [Meet.results.filter(func(t): return t.begins_with("You beat")).size(), Meet.results.filter(func(t): return t.ends_with("beat you")).size(), Meet.standing().to_lower(), Meet.money]
		if Meet.peak_heat >= 3:
			Meet.dare("survive")
		Meet.sfx("whistle")
		Meet.hud.night_over(_summary(), "HALF PAST SEVEN")
		return
	for ev in _events.duplicate():
		if Meet.clock >= ev["at"] and _ufo_state in ["", "gone"] and (_drone == null or _drone_t < 0.0) and _gulls == null:
			_events.erase(ev)
			call("start_" + ev["kind"])
			break
	_tune(dt)
	# Heat cools with time; a hidden bucket turns up again.
	if Meet.heat > 0.0:
		var st: int = Meet.stars()
		Meet.heat = max(0.0, Meet.heat - dt / 70.0)
		if Meet.stars() != st:
			Meet.touch_state()
	if Meet.chalk_hidden > 0.0:
		Meet.chalk_hidden -= dt
		if Meet.chalk_hidden <= 0.0:
			for m in _bucket:
				m.visible = true
			var h: Node = Meet.riser("harry")
			if h:
				h.say_aloud("Found the chalk. Behind a banner. WHO did this?", 5.0)
			stir(CHALK, ["Not me.", "Tommy?", "Wasn't me!", "Classic."], 12.0, 0.6, false)
	if _gulls != null:
		Meet.sfx("gull", -12.0, randf_range(0.9, 1.15), 3.5)
	# George notices when the club is taking to you.
	_reward -= dt
	if _reward <= 0.0:
		_reward = 3.0
		var george: Node = Meet.riser("george")
		for mark in [60, 70, 80, 90]:
			if Meet.reputation() >= mark and not Meet.paid.has(str(mark)) and george and george.is_free() and george.mood_level() >= 0:
				Meet.paid[str(mark)] = true
				george._convo = {}
				george._partner = null
				george.say_aloud("Oi, %s! Come here a sec." % Meet.you("you"), 4.0)
				george._give = func():
					george.say_aloud("Well done, man. Get yourself a drink.", 5.0)
					lob(george.global_position + Vector3(0, 1.3, 0), Meet.player.global_position + Vector3(0, 1.2, 0), Color(0.95, 0.6, 0.3), func():
						Meet.player.act("PickUp_Table", 0.8)
						Meet.pay(10, "George presses a tenner into your hand.")
						Meet.save())
				george._go(Meet.player.global_position + (george.global_position - Meet.player.global_position).normalized() * 1.3, "give")
				break
	_run_drone(dt)
	_run_gulls(dt)
	_run_food_fight(dt)
	_run_pets(dt)
	for i in TABLES.size():
		var on := false
		for m in _matches:
			if m["table"] == i and m["a"].at_table() and m["b"].at_table():
				on = true
				var prog: float = 1.0 - float(m["time"]) / float(m["total"])
				_rigs[i]["target"] = (1.0 if m["a_wins"] else -1.0) * prog * prog * 1.15 + sin(_clock * 1.7 + i * 2.0) * 0.3 * (1.0 - prog)
		var helper: Node = _rigs[i]["helper"]
		var can := false
		for m in _matches:
			if m["table"] == i and on and not m.get("strapped", false):
				can = true
		if can != helper.is_in_group("interact"):
			if can:
				helper.add_to_group("interact")
			else:
				helper.remove_from_group("interact")
		if i != _player_table:
			if on and not _rigs[i]["root"].visible:
				for m in _matches:
					if m["table"] == i:
						_rigs[i]["a"] = m["a"]._figure
						_rigs[i]["b"] = m["b"]._figure
						_rigs[i]["lean"] = 0.0
				_rigs[i]["root"].visible = true
			elif not on and _rigs[i]["root"].visible:
				_rig_off(i)
		if _rigs[i]["root"].visible:
			_pose_rig(i, dt)
	_director -= dt
	# People go past along the water all evening.
	_passer -= dt
	if _passer <= 0.0 and _ufo_state in ["", "gone"]:
		_passer = randf_range(9.0, 20.0)
		if _passer_pool.is_empty():
			_passer_pool = People.PASSERS.duplicate()
			_passer_pool.shuffle()
		var d: Dictionary = _passer_pool.pop_back()
		if Meet.riser(d["id"]) == null and not Meet.joined.has(d["id"]):
			var r: Node3D = RiserScript.new()
			add_child(r)
			r.setup(d, false, Vector3.ZERO)
			r.pass_by(1.0 if randf() < 0.5 else -1.0)
			Meet.risers.append(r)
	if _director <= 0.0:
		_director = randf_range(5.0, 10.0)
		_start_match()
	for m in _matches.duplicate():
		if not (m["a"].at_table() and m["b"].at_table()):
			continue
		m["time"] -= dt
		if m["time"] <= 0.0:
			_end_match(m)
	_run_ufo(dt)

## Two people with nothing to do go to a free table and pull.
func _start_match() -> void:
	var idle := free_risers().filter(func(r): return (r.is_riser or r.guest) and r.tonight.get("id", "") != "sore" and r.state != "huddle")
	if idle.size() < 2:
		return
	var keen := idle.filter(func(r): return r.wants_pull)
	if keen.is_empty() and randf() < 0.6:
		return
	for i in TABLES.size():
		if table_busy(i) or i == _player_table or _gone_tables.has(i):
			continue
		idle.shuffle()
		keen.shuffle()
		var a: Node3D = keen[0] if not keen.is_empty() else idle[0]
		var b: Node3D = keen[1] if keen.size() > 1 else idle.filter(func(r): return r != a)[0]
		var total := randf_range(9.0, 16.0)
		_matches.append({"table": i, "a": a, "b": b, "time": total, "total": total,
			"a_wins": randf() < 1.0 / (1.0 + pow(10.0, (b.strength - a.strength) / 12.0))})
		a.go_pull(TABLES[i] + Vector3(-0.66, 0, 0), TABLES[i])
		b.go_pull(TABLES[i] + Vector3(0.66, 0, 0), TABLES[i])
		return

func _end_match(m: Dictionary) -> void:
	_matches.erase(m)
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	var a_wins: bool = m["a_wins"]
	var winner: Node3D = a if a_wins else b
	var loser: Node3D = b if a_wins else a
	Meet.results.append("%s beat %s" % [winner.first_name, loser.first_name])
	Meet.bump(winner.id, loser.id, 0.03 if loser.mind.grudge < 1.05 else -0.04)
	evening.match_ended(m, winner)
	winner.finish_pull(true)
	loser.finish_pull(false)
	for r in Meet.risers:
		if r.state == "watch" and r.global_position.distance_to(TABLES[m["table"]]) < 6.0:
			r.say_aloud(["Ohh!", "Good pull!", "Big %s!" % winner.first_name, "Again, again!"][randi() % 4])

## The player pulled someone away from a table, or a scrap broke out: abandon the match.
func drop_match(r: Node) -> void:
	for m in _matches.duplicate():
		if m["a"] == r or m["b"] == r:
			_matches.erase(m)
			for o in [m["a"], m["b"]]:
				if o != r and o.state in ["to_table", "pull"]:
					o.idle()

## A scrap between the player and someone has ended, one way or the other.
func scrap_over(who: Node, player_won: bool) -> void:
	if player_won:
		Meet.say("%s sits down hard, winded. Everyone has stopped to stare at you, and they won't forget it." % who.riser_name)
	else:
		Meet.say("You sit down hard on the paving. %s stands over you, then walks off." % who.riser_name)
		who.mind.experience("scrap", 0.25, 0.8, true, "")
		who.idle()
	if player_won:
		Meet.add_heat(1.5, "flooring a member")
		warn("You put %s on the floor. At a club meet. What were you thinking?" % who.first_name, who)
	Meet.save()
	if Meet.scraps >= 3:
		Meet.hud.night_over("That's three. Harry walks you to the gate himself.\n\n\"Go home. Come back next week with your head on straight.\"")

func _grab_snack() -> void:
	if Meet.snacks >= 5:
		Meet.say("You've got as many as you can carry.")
		return
	if _free_snacks <= 0:
		if Meet.money < 2:
			Meet.say("You've had your three free ones. After that it's $2 in the tin, and you have $%d." % Meet.money)
			return
		Meet.pay(-2)
	_free_snacks -= 1
	Meet.snacks += 1
	Meet.sfx("crunch", -6.0)
	Meet.player.act("PickUp_Table", 0.9)
	Meet.say("You take a snack. That's %d. Eat one from your bag (%s) to get your breath back." % [Meet.snacks, "BAG" if Meet.touch else "R"])
	Meet.touch_state()

# --- Visitors from the sky ---------------------------------------------------------------

func start_ufo() -> void:
	if _ufo_state != "":
		return
	_ufo_state = "descend"
	_ufo = Node3D.new()
	add_child(_ufo)
	_ufo.position = Vector3(0, 60, 40)
	Build.cyl(_ufo, 1.2, 4.2, 0.7, Vector3(0, 0, 0), Color(0.55, 0.6, 0.66), 18)
	Build.cyl(_ufo, 4.2, 2.6, 0.5, Vector3(0, -0.6, 0), Color(0.4, 0.44, 0.5), 18)
	Build.sphere(_ufo, 1.5, Vector3(0, 0.5, 0), Color(0.5, 1.0, 0.8), 1.2).scale = Vector3(1, 0.7, 1)
	for i in 10:
		var a := TAU * i / 10.0
		Build.sphere(_ufo, 0.2, Vector3(cos(a) * 3.6, -0.5, sin(a) * 3.6), [Color(0.3, 1.0, 0.5), Color(1.0, 0.3, 0.8)][i % 2], 1.5)
	var beam := OmniLight3D.new()
	beam.light_color = Color(0.5, 1.0, 0.7)
	beam.light_energy = 4.0
	beam.omni_range = 22.0
	_ufo.add_child(beam)
	beam.position = Vector3(0, -2, 0)
	Meet.audio.loop("ufo", true, -12.0)
	Meet.hud.banner("SOMETHING IN THE SKY", "It is not a drone. It is not Tommy.")
	Meet.say("Everyone has stopped talking. Something is coming down over the water.")
	for r in Meet.risers:
		r.say_aloud(["What is THAT?", "Is that... no.", "Are you seeing this?", "..."][randi() % 4], 4.0)

func _run_ufo(dt: float) -> void:
	if _ufo_state == "":
		return
	if _ufo_state == "descend":
		_ufo.position = _ufo.position.move_toward(Vector3(0, 4.5, 16), dt * 14.0)
		_ufo.rotation.y += dt * 1.5
		if _ufo.position.distance_to(Vector3(0, 4.5, 16)) < 0.2:
			_ufo_state = "landed"
			for i in 4:
				var al: Node3D = RiserScript.new()
				add_child(al)
				al.setup(People.ALIEN, false, Vector3(-3.6 + i * 2.4, 0, 15))
				al.alien = true
				al.composure = 150.0
				_aliens.append(al)
				Fx.burst(self, al.global_position + Vector3(0, 1, 0), Vector3.UP, false, 14)
			Meet.say("Four small, cross-looking visitors have got out. They do not seem to be here for the arm wrestling. They hit hard and they shoot.")
			for r in Meet.risers:
				drop_match(r)
				r.aliens_arrive()
	elif _ufo_state == "landed":
		_ufo.rotation.y += dt * 0.6
		var up := 0
		for al in _aliens:
			if al.state != "winded":
				up += 1
		if up == 0:
			_ufo_state = "open"
			_ufo_wait = 45.0
			Meet.seen_ufo = true
			Meet.hud.banner("THE RAMP IS DOWN", "The ship is just sitting there. Nobody is guarding it.")
			Meet.say("That's the last of them. The ship hasn't left. The ramp is down and there's a light on inside.")
			for r in Meet.risers:
				r.aliens_gone()
			_ramp = Thing.new()
			add_child(_ramp)
			_ramp.position = Vector3(0, 0, 14.6)
			Build.box(_ramp, Vector3(1.6, 0.08, 3.4), Vector3(0, 1.3, 0.2), Color(0.5, 0.55, 0.6), false, 0.3).rotation.x = -0.75
			_ramp.setup("Go up the ramp into the ship", board_ship)
			Meet.save()
	elif _ufo_state == "open":
		_ufo.rotation.y += dt * 0.3
		if not _aboard:
			_ufo_wait -= dt
			if _ufo_wait <= 0.0:
				Meet.say("The ramp folds up by itself. Whatever was in there is leaving with it.")
				_lift_off()
	elif _ufo_state == "leave":
		_ufo.position += Vector3(0, dt * 16.0, dt * 6.0)
		_ufo.rotation.y += dt * 4.0
		for al in _aliens:
			if is_instance_valid(al):
				al.global_position = al.global_position.move_toward(_ufo.global_position, dt * 12.0)
		if _ufo.position.y > 70.0:
			Meet.audio.loop("ufo", false)
			for al in _aliens:
				al.queue_free()
			_aliens.clear()
			_ufo.queue_free()
			_ufo_state = "gone"

## True while the visitors are on the ground.
func invaded() -> bool:
	return _ufo_state in ["descend", "landed"]

func _lift_off() -> void:
	if is_instance_valid(_ramp):
		_ramp.queue_free()
	Meet.player.target = null
	_ufo_state = "leave"

## A green bolt from a visitor.
func bolt(from: Vector3, to: Vector3, landed: Callable) -> void:
	var b := Build.sphere(self, 0.13, from, Color(0.5, 1.0, 0.6), 2.5)
	var tw := create_tween()
	tw.tween_property(b, "position", to, max(0.2, from.distance_to(to) / 16.0))
	tw.tween_callback(func():
		Fx.burst(self, b.position, Vector3.UP, false, 6)
		b.queue_free()
		landed.call())

## One of them is down. They always drop something.
func alien_down(al: Node) -> void:
	_alien_drops += 1
	var at: Vector3 = al.global_position + Vector3(0.6, 0, 0.4)
	Meet.sfx("zap", -4.0, 0.6)
	if _alien_drops == 1 and not (Meet.owned.has("antennae") and Meet.owned.has("raygun")):
		drop(["antennae", "raygun"], at)
	elif randf() < 0.5:
		_coin(at, [5, 5, 20][randi() % 3])
	else:
		pickup("a glowing snack from another world", at, Color(0.4, 1.0, 0.6), func():
			Meet.snacks = min(5, Meet.snacks + 2)
			Meet.composure = min(100.0, Meet.composure + 25.0)
			Meet.say("It tastes like lime and static. You feel much better. (+2 snacks, health up.)")
			Meet.touch_state())

## Inside the ship: one round room, a console, and something on a plinth.
func board_ship() -> void:
	if _aboard:
		return
	_aboard = true
	_board_from = Meet.player.global_position
	if _cabin == null:
		_cabin = Node3D.new()
		add_child(_cabin)
		_cabin.position = Vector3(0, 300, 0)
		var wall := Color(0.3, 0.36, 0.42)
		Build.cyl(_cabin, 5.5, 5.5, 0.2, Vector3(0, -0.1, 0), Color(0.22, 0.26, 0.3), 20, true)
		Build.cyl(_cabin, 5.5, 3.0, 0.2, Vector3(0, 3.6, 0), wall, 20)
		for i in 20:
			var a := TAU * i / 20.0
			var p := Build.box(_cabin, Vector3(1.8, 3.6, 0.2), Vector3(cos(a) * 5.4, 1.8, sin(a) * 5.4), wall, true)
			p.rotation.y = -a + PI / 2.0
			Build.box(_cabin, Vector3(0.5, 0.12, 0.05), Vector3(cos(a) * 5.25, 1.6 + (i % 3) * 0.5, sin(a) * 5.25), [Color(0.3, 1.0, 0.5), Color(1.0, 0.3, 0.8), Color(0.4, 0.7, 1.0)][i % 3], false, 2.0).rotation.y = -a + PI / 2.0
		Build.cyl(_cabin, 0.9, 1.1, 0.9, Vector3(0, 0.45, -3.4), Color(0.4, 0.45, 0.5), 10, true)
		for i in 6:
			Build.sphere(_cabin, 0.08, Vector3(-0.5 + i * 0.2, 0.95, -3.4), [Color(1, 0.2, 0.2), Color(0.2, 1, 0.3), Color(1, 0.9, 0.2)][i % 3], 2.0)
		Build.cyl(_cabin, 0.4, 0.55, 1.0, Vector3(0, 0.5, 0), Color(0.15, 0.15, 0.2), 10, true)
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 1.0, 0.8)
		l.light_energy = 2.2
		l.omni_range = 12.0
		l.position = Vector3(0, 3.0, 0)
		_cabin.add_child(l)
		for sx in [-1.0, 1.0]:
			Build.box(_cabin, Vector3(0.7, 1.2, 0.5), Vector3(sx * 3.2, 0.6, 2.0), Color(0.3, 0.9, 0.5), false, 0.3)
		var hatch := Thing.new()
		_cabin.add_child(hatch)
		hatch.position = Vector3(0, 0, 4.2)
		Build.box(hatch, Vector3(1.6, 0.05, 1.2), Vector3(0, 0.03, 0), Color(0.9, 0.9, 0.4), false, 1.0)
		hatch.setup("Climb back down the ramp", leave_ship)
		if not Meet.owned.has("golden_grip"):
			var th := Thing.new()
			_cabin.add_child(th)
			th.position = Vector3(0, 1.0, 0.75)
			var m: Node3D = Wear.model("golden_grip")
			th.add_child(m)
			m.position = Vector3(0, 0.15, -0.75)
			m.create_tween().set_loops().tween_property(m, "rotation:y", TAU, 4.0).from(0.0)
			var gl := OmniLight3D.new()
			gl.light_color = Color(1.0, 0.85, 0.3)
			gl.light_energy = 3.0
			gl.omni_range = 4.0
			gl.position = Vector3(0, 0.6, -0.75)
			th.add_child(gl)
			th.setup("Take the golden gauntlet off the plinth", func():
				th.remove_from_group("interact")
				Meet.player.target = null
				Meet.player.act("PickUp_Table", 1.0)
				th.queue_free()
				Meet.hud.banner("THE GOLDEN GRIP", "It fits. It hums. Something on the console starts beeping.")
				Meet.sfx("win")
				Meet.grant("golden_grip")
				Meet.ripple("You took something from the ship that the visitors will want back."))
	Meet.player.global_position = _cabin.position + Vector3(0, 0.1, 3.2)
	Meet.player.rotation.y = 0.0
	Meet.sfx("ufo", -6.0, 1.4)
	Meet.hud.banner("ABOARD", "It's bigger on the inside. It smells of lime.")

func leave_ship() -> void:
	if not _aboard:
		return
	_aboard = false
	Meet.player.global_position = ground(Vector3(0, 0, 11.5))
	Meet.player.rotation.y = 0.0
	Meet.say("The moment your foot leaves the ramp it snaps shut behind you.")
	stir(Meet.player.global_position, ["You went IN?", "What's in there?", "Is that... gold?", "You absolute lunatic."], 20.0, 0.8, true)
	_lift_off()

func aliens() -> Array:
	return _aliens.filter(func(a): return is_instance_valid(a) and a.state != "winded")

# --- The clock ----------------------------------------------------------------------------

## The light goes as the evening does: gold at five, dark blue by half past seven.
func _dusk() -> void:
	if Meet.dark > 0.0:
		# A power cut: properly dark. Whatever glows is all there is to see by.
		_sun.light_energy = 0.0
		_env.ambient_light_energy = 0.03
		_sky_mat.sky_top_color = Color(0.0, 0.0, 0.02)
		_sky_mat.sky_horizon_color = Color(0.03, 0.02, 0.05)
		_env.fog_light_color = Color(0.02, 0.02, 0.04)
		return
	_env.fog_light_color = Color(0.7, 0.45, 0.4)
	var f: float = Meet.clock / NIGHT
	_sun.rotation_degrees.x = lerp(-16.0, -2.0, f)
	_sun.light_energy = lerp(0.95, 0.12, f)
	_sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(0.8, 0.4, 0.45), f)
	_env.ambient_light_energy = lerp(0.8, 0.5, f)
	_env.ambient_light_color = Color(0.55, 0.48, 0.58).lerp(Color(0.3, 0.33, 0.6), f)
	_sky_mat.sky_top_color = Color(0.16, 0.2, 0.42).lerp(Color(0.02, 0.03, 0.1), f)
	_sky_mat.sky_horizon_color = Color(1.0, 0.62, 0.36).lerp(Color(0.3, 0.16, 0.3), f)

func _summary() -> String:
	var mates := 0
	var sour := 0
	for r in Meet.risers:
		if r.is_riser and r.bond() in ["mates", "close"]:
			mates += 1
		elif r.is_riser and r.bond() in ["irritated", "gone"]:
			sour += 1
	var changed := ""
	if not Meet.ripples.is_empty():
		changed = "\n\nWhat you changed tonight:\n• " + "\n• ".join(Meet.ripples.slice(0, 7))
	return "Harry calls it. Tables down, chalk swept, snacks gone." + changed + "\n\nTonight: %d pulls won, %d lost. %d of the founders count you a mate; %d would rather you hadn't come. Standing with the club: %s (%d).\n\nSee you next Sunday." % [
		Meet.results.filter(func(t): return t.begins_with("You beat")).size(), Meet.results.filter(func(t): return t.ends_with("beat you")).size(),
		mates, sour, Meet.standing(), Meet.reputation()]

# --- Things that fall out of the sky ---------------------------------------------------------

## Leave something on the ground to be picked up: the first of these the player doesn't own.
func drop(items: Array, at: Vector3) -> void:
	var item := ""
	for it in items:
		if not Meet.owned.has(it):
			item = it
			break
	if item == "":
		Meet.snacks = min(5, Meet.snacks + 2)
		Meet.say("Nothing new this time. But there are two snacks on the ground, which is something.")
		Meet.touch_state()
		return
	var th := Thing.new()
	add_child(th)
	th.position = ground(at)
	var m: Node3D = Wear.model(item)
	th.add_child(m)
	m.position.y = 0.5
	var l := OmniLight3D.new()
	l.light_color = Wear.COLORS.get(item, Color.WHITE)
	l.light_energy = 2.5
	l.omni_range = 4.0
	l.position.y = 0.8
	th.add_child(l)
	m.create_tween().set_loops().tween_property(m, "rotation:y", TAU, 3.0).from(0.0)   # dies with the item
	th.setup("Pick up: %s" % Meet.ITEMS[item]["name"], func():
		th.remove_from_group("interact")
		Meet.player.target = null
		Meet.player.act("PickUp_Table", 0.8)
		th.queue_free()
		Meet.grant(item))

func start_kaiju() -> void:
	evening.start_kaiju()

func start_drone() -> void:
	if _drone != null and _drone_t >= 0.0:
		return
	if _drone != null:
		_drone.queue_free()
	_drone = Node3D.new()
	add_child(_drone)
	Build.box(_drone, Vector3(0.5, 0.12, 0.5), Vector3.ZERO, Color(0.15, 0.15, 0.18))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.cyl(_drone, 0.22, 0.22, 0.02, Vector3(sx * 0.35, 0.08, sz * 0.35), Color(0.6, 0.6, 0.65), 8)
	Build.sphere(_drone, 0.06, Vector3(0, -0.08, 0.2), Color(1.0, 0.1, 0.1), 2.0)
	Meet.audio.loop("drone", true, -16.0)
	_drone.position = Vector3(-30, 14, 20)
	_drone_t = 0.0
	var a := randf() * TAU
	_drone_to = Vector3(cos(a) * 5.0, 0.3, sin(a) * 5.0 + 1.0)
	Meet.hud.banner("INCOMING", "Somebody's drone, and it doesn't sound well.")
	Meet.say("There's a whining noise. Somebody's drone is coming in over the water, and it doesn't sound well.")

func _run_drone(dt: float) -> void:
	if _drone == null or _drone_t < 0.0:
		return
	_drone_t += dt
	if _drone_t < 9.0:
		var a := _drone_t * 1.3
		var want := Vector3(cos(a) * 7.0, 6.0 + sin(_drone_t * 5.0) * 1.2, sin(a) * 7.0 + 2.0)
		_drone.position = _drone.position.lerp(want, min(1.0, dt * 1.5))
		_drone.rotation = Vector3(sin(_drone_t * 7.0) * 0.4, _drone_t * 3.0, cos(_drone_t * 6.0) * 0.4)
		return
	_drone.position = _drone.position.move_toward(_drone_to, dt * 16.0)
	_drone.rotation.x += dt * 9.0
	if _drone.position.distance_to(_drone_to) < 0.2:
		_drone_t = -1.0
		Meet.audio.loop("drone", false)
		Meet.sfx("crash")
		_drone.rotation = Vector3(0.5, 1.0, 2.6)
		Fx.burst(self, _drone_to + Vector3(0, 0.5, 0), Vector3.UP, false, 30)
		Meet.say("The drone has landed. Upside down. In several pieces.")
		for r in Meet.risers:
			if r.state not in ["pull", "winded", "scrap"] and r.global_position.distance_to(_drone_to) < 12.0:
				r.say_aloud(["Whose drone is that?!", "Not mine. That's not mine, right?", "DUCK!", "Is everyone alright?", "That's coming out of someone's bond."][randi() % 5], 4.0)
		drop(["prop_hat"], _drone_to + Vector3(0.9, 0, 0.5))

func start_gulls() -> void:
	if _gulls != null:
		return
	_gulls = Node3D.new()
	add_child(_gulls)
	_gulls.position = SNACKS + Vector3(0, 30, 20)
	for i in 6:
		var b := Node3D.new()
		_gulls.add_child(b)
		Build.box(b, Vector3(0.14, 0.12, 0.36), Vector3.ZERO, Color(0.96, 0.96, 0.96))
		Build.box(b, Vector3(0.05, 0.04, 0.1), Vector3(0, 0.02, 0.22), Color(1.0, 0.7, 0.1))
		for sx in [-1.0, 1.0]:
			var wing := Build.box(b, Vector3(0.42, 0.02, 0.18), Vector3(sx * 0.27, 0.03, 0), Color(0.75, 0.77, 0.8))
			wing.set_meta("side", sx)
	_gulls_t = 0.0
	_gulls_off = false
	Meet.hud.banner("SEAGULLS", "They have seen the snack table.")
	Meet.say("Seagulls. A lot of seagulls. They have seen the snack table.")
	var kelvin: Node = Meet.riser("kelvin")
	if kelvin and kelvin.is_free():
		kelvin.say_aloud("NOT THE SNACKS.", 4.0)
		kelvin._go(SNACKS + Vector3(-1.5, 0, 1.2), "idle")

func _run_gulls(dt: float) -> void:
	if _gulls == null:
		return
	_gulls_t += dt
	var want := SNACKS + Vector3(0, 1.4, 0) if not _gulls_off else SNACKS + Vector3(-20, 40, 50)
	_gulls.position = _gulls.position.move_toward(want, dt * (12.0 if not _gulls_off else 18.0))
	var k := 0
	for b in _gulls.get_children():
		var a := _gulls_t * 2.2 + k * TAU / 6.0
		b.position = Vector3(cos(a) * 1.5, sin(a * 1.7 + k) * 0.5, sin(a) * 1.0)
		b.rotation.y = -a
		for w in b.get_children():
			if w.has_meta("side"):
				w.rotation.z = sin(_gulls_t * 14.0 + k) * 0.7 * float(w.get_meta("side"))
		k += 1
	if _gulls_off:
		if _gulls.position.y > 35.0:
			_gulls.queue_free()
			_gulls = null
		return
	if _gulls.position.distance_to(want) > 1.0:
		return
	if Meet.player.global_position.distance_to(SNACKS) < 3.4:
		_gulls_off = true
		Meet.dare("gulls")
		Meet.say("You run at them waving your arms. It works. One of them drops something on the way out.")
		drop(["golden_chip"], SNACKS + Vector3(-0.6, 0, 1.8))
	elif _gulls_t > 40.0:
		_gulls_off = true
		Meet.say("The seagulls leave when they are ready to leave, and not before. Half the snacks went with them.")

# --- The crowd ----------------------------------------------------------------------------

## Something noteworthy happened: some of the people nearby turn, say something, maybe come over.
func stir(at: Vector3, lines: Array, radius := 12.0, share := 0.6, gather := false) -> void:
	Meet.sfx("ooh", -12.0, randf_range(0.9, 1.1), 4.0)
	for r in Meet.risers:
		if r.alien or r.global_position.distance_to(at) > radius or r.global_position.distance_to(at) < 0.3:
			continue
		if randf() < share:
			r.gawp(at, lines[randi() % lines.size()], gather)
			if at.distance_to(Meet.player.global_position) < 3.0:
				r.stare(4.0)

## The player is picking on someone. Whoever is closest to them, and near enough, steps in.
func defend(victim: Node, kind: String) -> void:
	if not victim.is_riser:
		return
	var best: Node = null
	var v := 0.3
	for r in Meet.risers:
		if r == victim or not r.is_riser or not r.is_free() or r.global_position.distance_to(victim.global_position) > 13.0:
			continue
		var t: float = Meet.tie(victim.id, r.id)
		if t > v:
			v = t
			best = r
	if best != null:
		best.stand_up_for(victim, kind, v)

## Somebody with standing comes over to tell the player off. Once is a warning. Twice is the gate.
func warn(text: String, not_this_one: Node = null) -> void:
	if invaded():
		return
	if Meet.warned:
		Meet.hud.night_over("You were warned once already tonight.\n\nHarry doesn't raise his voice. He just points at the gate. \"Out. We'll talk about whether you come back.\"")
		return
	var pick: Node = null
	for id in ["harry", "george", "bhavya", "erick", "kelvin", "phillip", "luie", "tommy"]:
		var r: Node = Meet.riser(id)
		if r != null and r != not_this_one and r.state not in ["winded", "scrap", "confront", "pull"]:
			pick = r
			break
	if pick != null:
		pick.confront("warn", text)

## The club's patience, as stars. Three: nobody will pull you. Four: a warning. Five: the gate.
func heat_rose(now: int) -> void:
	var harry: Node = Meet.riser("harry")
	if now == 2 and harry:
		harry.say_aloud("I'm watching you.", 4.0)
		harry.stare(3.0)
	elif now == 3:
		stir(Meet.player.global_position, ["Calm down.", "Give it a rest.", "Somebody's going to get thrown out."], 14.0, 0.5, false)
	elif now == 4:
		warn("That's enough. You've been at it all night. One more thing and you're through that gate.")
	elif now >= 5:
		gang_up("Five stars. It took four of them. You are carried to the gate by one limb each, and Tommy holds it open.\n\n\"Go home. Think about what you've done. The chalk bucket has feelings.\"")

## The club has had enough: several of them close in on the player, and that is the night.
func gang_up(text: String) -> void:
	if _ganging:
		return
	_ganging = true
	Meet.menu.close()
	var p: Node3D = Meet.player
	p.caught(6.0)
	Meet.sfx("sting")
	Meet.say("That's it. They're all coming for you at once.")
	var crew: Array = []
	for id in ["harry", "kelvin", "george", "erick", "phillip", "bhavya"]:
		var r: Node = Meet.riser(id)
		if r != null and r.state != "winded" and crew.size() < 4:
			crew.append(r)
	for i in crew.size():
		var a := TAU * i / crew.size()
		var r: Node = crew[i]
		drop_match(r)
		r._convo = {}
		r._stare = 0.0
		r.global_position = clear(p.global_position + Vector3(cos(a), 0, sin(a)) * 5.0)
		r._noticed = true
		r.say_aloud(["RIGHT.", "Get them.", "Enough!", "Hold their arms!"][i % 4], 3.0)
		r.state = "walk"
		r._goal = p.global_position + Vector3(cos(a), 0, sin(a)) * 0.9
		r._then = "swarm"
	p.toggle_view() if not p._orbit else null
	var tw := create_tween()
	tw.tween_interval(1.9)
	tw.tween_callback(func():
		for k in 4:
			Fx.burst(self, p.global_position + Vector3(randf_range(-0.6, 0.6), 1.0, randf_range(-0.6, 0.6)), Vector3.UP, false, 14)
		Meet.sfx("punch")
		Meet.hud.shake()
		p.act("Hit_Chest", 0.7))
	tw.tween_interval(0.7)
	tw.tween_callback(func():
		Meet.sfx("punch", 0.0, 0.8)
		Meet.sfx("ooh", -4.0)
		Meet.hud.shake()
		Fx.burst(self, p.global_position + Vector3(0, 1.2, 0), Vector3.UP, false, 24)
		p.act("Death01", 30.0))
	tw.tween_interval(2.6)
	tw.tween_callback(func():
		_ganging = false
		Meet.hud.night_over(text))

## A piece of the player's kit, left lying somewhere. People notice it.
func leave_item(item: String, at: Vector3) -> void:
	var th := Thing.new()
	add_child(th)
	th.position = ground(at)
	var m: Node3D = Wear.model(item)
	th.add_child(m)
	m.position.y = 0.1
	m.rotation.z = 1.2
	th.setup("Pick your %s back up" % Meet.ITEMS[item]["name"].to_lower(), func():
		th.remove_from_group("interact")
		Meet.player.target = null
		Meet.player.act("PickUp_Table", 0.8)
		Meet.away.erase(item)
		th.queue_free()
		Meet.say("Back in your bag.")
		Meet.touch_state())
	for r in watchers(at, 9.0):
		if randf() < 0.5:
			r.say_aloud(["You can't just leave that there.", "Is that... yours?", "Somebody's going to trip on that.", "Finders keepers?"][randi() % 4], 3.5)
			break

# --- Shouting at everyone, and throwing food --------------------------------------------------------

const SHOUTS := [
	["dance", "\"EVERYBODY DANCE!\"", "EVERYBODY DANCE!"],
	["snacks", "\"FREE SNACKS AT THE GATE!\"", "FREE SNACKS AT THE GATE!"],
	["tables", "\"HARRY SAYS TABLES DOWN!\"", "HARRY SAYS TABLES DOWN!"],
	["hug", "\"GROUP HUG!\"", "GROUP HUG!"],
	["spider", "\"IS THAT A SPIDER?!\"", "IS THAT A SPIDER?!"],
	["race", "\"LAST ONE TO THE WATER'S A NOVICE!\"", "LAST ONE TO THE WATER'S A NOVICE!"],
]
var _shout_cd := 0.0
var _shouts := 0
var _race := 0
var _thrown: Array = []
var _fight := 0.0
var _fight_tick := 0.0

func shout_menu() -> void:
	if Meet.modal:
		return
	if _shout_cd > 0.0:
		Meet.say("You're still hoarse from the last one. Give it %d seconds." % int(ceil(_shout_cd)))
		return
	var opts: Array = []
	for sh in SHOUTS:
		var kind: String = sh[0]
		var text: String = sh[2]
		opts.append([sh[1], func(): shout(kind, text)])
	opts.append(["(Say nothing.)", func(): pass])
	Meet.menu.choice("Cup your hands and shout", "The whole amphitheatre will hear it.", opts)

func shout(kind: String, text: String) -> void:
	_shout_cd = 16.0
	_shouts += 1
	Meet.player.act("Punch_Jab", 0.7)
	Meet.sfx("whistle", -8.0, 0.6)
	Meet.hud.banner(text, "")
	Meet.dare("shout")
	if _shouts > 2:
		Meet.add_heat(0.5, "shouting the place down")
	var i := 0
	for r in Meet.risers:
		if r.global_position.distance_to(Meet.player.global_position) < 34.0:
			r.shouted(kind, i)
			i += 1
	match kind:
		"snacks":
			Meet.ripple("You sent the whole club to the gate for snacks that weren't there.")
			Meet.say("They've all gone. Every bag in the amphitheatre is unattended for the next little while.")
		"tables":
			for m in _matches.duplicate():
				drop_match(m["a"])
			var h: Node = Meet.riser("harry")
			if h:
				h.mind.experience("heckle", -0.3, 0.9, true, "the shouting")
		"race":
			_race = 0
			Meet.say("They're off. Get to the railing first and it's you who isn't the novice.")

## Someone has reached the water in the race.
func race_arrival(r: Node) -> void:
	_race += 1
	if _race == 1:
		if Meet.player.global_position.z > 25.0:
			Meet.hud.banner("YOU WIN THE RACE", "%s comes second and wants a recount." % r.first_name.capitalize())
			Meet.pay(5, "Winner's purse, by acclamation.")
			for x in Meet.risers:
				if x.is_riser:
					x.mind.experience("match", 0.15, 0.4, false, "the race")
		else:
			r.say_aloud("FIRST! Not a novice! NOT A NOVICE!", 4.0)
			Meet.hud.banner("%s WINS" % r.first_name.to_upper(), "You, technically, are the novice.")

## A thrown thing that arcs.
func lob(from: Vector3, to: Vector3, c: Color, landed: Callable) -> void:
	var ball := Build.box(self, Vector3(0.14, 0.1, 0.1), from, c)
	var tw := create_tween()
	tw.tween_method(func(f: float):
		ball.position = from.lerp(to, f) + Vector3(0, sin(f * PI) * 1.4, 0)
		ball.rotation.x = f * 9.0, 0.0, 1.0, 0.45)
	tw.tween_callback(func():
		ball.queue_free()
		landed.call())

func food_fight() -> bool:
	return _fight > 0.0

## The player has thrown a snack. Three inside half a minute and nobody can stop what happens next.
func snack_thrown() -> void:
	var now := Meet.clock
	_thrown.append(now)
	_thrown = _thrown.filter(func(t): return now - t < 30.0)
	if _thrown.size() >= 3 and _fight <= 0.0:
		_thrown.clear()
		_fight = 22.0
		_fight_tick = 0.0
		Meet.hud.banner("FOOD FIGHT", "Nobody knows who started it. (You started it.)")
		Meet.sfx("ooh")
		Meet.dare("foodfight")
		Meet.ripple("You started a food fight at an arm wrestling meet.")
		for m in _matches.duplicate():
			drop_match(m["a"])
		var h: Node = Meet.riser("harry")
		if h:
			h.say_aloud("NOT THE SNACKS! WHO STARTED THIS?!", 5.0)

func _run_food_fight(dt: float) -> void:
	_shout_cd = max(0.0, _shout_cd - dt)
	if _fight <= 0.0:
		return
	_fight -= dt
	_fight_tick -= dt
	if _fight_tick <= 0.0:
		_fight_tick = 0.28
		var pool: Array = Meet.risers.filter(func(r): return not r.alien and r.state not in ["winded", "ride", "pull"] and r.id != "phillip")
		if pool.size() >= 2:
			var a: Node = pool[randi() % pool.size()]
			var b: Node = Meet.player if randf() < 0.22 else pool[randi() % pool.size()]
			if a != b:
				a.throw_at(b)
				if randf() < 0.18:
					a.say_aloud(["TAKE THAT!", "For the red ones!", "I've wanted to do this for YEARS.", "Not the face!", "Reload! RELOAD!", "This is the best meet ever."][randi() % 6], 2.2)
	if _fight <= 0.0:
		_free_snacks = 0
		Meet.hud.banner("CEASEFIRE", "The snack table is empty. Everyone is wearing it.")
		var h: Node = Meet.riser("harry")
		var ph: Node = Meet.riser("phillip")
		if ph:
			ph.say_aloud("...I trained through all of that.", 5.0)
		for r in Meet.risers:
			if r.is_riser and r.id not in ["harry", "phillip"]:
				r.mind.experience("chalk", 0.3, 0.8, true, "the food fight")
		if h:
			h.mind.experience("heckle", -0.4, 1.2, true, "the food fight")
			Meet.add_heat(1.2, "starting a food fight")
			h.say_aloud("Whoever started this is sweeping. ALL of it.", 5.0)

# --- Keeping it smooth ----------------------------------------------------------------------------

const QUALITY := [[1.0, true], [0.8, false], [0.65, false], [0.5, false]]   # 3D resolution, shadows
var _fps_t := 0.0
var _fps_n := 0
var _fps_wait := 6.0
var fps := 60.0

func apply_quality() -> void:
	var q: Array = QUALITY[clamp(Meet.quality, 0, QUALITY.size() - 1)]
	get_viewport().scaling_3d_scale = q[0]
	_sun.shadow_enabled = q[1] and not Meet.touch

## Watch the frame rate and give up sharpness before smoothness.
func _tune(dt: float) -> void:
	_fps_t += dt
	_fps_n += 1
	if _fps_t < 2.5:
		return
	fps = _fps_n / _fps_t
	_fps_t = 0.0
	_fps_n = 0
	if _fps_wait > 0.0:
		_fps_wait -= 2.5
		return
	if not Meet.quality_auto:
		return
	if fps < 27.0 and Meet.quality < QUALITY.size() - 1:
		Meet.quality += 1
		_fps_wait = 5.0
		apply_quality()
		Meet.save()
	elif fps > 57.0 and Meet.quality > 0 and _clock > 60.0 and not Meet.touch:
		Meet.quality -= 1
		_fps_wait = 20.0
		apply_quality()

# --- The lions ---------------------------------------------------------------------------------------

## Something heavy enough hits a statue. Returns true if one was close enough to break.
func smash(at: Vector3) -> bool:
	for holder in _lions:
		if holder.visible and holder.position.distance_to(at) < 2.6:
			holder.visible = false
			for k in 8:
				Fx.burst(self, holder.position + Vector3(randf_range(-0.6, 0.6), 0.6 + k * 0.15, randf_range(-0.6, 0.6)), Vector3.UP, false, 14)
			for k in 7:
				var rub := Build.tbox(self, Vector3(randf_range(0.15, 0.4), randf_range(0.1, 0.3), randf_range(0.15, 0.4)), holder.position + Vector3(randf_range(-0.9, 0.9), 0.1, randf_range(-0.9, 0.9)), "stone", Color(0.7, 0.7, 0.72))
				rub.rotation = Vector3(randf(), randf(), randf())
			Meet.sfx("crash")
			Meet.hud.shake()
			Meet.hud.banner("THE LION CRACKS OPEN", "Something inside it stretches, yawns, and looks at you.")
			Meet.lions += 1
			Meet.add_heat(1.5, "smashing a guardian lion")
			Meet.ripple("You broke a stone lion at the gate and something alive came out of it.")
			_free_lion(holder.position)
			stir(holder.position, ["THE LION!", "That's council property!", "...Is it MOVING?", "It's alive. The lion is alive.", "Harry is going to lose his mind."], 40.0, 0.9, true)
			var harry: Node = Meet.riser("harry")
			if harry:
				harry.say_aloud("That lion has been there since BEFORE the club. ...Why is it purring?", 6.0)
			Meet.save()
			return true
	return false

func _free_lion(at: Vector3) -> void:
	var pet := Node3D.new()
	add_child(pet)
	pet.position = ground(at)
	Asia.lion(pet, Vector3.ZERO, 0.0, 0.32)
	_pets.append({"node": pet, "goal": pet.position, "mood": "follow", "t": randf_range(3.0, 8.0), "slot": _pets.size()})

## The lions that got out follow you about, and have a mind of their own while they do.
func _run_pets(dt: float) -> void:
	var p: Node3D = Meet.player
	for pet in _pets:
		var n: Node3D = pet["node"]
		pet["t"] -= dt
		if pet["t"] <= 0.0:
			pet["t"] = randf_range(5.0, 11.0)
			var roll := randf()
			if roll < 0.45:
				pet["mood"] = "follow"
			elif roll < 0.6:
				pet["mood"] = "sit"
			elif roll < 0.8 and _gulls != null:
				pet["mood"] = "chase"
				pet["goal"] = SNACKS + Vector3(0, 0, 1.5)
			else:
				# Go and inspect somebody.
				var near: Array = Meet.risers.filter(func(r): return not r.alien and r.global_position.distance_to(n.position) < 12.0 and r.state not in ["pull", "winded", "scrap"])
				if not near.is_empty():
					var who: Node = near[randi() % near.size()]
					pet["mood"] = "visit"
					pet["goal"] = who.global_position + Vector3(0.7, 0, 0.5)
					pet["who"] = who
				else:
					pet["mood"] = "follow"
		if pet["mood"] == "follow":
			var side: float = -1.0 if int(pet["slot"]) % 2 == 0 else 1.0
			pet["goal"] = p.global_position + p.global_transform.basis.z * 1.8 + p.global_transform.basis.x * side * (0.9 + int(pet["slot"]) / 2 * 0.8)
		var to: Vector3 = pet["goal"] - n.position
		to.y = 0
		if to.length() > 0.5 and pet["mood"] != "sit":
			var sp: float = 6.5 if to.length() > 6.0 else 3.0
			n.position += to.normalized() * sp * dt
			n.position.y = height(n.position.x, n.position.z) + absf(sin(_clock * 10.0 + int(pet["slot"]))) * 0.12
			n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), 0.2)
		else:
			n.position.y = height(n.position.x, n.position.z)
			n.rotation.y += sin(_clock * 0.9 + int(pet["slot"]) * 2.0) * dt * 0.8
			if pet["mood"] == "visit" and pet.has("who") and is_instance_valid(pet["who"]):
				var who2: Node = pet["who"]
				pet.erase("who")
				pet["mood"] = "sit"
				who2.pet_visit()
			elif pet["mood"] == "chase" and _gulls != null and not _gulls_off:
				_gulls_off = true
				Meet.sfx("bark", 0.0, 0.5)
				Meet.say("One of your stone lions roars at the seagulls. The seagulls reconsider everything.")
				drop(["golden_chip"], SNACKS + Vector3(-0.6, 0, 1.8))
