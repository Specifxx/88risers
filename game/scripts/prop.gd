extends RigidBody3D
## A loose object that reacts to being struck: it is knocked about, and breaks if hit enough.

const Build = preload("res://scripts/build.gd")
const Fx = preload("res://scripts/fx.gd")

var hp := 12

func setup(kind: String) -> void:
	mass = 12.0
	var cs := CollisionShape3D.new()
	if kind == "barrel":
		var sh := CylinderShape3D.new()
		sh.radius = 0.34
		sh.height = 0.9
		cs.shape = sh
		Build.tcyl(self, 0.3, 0.3, 0.9, Vector3.ZERO, "darkwood", Color(0.95, 0.85, 0.75), 10)
		Build.tcyl(self, 0.35, 0.35, 0.7, Vector3.ZERO, "darkwood", Color(0.8, 0.7, 0.6), 10)
		for y in [-0.3, 0.3]:
			Build.tcyl(self, 0.36, 0.36, 0.05, Vector3(0, y, 0), "iron", Color(0.5, 0.5, 0.52), 10)
	else:
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, 0.8, 0.8)
		cs.shape = bs
		Build.tbox(self, Vector3(0.8, 0.8, 0.8), Vector3.ZERO, "planks", Color(0.7, 0.6, 0.5))
		for sx in [-1.0, 1.0]:
			Build.tbox(self, Vector3(0.06, 0.84, 0.84), Vector3(sx * 0.38, 0, 0), "darkwood")
	add_child(cs)
	add_to_group("hittable")

func can_be_hit() -> bool:
	return true

func knock(v: Vector3) -> void:
	apply_central_impulse(v * mass)

func take_hit(dmg: int, from: Vector3) -> void:
	var away := global_position - from
	away.y = 0
	apply_impulse((away.normalized() * (3.0 + dmg * 0.4) + Vector3(0, 2.5, 0)) * mass, Vector3(randf_range(-0.2, 0.2), 0.2, 0))
	hp -= dmg
	if hp <= 0:
		Fx.burst(Game.main, global_position, Vector3.UP, false, 26)
		if randf() < 0.5:
			Game.main.drop_loot("what was inside", {["bread", "wine", "chalk"][randi() % 3]: 1}, randi_range(0, 4), global_position, "", "", true, 120.0)
		queue_free()
