class_name Pips
extends Control
## A row of drawn stars or dots, some filled. Drawn as shapes rather than typed as symbols,
## because not every browser's font has the symbols.

var total := 5
var filled := 0
var star := true
var color := Color(1.0, 0.75, 0.25)
var px := 18.0
var from_right := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_pips(n_filled: int, n_total: int) -> void:
	if n_filled == filled and n_total == total:
		return
	filled = n_filled
	total = n_total
	custom_minimum_size = Vector2(total * (px + 4.0), px + 2.0)
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(total * (px + 4.0), px + 2.0)

func _draw() -> void:
	for i in total:
		var on: bool = (i >= total - filled) if from_right else (i < filled)
		var c := Vector2(i * (px + 4.0) + px / 2.0 + 2.0, size.y / 2.0)
		if star:
			var pts := PackedVector2Array()
			for k in 10:
				var r: float = px / 2.0 if k % 2 == 0 else px / 4.6
				var a: float = -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			if on:
				draw_colored_polygon(pts, color)
			pts.append(pts[0])
			draw_polyline(pts, color if on else Color(color, 0.55), 1.5, true)
		else:
			if on:
				draw_circle(c, px / 2.0 - 1.0, color)
			draw_arc(c, px / 2.0 - 1.0, 0.0, TAU, 20, color if on else Color(color, 0.55), 1.5, true)
