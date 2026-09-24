class_name BattleHUD
extends CanvasLayer
## 战斗 HUD：生命/护盾/斗气/境界、技能栏（冷却/自动标记）、Boss 血条、横幅、突破演出、受伤暗角

var b
var root: Control
var draw_node: HudDraw
var boss: Enemy = null
var banners: Array = []
var boss_lines: Array = []
var flash_col := Color(0, 0, 0, 0)
var dmg_flash := 0.0
var brk_t := 0.0
var brk_txt := ""
var brk_col := Color.WHITE
var ult_t := 0.0
var ult_txt := ""
var ult_col := Color.WHITE

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size = Vector2(960, 540)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	draw_node = HudDraw.new()
	draw_node.h = self
	draw_node.size = Vector2(960, 540)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(draw_node)

func show_boss(e:Enemy) -> void:
	boss = e
	if e and e.is_boss:
		banner(e.data["n"], Color(1, 0.4, 0.3), e.data.get("t", ""))
		if e.phases.size() > 0 and e.phases[0]["line"] != "":
			boss_line(e.data["n"], e.phases[0]["line"])

func hide_boss() -> void:
	boss = null

func banner(txt:String, col:Color, sub:String="") -> void:
	banners.append({"txt": txt, "sub": sub, "col": col, "t": 0.0})

func boss_line(who:String, txt:String) -> void:
	boss_lines = [{"who": who, "txt": txt, "t": 0.0}]

func flash_damage() -> void:
	dmg_flash = 1.0

func screen_flash(c:Color) -> void:
	if G.settings["fx"] < 0.5:
		return
	flash_col = Color(c.r, c.g, c.b, 0.35)

func breakthrough(txt:String, col:Color) -> void:
	brk_t = 2.2
	brk_txt = txt
	brk_col = col

func ult_banner(txt:String, col:Color) -> void:
	ult_t = 1.3
	ult_txt = txt
	ult_col = col

func _process(delta:float) -> void:
	for bn in banners:
		bn["t"] += delta
	banners = banners.filter(func(x): return x["t"] < 2.2)
	for bl in boss_lines:
		bl["t"] += delta
	boss_lines = boss_lines.filter(func(x): return x["t"] < 3.5)
	flash_col.a = max(0.0, flash_col.a - delta * 1.5)
	dmg_flash = max(0.0, dmg_flash - delta * 2.5)
	brk_t -= delta
	ult_t -= delta
	draw_node.queue_redraw()


class HudDraw extends Control:
	var h
	func _txt(pos:Vector2, s:String, sz:int, col:Color, align:int=HORIZONTAL_ALIGNMENT_LEFT, w:float=-1, outline:int=4) -> void:
		sz = max(sz, 10)
		if w < 0 and align == HORIZONTAL_ALIGNMENT_RIGHT:
			pos.x -= G.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			align = HORIZONTAL_ALIGNMENT_LEFT
		elif w < 0 and align == HORIZONTAL_ALIGNMENT_CENTER:
			pos.x -= G.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x * 0.5
			align = HORIZONTAL_ALIGNMENT_LEFT
		draw_string_outline(G.font, pos, s, align, w, sz, outline, Color(0, 0, 0, col.a * 0.9))
		draw_string(G.font, pos, s, align, w, sz, col)

	func _bar(r:Rect2, k:float, col:Color, bg:Color=Color(0.08, 0.05, 0.05, 0.85)) -> void:
		draw_rect(r.grow(1), Color(0, 0, 0, 0.9))
		draw_rect(r, bg)
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0, 1), r.size.y)), col)
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0, 1), max(1.0, r.size.y * 0.3))), col.lightened(0.35))

	func _draw() -> void:
		var b = h.b
		if b == null or b.player == null or G.run.is_empty():
			return
		var p: Player = b.player
		var th := UI.theme_cols()
		var t := Time.get_ticks_msec() * 0.001
		# ---- 左上：头像 + 生命 + 斗气 ----
		var por: Texture2D = G.portrait(D.chars[p.cid]["spr"])
		draw_rect(Rect2(10, 10, 52, 52), Color(0, 0, 0, 0.7))
		if por:
			var ps: float = 50.0 / max(por.get_width(), por.get_height()) * 1.6
			draw_set_transform(Vector2(11, 11), 0, Vector2.ONE)
			draw_texture_rect_region(por, Rect2(0, 0, 50, 50), Rect2(por.get_width() * 0.5 - 25 / ps * 1.0 - 5, 0, 50 / ps * 1.6, 50 / ps * 1.6))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_rect(Rect2(10, 10, 52, 52), th["border"], false, 2)
		var hpk: float = p.hp / p.st["hp_max"]
		_bar(Rect2(68, 14, 200, 12), hpk, Color(0.85, 0.2, 0.2) if hpk > 0.3 else Color(1, 0.3 + 0.2 * sin(t * 8), 0.2))
		if p.shield > 0:
			draw_rect(Rect2(68, 14, 200 * clampf(p.shield / p.st["hp_max"], 0, 1), 4), Color(0.5, 0.8, 1))
		_txt(Vector2(72, 25), "%d / %d" % [int(p.hp), int(p.st["hp_max"])], 12, Color.WHITE)
		var realm: int = int(G.run["realm"])
		var need := G.exp_needed(realm)
		var rc: Color = D.REALM_COLORS[D.realm_major(realm)]
		_bar(Rect2(68, 30, 200, 6), float(G.run["exp"]) / need, rc)
		_txt(Vector2(68, 50), D.realm_name(realm) + ("（已达本章上限）" if realm >= G.realm_cap() else ""), 12, rc)
		# 金币/药材
		_txt(Vector2(12, 78), "金币 %d" % int(G.run["gold"]), 12, Color(1, 0.85, 0.3))
		var hx := 90.0
		for hk in G.run["herbs"]:
			var n: int = int(G.run["herbs"][hk])
			if n > 0:
				draw_circle(Vector2(hx, 74), 4, D.herbs[hk]["c"])
				_txt(Vector2(hx + 6, 78), str(n), 8, Color.WHITE)
				hx += 24
		# 异火
		var fx := 12.0
		for f in G.run["fires"]:
			var fc: Color = D.fire_by_id[f]["c"]
			for i in 3:
				var pts := PackedVector2Array([Vector2(fx + i, 104), Vector2(fx + 6, 88 - i * 2 + sin(t * 5 + fx) * 2), Vector2(fx + 12 - i, 104)])
				draw_colored_polygon(pts, fc.lerp(Color.WHITE, i * 0.3))
			fx += 16
		# 角色机制条
		var mech_y := 116.0
		match p.cid:
			"xuner":
				_bar(Rect2(12, mech_y, 120, 5), p.blood / 100.0 if p.awaken_t <= 0 else p.awaken_t / 10.0, Color(1, 0.85, 0.3))
				_txt(Vector2(136, mech_y + 7), "觉醒中" if p.awaken_t > 0 else ("血脉 [%s] 可觉醒" % G.key_name("special") if p.blood >= 100 else "血脉"), 8, Color(1, 0.85, 0.3))
			"yunyun":
				_txt(Vector2(12, mech_y + 10), "连击 %d" % p.hits_combo, 16 if p.hits_combo > 0 else 12, Color(0.6, 1, 0.9))
			"medusa":
				_txt(Vector2(12, mech_y + 8), ("蛇形" if p.special_on else "人形") + "  [%s]切换" % G.key_name("special"), 12, Color(0.8, 0.5, 1))
			"xiaoyixian":
				_txt(Vector2(12, mech_y + 8), ("燃血：开 伤害+50%%" if p.special_on else "燃血：关") + "  [%s]" % G.key_name("special"), 12, Color(0.6, 1, 0.4))
			"xiaoyan":
				_txt(Vector2(12, mech_y + 8), "普攻：%s  [%s]切换" % [D.skills[G.run["atk"]]["n"], G.key_name("special")], 12, Color(1, 0.7, 0.4))
		# ---- 底部：技能栏 ----
		var arts: Array = G.run["arts"]
		var slots := G.art_slots()
		var keys := ["Q", "E", "R", "F", "", ""]
		var akeys := ["art1", "art2", "art3", "art4"]
		var n_total := slots + G.ult_slots() + 1
		var sx := 480.0 - (n_total * 44) * 0.5
		var y := 486.0
		# 身法
		_slot(Vector2(sx, y), G.run["move"], G.key_name("dodge"), p.dodge_charges < p.st["dodge_charges"], p.dodge_recharge / max(0.01, p.cd_move()), "%d" % p.dodge_charges)
		sx += 48
		for i in slots:
			if i < arts.size():
				var id: String = arts[i]
				var k: float = max(0.0, p.cds.get(id, 0.0)) / p.cd_of(id)
				var kn: String = G.key_name(akeys[i]) if i < 4 else "自"
				_slot(Vector2(sx, y), id, kn, k > 0, k, "自" if G.run["auto"].get(id, true) and i < 4 else "")
			else:
				draw_rect(Rect2(sx, y, 40, 40), Color(0, 0, 0, 0.5))
				draw_rect(Rect2(sx, y, 40, 40), Color(0.4, 0.4, 0.4, 0.5), false, 1)
			sx += 44
		sx += 6
		var ults: Array = G.run["ults"]
		for i in G.ult_slots():
			if i < ults.size():
				var uid: String = ults[i]
				var k2: float = max(0.0, p.cds.get(uid, 0.0)) / p.cd_of(uid)
				_slot(Vector2(sx, y - 6), uid, G.key_name(["ult", "ult2"][i]), k2 > 0, k2, "", 1.2)
			sx += 54
		# 丹药
		var pills: Array = G.run["pills"]
		draw_rect(Rect2(870, 486, 40, 40), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(870, 486, 40, 40), Color(0.6, 0.9, 0.6, 0.8), false, 2)
		if pills.size() > 0:
			var pc: Color = D.pills[pills[0]]["c"]
			draw_circle(Vector2(890, 506), 10, pc.darkened(0.3))
			draw_circle(Vector2(887, 503), 5, pc.lightened(0.4))
			_txt(Vector2(872, 524), "x%d" % pills.size(), 8, Color.WHITE)
			_txt(Vector2(862, 482), D.pills[pills[0]]["n"], 8, pc)
		_txt(Vector2(898, 496), G.key_name("pill"), 8, Color(1, 0.9, 0.6))
		# 同伴默契
		if b.comp:
			_bar(Rect2(820, 470, 90, 5), b.combo_energy / 100.0, Color(0.7, 0.8, 1))
			_txt(Vector2(820, 466), "%s·%s [%s]合击" % [D.companions[b.comp.cid]["n"], b.comp.MODES[b.comp.mode], G.key_name("combo")], 8, Color(0.8, 0.9, 1))
		# ---- 右上：楼层 / 时间 ----
		var ch: Dictionary = D.chapters[int(G.run["chapter"])]
		_txt(Vector2(950, 22), "%s · %s" % [ch["n"], ch["t"]], 12, th["accent"], HORIZONTAL_ALIGNMENT_RIGHT, -1)
		var tt := int(G.run["time"])
		if b.room_type == "explore":
			_txt(Vector2(950, 40), "%02d:%02d   击杀 %d" % [tt / 60, tt % 60, int(G.run["kills"])], 11, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, -1)
		else:
			_txt(Vector2(950, 40), "%02d:%02d   击杀 %d" % [tt / 60, tt % 60, int(G.run["kills"])], 11, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, -1)
		if b.room_type == "fight":
			_txt(Vector2(950, 56), "剩余 %d 波 · 敌人 %d" % [max(0, b.waves_left), b.enemies.size()], 11, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, -1)
		if G.run["tianjie"].size() > 0:
			_txt(Vector2(950, 70 if b.room_type != "explore" else 204), "天劫 %d" % G.run["tianjie"].size(), 11, Color(1, 0.4, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, -1)
		# ---- Boss 血条 ----
		if h.boss and is_instance_valid(h.boss) and not h.boss.dead:
			var e: Enemy = h.boss
			var bw := 520.0
			var bx := 480 - bw / 2
			_txt(Vector2(bx, 452), e.data["n"], 16, Color(1, 0.85, 0.7))
			_txt(Vector2(bx + bw, 452), e.data.get("t", ""), 8, Color(0.9, 0.7, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, -1)
			_bar(Rect2(bx, 458, bw, 10), e.hp / e.hp_max, Color(0.8, 0.12, 0.1) if e.phase < 2 else Color(1, 0.2 + 0.1 * sin(t * 10), 0.1))
			for ph in e.phases.size():
				if ph > 0:
					var px: float = bx + bw * float(e.phases[ph]["hp"])
					draw_line(Vector2(px, 456), Vector2(px, 470), Color(1, 0.9, 0.6), 2)
		# ---- Boss 台词 ----
		for bl in h.boss_lines:
			var a: float = clampf(min(bl["t"] * 4, (3.5 - bl["t"]) * 2), 0, 1)
			draw_rect(Rect2(180, 120, 600, 40), Color(0, 0, 0, 0.6 * a))
			_txt(Vector2(190, 136), bl["who"], 12, Color(1, 0.6, 0.4, a))
			_txt(Vector2(190, 154), bl["txt"], 12, Color(1, 1, 1, a))
		# ---- 横幅 ----
		for bn in h.banners:
			var k3: float = bn["t"]
			var a2: float = clampf(min(k3 * 5, (2.2 - k3) * 2.5), 0, 1)
			var yy = 200.0 - (1.0 - min(1.0, k3 * 4)) * 20
			draw_rect(Rect2(0, yy - 26, 960, 44), Color(0, 0, 0, 0.45 * a2))
			var c: Color = bn["col"]
			c.a = a2
			_txt(Vector2(0, yy + 6), bn["txt"], 24, c, HORIZONTAL_ALIGNMENT_CENTER, 960, 6)
			if bn["sub"] != "":
				_txt(Vector2(0, yy + 22), bn["sub"], 12, Color(1, 1, 1, a2), HORIZONTAL_ALIGNMENT_CENTER, 960)
		# ---- 大招喝名 ----
		if h.ult_t > 0:
			var k4: float = 1.3 - h.ult_t
			var a3: float = clampf(min(k4 * 6, h.ult_t * 3), 0, 1)
			var x0 := lerpf(-300, 0, clampf(k4 * 5, 0, 1))
			var pts := PackedVector2Array([Vector2(x0, 300), Vector2(x0 + 560, 300), Vector2(x0 + 520, 350), Vector2(x0, 350)])
			draw_colored_polygon(pts, Color(0, 0, 0, 0.7 * a3))
			draw_line(Vector2(x0, 300), Vector2(x0 + 560, 300), Color(h.ult_col.r, h.ult_col.g, h.ult_col.b, a3), 2)
			draw_line(Vector2(x0, 350), Vector2(x0 + 520, 350), Color(h.ult_col.r, h.ult_col.g, h.ult_col.b, a3), 2)
			var por2: Texture2D = G.portrait(D.chars[p.cid]["spr"])
			if por2:
				var sc := 50.0 / por2.get_height() * 1.0
				draw_texture_rect(por2, Rect2(x0 + 20, 300, por2.get_width() * 50.0 / por2.get_height(), 50), false, Color(1, 1, 1, a3))
			var c2 = h.ult_col.lightened(0.3)
			c2.a = a3
			_txt(Vector2(x0 + 140, 336), h.ult_txt + "！", 24, c2, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		# ---- 突破演出 ----
		if h.brk_t > 0:
			var k5: float = 2.2 - h.brk_t
			var a4: float = clampf(min(k5 * 3, h.brk_t * 2), 0, 1)
			draw_rect(Rect2(0, 0, 960, 540), Color(h.brk_col.r, h.brk_col.g, h.brk_col.b, 0.18 * a4))
			for i in 24:
				var ang := TAU * i / 24 + k5 * 0.5
				var r1 := 60 + k5 * 200
				draw_line(Vector2(480, 250) + Vector2.from_angle(ang) * r1 * 0.3, Vector2(480, 250) + Vector2.from_angle(ang) * r1, Color(h.brk_col.r, h.brk_col.g, h.brk_col.b, 0.5 * a4), 3)
			_txt(Vector2(0, 236), "境 界 突 破", 16, Color(1, 1, 1, a4), HORIZONTAL_ALIGNMENT_CENTER, 960)
			var c3 = h.brk_col.lightened(0.2)
			c3.a = a4
			_txt(Vector2(0, 272), h.brk_txt, 24, c3, HORIZONTAL_ALIGNMENT_CENTER, 960, 8)
		# ---- 屏幕闪光/受伤暗角 ----
		if h.flash_col.a > 0:
			draw_rect(Rect2(0, 0, 960, 540), h.flash_col)
		var low := 1.0 - hpk
		var vig: float = max(h.dmg_flash * 0.5, (low - 0.6) * 0.8 if low > 0.6 else 0.0)
		if vig > 0:
			for i in 12:
				var w := 6.0 + i * 5
				var ca := Color(0.7, 0, 0, vig * (1.0 - i / 12.0) * 0.35)
				draw_rect(Rect2(0, 0, 960, w), ca)
				draw_rect(Rect2(0, 540 - w, 960, w), ca)
				draw_rect(Rect2(0, 0, w, 540), ca)
				draw_rect(Rect2(960 - w, 0, w, 540), ca)

	func _slot(pos:Vector2, id:String, key:String, on_cd:bool, k:float, badge:String, sc:float=1.0) -> void:
		var s: Dictionary = D.skills[id]
		var g: int = int(G.run["skill_grades"].get(id, s["tier"] * 3))
		var sz := 40.0 * sc
		var col := D.grade_color(g)
		var r := Rect2(pos, Vector2(sz, sz))
		draw_rect(r, Color(0.04, 0.03, 0.04, 0.9))
		var ec := D.elem_color(s["elem"])
		var c := r.get_center()
		# 简易图标
		match s["kind"]:
			"proj", "nova":
				draw_circle(c, sz * 0.22, ec)
				draw_circle(c + Vector2(-sz * 0.18, sz * 0.1), sz * 0.1, ec.darkened(0.3))
				draw_circle(c, sz * 0.1, Color.WHITE)
			"aoe", "lotus", "rain":
				draw_arc(c, sz * 0.3, 0, TAU, 16, ec, 3)
				draw_circle(c, sz * 0.14, ec.lightened(0.3))
			"arc":
				draw_arc(c, sz * 0.3, -2.4, 0.4, 12, ec, 4)
			"dash", "blink", "roll", "fly":
				draw_line(c - Vector2(sz * 0.3, 0), c + Vector2(sz * 0.3, 0), ec, 4)
				draw_colored_polygon(PackedVector2Array([c + Vector2(sz * 0.35, 0), c + Vector2(sz * 0.15, -sz * 0.15), c + Vector2(sz * 0.15, sz * 0.15)]), ec)
			"beam":
				draw_line(c - Vector2(sz * 0.35, sz * 0.2), c + Vector2(sz * 0.35, -sz * 0.2), ec, 6)
				draw_line(c - Vector2(sz * 0.35, sz * 0.2), c + Vector2(sz * 0.35, -sz * 0.2), Color.WHITE, 2)
			"zone", "trap":
				draw_set_transform(c, 0, Vector2(1, 0.6))
				draw_circle(Vector2.ZERO, sz * 0.32, Color(ec.r, ec.g, ec.b, 0.6))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"orbit":
				for i in 3:
					draw_circle(c + Vector2.from_angle(TAU * i / 3 + Time.get_ticks_msec() * 0.003) * sz * 0.28, sz * 0.09, ec)
			"buff":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz * 0.3), c + Vector2(sz * 0.25, 0), c + Vector2(0, sz * 0.3), c + Vector2(-sz * 0.25, 0)]), ec)
			"chain":
				draw_polyline(PackedVector2Array([c + Vector2(-sz * 0.3, -sz * 0.2), c + Vector2(-sz * 0.05, sz * 0.1), c + Vector2(sz * 0.05, -sz * 0.1), c + Vector2(sz * 0.3, sz * 0.2)]), ec, 3)
			_:
				draw_circle(c, sz * 0.25, ec)
		if on_cd:
			draw_rect(Rect2(pos, Vector2(sz, sz * clampf(k, 0, 1))), Color(0, 0, 0, 0.7))
		draw_rect(r, col, false, 2)
		_txt(pos + Vector2(2, 10), key, 8, Color(1, 0.95, 0.75))
		if badge != "":
			_txt(pos + Vector2(sz - 10, sz - 2), badge, 8, Color(0.6, 1, 0.6))
		_txt(pos + Vector2(0, sz + 10), s["n"].substr(0, 4), 8, col.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, sz)
