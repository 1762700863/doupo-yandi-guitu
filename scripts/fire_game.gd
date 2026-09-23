class_name FireGame
extends Control
## 吞噬异火小游戏：异火在经脉中反噬。用鼠标/AD 旋转“斗气护盾”挡住火流，保护心脉直到炼化完成。

var fid := ""
var diff := 0.5
var cb: Callable
var col := Color(1, 0.5, 0.2)
var t := 0.0
var dur := 14.0
var heart := 100.0
var shield_ang := 0.0
var shield_w := 0.9
var flames: Array = []   # {a, r, v, s}
var spawn_t := 0.0
var parts: Array = []
var over := false
var shake := 0.0
var C := Vector2(480, 290)
var title_l: Label

static func start(m, id:String, d:float, done:Callable) -> void:
	var g := FireGame.new()
	g.fid = id
	g.diff = d
	g.cb = done
	var root: Control = m.ui_root()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(g)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var f: Dictionary = D.fire_by_id[fid]
	col = f["c"]
	dur = 11.0 + diff * 8.0
	shield_w = 1.05 - diff * 0.35
	if G.run["flags"].get("humai", false):
		shield_w += 0.25
	if G.run.get("char", "") == "xiaoyan":
		shield_w += 0.1
	title_l = UI.label(self, "吞噬 · " + f["n"], Vector2(0, 16), 24, col.lightened(0.2), 960, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(self, "移动鼠标 或 A/D 旋转斗气护盾，挡住反噬的火流，守住心脉！", Vector2(0, 50), 12, Color(0.95, 0.9, 0.8), 960, HORIZONTAL_ALIGNMENT_CENTER)
	Au.sfx("whoosh_fire")
	Au.music("boss")

func _process(d:float) -> void:
	if over:
		queue_redraw()
		_update_parts(d)
		return
	t += d
	# 输入
	var mp := get_local_mouse_position()
	if Input.is_action_pressed("left"):
		shield_ang -= 4.0 * d
	elif Input.is_action_pressed("right"):
		shield_ang += 4.0 * d
	elif mp.distance_to(C) > 30:
		var target := (mp - C).angle()
		shield_ang = lerp_angle(shield_ang, target, clampf(d * 18, 0, 1))
	# 生成火流
	spawn_t -= d
	var prog := t / dur
	if spawn_t <= 0:
		var rate := lerpf(0.55, 0.22, diff) * lerpf(1.0, 0.6, prog)
		spawn_t = rate
		var n := 1 + (1 if randf() < diff * prog else 0)
		for i in n:
			var a := randf() * TAU
			if randf() < 0.5 and flames.size() > 0:
				a = flames[-1]["a"] + randf_range(-0.8, 0.8)
			flames.append({"a": a, "r": 260.0, "v": lerpf(110, 190, diff) * randf_range(0.85, 1.2) * (1 + prog * 0.4), "s": randf_range(7, 12), "big": randf() < 0.12 + diff * 0.1, "wob": randf() * TAU})
	for fl in flames.duplicate():
		fl["r"] -= fl["v"] * d
		fl["a"] += sin(t * 3 + fl["wob"]) * d * 0.3
		if fl["r"] <= 78 and fl["r"] > 60:
			var diffa: float = abs(wrapf(fl["a"] - shield_ang, -PI, PI))
			if diffa < shield_w * 0.5:
				flames.erase(fl)
				_burst(C + Vector2.from_angle(fl["a"]) * 74, col, 8)
				Au.sfx("hit", -12, 1.4)
				continue
		if fl["r"] <= 34:
			flames.erase(fl)
			var dmg := 14.0 if fl["big"] else 8.0
			heart -= dmg
			shake = 6
			_burst(C + Vector2.from_angle(fl["a"]) * 34, Color(1, 0.3, 0.2), 14)
			Au.sfx("hurt", -6)
	shake = max(0, shake - d * 30)
	_update_parts(d)
	if heart <= 0:
		_end(false)
	elif t >= dur:
		_end(true)
	queue_redraw()

func _update_parts(d:float) -> void:
	for p in parts.duplicate():
		p["p"] += p["v"] * d
		p["v"] *= 0.92
		p["l"] -= d
		if p["l"] <= 0:
			parts.erase(p)

func _burst(p:Vector2, c:Color, n:int) -> void:
	for i in n:
		parts.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(60, 200), "l": randf_range(0.3, 0.6), "c": c})

func _end(ok:bool) -> void:
	over = true
	flames.clear()
	if ok:
		Au.sfx("fire_get")
		for i in 80:
			parts.append({"p": C, "v": Vector2.from_angle(randf() * TAU) * randf_range(80, 400), "l": randf_range(0.5, 1.2), "c": col.lightened(randf() * 0.5)})
	else:
		Au.sfx("fail")
	UI.label(self, "炼化成功！" if ok else "反噬失控……", Vector2(0, 460), 24, col if ok else Color(1, 0.3, 0.3), 960, HORIZONTAL_ALIGNMENT_CENTER)
	await get_tree().create_timer(1.6).timeout
	var ch: Dictionary = D.chapters[int(G.run["chapter"])]
	Au.music(ch.get("music", "battle1"))
	get_parent().queue_free()
	cb.call(ok)

func _draw() -> void:
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var c := C + off
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.02, 0.96))
	# 经脉纹路
	for i in 16:
		var a := i * TAU / 16 + sin(t * 0.3) * 0.1
		var pts := PackedVector2Array()
		for k in 12:
			var r := 40.0 + k * 20
			pts.append(c + Vector2.from_angle(a + sin(k * 0.6 + t + i) * 0.08) * r)
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.08 + 0.05 * sin(t * 2 + i)), 2.0)
	# 进度环
	var prog := clampf(t / dur, 0, 1)
	draw_arc(c, 250, -PI / 2, -PI / 2 + TAU, 96, Color(1, 1, 1, 0.08), 6)
	draw_arc(c, 250, -PI / 2, -PI / 2 + TAU * prog, 96, col, 6)
	draw_string(G.font, c + Vector2(-100, 272), "炼化 %d%%" % int(prog * 100), HORIZONTAL_ALIGNMENT_CENTER, 200, 12, col)
	# 火流
	for fl in flames:
		var p: Vector2 = c + Vector2.from_angle(fl["a"]) * fl["r"]
		var s: float = fl["s"] * (1.6 if fl["big"] else 1.0)
		for k in 5:
			var tp: Vector2 = c + Vector2.from_angle(fl["a"]) * (fl["r"] + k * s * 0.9)
			draw_circle(tp, s * (1.0 - k * 0.17), Color(col.r, col.g, col.b, 0.5 - k * 0.09))
		draw_circle(p, s * 0.55, Color(1, 1, 0.85, 0.9))
	# 护盾
	var sc := Color(0.6, 0.85, 1)
	draw_arc(c, 74, shield_ang - shield_w * 0.5, shield_ang + shield_w * 0.5, 24, Color(sc.r, sc.g, sc.b, 0.3), 16)
	draw_arc(c, 74, shield_ang - shield_w * 0.5, shield_ang + shield_w * 0.5, 24, Color(0.9, 0.97, 1), 4)
	# 心脉
	var hk := clampf(heart / 100.0, 0, 1)
	var beat := 1.0 + 0.08 * sin(t * (6 + (1 - hk) * 8))
	draw_circle(c, 30 * beat, Color(0.25, 0.05, 0.05))
	draw_circle(c, 26 * beat * (0.4 + 0.6 * hk), Color(1, 0.35, 0.3).lerp(Color(1, 0.8, 0.6), hk))
	draw_arc(c, 32, -PI / 2, -PI / 2 + TAU * hk, 48, Color(1, 0.5, 0.45), 3)
	draw_string(G.font, c + Vector2(-50, 52), "心脉 %d" % int(max(heart, 0)), HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Color(1, 0.8, 0.8))
	for p in parts:
		var pc: Color = p["c"]
		pc.a = clampf(p["l"] * 2, 0, 1)
		draw_rect(Rect2(p["p"] + off, Vector2(3, 3)), pc)
