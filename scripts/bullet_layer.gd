class_name BulletLayer
extends Node2D
## 统一绘制：玩家弹丸、敌方弹幕、区域、环绕物、召唤物、掉落物、陷阱、粒子（批量绘制，性能好）

var b

func _ready() -> void:
	pass

func _draw() -> void:
	if b == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	# 区域（地面）
	for z in b.zones:
		if z["type"] == "zone":
			var k: float = clampf(z["t"] / max(0.01, z["life"]), 0, 1)
			var c: Color = z["col"]
			var a = 0.18 * min(1.0, k * 4.0)
			draw_set_transform(z["p"], 0, Vector2(1, 0.62))
			draw_circle(Vector2.ZERO, z["r"], Color(c.r, c.g, c.b, a))
			draw_arc(Vector2.ZERO, z["r"], 0, TAU, 40, Color(c.r, c.g, c.b, a * 3), 2.0)
			for i in 3:
				var ang: float = t * (2.0 + i) + i * 2.1
				draw_arc(Vector2.ZERO, z["r"] * (0.4 + i * 0.2), ang, ang + 1.8, 12, Color(c.r, c.g, c.b, a * 2.5), 2.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 陷阱
	for tp in b.traps:
		var c2: Color = tp["col"]
		var blink := 0.5 + 0.5 * sin(t * 10)
		draw_circle(tp["p"], 6, Color(c2.r, c2.g, c2.b, 0.9))
		draw_arc(tp["p"], tp["r"] * 0.5, 0, TAU, 24, Color(c2.r, c2.g, c2.b, 0.3 * blink), 1.5)
	# 掉落物
	for pk in b.pickups:
		var p: Vector2 = pk["p"] + Vector2(0, -pk["z"])
		match pk["k"]:
			"exp":
				draw_circle(p, 3.2, Color(0.4, 0.85, 1, 0.35))
				draw_circle(p, 2.0, Color(0.7, 0.95, 1))
			"gold":
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.55, 0.35, 0.05))
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.82, 0.25))
				draw_rect(Rect2(p - Vector2(1, 2), Vector2(1, 1)), Color(1, 1, 0.8))
			"heal":
				draw_circle(p, 5, Color(0.2, 0.6, 0.2))
				draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), Color(0.8, 1, 0.8))
				draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), Color(0.8, 1, 0.8))
			_:
				var hc: Color = D.herbs.get(pk["k"].substr(5), {"c": Color.WHITE})["c"]
				draw_circle(p, 6, Color(hc.r, hc.g, hc.b, 0.3 + 0.2 * sin(t * 6)))
				draw_line(p + Vector2(0, 4), p + Vector2(0, -3), Color(0.3, 0.6, 0.2), 2)
				draw_circle(p + Vector2(-2, -3), 2.5, hc)
				draw_circle(p + Vector2(2, -4), 2.5, hc)
	# 召唤物（火焰灵兽）
	for s in b.summons:
		var sc: Color = s["col"]
		var sp: Vector2 = s["p"]
		draw_set_transform(sp, 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 9, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		for i in 4:
			draw_circle(sp + Vector2(sin(t * 8 + i) * 2, -10 - i * 3), 9 - i * 2, sc.lerp(Color(1, 1, 0.8), i * 0.25))
		draw_circle(sp + Vector2(-3, -12), 1.5, Color(0.1, 0, 0))
		draw_circle(sp + Vector2(3, -12), 1.5, Color(0.1, 0, 0))
	# 分身
	if b.decoy.size() > 0:
		var dp: Vector2 = b.decoy["p"]
		draw_arc(dp + Vector2(0, -20), 16, 0, TAU, 20, Color(0.7, 0.5, 1, 0.5), 2)
	# 粒子（普通）
	for p2 in b.particles:
		if p2["add"]:
			continue
		var k2: float = 1.0 - p2["t"] / p2["life"]
		var c3: Color = p2["c"]
		draw_rect(Rect2(p2["p"], Vector2(p2["s"], p2["s"])), Color(c3.r, c3.g, c3.b, c3.a * k2))
	# 玩家弹丸
	for p3 in b.pprojs:
		var c4: Color = p3["col"]
		var pos: Vector2 = p3["p"]
		var r: float = p3["r"]
		var dir: Vector2 = p3["v"].normalized()
		if p3.get("crescent", false):
			var ang := dir.angle()
			draw_arc(pos - dir * r * 0.5, r * 1.3, ang - 1.2, ang + 1.2, 12, Color(c4.r, c4.g, c4.b, 0.5), r * 0.7)
			draw_arc(pos - dir * r * 0.5, r * 1.3, ang - 1.0, ang + 1.0, 12, Color(1, 1, 1, 0.9), r * 0.25)
		else:
			# 拖尾
			for i in 4:
				var tp2 := pos - dir * r * (i + 1) * 0.9
				draw_circle(tp2, r * (0.8 - i * 0.17), Color(c4.r, c4.g, c4.b, 0.35 - i * 0.07))
			draw_circle(pos, r * 1.25, Color(c4.r, c4.g, c4.b, 0.3))
			draw_circle(pos, r, c4)
			draw_circle(pos - dir * 1, r * 0.55, Color(1, 1, 0.9, 0.95))
	# 环绕物
	for o in b.orbits:
		if not o.has("p"):
			continue
		var c5: Color = o["col"]
		draw_circle(o["p"], o["size"] * 1.4, Color(c5.r, c5.g, c5.b, 0.25))
		draw_circle(o["p"], o["size"], c5)
		draw_circle(o["p"], o["size"] * 0.5, Color(1, 1, 1, 0.8))
	# 敌方弹幕（高辨识度：暗边 + 亮芯）
	for bl in b.ebullets:
		var c6: Color = bl["col"]
		var bp: Vector2 = bl["p"]
		var br: float = bl["r"]
		draw_circle(bp, br + 2.5, Color(0.1, 0, 0.05, 0.85))
		draw_circle(bp, br + 1, c6)
		draw_circle(bp, br * 0.5, Color(1, 1, 1))
	# 粒子（加色）
	for p4 in b.particles:
		if not p4["add"]:
			continue
		var k3: float = 1.0 - p4["t"] / p4["life"]
		var c7: Color = p4["c"]
		var s2: float = p4["s"] * (0.5 + k3 * 0.5)
		draw_rect(Rect2(p4["p"] - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), Color(c7.r, c7.g, c7.b, k3))
