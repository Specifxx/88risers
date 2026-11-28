extends Node3D
## Rolling ground for the island: hills from noise, flattened where Rhodes and Tallow Ford
## stand, eased along the road, and cut by the river. Textured by a blend shader.

const X0 := -240.0
const X1 := 440.0
const Z0 := -280.0
const Z1 := 280.0
const STEP := 4.0
const RIVER_X := 284.0
const WATER_Y := -1.3

var road: Array = []
var village := Vector3.ZERO
var ring := 42.0
var _noise := FastNoiseLite.new()
var _fine := FastNoiseLite.new()

func setup(road_points: Array, village_at: Vector3, ring_radius: float) -> void:
	road = road_points
	village = village_at
	ring = ring_radius
	_noise.seed = 88
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.011
	_noise.fractal_octaves = 3
	_fine.seed = 8
	_fine.frequency = 0.05
	_build()

func road_distance(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var best := 1e9
	for i in road.size() - 1:
		var a := Vector2(road[i].x, road[i].z)
		var b := Vector2(road[i + 1].x, road[i + 1].z)
		var t: float = clamp((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = min(best, q.distance_to(a + (b - a) * t))
	return best

func height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 9.0 + _fine.get_noise_2d(x, z) * 0.5 + 1.5
	# Flat where people have built.
	h *= smoothstep(ring + 5.0, ring + 55.0, Vector2(x, z).length())
	h *= smoothstep(32.0, 75.0, Vector2(x - village.x, z - village.z).length())
	# The road keeps to the easy ground.
	h *= lerp(0.2, 1.0, smoothstep(3.0, 30.0, road_distance(x, z)))
	# The river.
	var r := absf(x - RIVER_X - sin(z * 0.02) * 6.0)
	h = lerp(-3.0, h, smoothstep(5.0, 22.0, r))
	return h

func normal(x: float, z: float) -> Vector3:
	var e := 1.0
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()

func _build() -> void:
	var nx := int((X1 - X0) / STEP) + 1
	var nz := int((Z1 - Z0) / STEP) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var heights := PackedFloat32Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	cols.resize(nx * nz)
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := X0 + i * STEP
			var z := Z0 + j * STEP
			var h := height(x, z)
			var n := normal(x, z)
			var k := j * nx + i
			verts[k] = Vector3(x, h, z)
			norms[k] = n
			heights[k] = h
			# r = worn dirt (road, village), g = rock (steep or riverbed), b = packed earth inside the Ring.
			var dirt := 1.0 - smoothstep(1.6, 4.6, road_distance(x, z))
			dirt = max(dirt, 1.0 - smoothstep(16.0, 30.0, Vector2(x - village.x, z - village.z).length()))
			var rock: float = clamp(smoothstep(0.86, 0.74, n.y) + smoothstep(-0.6, -1.6, h), 0.0, 1.0)
			var earth := 1.0 - smoothstep(ring - 2.0, ring + 4.0, Vector2(x, z).length())
			cols[k] = Color(dirt * (1.0 - earth), rock, earth)
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material()
	add_child(mi)

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = nx
	hm.map_depth = nz
	hm.map_data = heights
	cs.shape = hm
	body.add_child(cs)
	add_child(body)
	body.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	body.scale = Vector3(STEP, 1, STEP)

	# Water.
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, Z1 - Z0)
	var water := MeshInstance3D.new()
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.22, 0.27, 0.82)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic = 0.3
	water.material_override = wm
	add_child(water)
	water.position = Vector3(RIVER_X, WATER_Y, 0)

func _material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D earth : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wpos.xz * 0.16;
	vec3 g = texture(grass, uv).rgb;
	// A second, larger sampling breaks up the repeat.
	g *= mix(vec3(0.72, 0.78, 0.62), vec3(1.12, 1.08, 0.92), texture(grass, wpos.xz * 0.011).g * 1.6);
	vec3 d = texture(dirt, uv * 0.8).rgb;
	vec3 r = texture(rock, uv * 0.6).rgb;
	vec3 e = texture(earth, uv * 0.7).rgb * vec3(1.15, 1.05, 0.9);
	vec3 c = mix(g * vec3(0.5, 0.58, 0.4), r * 0.7, COLOR.g);
	c = mix(c, d * vec3(0.62, 0.56, 0.5), COLOR.r);
	c = mix(c, e * vec3(0.5, 0.47, 0.44), COLOR.b);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	for t in ["grass", "dirt", "rock", "earth"]:
		m.set_shader_parameter(t, load("res://assets/tex/%s.jpg" % t))
	return m
