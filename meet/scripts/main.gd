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
		if randf() < 0.35:
			kinds.append("ufo")
		kinds.shuffle()
		for i in 2 + randi() % 2:
			_events.append({"at": randf_range(60.0, 800.0), "kind": kinds[i]})
	if OS.get_cmdline_user_args().has("--selftest"):
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
	for t in TABLES + [SNACKS, CHALK]:
		var d := Vector2(p.x - t.x, p.z - t.z)
		if d.length() < 1.15 and d.length() > 0.001:
			d = d.normalized() * 1.15
			p.x = t.x + d.x
			p.z = t.z + d.y
	p.x = clamp(p.x, -24.0, 24.0)
	p.z = clamp(p.z, -20.0, 26.5)
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
	var lm := Build.mesh(self, lawn, Vector3.ZERO, Color.WHITE)
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
	for t in TIERS:
		var radius := PLAZA + 0.5 + t
		var n := 26
		for i in n:
			var a := PI + 0.12 + (PI - 0.24) * (i + 0.5) / n
			var hgt := (t + 1) * TIER_H
			var seg := Build.tbox(self, Vector3(1.0, hgt, (PI - 0.24) * radius / n + 0.06), Vector3(cos(a) * radius, hgt / 2.0, sin(a) * radius), "stone", stone * (0.92 + 0.04 * (t % 2)), false, 0.5)
			seg.rotation.y = -a
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
	for i in 5:
		var a := randf() * TAU
		var r := randf_range(3.0, 20.0)
		_coin(clear(Vector3(cos(a) * r, 0, absf(sin(a)) * r + 2.0)), 2)
	_coin(Vector3(-9, 0, 20.6), 20)
	# The way in from the water, the club's guardians, and its banners.
	Asia.gate(self, Vector3(0, 0, 24.5), 0.0, 6.0)
	Asia.lion(self, Vector3(-5.2, 0, 22.5), 0.2, 1.0)
	Asia.lion(self, Vector3(5.2, 0, 22.5), -0.2, 1.0)
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
	for i in poles.size():
		var a: Vector3 = poles[i]
		var b: Vector3 = poles[(i + 1) % poles.size()]
		for k in range(1, 7):
			var f := k / 7.0
			var p := a.lerp(b, f) - Vector3(0, sin(f * PI) * 0.8, 0)
			Build.sphere(self, 0.09, p, [Color(1.0, 0.8, 0.45), Color(1.0, 0.45, 0.3), Color(1.0, 0.9, 0.7)][k % 3], 1.5)
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

func _table(at: Vector3) -> void:
	var t := Node3D.new()
	add_child(t)
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
	var idx := _rigs.size() - 1
	var st := Thing.new()
	st.setup("Strap their hands in", _strap_in.bind(idx))
	st.remove_from_group("interact")
	add_child(st)
	st.position = at + Vector3(0, 0, 1.3)
	_rigs[idx]["helper"] = st

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
	var seen: Array = []
	for r in Meet.risers:
		if r.is_riser and r.state != "winded" and r.global_position.distance_to(p) < 10.0 and r.facing(p):
			seen.append(r)
	if seen.has(owner):
		owner.mind.experience("theft", -0.8, 2.0, true, "my wallet")
		owner.say_aloud("That's my WALLET. Get out of it!", 4.0)
		Meet.say("%s saw exactly what you were doing." % owner.riser_name)
		stir(p, ["Seriously?", "From a wallet?", "Unreal."], 12.0, 0.6, false)
		return
	var got: int = owner.wallet
	owner.wallet = 0
	owner.wallet_taken = got
	for r in seen:
		r.saw_theft[id + "$"] = true
		r.mind.experience("theft", -0.4, 1.0, false, bag["who"])
	if seen.is_empty():
		Meet.pay(got, "You lift $%d from %s's wallet. Nobody saw." % [got, bag["who"]])
	else:
		seen[0].say_aloud("...", 3.0)
		Meet.pay(got, "You lift $%d from %s's wallet. %s was watching." % [got, bag["who"], seen[0].first_name])
	Meet.save()

## Two founders are sent to a free table to settle something.
func force_match(a_id: String, b_id: String) -> bool:
	var a: Node = Meet.riser(a_id)
	var b: Node = Meet.riser(b_id)
	if a == null or b == null or not a.is_free() or not b.is_free():
		return false
	for i in TABLES.size():
		if table_busy(i) or i == _player_table:
			continue
		var total := randf_range(10.0, 16.0)
		_matches.append({"table": i, "a": a, "b": b, "time": total, "total": total,
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
	var seen: Array = []
	for r in Meet.risers:
		if r.is_riser and r.state != "winded" and r.global_position.distance_to(p) < 10.0 and r.facing(p):
			seen.append(r)
	if seen.has(owner):
		owner.mind.experience("theft", -0.6, 1.5, true, "my strap")
		owner.say_aloud("Oi! Out of my bag!", 4.0)
		Meet.say("%s is looking right at you. You take your hand out of the bag." % owner.riser_name)
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
	# This week's visitor.
	var g: Dictionary = People.GUESTS[Meet.week() % People.GUESTS.size()]
	_add(g, false)
	Meet.risers[-1].join_meet()
	Meet.risers[-1].wants_pull = false
	_events.append({"at": randf_range(200.0, 520.0), "kind": People.RUMOURS[Meet.week() % People.RUMOURS.size()]})
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
		Meet.sfx("whistle")
		Meet.hud.night_over(_summary(), "HALF PAST SEVEN")
		return
	for ev in _events.duplicate():
		if Meet.clock >= ev["at"] and _ufo_state in ["", "gone"] and _drone == null and _gulls == null:
			_events.erase(ev)
			call("start_" + ev["kind"])
			break
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
				george.say_aloud("Well done, man. Get yourself a drink.", 5.0)
				george.stare(4.0)
				Meet.pay(10, "George presses a tenner into your hand. \"Well done, man.\"")
				Meet.save()
				break
	_run_drone(dt)
	_run_gulls(dt)
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
		if Meet.riser(d["id"]) == null:
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
		if table_busy(i) or i == _player_table:
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
			for i in 3:
				var al: Node3D = RiserScript.new()
				add_child(al)
				al.setup(People.ALIEN, false, Vector3(-2.5 + i * 2.5, 0, 15))
				al.alien = true
				_aliens.append(al)
				Fx.burst(self, al.global_position + Vector3(0, 1, 0), Vector3.UP, false, 14)
			Meet.say("Three small, cross-looking visitors have got out. They do not seem to be here for the arm wrestling.")
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
			_ufo_state = "leave"
			Meet.seen_ufo = true
			Meet.say("That's the last of them. They are being dragged back up the ramp by something you can't see. Something fell out on the way.")
			drop(["antennae", "raygun"], Vector3(1.5, 0, 14.0))
			for r in Meet.risers:
				r.aliens_gone()
			Meet.save()
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

func aliens() -> Array:
	return _aliens.filter(func(a): return is_instance_valid(a) and a.state != "winded")

# --- The clock ----------------------------------------------------------------------------

## The light goes as the evening does: gold at five, dark blue by half past seven.
func _dusk() -> void:
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
	return "Harry calls it. Tables down, chalk swept, snacks gone.\n\nTonight: %d pulls won, %d lost. %d of the founders count you a mate; %d would rather you hadn't come. Standing with the club: %s (%d).\n\nSee you next Sunday." % [
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
	create_tween().set_loops().tween_property(m, "rotation:y", TAU, 3.0).from(0.0)
	th.setup("Pick up: %s" % Meet.ITEMS[item]["name"], func():
		Meet.grant(item)
		Meet.player.act("PickUp_Table", 0.8)
		th.queue_free())

func start_drone() -> void:
	if _drone != null:
		return
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
		Meet.hud.night_over("Five stars. Harry, George and Kelvin walk you to the gate in a tight triangle. Tommy holds it open.\n\n\"Go home. Think about what you've done. The chalk bucket has feelings.\"")
