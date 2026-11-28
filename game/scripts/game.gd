extends Node
## Shared game state. Autoloaded as "Game".

signal changed
signal message(text: String)

const RING_RADIUS := 42.0
const QUOTA := 88
const SLICE_GOAL := 3
const RHODES_SPAWN := Vector3(4, 0.1, 6)

var hp := 30
var max_hp := 30
var power := 5
var chalk := 0
var straps := 0
var bread := 1
var coins := 20
var raised := 0
var recruits: Array = []
var founders_alive := 8
var journal: Array = []
var rep := {"rhodes": 20, "tallow": 0}
var flags := {}
var modal := true

var main: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var dialogue: CanvasLayer
var battle: CanvasLayer
var npcs: Array = []
var pinned: Array = []

func _ready() -> void:
	_action("forward", [KEY_W, KEY_UP])
	_action("back", [KEY_S, KEY_DOWN])
	_action("left", [KEY_A])
	_action("right", [KEY_D])
	_action("sprint", [KEY_SHIFT])
	_action("interact", [KEY_E])
	_action("journal", [KEY_J])
	_action("eat", [KEY_H])

func _action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func register_count() -> int:
	return founders_alive + recruits.size()

func say(text: String) -> void:
	message.emit(text)

func note(text: String) -> void:
	if not journal.has(text):
		journal.append(text)
		message.emit("Journal updated (J).")

func touch() -> void:
	changed.emit()

func in_ring(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < RING_RADIUS

func heal_full() -> void:
	hp = max_hp
	touch()

func eat() -> bool:
	if bread <= 0 or hp >= max_hp:
		return false
	bread -= 1
	hp = min(max_hp, hp + 12)
	touch()
	return true

## Anyone alive and near enough to see what the player just did.
func witnesses(at: Vector3, except: Node = null, radius := 22.0) -> Array:
	var out: Array = []
	for n in npcs:
		if n != except and n.alive and n.global_position.distance_to(at) < radius:
			out.append(n)
	return out

func fall() -> void:
	hp = int(max_hp / 2.0)
	coins = int(coins / 2.0)
	player.global_position = RHODES_SPAWN
	player.velocity = Vector3.ZERO
	say("You wake inside the Ring. Someone carried you back. Half your coin is gone.")
	touch()
