class_name ArenaEdge
extends Node2D
## 竞技场边界：柔和的暗角与符文边线

var rect := Rect2()
var t := 0.0

func _process(delta:float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c := Color(1, 0.8, 0.45, 0.16 + 0.05 * sin(t * 2))
	draw_rect(rect, c, false, 2.0)
	var step := 48.0
	var x := rect.position.x
	while x < rect.end.x:
		draw_rect(Rect2(x, rect.position.y - 2, 6, 4), c)
		draw_rect(Rect2(x, rect.end.y - 2, 6, 4), c)
		x += step
	var y := rect.position.y
	while y < rect.end.y:
		draw_rect(Rect2(rect.position.x - 2, y, 4, 6), c)
		draw_rect(Rect2(rect.end.x - 2, y, 4, 6), c)
		y += step
