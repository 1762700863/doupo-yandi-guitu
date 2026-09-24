class_name StoryBG
extends Node2D
## 剧情背景：章节地貌暗化 + 飘散光尘 + 暗角（剧情对话时的底图，避免台词压在标题/战斗画面上）

var biome := "void"
var t := 0.0
var dust: Array = []

static func make(b:String) -> StoryBG:
	var s := StoryBG.new()
	s.biome = b
	return s

func _ready() -> void:
	for i in 70:
		dust.append([Vector2(randf() * 960, randf() * 540), randf_range(6, 22), randf() * TAU, randf_range(1, 2.5)])

func _process(d:float) -> void:
	t += d
	for p in dust:
		p[0] += Vector2(sin(t * 0.5 + p[2]) * 6, -p[1]) * d
		if p[0].y < -4:
			p[0] = Vector2(randf() * 960, 545)
	queue_redraw()

func _draw() -> void:
	var tiles := G.tex("res://assets/tiles/%s.png" % biome)
	if tiles:
		var n := int(tiles.get_width() / 64)
		for y in range(0, 540, 64):
			for x in range(0, 960, 64):
				var v: int = int(abs(sin(x * 0.37 + y * 0.11)) * 7) % maxi(1, n)
				draw_texture_rect_region(tiles, Rect2(x, y, 64, 64), Rect2(v * 64, 0, 64, 64), Color(0.45, 0.42, 0.5))
	else:
		draw_rect(Rect2(0, 0, 960, 540), Color(0.05, 0.03, 0.08))
	var acc := Color(1, 0.7, 0.4) if biome != "void" else Color(0.75, 0.55, 1)
	for p in dust:
		draw_rect(Rect2(p[0], Vector2(p[3], p[3])), Color(acc.r, acc.g, acc.b, 0.35 + 0.3 * sin(t * 2 + p[2])))
	for i in 14:
		var w := 12.0 + i * 12
		var c := Color(0, 0, 0, 0.07)
		draw_rect(Rect2(0, 0, 960, w * 0.6), c)
		draw_rect(Rect2(0, 540 - w * 0.6, 960, w * 0.6), c)
		draw_rect(Rect2(0, 0, w, 540), c)
		draw_rect(Rect2(960 - w, 0, w, 540), c)
