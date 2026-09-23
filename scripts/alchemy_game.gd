class_name AlchemyGame
extends Control
## 炼丹小游戏：按住 空格/鼠标左键 催动火焰，把火候保持在移动的“最佳区间”内；三个阶段；高品质时触发丹雷（按键时机）

var pid := ""
var cb: Callable
var heat := 0.3
var heat_v := 0.0
var zone_c := 0.5
var zone_w := 0.18
var zone_t := 0.0
var stage := 0
var stage_prog := 0.0
var in_zone_time := 0.0
var total_time := 0.0
var t := 0.0
var over := false
var thunder := false
var thunder_t := 0.0
var thunder_ok := false
var parts: Array = []
var col := Color(0.5, 1, 0.6)
var stage_l: Label
var info_l: Label
const STAGES := ["融药", "提纯", "凝丹"]
const STAGE_LEN := 4.5

static func start(m, id:String, done:Callable) -> void:
	var g := AlchemyGame.new()
	g.pid = id
	g.cb = done
	var root: Control = m.ui_root()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(g)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	col = D.pills[pid]["c"]
	var tier: int = D.pills[pid]["tier"]
	zone_w = 0.2 - tier * 0.03 + int(G.meta["buildings"].get("alchemy", 1)) * 0.01
	if G.run.get("char", "") == "xiaoyixian" or G.meta.get("last_char", "") == "xiaoyixian":
		zone_w += 0.02
	UI.label(self, "炼制 · " + D.pills[pid]["n"], Vector2(0, 16), 24, col, 960, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "按住 空格 / 鼠标左键 催动火焰，松开降温。让火候停留在金色区间内！", Vector2(0, 50), 12, Color(0.95, 0.9, 0.8), 960, HORIZONTAL_ALIGNMENT_CENTER)
	stage_l = UI.label(self, "", Vector2(0, 460), 16, Color(1, 0.85, 0.5), 960, HORIZONTAL_ALIGNMENT_CENTER)
	info_l = UI.label(self, "", Vector2(0, 486), 12, Color(0.85, 0.85, 0.85), 960, HORIZONTAL_ALIGNMENT_CENTER)

func _pressing() -> bool:
	return Input.is_action_pressed("dodge") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)

func _process(d:float) -> void:
	t += d
	_update_parts(d)
	if over:
		queue_redraw()
		return
	if thunder:
		thunder_t += d
		if thunder_t > 1.8:
			_finish()
		queue_redraw()
		return
	# 火候物理
	var push := 1.5 if _pressing() else -1.1
	heat_v = lerpf(heat_v, push, d * 3.5)
	heat = clampf(heat + heat_v * d * 0.5, 0, 1)
	# 区间移动（阶段越后越快）
	zone_t += d * (0.6 + stage * 0.35)
	zone_c = 0.5 + sin(zone_t) * 0.22 + sin(zone_t * 2.3 + 1) * 0.08 * stage
	var inz: bool = abs(heat - zone_c) < zone_w * 0.5
	total_time += d
	if inz:
		in_zone_time += d
		stage_prog += d
		if randf() < 0.5:
			parts.append({"p": Vector2(480 + randf_range(-30, 30), 300), "v": Vector2(randf_range(-20, 20), randf_range(-90, -40)), "l": 1.0, "c": col})
	else:
		stage_prog += d * 0.35
		if heat > zone_c + zone_w * 0.5 and randf() < 0.3:
			parts.append({"p": Vector2(480 + randf_range(-30, 30), 300), "v": Vector2(randf_range(-30, 30), randf_range(-60, -20)), "l": 0.8, "c": Color(0.3, 0.3, 0.3)})
	if heat > 0.97:
		in_zone_time -= d * 0.6
	if stage_prog >= STAGE_LEN:
		stage += 1
		stage_prog = 0
		Au.sfx("pill", -4)
		if stage >= STAGES.size():
			_stage_done()
	stage_l.text = "阶段：%s（%d/3）" % [STAGES[min(stage, 2)], min(stage + 1, 3)]
	info_l.text = "成丹度 %d%%" % int(_ratio() * 100)
	queue_redraw()

func _ratio() -> float:
	return clampf(in_zone_time / max(0.1, total_time), 0, 1)

func _quality() -> int:
	var r := _ratio()
	if r > 0.82: return 4 if (not thunder or thunder_ok) else 3
	if r > 0.62: return 3
	if r > 0.42: return 2
	if r > 0.22: return 1
	return 0

func _stage_done() -> void:
	if _ratio() > 0.82:
		thunder = true
		thunder_t = 0
		stage_l.text = "丹雷降临！在雷光落下时（圆环收缩至最小）按 空格！"
		Au.sfx("thunder")
		G.unlock_ach("ach_pill_thunder")
	else:
		_finish()

func _input(e:InputEvent) -> void:
	if thunder and not over:
		var pressed = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE) or (e is InputEventMouseButton and e.pressed)
		if pressed:
			get_viewport().set_input_as_handled()
			thunder_ok = abs(thunder_t - 1.0) < 0.18
			Au.sfx("thunder_small" if thunder_ok else "fail")
			_finish()

func _finish() -> void:
	if over:
		return
	over = true
	var q := _quality()
	var names := ["失败", "下品", "中品", "上品", "完美"]
	var cols := [Color(0.6, 0.3, 0.3), Color(0.8, 0.8, 0.8), Color(0.5, 0.9, 1), Color(0.8, 0.6, 1), Color(1, 0.8, 0.3)]
	UI.label(self, names[q], Vector2(0, 390), 24, cols[q], 960, HORIZONTAL_ALIGNMENT_CENTER)
	if q > 0:
		for i in 40:
			parts.append({"p": Vector2(480, 290), "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 220), "l": 1.0, "c": col.lightened(0.3)})
		Au.sfx("levelup")
	else:
		Au.sfx("fail")
	await get_tree().create_timer(1.3).timeout
	get_parent().queue_free()
	cb.call(q)

func _update_parts(d:float) -> void:
	for p in parts.duplicate():
		p["p"] += p["v"] * d
		p["l"] -= d
		if p["l"] <= 0:
			parts.erase(p)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.02, 0.95))
	var c := Vector2(480, 300)
	# 丹炉
	var cauldron := G.tex("res://assets/obj/cauldron.png")
	var fl_h := 20 + heat * 60
	for i in 14:
		var k := float(i) / 14
		var x := c.x - 40 + k * 80
		var h := fl_h * (0.6 + 0.4 * sin(t * 12 + i * 1.7))
		var fc := Color(1, 0.4, 0.1).lerp(Color(1, 0.95, 0.5), heat)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8, c.y + 70), Vector2(x, c.y + 70 - h), Vector2(x + 8, c.y + 70)]), Color(fc.r, fc.g, fc.b, 0.7))
	if cauldron:
		draw_texture_rect(cauldron, Rect2(c - Vector2(72, 80), Vector2(144, 150)), false)
	# 丹光
	var glow := _ratio()
	draw_circle(c + Vector2(0, -80), 10 + glow * 18 + sin(t * 4) * 2, Color(col.r, col.g, col.b, 0.25 + glow * 0.4))
	# 火候条
	var bar := Rect2(640, 110, 34, 300)
	draw_rect(bar.grow(3), Color(0.3, 0.25, 0.15))
	for i in 30:
		var k := float(i) / 30
		draw_rect(Rect2(bar.position.x, bar.end.y - (k + 1.0 / 30) * bar.size.y, bar.size.x, bar.size.y / 30 + 1), Color(0.2, 0.3, 0.9).lerp(Color(1, 0.3, 0.1), k).darkened(0.4))
	var zy := bar.end.y - zone_c * bar.size.y
	var zh := zone_w * bar.size.y
	draw_rect(Rect2(bar.position.x - 4, zy - zh / 2, bar.size.x + 8, zh), Color(1, 0.85, 0.3, 0.45))
	draw_rect(Rect2(bar.position.x - 4, zy - zh / 2, bar.size.x + 8, zh), Color(1, 0.9, 0.4), false, 2)
	var hy := bar.end.y - heat * bar.size.y
	draw_colored_polygon(PackedVector2Array([Vector2(bar.position.x - 14, hy - 7), Vector2(bar.position.x - 2, hy), Vector2(bar.position.x - 14, hy + 7)]), Color.WHITE)
	draw_line(Vector2(bar.position.x, hy), Vector2(bar.end.x, hy), Color.WHITE, 2)
	draw_string(G.font, Vector2(bar.position.x - 20, bar.position.y - 10), "火候", HORIZONTAL_ALIGNMENT_CENTER, 74, 12, Color(1, 0.8, 0.5))
	# 阶段进度
	for i in 3:
		var r := Rect2(300 + i * 80, 430, 70, 8)
		draw_rect(r, Color(0.2, 0.2, 0.2))
		var k := 1.0 if i < stage else (stage_prog / STAGE_LEN if i == stage else 0.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
	# 丹雷
	if thunder:
		var ring_r := lerpf(160, 20, clampf(thunder_t / 1.0, 0, 1.3))
		draw_arc(c + Vector2(0, -80), max(ring_r, 10), 0, TAU, 48, Color(0.8, 0.7, 1), 3)
		draw_arc(c + Vector2(0, -80), 22, 0, TAU, 32, Color(1, 1, 1, 0.6), 1)
		if thunder_t > 0.9 and thunder_t < 1.1:
			var p := c + Vector2(0, -400)
			for k in 8:
				var np := p + Vector2(randf_range(-20, 20), 40)
				draw_line(p, np, Color(0.85, 0.8, 1), 3)
				p = np
	for p in parts:
		var pc: Color = p["c"]
		pc.a = clampf(p["l"], 0, 1)
		draw_rect(Rect2(p["p"], Vector2(3, 3)), pc)
