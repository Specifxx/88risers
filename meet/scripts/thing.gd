extends Node3D
## Something in the world you can use: a board to read, a box to open.

var _text := ""
var _use: Callable

func setup(text: String, use: Callable) -> void:
	_text = text
	_use = use
	add_to_group("interact")

func prompt() -> String:
	return _text

func interact() -> void:
	_use.call()
