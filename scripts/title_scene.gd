class_name TitleScene
extends Node2D
## 标题画面：星空 + 火焰粒子 + 炎帝立绘 + 标题

var t := 0.0
var embers: Array = []
var stars: Array = []
var por: Texture2D

func _ready() -> void:
	por = G.portrait("yandi_full")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		stars.append([Vector2(rng.randf() * 960, rng.randf() * 360), rng.randf_range(0.5, 1.6), rng.randf() * TAU])
	for i in 90:
		embers.append(_new_ember(true))

func _new_ember(any_y:bool) -> Dictionary:
	return {"p": Vector2(randf() * 960, randf_range(0, 540) if any_y else 560.0), "v": Vector2(randf_range(-12, 12), randf_range(-70, -25)),
		"s": randf_range(1, 3), "c": [Color(1, 0.55, 0.2), Color(1, 0.8, 0.3), Color(0.7, 0.5, 1), Color(0.4, 1, 0.8)][randi() % 4], "ph": randf() * TAU}

func _process(d:float) -> void:
	t += d
	for e in embers:
		e["p"] += e["v"] * d + Vector2(sin(t * 2 + e["ph"]) * 10 * d, 0)
		if e["p"].y < -10:
			e.merge(_new_ember(false), true)
	queue_redraw()

func _draw() -> void:
	# 天空渐变
	for i in 27:
		var k := float(i) / 27
		draw_rect(Rect2(0, i * 20, 960, 21), Color(0.03, 0.02, 0.07).lerp(Color(0.22, 0.07, 0.08), k * k))
	for s in stars:
		var a = 0.4 + 0.6 * abs(sin(t * s[1] + s[2]))
		draw_rect(Rect2(s[0], Vector2(s[1], s[1])), Color(1, 0.95, 0.85, a * 0.8))
	# 巨大的火莲光环
	var c := Vector2(690, 250)
	for i in 3:
		var r := 150.0 + i * 36 + sin(t * 1.4 + i) * 6
		draw_arc(c, r, 0, TAU, 96, Color(1, 0.55 + i * 0.1, 0.25, 0.12 - i * 0.03), 3.0)
	for i in 12:
		var ang := t * 0.25 + i * TAU / 12
		var p1 := c + Vector2.from_angle(ang) * 120
		var p2 := c + Vector2.from_angle(ang + 0.26) * 190
		var p3 := c + Vector2.from_angle(ang - 0.26) * 190
		draw_colored_polygon(PackedVector2Array([p1, p2, c + Vector2.from_angle(ang) * 230, p3]), Color(1, 0.5, 0.2, 0.06))
	# 远山剪影
	var pts := PackedVector2Array([Vector2(0, 540)])
	for x in range(0, 961, 24):
		pts.append(Vector2(x, 430 - abs(sin(x * 0.011)) * 70 - abs(sin(x * 0.037 + 1)) * 30))
	pts.append(Vector2(960, 540))
	draw_colored_polygon(pts, Color(0.06, 0.03, 0.05))
	# 立绘
	if por:
		var h := 470.0
		var w := por.get_width() * h / por.get_height()
		var bob := sin(t * 1.2) * 4
		draw_texture_rect(por, Rect2(690 - w / 2, 540 - h + bob + 10, w, h), false)
	# 余烬
	for e in embers:
		var col: Color = e["c"]
		col.a = 0.6 + 0.4 * sin(t * 5 + e["ph"])
		draw_rect(Rect2(e["p"], Vector2(e["s"], e["s"])), col)
	# 标题
	var f: Font = G.font
	var title := "斗破苍穹"
	for o in [Vector2(3, 3), Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(f, Vector2(100, 170) + o, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0.25, 0.05, 0.02, 0.9))
	draw_string(f, Vector2(100, 170), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(1, 0.78, 0.35).lerp(Color(1, 0.95, 0.7), 0.5 + 0.5 * sin(t * 2)))
	draw_string(f, Vector2(104, 214), "—— 焰 帝 归 途 ——", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.5, 0.3))
	draw_string(f, Vector2(106, 244), "三十年河东，三十年河西，莫欺少年穷！", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.75, 0.8))
