extends RefCounted
## Puts a figure into an arm wrestling stance by turning its own bones: leaning in over the
## table, right elbow down on the pad, forearm up to the grip, left hand out to the peg.

const ARM := ["spine_01", "spine_02", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l", "neck_01"]

static func posed(fig: Node3D) -> bool:
	return fig.has_meta("posed")

static func start(fig: Node3D, base_anim := "Idle") -> void:
	if fig.has_meta("posed"):
		return
	var ap: AnimationPlayer = fig.get_meta("anim")
	ap.play(base_anim)
	ap.seek(0.0, true)
	ap.pause()
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base := {}
	for n in ARM:
		var i := sk.find_bone(n)
		if i >= 0:
			base[n] = [sk.get_bone_pose_position(i), sk.get_bone_pose_rotation(i), sk.get_bone_pose_scale(i)]
	fig.set_meta("posed", base)

static func stop(fig: Node3D) -> void:
	if not fig.has_meta("posed"):
		return
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base: Dictionary = fig.get_meta("posed")
	for n in base:
		_restore(sk, sk.find_bone(n), base[n])
	fig.remove_meta("posed")
	(fig.get_meta("anim") as AnimationPlayer).play("Idle")

## elbow, grip and peg are points in the world. lean is how far over the table they are (radians).
static func pull(fig: Node3D, elbow: Vector3, grip: Vector3, peg: Vector3, lean: float) -> void:
	start(fig)
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base: Dictionary = fig.get_meta("posed")
	for n in base:
		_restore(sk, sk.find_bone(n), base[n])
	var inv := sk.global_transform.affine_inverse()
	for n in ["spine_01", "spine_02"]:
		var i := sk.find_bone(n)
		var g := sk.get_bone_global_pose(i)
		_turn(sk, i, Basis(Vector3.RIGHT, lean * 0.5) * g.basis)
	var neck := sk.find_bone("neck_01")
	var ng := sk.get_bone_global_pose(neck)
	_turn(sk, neck, Basis(Vector3.RIGHT, -lean * 0.7) * ng.basis)
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
	var cur := sk.get_bone_global_pose(c).origin - g.origin
	var want := target - g.origin
	if cur.length() < 0.001 or want.length() < 0.001:
		return
	cur = cur.normalized()
	want = want.normalized()
	if absf(cur.dot(want)) > 0.9999:
		return
	_turn(sk, b, Basis(Quaternion(cur, want)) * g.basis)

static func _reset(fig: Node3D) -> Skeleton3D:
	var sk: Skeleton3D = fig.find_child("Skeleton3D", true, false)
	var base: Dictionary = fig.get_meta("posed")
	for n in base:
		_restore(sk, sk.find_bone(n), base[n])
	return sk

## Rubbing chalk into both hands in front of the chest. t is seconds since starting.
static func chalk(fig: Node3D, t: float) -> void:
	start(fig, "Idle")
	var sk := _reset(fig)
	var rub := sin(t * 15.0) * 0.045
	for side in [["upperarm_r", "lowerarm_r", "hand_r", -1.0], ["upperarm_l", "lowerarm_l", "hand_l", 1.0]]:
		var sh := sk.get_bone_global_pose(sk.find_bone(side[0])).origin
		var sx: float = side[3]
		_aim(sk, side[0], side[1], sh + Vector3(sx * 0.07, -0.26, 0.1))
		_aim(sk, side[1], side[2], Vector3(sx * 0.02, 1.2 + rub * sx, 0.34 + rub * sx * 0.5))

## Crouched, one hand out, stroking something at this point in the world.
static func pet(fig: Node3D, at: Vector3, t: float) -> void:
	start(fig, "Crouch_Idle")
	var sk := _reset(fig)
	var p := sk.global_transform.affine_inverse() * at
	p += Vector3(0, 0.06 + absf(sin(t * 5.0)) * 0.05, sin(t * 5.0) * 0.09)
	var sh := sk.get_bone_global_pose(sk.find_bone("upperarm_r")).origin
	_aim(sk, "upperarm_r", "lowerarm_r", (sh + p) / 2.0 + Vector3(-0.08, 0.05, 0))
	_aim(sk, "lowerarm_r", "hand_r", p)

static func _restore(sk: Skeleton3D, i: int, pose: Array) -> void:
	sk.set_bone_pose_position(i, pose[0])
	sk.set_bone_pose_rotation(i, pose[1])
	sk.set_bone_pose_scale(i, pose[2])

## Turn a bone to a new orientation in skeleton space, changing only its rotation, never its
## position or length.
static func _turn(sk: Skeleton3D, i: int, global_basis: Basis) -> void:
	var parent := sk.get_bone_parent(i)
	var pb := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	sk.set_bone_pose_rotation(i, (pb.inverse() * global_basis.orthonormalized()).get_rotation_quaternion())
