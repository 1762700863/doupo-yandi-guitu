class_name MapScene
extends Node2D
## 局内地图：第一章分支地图（横向）/ 第二章房间门

var m
var t := 0.0
var nodes_pos := {}      # "f_i" -> Vector2
var avail: Array = []    # [[f, i], ...]
var hover_key := ""
var ch: Dictionary
var ember: Array = []

func build(main) -> void:
	m = main
	ch = D.chapters[int(G.run["chapter"])]
	for i in 50:
		ember.append([Vector2(randf() * 960, randf() * 540), randf_range(10, 30), randf() * TAU])
	var mp: Dictionary = G.run["map"]
	if mp.get("type", "branch") == "branch":
		_build_branch()
	else:
		_build_doors()
	_build_topbar()
	if int(G.run["floor"]) == 0 and not G.run["flags"].get("map_tip", false):
		G.run["flags"]["map_tip"] = true
		m.toast("提示", "选择下一个节点。Tab 打开功法面板，可切换斗技自动/手动。", Color(0.8, 0.9, 1))

# ---------------------------------------------------------------- 顶栏
func _build_topbar() -> void:
	var root: Control = m.ui_root()
	var r: Dictionary = G.run
	var p := UI.panel(root, Rect2(8, 6, 944, 50))
	var por := G.portrait(D.chars[r["char"]]["spr"])
	if por:
		UI.tex_rect(p, por, Rect2(6, 3, 44, 44))
	var hpmax := G.est_hp_max()
	var hp: float = hpmax if float(r["hp"]) < 0 else float(r["hp"])
	UI.label(p, D.chars[r["char"]]["n"], Vector2(56, 4), 12, D.chars[r["char"]]["color"])
	var bar := ColorRect.new()
	bar.color = Color(0.2, 0.05, 0.05)
	bar.position = Vector2(56, 24)
	bar.size = Vector2(140, 10)
	p.add_child(bar)
	var fill := ColorRect.new()
	fill.color = Color(0.85, 0.2, 0.2)
	fill.size = Vector2(140 * clampf(hp / hpmax, 0, 1), 10)
	bar.add_child(fill)
	UI.label(p, "%d/%d" % [int(hp), int(hpmax)], Vector2(60, 34), 8, Color(1, 0.85, 0.85))
	var rc: Color = D.REALM_COLORS[clampi(int(r["realm"]) / 3, 0, D.REALM_COLORS.size() - 1)]
	UI.label(p, D.realm_name(int(r["realm"])), Vector2(210, 6), 12, rc)
	UI.label(p, "金币 %d" % int(r["gold"]), Vector2(210, 26), 12, Color(1, 0.85, 0.3))
	var fires := ""
	for f in r["fires"]:
		fires += D.fire_by_id[f]["n"].substr(0, 2) + " "
	UI.label(p, "异火：" + (fires if fires != "" else "无"), Vector2(320, 6), 12, Color(1, 0.6, 0.3))
	UI.label(p, "丹药 %d  斗技 %d/%d" % [r["pills"].size(), r["arts"].size(), G.art_slots()], Vector2(320, 26), 12, Color(0.7, 1, 0.7))
	UI.label(p, "%s · %s" % [ch["n"], ch["t"]], Vector2(520, 6), 12, UI.theme_cols()["accent"])
	var total: int = int(ch.get("floors", 10))
	UI.label(p, "第 %d / %d 层   难度：%s%s" % [int(r["floor"]) + 1, total, D.DIFFS[int(r["diff"])]["n"], ("  天劫%d" % r["tianjie"].size()) if r["tianjie"].size() > 0 else ""], Vector2(520, 26), 8, Color(0.85, 0.85, 0.8))
	UI.button(p, "功法", Rect2(790, 10, 70, 30), func(): m.toggle_pause(true), Color(1, 0.8, 0.4))
	UI.button(p, "设置", Rect2(866, 10, 70, 30), func():
		Screens.settings(m, func(): pass))

# ---------------------------------------------------------------- 分支地图
func _build_branch() -> void:
	var mp: Dictionary = G.run["map"]
	var floors: Array = mp["floors"]
	var nf := floors.size()
	for f in nf:
		var row: Array = floors[f]
		for i in row.size():
			var x = 70.0 + f * (820.0 / max(1, nf - 1))
			var y := 300.0
			if row.size() > 1:
				y = 140.0 + (320.0 / (row.size() - 1)) * i
			var jit := Vector2(sin(f * 3.7 + i * 1.3) * 10, cos(f * 2.1 + i * 2.9) * 12) if row.size() > 1 else Vector2.ZERO
			nodes_pos["%d_%d" % [f, i]] = Vector2(x, y) + jit
	var cur: int = int(G.run["floor"])
	var pos: Array = mp.get("pos", [-1, -1])
	avail.clear()
	if cur < nf:
		if int(pos[0]) == cur:
			avail.append([cur, int(pos[1])])
		elif int(pos[0]) < 0 or int(pos[0]) != cur - 1:
			for i in floors[cur].size():
				avail.append([cur, i])
		else:
			for j in floors[int(pos[0])][int(pos[1])]["links"]:
				avail.append([cur, j])
	var root: Control = m.ui_root()
	for a in avail:
		var key := "%d_%d" % [a[0], a[1]]
		var c: Vector2 = nodes_pos[key]
		var b := Button.new()
		b.flat = true
		b.position = c - Vector2(22, 22)
		b.size = Vector2(44, 44)
		b.focus_mode = Control.FOCUS_ALL
		var node: Dictionary = floors[a[0]][a[1]]
		var info: Dictionary = Flow.NODE_INFO.get(node["t"], Flow.NODE_INFO["fight"])
		b.tooltip_text = info["n"]
		var aa: Array = a
		b.mouse_entered.connect(func():
			hover_key = key
			Au.sfx("hover", -14))
		b.focus_entered.connect(func(): hover_key = key)
		b.mouse_exited.connect(func(): if hover_key == key: hover_key = "")
		b.pressed.connect(func(): _pick_branch(aa))
		root.add_child(b)
		if a == avail[0]:
			b.call_deferred("grab_focus")
	# 图例
	var lg := "图例："
	for k in ["fight", "elite", "event", "shop", "alchemy", "rest", "auction", "fire", "midboss", "boss"]:
		lg += Flow.NODE_INFO[k]["icon"] + Flow.NODE_INFO[k]["n"] + "  "
	UI.label(root, lg, Vector2(20, 510), 8, Color(0.85, 0.8, 0.7))

func _pick_branch(a:Array) -> void:
	var mp: Dictionary = G.run["map"]
	mp["pos"] = [a[0], a[1]]
	if not mp.has("hist"):
		mp["hist"] = []
	mp["hist"].append([a[0], a[1]])
	G.save_run()
	Au.sfx("door", -4)
	var node: Dictionary = mp["floors"][a[0]][a[1]]
	m.fade_to(func(): Flow.node_selected(m, node))

# ---------------------------------------------------------------- 房间门
func _build_doors() -> void:
	var mp: Dictionary = G.run["map"]
	var f: int = int(G.run["floor"])
	if int(mp.get("doors_f", -1)) != f:
		mp["doors"] = Flow._door_options()
		mp["doors_f"] = f
		G.save_run()
	var opts: Array = mp["doors"]
	var root: Control = m.ui_root()
	UI.label(root, "选择前进的方向", Vector2(0, 80), 24, UI.theme_cols()["accent"], 960, HORIZONTAL_ALIGNMENT_CENTER)
	var w := 200.0
	var gap := 60.0
	var x0 := 480 - (opts.size() * w + (opts.size() - 1) * gap) * 0.5
	for i in opts.size():
		var o: Dictionary = opts[i]
		var info: Dictionary = Flow.NODE_INFO.get(o["t"], Flow.NODE_INFO["fight"])
		var r := Rect2(x0 + i * (w + gap), 140, w, 300)
		nodes_pos["door_%d" % i] = r
		var b := Button.new()
		b.flat = true
		b.position = r.position
		b.size = r.size
		var key := "door_%d" % i
		b.mouse_entered.connect(func():
			hover_key = key
			Au.sfx("hover", -14))
		b.focus_entered.connect(func(): hover_key = key)
		b.mouse_exited.connect(func(): if hover_key == key: hover_key = "")
		b.pressed.connect(func():
			Au.sfx("door", -2)
			m.fade_to(func(): Flow.node_selected(m, o)))
		root.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")
		var title: String = info["n"]
		if o.has("boss") and D.bosses.has(o["boss"]):
			title = D.bosses[o["boss"]]["n"]
		UI.label(root, title, Vector2(r.position.x, r.end.y + 8), 16, info["c"], w, HORIZONTAL_ALIGNMENT_CENTER)
		if o.has("rw"):
			var rw: Dictionary = Flow.DOOR_REWARDS[o["rw"]]
			UI.label(root, "奖励：" + rw["n"], Vector2(r.position.x, r.end.y + 30), 12, rw["c"], w, HORIZONTAL_ALIGNMENT_CENTER)

# ---------------------------------------------------------------- 绘制
func _process(d:float) -> void:
	t += d
	for e in ember:
		e[0].y -= e[1] * d
		if e[0].y < 0:
			e[0] = Vector2(randf() * 960, 545)
	queue_redraw()

func _draw() -> void:
	var ui: Dictionary = ch["ui"]
	var bg: Color = ui["bg"]
	var border: Color = ui["border"]
	var acc: Color = ui["accent"]
	# 背景：章节色渐变 + 暗角 + 地形纹理
	for i in 27:
		var k := float(i) / 27
		draw_rect(Rect2(0, i * 20, 960, 21), Color(bg.r, bg.g, bg.b).darkened(0.3).lerp(Color(bg.r, bg.g, bg.b).lightened(0.05), sin(k * PI)))
	var tiles: Texture2D = G.tex("res://assets/tiles/%s.png" % ch["biome"])
	if tiles:
		for y in range(0, 540, 64):
			for x in range(0, 960, 64):
				var v := int(abs(sin(x * 0.13 + y * 0.71)) * 4) % 4
				draw_texture_rect_region(tiles, Rect2(x, y, 64, 64), Rect2(v * 64, 0, 64, 64), Color(1, 1, 1, 0.18))
	for e in ember:
		draw_rect(Rect2(e[0], Vector2(2, 2)), Color(acc.r, acc.g, acc.b, 0.35 + 0.3 * sin(t * 3 + e[2])))
	# 卷轴边框
	draw_rect(Rect2(14, 64, 932, 468), Color(border.r, border.g, border.b, 0.5), false, 2.0)
	draw_rect(Rect2(20, 70, 920, 456), Color(border.r, border.g, border.b, 0.25), false, 1.0)
	var mp: Dictionary = G.run["map"]
	if mp.get("type", "branch") == "branch":
		_draw_branch(mp)
	else:
		_draw_doors(mp)

func _draw_branch(mp:Dictionary) -> void:
	var floors: Array = mp["floors"]
	var cur: int = int(G.run["floor"])
	var pos: Array = mp.get("pos", [-1, -1])
	var f: Font = G.font
	# 连线
	for fi in floors.size() - 1:
		for i in floors[fi].size():
			var a: Vector2 = nodes_pos["%d_%d" % [fi, i]]
			for j in floors[fi][i]["links"]:
				var b: Vector2 = nodes_pos["%d_%d" % [fi + 1, j]]
				var walked: bool = fi < cur and _on_path(fi, i) and _on_path(fi + 1, j)
				var col := Color(1, 0.8, 0.4, 0.9) if walked else Color(0.9, 0.85, 0.7, 0.28)
				var seg := 10
				for s in seg:
					if s % 2 == 0 or walked:
						draw_line(a.lerp(b, float(s) / seg), a.lerp(b, float(s + 1) / seg), col, 2.0 if walked else 1.5)
	# 节点
	for fi in floors.size():
		for i in floors[fi].size():
			var key := "%d_%d" % [fi, i]
			var c: Vector2 = nodes_pos[key]
			var node: Dictionary = floors[fi][i]
			var info: Dictionary = Flow.NODE_INFO.get(node["t"], Flow.NODE_INFO["fight"])
			var col: Color = info["c"]
			var is_av := false
			for a in avail:
				if a[0] == fi and a[1] == i:
					is_av = true
			var r := 16.0
			if node["t"] in ["boss", "midboss"]:
				r = 22.0
			var passed := fi < cur
			var alpha := 1.0 if (is_av or fi >= cur) else 0.35
			if is_av:
				var pulse := 0.5 + 0.5 * sin(t * 4)
				draw_circle(c, r + 6 + pulse * 4, Color(col.r, col.g, col.b, 0.18 + pulse * 0.12))
				if hover_key == key:
					draw_circle(c, r + 12, Color(col.r, col.g, col.b, 0.25))
			draw_circle(c, r + 2, Color(0.05, 0.03, 0.03, alpha))
			draw_circle(c, r, Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, alpha))
			draw_arc(c, r, 0, TAU, 32, Color(col.r, col.g, col.b, alpha), 2.0)
			var fs := 16 if r < 20 else 24
			draw_string(f, c + Vector2(-fs / 2.0, fs * 0.36), info["icon"], HORIZONTAL_ALIGNMENT_CENTER, fs, fs, Color(col.r, col.g, col.b, alpha).lightened(0.2))
			if passed and _on_path(fi, i):
				draw_arc(c, r + 4, 0, TAU, 32, Color(1, 0.85, 0.4, 0.9), 2.0)
			if hover_key == key:
				draw_string(f, c + Vector2(-60, r + 18), info["n"], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color.WHITE)
	# 当前位置标记（角色小头像）
	var sp := G.spr(D.chars[G.run["char"]]["spr"])
	if sp and int(pos[0]) >= 0:
		var c2: Vector2 = nodes_pos["%d_%d" % [int(pos[0]), int(pos[1])]]
		var sc := 28.0 / sp.get_height()
		draw_texture_rect(sp, Rect2(c2 + Vector2(-sp.get_width() * sc / 2, -48 + sin(t * 3) * 2), sp.get_size() * sc), false)

func _on_path(fi:int, i:int) -> bool:
	var hist: Array = G.run["map"].get("hist", [])
	for h in hist:
		if int(h[0]) == fi and int(h[1]) == i:
			return true
	return false

func _draw_doors(mp:Dictionary) -> void:
	var opts: Array = mp.get("doors", [])
	var f: Font = G.font
	var acc: Color = ch["ui"]["accent"]
	for i in opts.size():
		if not nodes_pos.has("door_%d" % i):
			continue
		var r: Rect2 = nodes_pos["door_%d" % i]
		var o: Dictionary = opts[i]
		var info: Dictionary = Flow.NODE_INFO.get(o["t"], Flow.NODE_INFO["fight"])
		var col: Color = info["c"]
		var hov := hover_key == "door_%d" % i
		var lift := -6.0 if hov else 0.0
		var rr := Rect2(r.position + Vector2(0, lift), r.size)
		# 门框（拱门）
		var stone := Color(0.32, 0.26, 0.2) if ch["biome"] == "desert" else Color(0.3, 0.3, 0.34)
		draw_rect(Rect2(rr.position + Vector2(-12, 30), Vector2(rr.size.x + 24, rr.size.y - 30)), stone.darkened(0.3))
		draw_circle(rr.position + Vector2(rr.size.x / 2, 60), rr.size.x / 2 + 12, stone.darkened(0.3))
		# 门内光
		var inner := Rect2(rr.position + Vector2(8, 60), Vector2(rr.size.x - 16, rr.size.y - 60))
		var glow := 0.55 + 0.25 * sin(t * 2.5 + i) + (0.2 if hov else 0.0)
		var steps := 48
		for k in steps:
			var kk := float(k) / steps
			var cc := col.darkened(0.85).lerp(col.darkened(0.1), pow(kk, 1.6) * glow)
			draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y * (1.0 - kk) - inner.size.y / steps, inner.size.x, inner.size.y / steps + 1), cc)
		draw_rect(inner, Color(col.r, col.g, col.b, 0.18 * glow))
		draw_circle(rr.position + Vector2(rr.size.x / 2, 60), rr.size.x / 2 - 8, Color(col.r, col.g, col.b, 0.22 * glow))
		# 砖纹
		for k in 7:
			var a := PI + k * PI / 6
			var p1 := rr.position + Vector2(rr.size.x / 2, 60) + Vector2.from_angle(a) * (rr.size.x / 2 - 6)
			var p2 := rr.position + Vector2(rr.size.x / 2, 60) + Vector2.from_angle(a) * (rr.size.x / 2 + 12)
			draw_line(p1, p2, stone.lightened(0.15), 2)
		draw_arc(rr.position + Vector2(rr.size.x / 2, 60), rr.size.x / 2 + 12, PI, TAU, 32, (acc if hov else stone.lightened(0.2)), 2)
		# 图标
		draw_string(f, rr.position + Vector2(0, 150), info["icon"], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 48, col.lightened(0.3))
		if o.has("rw"):
			var rw: Dictionary = Flow.DOOR_REWARDS[o["rw"]]
			var ic := rr.position + Vector2(rr.size.x / 2, 220)
			draw_circle(ic, 20, Color(0, 0, 0, 0.5))
			draw_arc(ic, 20, 0, TAU, 24, rw["c"], 2)
			draw_string(f, ic + Vector2(-20, 6), rw["n"].substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, rw["c"])
		# 粒子
		for k in 5:
			var ph := t * 1.5 + k * 1.3 + i
			var pp := inner.position + Vector2(fmod(k * 37.0 + i * 11, inner.size.x), inner.size.y - fmod(ph * 40, inner.size.y))
			draw_rect(Rect2(pp, Vector2(2, 2)), Color(col.r, col.g, col.b, 0.7))
