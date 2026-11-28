extends RefCounted
## Puts a figure into an arm wrestling stance by turning its own bones: leaning in over the
## table, right elbow down on the pad, forearm up to the grip, left hand out to the peg.

const ARM := ["spine_01", "spine_02", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l", "neck_01"]

static func posed(fig: Node3D) -> bool:
	return fig.has_meta("posed")

static func start(fig: Node3D) -> void:
	if fig.has_meta("posed"):
		return
	var ap: AnimationPlayer = fig.get_meta("anim")
	ap.play("Idle")
	ap.seek(0.0, true)
	ap.pause()
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base := {}
	for n in ARM:
		var i := sk.find_bone(n)
		if i >= 0:
			base[n] = sk.get_bone_pose_rotation(i)
	fig.set_meta("posed", base)

static func stop(fig: Node3D) -> void:
	if not fig.has_meta("posed"):
		return
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base: Dictionary = fig.get_meta("posed")
	for n in base:
		sk.set_bone_pose_rotation(sk.find_bone(n), base[n])
	fig.remove_meta("posed")
	(fig.get_meta("anim") as AnimationPlayer).play("Idle")

## elbow, grip and peg are points in the world. lean is how far over the table they are (radians).
static func pull(fig: Node3D, elbow: Vector3, grip: Vector3, peg: Vector3, lean: float) -> void:
	start(fig)
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base: Dictionary = fig.get_meta("posed")
	for n in base:
		sk.set_bone_pose_rotation(sk.find_bone(n), base[n])
	var inv := sk.global_transform.affine_inverse()
	for n in ["spine_01", "spine_02"]:
		var i := sk.find_bone(n)
		var g := sk.get_bone_global_pose(i)
		g.basis = Basis(Vector3.RIGHT, lean * 0.5) * g.basis
		sk.set_bone_global_pose(i, g)
	var neck := sk.find_bone("neck_01")
	var ng := sk.get_bone_global_pose(neck)
	ng.basis = Basis(Vector3.RIGHT, -lean * 0.7) * ng.basis
	sk.set_bone_global_pose(neck, ng)
	_aim(sk, "upperarm_r", "lowerarm_r", inv * elbow)
	_aim(sk, "lowerarm_r", "hand_r", inv * grip)
	var lsh := sk.get_bone_global_pose(sk.find_bone("upperarm_l")).origin
	var lp := inv * peg
	_aim(sk, "upperarm_l", "lowerarm_l", (lsh + lp) / 2.0 + Vector3(0, -0.14, 0))
	_aim(sk, "lowerarm_l", "hand_l", lp)

static func _aim(sk: Skeleton3D, bone: String, child: String, target: Vector3) -> void:
	var b := sk.find_bone(bone)
	var c := sk.find_bone(child)
	if b < 0 or c < 0:
		return
	var g := sk.get_bone_global_pose(b)
	var cur := (sk.get_bone_global_pose(c).origin - g.origin).normalized()
	var want := (target - g.origin).normalized()
	if cur.dot(want) > 0.9999:
		return
	g.basis = Basis(Quaternion(cur, want)) * g.basis
	sk.set_bone_global_pose(b, g)
