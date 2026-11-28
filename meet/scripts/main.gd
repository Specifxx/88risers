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
	Build.tcyl(self, 0.28, 0.22, 0.5, CHALK + Vector3(0, 0.55, 0), "iron", Color(0.5, 0.52, 0.56), 12)
	Build.tcyl(self, 0.05, 0.2, 0.3, CHALK + Vector3(0, 0.15, 0), "iron", Color(0.3, 0.3, 0.33), 8)
	Build.cyl(self, 0.25, 0.25, 0.04, CHALK + Vector3(0, 0.8, 0), Color(0.97, 0.97, 0.97), 12)
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
	var parts := {"root": rig, "lean": 0.0, "target": 0.0}
	for k in ["fa", "fb", "ua", "ub"]:
		parts[k] = Build.cyl(rig, 0.045, 0.055, 1.0, Vector3.ZERO, SKIN, 8)
	parts["fist"] = Build.sphere(rig, 0.085, Vector3.ZERO, SKIN)
	_rigs.append(parts)

static func _limb(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	var x := y.cross(Vector3.FORWARD).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y.normalized())), (a + b) / 2.0)

func _pose_rig(i: int, dt: float) -> void:
	var r: Dictionary = _rigs[i]
	r["lean"] = lerp(float(r["lean"]), float(r["target"]), min(1.0, dt * 4.0))
	var a: float = r["lean"] + sin(_clock * 9.0 + i) * 0.03
	var fist := Vector3(0, 1.1 + 0.3 * cos(a), 0.05 + 0.3 * sin(a))
	r["fist"].position = fist
	for side in [[-1.0, "fa", "ua"], [1.0, "fb", "ub"]]:
		var elbow := Vector3(side[0] * 0.17, 1.09, 0.05)
		_limb(r[side[1]], elbow, fist)
		_limb(r[side[2]], Vector3(side[0] * 0.52, 1.36, 0.0), elbow)

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
	Meet.player.global_position = t + Vector3(-0.78, 0, 0)
	Meet.player.rotation.y = -PI / 2.0
	r.global_position = t + Vector3(0.78, 0, 0)
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
	_pose_rig(best, 1.0)
	return best

func unseat_player(i: int) -> void:
	_player_table = -1
	Meet.player.cam.current = true
	if i >= 0:
		_rigs[i]["root"].visible = false
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

func _chalk_up() -> void:
	Meet.chalked = true
	Fx.burst(self, Meet.player.global_position + Vector3(0, 1.1, 0), Vector3.UP, false, 8)
	Meet.say("You chalk your hands. Your grip will last longer in your next pull.")
	Meet.touch_state()

func _chalk_take() -> void:
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
		Fx.burst(self, ball.position, Vector3.UP, false, 16)
		ball.queue_free()
		landed.call())

## The player has hit a member of the public.
func public_hit(who: Node) -> void:
	Meet.scraps += 1
	Meet.say("%s runs for it. The whole meet saw that." % who.riser_name)
	var harry: Node = Meet.riser("harry")
	if harry and harry.state != "winded":
		harry.say_aloud("That's the PUBLIC. What is wrong with you?", 5.0)
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
		Meet.hud.night_over(_summary(), "HALF PAST SEVEN")
		return
	for ev in _events.duplicate():
		if Meet.clock >= ev["at"] and _ufo_state in ["", "gone"] and _drone == null and _gulls == null:
			_events.erase(ev)
			call("start_" + ev["kind"])
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
		if i != _player_table:
			_rigs[i]["root"].visible = on
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
		a.go_pull(TABLES[i] + Vector3(-0.78, 0, 0), TABLES[i])
		b.go_pull(TABLES[i] + Vector3(0.78, 0, 0), TABLES[i])
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
		Meet.say("%s sits down hard, winded. Everyone is looking at you." % who.riser_name)
	else:
		Meet.say("You sit down hard on the paving. %s stands over you, then walks off." % who.riser_name)
		who.mind.experience("scrap", 0.25, 0.8, true, "")
		who.idle()
	var harry: Node = Meet.riser("harry")
	if harry and harry != who and harry.state != "winded":
		harry.mind.experience("scrap", -0.5, 1.2, true, who.riser_name)
		harry.say_aloud("Not at the meet. Take it to the table.", 4.0)
	Meet.save()
	if Meet.scraps >= 3:
		Meet.hud.night_over("That's three. Harry walks you to the gate himself.\n\n\"Go home. Come back next week with your head on straight.\"")

func _grab_snack() -> void:
	if Meet.snacks >= 5:
		Meet.say("You've got as many as you can carry.")
		return
	Meet.snacks += 1
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
		Meet.say("You run at them waving your arms. It works. One of them drops something on the way out.")
		drop(["golden_chip"], SNACKS + Vector3(-0.6, 0, 1.8))
	elif _gulls_t > 40.0:
		_gulls_off = true
		Meet.say("The seagulls leave when they are ready to leave, and not before. Half the snacks went with them.")

# --- The crowd ----------------------------------------------------------------------------

## Something noteworthy happened: some of the people nearby turn, say something, maybe come over.
func stir(at: Vector3, lines: Array, radius := 12.0, share := 0.6, gather := false) -> void:
	for r in Meet.risers:
		if r.alien or r.global_position.distance_to(at) > radius or r.global_position.distance_to(at) < 0.3:
			continue
		if randf() < share:
			r.gawp(at, lines[randi() % lines.size()], gather)

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
