extends Node3D
## Something in the world you can use: a board to read, a box to open. Some can also be hit.

var _text := ""
var _use: Callable
var _hit: Callable
var alien := false
var _figure: Node3D
var state := ""

func setup(text: String, use: Callable) -> void:
	_text = text
	_use = use
	_figure = self
	add_to_group("interact")

## Let it be struck. The callback gets the damage.
func hittable(cb: Callable) -> void:
	_hit = cb
	add_to_group("hittable")

func prompt() -> String:
	return _text

func interact() -> void:
	_use.call()

func can_be_hit() -> bool:
	return _hit.is_valid()

func take_hit(dmg: int, _from: Vector3) -> void:
	if _hit.is_valid():
		_hit.call(dmg)

func dusted(_by: Node) -> void:
	pass

func splatted(_by: Node) -> void:
	pass

func bowled(_dir: Vector3) -> void:
	pass

func pranked(_kind: String, _a: Array, _b: Array) -> void:
	pass
