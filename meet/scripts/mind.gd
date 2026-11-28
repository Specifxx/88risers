extends RefCounted
## A person's mind: a small neural network (one hidden layer) that learns, from what
## happens to them and what they hear, how dealing with the player tends to turn out.
##
## Every experience becomes a memory with a feeling attached. The network is trained on
## those memories as they arrive and again whenever the person has a quiet moment, so
## opinions form gradually, differ from person to person, and depend on the situation:
## someone can like you in general and still not trust you near their strongbox.

const KINDS := ["meet", "talk", "gift", "match", "heckle", "scrap", "violence", "nagged", "aliens", "photo", "helped", "theft", "chalk"]
const N_IN := 15   # 1 bias + 13 kinds + familiarity
const N_HID := 10

## Temperament. Fixed for life, different for everyone.
var open := 1.0      # how readily good experiences change them
var grudge := 1.0    # how readily bad ones do
var warmth := 0.0    # where they start with strangers (-1..1)
var chatty := 0.5    # how much they pass on what they know

var familiarity := 0.0
var memories: Array = []   # {kind, valence, weight, firsthand, about}
var mood := 0.0            # short-lived; decays
var fear := 0.0            # of the player, 0..1; fades slowly, never quite to nothing once learned
var scars := 0             # how many times something terrible has reshaped them
var activity := PackedFloat32Array()   # last hidden-layer activations, for display

var _w1 := PackedFloat32Array()
var _b1 := PackedFloat32Array()
var _w2 := PackedFloat32Array()
var _b2 := 0.0
var _rng := RandomNumberGenerator.new()

func setup(seed_text: String, temperament: Dictionary) -> void:
	open = temperament.get("open", 1.0)
	grudge = temperament.get("grudge", 1.0)
	warmth = temperament.get("warmth", 0.0)
	chatty = temperament.get("chatty", 0.5)
	_rng.seed = hash(seed_text)
	_w1.resize(N_HID * N_IN)
	_b1.resize(N_HID)
	_w2.resize(N_HID)
	activity.resize(N_HID)
	for i in _w1.size():
		_w1[i] = _rng.randfn(0.0, 0.35)
	for i in N_HID:
		_b1[i] = _rng.randfn(0.0, 0.1)
		_w2[i] = _rng.randfn(0.0, 0.35)
	# Before anything has happened, they feel about a stranger the way their temperament says.
	for i in 60:
		_step(_inputs(""), warmth * 0.5, 0.08)

func _inputs(kind: String) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(N_IN)
	x[0] = 1.0
	var k := KINDS.find(kind)
	if k >= 0:
		x[1 + k] = 1.0
	x[N_IN - 1] = familiarity
	return x

func _forward(x: PackedFloat32Array) -> float:
	var out := _b2
	for h in N_HID:
		var s := _b1[h]
		for i in N_IN:
			s += _w1[h * N_IN + i] * x[i]
		activity[h] = tanh(s)
		out += _w2[h] * activity[h]
	return tanh(out)

## One step of gradient descent towards `target`.
func _step(x: PackedFloat32Array, target: float, rate: float) -> void:
	var y := _forward(x)
	var d_out := (y - target) * (1.0 - y * y)
	for h in N_HID:
		var a := activity[h]
		var d_h := d_out * _w2[h] * (1.0 - a * a)
		_w2[h] -= rate * d_out * a
		_b1[h] -= rate * d_h
		for i in N_IN:
			_w1[h * N_IN + i] -= rate * d_h * x[i]
	_b2 -= rate * d_out

## How they expect things to go with the player, in general (-1..1).
func feeling() -> float:
	return _forward(_inputs(""))

## How they expect a particular kind of dealing to go ("trade", "nagged", ...).
func expects(kind: String) -> float:
	return _forward(_inputs(kind))

## Something happened. `valence` is how it felt (-1..1); `weight` how much it mattered.
func experience(kind: String, valence: float, weight := 1.0, firsthand := true, about := "") -> void:
	var salience := weight * (open if valence >= 0.0 else grudge) * (1.0 if firsthand else 0.6)
	if salience <= 0.0:
		return
	memories.append({"kind": kind, "valence": valence, "weight": salience, "firsthand": firsthand, "about": about})
	if memories.size() > 40:
		memories.pop_front()
	mood = clamp(mood + valence * min(salience, 2.0) * 0.5, -1.0, 1.0)
	if kind == "violence":
		fear = clamp(fear + (0.5 if firsthand else 0.2) * min(weight, 4.0) / 3.0, 0.0, 1.0)
		if firsthand and weight >= 3.0:
			_scar()
	for i in int(ceil(8.0 * min(salience, 3.0))):
		_step(_inputs(kind), valence, 0.07)
	reflect(30)

## Seeing blood changes who a person is, not only what they think of you: they become
## slower to warm to anyone, quicker to hold a wrong against them, and quieter or louder.
func _scar() -> void:
	scars += 1
	open = max(0.2, open * 0.75)
	grudge = min(2.6, grudge * 1.2)
	warmth = max(-0.8, warmth - 0.15)
	chatty = clamp(chatty + (0.2 if chatty > 0.5 else -0.15), 0.05, 1.0)

## Simply being around someone makes them familiar.
func met() -> void:
	familiarity = min(1.0, familiarity + 0.08)

## A quiet moment: go back over what they remember and settle their general view.
func reflect(steps := 6) -> void:
	if memories.is_empty():
		return
	var total := 0.0
	var mean := 0.0
	for m in memories:
		total += m["weight"]
		mean += m["valence"] * m["weight"]
	mean /= total
	# Few experiences: hold the view loosely. Many: hold it firmly.
	var settled: float = lerp(warmth * 0.5, mean, 1.0 - exp(-total / 2.0))
	for i in steps:
		_step(_inputs(""), settled, 0.09)
		var m: Dictionary = memories[_rng.randi() % memories.size()]
		_step(_inputs(m["kind"]), m["valence"], 0.03)

## Amends have been made. The memory stays; its hold on them loosens.
func forgive() -> void:
	fear *= 0.4
	for m in memories:
		if m["valence"] < 0.0:
			m["weight"] *= 0.1
	# Being paid what is owed counts the same for everyone, however guarded.
	memories.append({"kind": "helped", "valence": 0.5, "weight": 3.0, "firsthand": true, "about": ""})
	for i in 30:
		_step(_inputs("helped"), 0.5, 0.07)
	reflect(60)

## Everything needed to bring this mind back exactly as it was.
func to_data() -> Dictionary:
	return {"w1": Array(_w1), "b1": Array(_b1), "w2": Array(_w2), "b2": _b2, "open": open, "grudge": grudge, "warmth": warmth,
		"chatty": chatty, "familiarity": familiarity, "memories": memories, "fear": fear, "scars": scars}

func from_data(d: Dictionary) -> void:
	if not d.has("w1") or (d["w1"] as Array).size() != _w1.size():
		return
	_w1 = PackedFloat32Array(d["w1"])
	_b1 = PackedFloat32Array(d["b1"])
	_w2 = PackedFloat32Array(d["w2"])
	_b2 = float(d["b2"])
	open = float(d.get("open", open))
	grudge = float(d.get("grudge", grudge))
	warmth = float(d.get("warmth", warmth))
	chatty = float(d.get("chatty", chatty))
	familiarity = float(d.get("familiarity", 0.0))
	memories = d.get("memories", [])
	fear = float(d.get("fear", 0.0))
	scars = int(d.get("scars", 0))

func tick(dt: float) -> void:
	mood = move_toward(mood, 0.0, dt * 0.01)
	fear = move_toward(fear, 0.15 * min(scars, 2), dt * 0.004)

## Hearing about something from someone else. Returns true if it was news.
func hear(m: Dictionary) -> bool:
	for own in memories:
		if own["kind"] == m["kind"] and own["about"] == m["about"]:
			return false
	experience(m["kind"], m["valence"], m["weight"] / max(0.2, (open if m["valence"] >= 0.0 else grudge)), false, m["about"])
	return true

## Something worth passing on, if they have anything.
func gossip() -> Dictionary:
	var best := {}
	for m in memories:
		if m["about"] != "" and (best.is_empty() or m["weight"] > best["weight"]):
			best = m
	return best

func remembers(kind: String) -> bool:
	for m in memories:
		if m["kind"] == kind:
			return true
	return false

func state_word() -> String:
	var f := feeling()
	if fear > 0.5 and f < 0.2:
		return "afraid"
	if f < -0.6:
		return "hostile"
	if f < -0.25:
		return "wary"
	if f < 0.2:
		return "reserved" if familiarity < 0.4 else "used to you"
	if f < 0.55:
		return "friendly"
	return "trusting"
