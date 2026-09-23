class_name Fx
extends Node2D
## 通用程序化特效：刀光、冲击环、预警圈、预警线、火莲、光束、爆裂、伤害数字

var type := ""
var t := 0.0
var life := 0.5
var col := Color.WHITE
var col2 := Color.WHITE
var r := 40.0
var r2 := 0.0
var ang := 0.0
var arc := PI
var width := 20.0
var length := 100.0
var text := ""
var vel := Vector2.ZERO
var colors: Array = []
var follow: Node2D = null
var big := false
var seed_ := 0.0

static var add_mat: CanvasItemMaterial

static func additive() -> CanvasItemMaterial:
	if add_mat == null:
		add_mat = CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return add_mat

func _ready() -> void:
	seed_ = randf() * 100.0
	if type in ["slash", "ring", "burst", "lotus", "beam", "glow", "pillar", "bolt", "petal_ring", "aura"]:
		material = Fx.additive()
	if type == "text":
		z_index = 50
	elif type in ["tele_circle", "tele_line", "tele_fan"]:
		z_index = -5
	else:
		z_index = 20

func _process(delta:float) -> void:
	t += delta
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	if type == "text":
		position += vel * delta
		vel.y += 260 * delta
		vel.x *= 0.96
	if t >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(t / life, 0.0, 1.0)
	match type:
		"slash":
			# 月牙刀光：多层弧线，外亮内暗
			var a0 := ang - arc * 0.5
			var sweep := clampf(k * 3.0, 0.0, 1.0)
			var fade := 1.0 - clampf((k - 0.3) / 0.7, 0.0, 1.0)
			var segs := 18
			for layer in 4:
				var rr := r * (0.55 + layer * 0.15)
				var w := width * (1.0 - layer * 0.2) * fade
				var c := col.lerp(Color.WHITE, layer * 0.22)
				c.a = fade * (0.35 + layer * 0.18)
				var pts := PackedVector2Array()
				for i in segs + 1:
					var aa := a0 + arc * sweep * float(i) / segs
					pts.append(Vector2(cos(aa), sin(aa)) * rr)
				if pts.size() > 1:
					draw_polyline(pts, c, max(1.0, w * (0.4 + 0.6 * sin(PI * 0.5))), true)
		"ring":
			var rr := lerpf(r2, r, ease(k, 0.4))
			var c := col
			c.a = (1.0 - k)
			draw_arc(Vector2.ZERO, rr, 0, TAU, 48, c, max(1.0, width * (1.0 - k)), true)
			c.a *= 0.35
			draw_circle(Vector2.ZERO, rr, c)
		"glow":
			var c := col
			c.a = (1.0 - k) * 0.9
			var rr := r * (0.6 + 0.4 * k)
			for i in 4:
				var cc := c
				cc.a = c.a * (0.2 + i * 0.2)
				draw_circle(Vector2.ZERO, rr * (1.0 - i * 0.22), cc)
		"burst":
			var c := col
			c.a = 1.0 - k
			for i in 14:
				var aa := TAU * i / 14.0 + seed_
				var l0 := r * k * 0.6
				var l1 := r * (0.3 + k)
				draw_line(Vector2(cos(aa), sin(aa)) * l0, Vector2(cos(aa), sin(aa)) * l1, c, 3.0 * (1.0 - k) + 1.0)
			draw_circle(Vector2.ZERO, r * 0.5 * (1.0 - k), Color(1, 1, 1, (1.0 - k) * 0.8))
		"tele_circle":
			var c := col
			var a := 0.25 + 0.2 * sin(t * 20.0)
			draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, a * 0.5))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(c.r, c.g, c.b, 0.9), 2.0, true)
			draw_circle(Vector2.ZERO, r * k, Color(c.r, c.g, c.b, 0.35))
		"tele_line":
			var c := col
			var dir := Vector2.from_angle(ang)
			var nrm := dir.orthogonal() * width * 0.5
			var p := PackedVector2Array([nrm, dir * length + nrm, dir * length - nrm, -nrm])
			draw_colored_polygon(p, Color(c.r, c.g, c.b, 0.18 + 0.12 * sin(t * 22.0)))
			var p2 := PackedVector2Array([nrm, dir * length * k + nrm, dir * length * k - nrm, -nrm])
			draw_colored_polygon(p2, Color(c.r, c.g, c.b, 0.35))
			draw_line(nrm, dir * length + nrm, Color(c.r, c.g, c.b, 0.8), 1.5)
			draw_line(-nrm, dir * length - nrm, Color(c.r, c.g, c.b, 0.8), 1.5)
		"tele_fan":
			var c := col
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 17:
				var aa := ang - arc * 0.5 + arc * i / 16.0
				pts.append(Vector2.from_angle(aa) * r)
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.2 + 0.1 * sin(t * 20)))
		"beam":
			var dir := Vector2.from_angle(ang)
			var fade := 1.0 - clampf((k - 0.75) / 0.25, 0, 1)
			var grow := clampf(k * 6.0, 0, 1)
			for i in 4:
				var w := width * grow * (1.0 - i * 0.22) * (0.85 + 0.15 * sin(t * 40.0 + i))
				var c := col.lerp(Color.WHITE, i * 0.28)
				c.a = fade * (0.3 + i * 0.2)
				draw_line(Vector2.ZERO, dir * length, c, max(1.0, w))
			draw_circle(Vector2.ZERO, width * 0.8 * grow, Color(col.r, col.g, col.b, fade * 0.6))
		"pillar":
			var fade := 1.0 - k
			var h := r * 3.0 * clampf(k * 5.0, 0, 1)
			for i in 3:
				var w := r * (1.0 - i * 0.3)
				var c := col.lerp(Color.WHITE, i * 0.3)
				c.a = fade * (0.3 + i * 0.25)
				draw_rect(Rect2(-w * 0.5, -h, w, h), c)
			draw_circle(Vector2.ZERO, r * 0.8, Color(col.r, col.g, col.b, fade * 0.5))
		"bolt":
			var fade := 1.0 - k
			var pts := PackedVector2Array()
			var steps := 10
			var target := Vector2.from_angle(ang) * length
			var rng := RandomNumberGenerator.new()
			rng.seed = int(seed_ * 1000) + int(t * 30)
			for i in steps + 1:
				var f := float(i) / steps
				var off := target.orthogonal().normalized() * rng.randf_range(-12, 12) * (1.0 if i > 0 and i < steps else 0.0)
				pts.append(target * f + off)
			draw_polyline(pts, Color(col.r, col.g, col.b, fade), 4.0)
			draw_polyline(pts, Color(1, 1, 1, fade), 1.5)
		"lotus":
			_draw_lotus(k)
		"petal_ring":
			var c := col
			c.a = 1.0 - k
			for i in 8:
				var aa := TAU * i / 8.0 + t * 2.0
				var p := Vector2.from_angle(aa) * r * (0.4 + k * 0.8)
				_petal(p, aa, r * 0.35, c)
		"aura":
			var c := col
			for i in 3:
				var rr := r * (0.8 + 0.2 * sin(t * 6.0 + i * 2.0))
				c.a = 0.12 + 0.05 * i
				draw_circle(Vector2.ZERO, rr * (1.0 - i * 0.25), c)
		"text":
			var fs := 24 if big else 12
			var a := 1.0 - clampf((k - 0.6) / 0.4, 0, 1)
			var sc = 1.0 + max(0.0, 0.4 - t * 3.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2(sc, sc))
			draw_string_outline(G.font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 4, Color(0, 0, 0, a))
			draw_string(G.font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(col.r, col.g, col.b, a))

func _petal(p:Vector2, aa:float, sz:float, c:Color) -> void:
	var d := Vector2.from_angle(aa)
	var n := d.orthogonal()
	var pts := PackedVector2Array([p - d * sz * 0.3, p + n * sz * 0.45 + d * sz * 0.4, p + d * sz * 1.2, p - n * sz * 0.45 + d * sz * 0.4])
	draw_colored_polygon(pts, c)

func _draw_lotus(k:float) -> void:
	# 佛怒火莲：多色花瓣层层绽放，最后收缩爆炸
	var cols: Array = colors if colors.size() > 0 else [col]
	var bloom := clampf(k / 0.7, 0.0, 1.0)
	var fade := 1.0 - clampf((k - 0.85) / 0.15, 0.0, 1.0)
	var layers := cols.size()
	for L in range(layers - 1, -1, -1):
		var c: Color = cols[L]
		var n := 6 + L * 2
		var rr := r * (0.35 + 0.65 * float(L + 1) / layers) * ease(bloom, 0.5)
		for i in n:
			var aa := TAU * i / n + t * (0.6 + L * 0.3) * (1 if L % 2 == 0 else -1)
			var cc := c
			cc.a = fade * 0.55
			_petal(Vector2.ZERO, aa, rr, cc)
			var c2 := c.lerp(Color.WHITE, 0.5)
			c2.a = fade * 0.4
			_petal(Vector2.ZERO, aa, rr * 0.6, c2)
	draw_circle(Vector2.ZERO, r * 0.2 * (1.0 + sin(t * 30.0) * 0.2), Color(1, 1, 1, fade))
