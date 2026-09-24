class_name HubScene
extends Node2D
## 局外基地：萧家 → 萧族。点击建筑进行局外成长；城门出征。

var m
var t := 0.0
var bld_rects := {}     # id -> Rect2
var hover := ""
var npc: Array = []
var leaves: Array = []
var topbar: Control
const LAYOUT := {
	"alchemy": Vector2(120, 170), "library": Vector2(330, 130), "train": Vector2(560, 170),
	"tower": Vector2(790, 146), "forge": Vector2(110, 322), "inn": Vector2(310, 322),
	"codex": Vector2(610, 322), "challenge": Vector2(810, 322), "gate": Vector2(460, 448),
}

func _ready() -> void:
	m = get_tree().get_first_node_in_group("main")
	for i in 40:
		leaves.append([Vector2(randf() * 960, randf() * 540), randf_range(8, 20), randf() * TAU])
	for c in G.meta["unlocked_chars"]:
		if c != G.meta.get("last_char", "xiaoyan"):
			npc.append({"id": c, "p": Vector2(randf_range(200, 760), randf_range(260, 300)), "tgt": Vector2(randf_range(200, 760), randf_range(250, 310)), "w": 0.0})
	for c in G.meta["unlocked_comps"]:
		if c == "yaolao":
			npc.append({"id": "yaolao", "p": Vector2(470, 270), "tgt": Vector2(470, 270), "w": 0.0})
	call_deferred("_build_ui")

func _build_ui() -> void:
	var root: Control = m.ui_root()
	topbar = root
	for id in LAYOUT:
		var sz := Vector2(150, 190) if id == "tower" else (Vector2(150, 120) if id == "gate" else Vector2(160, 110))
		var r := Rect2(LAYOUT[id] - sz / 2, sz)
		bld_rects[id] = r
		var b := Button.new()
		b.flat = true
		b.position = r.position
		b.size = r.size
		b.focus_mode = Control.FOCUS_ALL
		var bid: String = id
		b.mouse_entered.connect(func():
			hover = bid
			Au.sfx("hover", -14))
		b.mouse_exited.connect(func(): if hover == bid: hover = "")
		b.focus_entered.connect(func(): hover = bid)
		b.focus_exited.connect(func(): if hover == bid: hover = "")
		b.pressed.connect(func(): _open(bid))
		root.add_child(b)
		if id == "gate":
			b.call_deferred("grab_focus")
	_refresh_top()   # 顶栏最后添加 → 位于建筑按钮之上，点击“设置/标题”不会穿透到建筑
	# 首次进入提示
	if int(G.meta["runs"]) == 0 and not ("hub_intro" in G.meta["story_seen"]):
		G.meta["story_seen"].append("hub_intro")
		Dialog.lines(m, [["yaolao", "药老", "这里是萧家——你的根。每次出征归来，都能在这里变强。"], ["yaolao", "药老", "修炼室提升天赋，藏经阁解锁斗技，炼药房炼制丹药带入征途。"], ["xiaoyan", "萧炎", "准备好了就从城门出发吧。莫欺少年穷！"]], func(): pass)

func _refresh_top() -> void:
	if topbar == null:
		return
	for c in topbar.get_children():
		if c.has_meta("top"):
			c.queue_free()
	var p := UI.panel(topbar, Rect2(8, 6, 944, 40))
	p.set_meta("top", true)
	var mt: Dictionary = G.meta
	UI.label(p, G.faction_name(), Vector2(10, 8), 16, Color(1, 0.8, 0.4))
	UI.label(p, "斗气结晶 %d    贡献点 %d    魔核 %d    异火火种 %d    局数 %d" % [int(mt["crystal"]), int(mt["contrib"]), int(mt["mohe"]), int(mt["fire_seed"]), int(mt["runs"])], Vector2(110, 10), 12, Color(0.9, 0.9, 0.85))
	UI.button(p, "设置", Rect2(790, 5, 70, 28), func(): Screens.settings(m, func(): pass))
	UI.button(p, "标题", Rect2(866, 5, 70, 28), func(): m.fade_to(func(): m.title_screen()), Color(0.6, 0.6, 0.6))

# ---------------------------------------------------------------- 绘制
func _process(d:float) -> void:
	t += d
	for n in npc:
		n["w"] -= d
		if n["w"] <= 0 and n["p"].distance_to(n["tgt"]) < 4:
			n["tgt"] = Vector2(randf_range(200, 760), randf_range(250, 310))
			n["w"] = randf_range(2, 5)
		if n["w"] <= 0:
			n["p"] = n["p"].move_toward(n["tgt"], 26 * d)
	for l in leaves:
		l[0] += Vector2(l[1] * 0.6, l[1]) * d
		if l[0].y > 545:
			l[0] = Vector2(randf() * 960 - 100, -5)
	queue_redraw()

func _draw() -> void:
	var tiles := G.tex("res://assets/tiles/hub.png")
	if tiles:
		for y in range(0, 540, 64):
			for x in range(0, 960, 64):
				var v := int(abs(sin(x * 0.37 + y * 0.11)) * 7) % 4
				draw_texture_rect_region(tiles, Rect2(x, y, 64, 64), Rect2(v * 64, 0, 64, 64))
	else:
		draw_rect(Rect2(0, 0, 960, 540), Color(0.25, 0.22, 0.18))
	# 中央石路
	draw_rect(Rect2(150, 245, 660, 70), Color(0.45, 0.4, 0.33, 0.55))
	draw_rect(Rect2(445, 245, 70, 260), Color(0.45, 0.4, 0.33, 0.55))
	for x in range(150, 810, 22):
		draw_line(Vector2(x, 245), Vector2(x, 315), Color(0.3, 0.26, 0.2, 0.3), 1)
	# 围墙
	draw_rect(Rect2(0, 50, 960, 16), Color(0.35, 0.22, 0.16))
	draw_rect(Rect2(0, 64, 960, 4), Color(0.2, 0.12, 0.08))
	for x in range(0, 960, 32):
		draw_rect(Rect2(x, 44, 22, 8), Color(0.3, 0.18, 0.12))
	# 建筑 & 标签
	var font: Font = G.font
	for id in LAYOUT:
		var r: Rect2 = bld_rects.get(id, Rect2(LAYOUT[id] - Vector2(80, 55), Vector2(160, 110)))
		var lv: int = int(G.meta["buildings"].get(id, 1)) if id != "gate" else 1
		var locked := lv <= 0
		var tex := G.tex("res://assets/obj/b_%s.png" % id)
		var hov = hover == id
		draw_rect(Rect2(r.position.x + 10, r.end.y - 8, r.size.x - 20, 10), Color(0, 0, 0, 0.3))
		if tex:
			var mod := Color(0.45, 0.45, 0.5) if locked else (Color(1.15, 1.1, 1.0) if hov else Color.WHITE)
			var lift := -3.0 if hov else 0.0
			draw_texture_rect(tex, Rect2(r.position + Vector2(0, lift), r.size), false, mod)
		var name: String = "出征 · 城门" if id == "gate" else D.buildings[id]["n"]
		var sub := "" if id == "gate" else ("未建造" if locked else "Lv.%d" % lv)
		var ly := r.end.y + 2
		# 名称与等级放在同一行标签里（避免小字看不清、与其它建筑重叠）
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var sw := 0.0 if sub == "" else font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8
		var w := nw + sw + 16
		var lx := r.get_center().x - w / 2
		draw_rect(Rect2(lx, ly, w, 20), Color(0, 0, 0, 0.7 if hov else 0.55))
		draw_string(font, Vector2(lx + 8, ly + 15), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.4) if hov else Color(0.95, 0.9, 0.8))
		if sub != "":
			draw_string(font, Vector2(lx + 8 + nw + 8, ly + 15), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.85, 1) if not locked else Color(0.62, 0.62, 0.62))
		if id == "gate":
			var gl := 0.5 + 0.5 * sin(t * 3)
			draw_arc(r.get_center() + Vector2(0, 10), 50 + gl * 6, PI, TAU, 24, Color(1, 0.7, 0.3, 0.3 + gl * 0.3), 3)
	# NPC
	for n in npc:
		var sp := G.spr(D.chars[n["id"]]["spr"] if D.chars.has(n["id"]) else D.companions[n["id"]]["spr"])
		if sp:
			var sc := 38.0 / sp.get_height()
			var bob: float = absf(sin(t * 6)) * 2 if n["w"] <= 0 else 0.0
			var flip: bool = n["tgt"].x < n["p"].x
			draw_ellipse_shadow(n["p"])
			draw_set_transform(n["p"] + Vector2(0, -bob), 0, Vector2(-sc if flip else sc, sc))
			draw_texture(sp, Vector2(-sp.get_width() / 2.0, -sp.get_height()))
			draw_set_transform(Vector2.ZERO)
	for l in leaves:
		draw_rect(Rect2(l[0], Vector2(3, 2)), Color(1, 0.7, 0.4, 0.5 + 0.3 * sin(t + l[2])))

func draw_ellipse_shadow(p:Vector2) -> void:
	draw_set_transform(p, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- 建筑面板
func _open(id:String) -> void:
	Au.sfx("click")
	if id == "gate":
		_launch_panel()
		return
	var lv: int = int(G.meta["buildings"].get(id, 0))
	if lv <= 0:
		_build_panel(id)
		return
	match id:
		"alchemy": _alchemy_panel()
		"library": _library_panel()
		"train": _train_panel()
		"tower": _tower_panel()
		"forge": _forge_panel()
		"inn": _inn_panel()
		"codex": _codex_panel("chars")
		"challenge": _challenge_panel()

func _bld_cost(id:String) -> int:
	var lv: int = int(G.meta["buildings"].get(id, 0))
	return 60 + lv * lv * 50

func _panel(title:String, col:Color=Color(1, 0.8, 0.4)) -> Array:
	var root: Control = m.ui_root()
	UI.dim(root, 0.7).mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(root, Rect2(50, 30, 860, 480))
	UI.label(p, title, Vector2(0, 8), 24, col, 860, HORIZONTAL_ALIGNMENT_CENTER)
	UI.button(p, "关闭", Rect2(770, 10, 76, 28), func():
		root.queue_free()
		_refresh_top(), Color(0.7, 0.7, 0.7))
	return [root, p]

func _upgrade_btn(p:Control, id:String, root:Control, reopen:Callable) -> void:
	var lv: int = int(G.meta["buildings"].get(id, 0))
	var mx: int = D.buildings[id]["max"]
	if lv >= mx:
		UI.label(p, "已满级", Vector2(20, 446), 12, Color(0.7, 0.9, 0.7))
		return
	var cost := _bld_cost(id)
	UI.button(p, "升级建筑（%d 贡献点）" % cost, Rect2(16, 440, 200, 28), func():
		if int(G.meta["contrib"]) < cost:
			Au.sfx("fail")
			m.toast("贡献点不足", "出征可获得贡献点", Color(0.8, 0.5, 0.5))
			return
		G.meta["contrib"] = int(G.meta["contrib"]) - cost
		G.meta["buildings"][id] = lv + 1
		G.save_meta()
		Au.sfx("levelup")
		root.queue_free()
		reopen.call(), Color(0.6, 0.9, 1))

func _build_panel(id:String) -> void:
	var cost := _bld_cost(id)
	Screens.confirm(m, "建造 " + D.buildings[id]["n"], D.buildings[id]["d"] + "\n\n花费 %d 贡献点（当前 %d）" % [cost, int(G.meta["contrib"])], "建造", "取消", func(yes):
		if yes:
			if int(G.meta["contrib"]) >= cost:
				G.meta["contrib"] = int(G.meta["contrib"]) - cost
				G.meta["buildings"][id] = 1
				G.save_meta()
				Au.sfx("levelup")
				m.toast("建造完成", D.buildings[id]["n"], Color(1, 0.8, 0.4))
				_refresh_top()
			else:
				Au.sfx("fail")
				m.toast("贡献点不足", "需要 %d" % cost, Color(0.8, 0.5, 0.5)))

# ---- 炼药房
func _alchemy_panel() -> void:
	var a := _panel("炼药房 Lv.%d" % int(G.meta["buildings"]["alchemy"]), Color(0.5, 1, 0.6))
	var root: Control = a[0]
	var p: Panel = a[1]
	UI.label(p, D.buildings["alchemy"]["d"], Vector2(20, 44), 12, Color(0.85, 0.85, 0.8), 820)
	var txt := "库存丹药（下局自动带入）：\n"
	for pid in G.meta["pills"]:
		if int(G.meta["pills"][pid]) > 0:
			txt += "  %s ×%d — %s\n" % [D.pills[pid]["n"], int(G.meta["pills"][pid]), D.pills[pid]["d"]]
	txt += "\n药材库存："
	for h in G.meta["herbs"]:
		txt += "%s×%d  " % [D.herbs[h]["n"], int(G.meta["herbs"][h])]
	txt += "魔核×%d" % int(G.meta["mohe"])
	UI.label(p, txt, Vector2(20, 80), 12, Color(0.9, 0.95, 0.9), 520)
	UI.button(p, "开炉炼丹", Rect2(600, 90, 200, 40), func():
		root.queue_free()
		# 局外炼丹需要临时 run 上下文
		var had_run := not G.run.is_empty()
		Screens.alchemy_select(m, false, func(): _alchemy_panel()), Color(0.5, 1, 0.6), 16)
	# 学习丹方
	var unk := []
	for pid in D.pills:
		if not (pid in G.meta["known_pills"]) and D.pills[pid]["tier"] <= int(G.meta["buildings"]["alchemy"]):
			unk.append(pid)
	var y := 150.0
	UI.label(p, "学习丹方（斗气结晶）", Vector2(600, y), 12, Color(1, 0.85, 0.5))
	y += 22
	for pid in unk.slice(0, 7):
		var cost: int = 40 + D.pills[pid]["tier"] * 60
		var pp: String = pid
		UI.button(p, "%s  %d晶" % [D.pills[pid]["n"], cost], Rect2(600, y, 230, 26), func():
			if int(G.meta["crystal"]) < cost:
				Au.sfx("fail")
				return
			G.meta["crystal"] = int(G.meta["crystal"]) - cost
			G.meta["known_pills"].append(pp)
			G.save_meta()
			root.queue_free()
			_alchemy_panel(), D.pills[pid]["c"], 8)
		y += 30
	_upgrade_btn(p, "alchemy", root, _alchemy_panel)

# ---- 藏经阁
func _library_panel(cat:String="art") -> void:
	var a := _panel("藏经阁 Lv.%d" % int(G.meta["buildings"]["library"]), Color(1, 0.85, 0.5))
	var root: Control = a[0]
	var p: Panel = a[1]
	UI.label(p, "永久解锁高阶斗技进入奖励池（地阶/天阶默认需要藏经阁等级）。已见过的斗技会记录在图鉴中。", Vector2(20, 44), 8, Color(0.85, 0.85, 0.8), 820)
	var cats := {"art": "斗技", "ult": "大招", "move": "身法", "gong": "功法", "relic": "法宝"}
	var cx := 20.0
	for c in cats:
		var cc: String = c
		UI.button(p, cats[c], Rect2(cx, 62, 80, 24), func():
			root.queue_free()
			_library_panel(cc), Color(1, 0.8, 0.4) if c == cat else Color(0.5, 0.5, 0.5), 12)
		cx += 86
	var pool: Array = {"art": D.art_pool, "ult": D.ult_pool, "move": D.move_pool, "gong": D.gong_pool, "relic": D.relic_pool}[cat]
	var lib: int = int(G.meta["buildings"]["library"])
	var i := 0
	var sc := ScrollContainer.new()
	sc.position = Vector2(16, 94)
	sc.size = Vector2(828, 340)
	p.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	for id in pool:
		var s: Dictionary = D.skills[id]
		var unlocked: bool = id in G.meta["unlocked_skills"] or s["tier"] < 2 or s["tier"] <= lib / 2 + 1
		var cost: int = 60 + s["tier"] * 80
		var sid: String = id
		var b := Button.new()
		b.custom_minimum_size = Vector2(268, 54)
		b.add_theme_stylebox_override("normal", UI.panel_style(Color(0.08, 0.06, 0.05, 0.9), D.TIER_COLORS[s["tier"]].darkened(0.3 if unlocked else 0.6), 1))
		b.add_theme_stylebox_override("hover", UI.panel_style(Color(0.14, 0.1, 0.07, 0.95), D.TIER_COLORS[s["tier"]], 1))
		b.tooltip_text = s["d"]
		grid.add_child(b)
		UI.label(b, "%s [%s]" % [s["n"], D.TIER_NAMES[s["tier"]]], Vector2(8, 4), 12, D.TIER_COLORS[s["tier"]] if unlocked else Color(0.55, 0.55, 0.55))
		UI.label(b, ("已入池" if unlocked else "解锁：%d 斗气结晶" % cost) + ("  · 已见" if id in G.meta["codex_skills"] else ""), Vector2(8, 22), 8, Color(0.6, 0.9, 0.6) if unlocked else Color(1, 0.85, 0.4))
		UI.label(b, s["d"].substr(0, 30), Vector2(8, 36), 8, Color(0.75, 0.75, 0.7))
		if not unlocked:
			b.pressed.connect(func():
				if int(G.meta["crystal"]) < cost:
					Au.sfx("fail")
					return
				G.meta["crystal"] = int(G.meta["crystal"]) - cost
				G.meta["unlocked_skills"].append(sid)
				G.save_meta()
				Au.sfx("levelup")
				root.queue_free()
				_library_panel(cat))
		i += 1
	_upgrade_btn(p, "library", root, func(): _library_panel(cat))

# ---- 修炼室
func _train_panel() -> void:
	var a := _panel("修炼室 · 焚决天赋", Color(1, 0.6, 0.3))
	var root: Control = a[0]
	var p: Panel = a[1]
	var lv: int = int(G.meta["buildings"]["train"])
	UI.label(p, "修炼室等级决定天赋上限（每级可修到 %d 层）" % (lv * 2), Vector2(20, 44), 12, Color(0.85, 0.85, 0.8))
	var i := 0
	for tl in D.talents:
		var cur: int = int(G.meta["talents"].get(tl["id"], 0))
		var cap: int = min(tl["max"], lv * 2)
		var cost: int = int(tl["cost"]) * (cur + 1)
		var tid: String = tl["id"]
		var x := 20 + (i % 3) * 276
		var y := 72 + (i / 3) * 88
		var b := UI.button(p, "", Rect2(x, y, 266, 80), func():
			if cur >= cap or int(G.meta["crystal"]) < cost:
				Au.sfx("fail")
				return
			G.meta["crystal"] = int(G.meta["crystal"]) - cost
			G.meta["talents"][tid] = cur + 1
			G.save_meta()
			Au.sfx("levelup")
			root.queue_free()
			_train_panel(), Color(1, 0.6, 0.3))
		UI.label(b, tl["n"], Vector2(10, 6), 16, Color(1, 0.8, 0.5))
		UI.label(b, tl["d"], Vector2(10, 30), 12, Color(0.9, 0.9, 0.85))
		UI.label(b, "%d / %d" % [cur, tl["max"]], Vector2(200, 8), 12, Color(0.8, 0.9, 1))
		UI.label(b, ("消耗 %d 斗气结晶" % cost) if cur < cap else ("已达上限" if cur >= tl["max"] else "需升级修炼室"), Vector2(10, 54), 8, Color(1, 0.85, 0.4))
		# 进度条
		for k in tl["max"]:
			var pip := ColorRect.new()
			pip.color = Color(1, 0.6, 0.3) if k < cur else Color(0.25, 0.2, 0.18)
			pip.position = Vector2(140 + k * 12, 56)
			pip.size = Vector2(9, 6)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(pip)
		i += 1
	_upgrade_btn(p, "train", root, _train_panel)

# ---- 天火塔
func _tower_panel() -> void:
	var a := _panel("天火塔 · 异火培养", Color(1, 0.5, 0.2))
	var root: Control = a[0]
	var p: Panel = a[1]
	UI.label(p, "以异火火种培养曾经吞噬过的异火：每级使该异火效果提升。天火塔也开放“无尽模式”（在城门出征时选择）。", Vector2(20, 44), 8, Color(0.85, 0.85, 0.8), 820)
	var seen: Array = G.meta["seen_fires"]
	if seen.is_empty():
		UI.label(p, "尚未吞噬任何异火。去征途中寻找吧！", Vector2(0, 200), 16, Color(0.8, 0.7, 0.6), 860, HORIZONTAL_ALIGNMENT_CENTER)
	var i := 0
	var mx: int = int(G.meta["buildings"]["tower"])
	for fid in seen:
		var f: Dictionary = D.fire_by_id[fid]
		var lv: int = int(G.meta["fire_levels"].get(fid, 0))
		var cost := 1 + lv
		var ff: String = fid
		var x := 20 + (i % 3) * 276
		var y := 72 + (i / 3) * 70
		var b := UI.button(p, "", Rect2(x, y, 266, 62), func():
			if lv >= mx or int(G.meta["fire_seed"]) < cost:
				Au.sfx("fail")
				return
			G.meta["fire_seed"] = int(G.meta["fire_seed"]) - cost
			G.meta["fire_levels"][ff] = lv + 1
			G.save_meta()
			Au.sfx("fire_get")
			root.queue_free()
			_tower_panel(), f["c"])
		UI.label(b, "%s  Lv.%d/%d" % [f["n"], lv, mx], Vector2(8, 4), 12, f["c"].lightened(0.2))
		UI.label(b, f["d"].substr(0, 28), Vector2(8, 24), 8, Color(0.85, 0.85, 0.8))
		UI.label(b, "培养：%d 火种" % cost if lv < mx else "已达塔等级上限", Vector2(8, 42), 8, Color(1, 0.8, 0.4))
		i += 1
	_upgrade_btn(p, "tower", root, _tower_panel)

# ---- 炼器坊
func _forge_panel() -> void:
	var a := _panel("炼器坊", Color(0.8, 0.8, 0.9))
	var root: Control = a[0]
	var p: Panel = a[1]
	UI.label(p, "用魔核解锁萧炎的普攻风格（出征时可选）。", Vector2(20, 44), 12, Color(0.85, 0.85, 0.8))
	var i := 0
	for aid in D.chars["xiaoyan"]["atks"]:
		var s: Dictionary = D.skills[aid]
		var own: bool = aid in G.meta["unlocked_atks"]
		var cost := 3 + i * 3
		var id: String = aid
		var b := UI.button(p, "", Rect2(20 + (i % 3) * 276, 76 + (i / 3) * 100, 266, 90), func():
			if own or int(G.meta["mohe"]) < cost:
				Au.sfx("fail")
				return
			G.meta["mohe"] = int(G.meta["mohe"]) - cost
			G.meta["unlocked_atks"].append(id)
			G.save_meta()
			Au.sfx("levelup")
			root.queue_free()
			_forge_panel(), D.elem_color(s["elem"]))
		UI.label(b, s["n"], Vector2(10, 6), 16, D.elem_color(s["elem"]).lightened(0.2))
		UI.label(b, s["d"], Vector2(10, 30), 8, Color(0.85, 0.85, 0.8), 246)
		UI.label(b, "已拥有" if own else "解锁：%d 魔核" % cost, Vector2(10, 70), 8, Color(0.6, 0.9, 0.6) if own else Color(1, 0.8, 0.4))
		i += 1
	_upgrade_btn(p, "forge", root, _forge_panel)

# ---- 招待所
func _inn_panel() -> void:
	var a := _panel("招待所 · 羁绊", Color(1, 0.7, 0.8))
	var root: Control = a[0]
	var p: Panel = a[1]
	UI.label(p, "赠送魔核提升好感。好感越高，作为同伴时的伤害越高（每级+8%），5级解锁成就。", Vector2(20, 44), 12, Color(0.85, 0.85, 0.8), 820)
	var i := 0
	for cid in G.meta["unlocked_comps"]:
		var c: Dictionary = D.companions[cid]
		var bond: int = int(G.meta["bond"].get(cid, 0))
		var cc: String = cid
		var x := 20 + i * 205
		var por := G.portrait(c["spr"] + "_full")
		var bx := UI.panel(p, Rect2(x, 76, 196, 350), Color(0.1, 0.07, 0.08, 0.9), Color(1, 0.7, 0.8))
		if por:
			UI.tex_rect(bx, por, Rect2(8, 8, 180, 210))
		UI.label(bx, c["n"], Vector2(0, 222), 16, Color(1, 0.85, 0.9), 196, HORIZONTAL_ALIGNMENT_CENTER)
		UI.label(bx, "好感 " + "♥".repeat(bond) + "♡".repeat(max(0, 5 - bond)), Vector2(0, 246), 12, Color(1, 0.5, 0.6), 196, HORIZONTAL_ALIGNMENT_CENTER)
		UI.label(bx, "合击：" + c["combo"], Vector2(8, 268), 8, Color(1, 0.8, 0.5), 180)
		var cost := 2 + bond * 2
		UI.button(bx, "赠礼（%d 魔核）" % cost if bond < 5 else "心意相通", Rect2(18, 306, 160, 30), func():
			if bond >= 5 or int(G.meta["mohe"]) < cost:
				Au.sfx("fail")
				return
			G.meta["mohe"] = int(G.meta["mohe"]) - cost
			G.meta["bond"][cc] = bond + 1
			if bond + 1 >= 5:
				G.unlock_ach("ach_bond")
			G.save_meta()
			Au.sfx("levelup")
			root.queue_free()
			_inn_panel(), Color(1, 0.6, 0.7))
		i += 1
	_upgrade_btn(p, "inn", root, _inn_panel)

# ---- 图鉴馆
func _codex_panel(tab:String) -> void:
	var a := _panel("图鉴馆", Color(0.7, 0.85, 1))
	var root: Control = a[0]
	var p: Panel = a[1]
	var tabs := {"chars": "角色", "enemies": "敌人", "skills": "斗技", "fires": "异火榜", "ach": "成就", "tips": "药老语录"}
	var tx := 20.0
	for k in tabs:
		var kk: String = k
		UI.button(p, tabs[k], Rect2(tx, 44, 90, 24), func():
			root.queue_free()
			_codex_panel(kk), Color(0.7, 0.85, 1) if k == tab else Color(0.45, 0.45, 0.5))
		tx += 96
	var sc := ScrollContainer.new()
	sc.position = Vector2(16, 76)
	sc.size = Vector2(828, 390)
	p.add_child(sc)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(810, 0)
	sc.add_child(vb)
	var add := func(txt:String, col:Color, sz:int=12):
		var l := Label.new()
		l.text = txt
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(800, 0)
		l.add_theme_font_override("font", G.font)
		l.add_theme_font_size_override("font_size", sz)
		l.add_theme_color_override("font_color", col)
		vb.add_child(l)
	match tab:
		"chars":
			for cid in D.char_order:
				var c: Dictionary = D.chars[cid]
				var un := G.is_char_unlocked(cid)
				add.call("%s · %s %s" % [c["n"], c["t"], "" if un else "（未解锁）"], c["color"] if un else Color(0.5, 0.5, 0.5), 16)
				add.call(c["mech"] if un else "？？？", Color(0.85, 0.85, 0.8))
		"enemies":
			for eid in D.enemies:
				var seen: bool = eid in G.meta["codex_enemies"]
				add.call(("◆ " + D.enemies[eid]["n"]) if seen else "◆ ？？？", Color(0.9, 0.8, 0.7) if seen else Color(0.5, 0.5, 0.5))
			for bid in D.bosses:
				var seen2: bool = bid in G.meta["codex_enemies"]
				add.call(("★ %s · %s" % [D.bosses[bid]["n"], D.bosses[bid].get("t", "")]) if seen2 else "★ ？？？", Color(1, 0.5, 0.4) if seen2 else Color(0.5, 0.5, 0.5))
		"skills":
			var n := 0
			for id in D.skills:
				if D.skills[id]["cat"] in ["art", "ult"]:
					var seen3: bool = id in G.meta["codex_skills"]
					if seen3:
						n += 1
					add.call(("%s [%s] — %s" % [D.skills[id]["n"], D.TIER_NAMES[D.skills[id]["tier"]], D.skills[id]["d"]]) if seen3 else "？？？", D.TIER_COLORS[D.skills[id]["tier"]] if seen3 else Color(0.45, 0.45, 0.45), 8)
			add.call("已收录 %d" % n, Color(1, 0.85, 0.4))
		"fires":
			for f in D.fires:
				var seen4: bool = f["id"] in G.meta["seen_fires"]
				add.call("第%d位 %s — %s" % [f["rank"], f["n"], f["d"] if seen4 else "尚未收服"], f["c"] if seen4 else Color(0.5, 0.5, 0.5))
		"ach":
			for aid in D.achievements:
				var got: bool = aid in G.meta["ach"]
				add.call(("✔ " if got else "✘ ") + D.achievements[aid]["n"] + " — " + D.achievements[aid]["d"], Color(1, 0.85, 0.4) if got else Color(0.55, 0.55, 0.55))
		"tips":
			for tp in D.TIPS:
				add.call("“" + tp + "”", Color(0.85, 0.9, 1))

# ---- 挑战塔
func _challenge_panel() -> void:
	Screens.confirm(m, "挑战塔 · Boss车轮战", "连续挑战 狼王 → 穆蛇 → 美杜莎 → 云山。\n使用上次出征的角色，从斗师境界开始。胜利奖励大量斗气结晶。", "挑战！", "算了", func(yes):
		if yes:
			var c: String = G.meta.get("last_char", "xiaoyan")
			G.new_run(c, 2, D.chars[c]["atks"][0], "", int(G.meta.get("diff", 1)), [], "bossrush")
			G.run["realm"] = 27
			Flow.start_bossrush(m))

# ---------------------------------------------------------------- 出征
var sel := {}

func _launch_panel() -> void:
	if sel.is_empty():
		var lc: String = G.meta.get("last_char", "xiaoyan")
		if not G.is_char_unlocked(lc):
			lc = "xiaoyan"
		sel = {"char": lc, "atk": G.meta.get("last_atk", "atk_ruler"), "comp": G.meta.get("last_comp", "yaolao"), "chapter": 1, "diff": int(G.meta.get("diff", 1)), "tj": G.meta.get("tianjie", []).duplicate(), "mode": "story"}
	var a := _panel("出 征", Color(1, 0.6, 0.3))
	var root: Control = a[0]
	var p: Panel = a[1]
	var reopen := func():
		root.queue_free()
		_launch_panel()
	# 角色
	UI.label(p, "角色", Vector2(20, 44), 12, Color(1, 0.8, 0.5))
	var x := 20.0
	for cid in D.char_order:
		var c: Dictionary = D.chars[cid]
		var un := G.is_char_unlocked(cid)
		var cc: String = cid
		var b := UI.button(p, "", Rect2(x, 62, 96, 110), func():
			if not un:
				Au.sfx("fail")
				return
			sel["char"] = cc
			if cc != "xiaoyan":
				sel["atk"] = D.chars[cc]["atks"][0]
			elif not (sel["atk"] in D.chars["xiaoyan"]["atks"]):
				sel["atk"] = "atk_ruler"
			if sel["comp"] == cc:
				sel["comp"] = "yaolao"
			reopen.call(), c["color"] if sel["char"] == cid else Color(0.35, 0.35, 0.35))
		var por := G.portrait(c["spr"])
		if por:
			var tr := UI.tex_rect(b, por, Rect2(12, 6, 72, 72))
			if not un:
				tr.modulate = Color(0, 0, 0, 0.8)
		UI.label(b, c["n"] if un else "？？？", Vector2(0, 84), 12, c["color"] if un else Color(0.5, 0.5, 0.5), 96, HORIZONTAL_ALIGNMENT_CENTER)
		x += 102
	var ch: Dictionary = D.chars[sel["char"]]
	UI.label(p, "%s · %s\n%s" % [ch["n"], ch["t"], ch["mech"]], Vector2(540, 62), 8, Color(0.9, 0.9, 0.85), 300)
	# 普攻风格（萧炎）
	var y := 184.0
	UI.label(p, "普攻", Vector2(20, y), 12, Color(1, 0.8, 0.5))
	x = 70.0
	var atks: Array = ch["atks"]
	for aid in atks:
		if sel["char"] == "xiaoyan" and not (aid in G.meta["unlocked_atks"]):
			continue
		var aa: String = aid
		UI.button(p, D.skills[aid]["n"], Rect2(x, y - 2, 110, 24), func():
			sel["atk"] = aa
			reopen.call(), Color(1, 0.7, 0.3) if sel["atk"] == aid else Color(0.4, 0.4, 0.4), 8)
		x += 116
	# 同伴
	y += 34
	UI.label(p, "同伴", Vector2(20, y), 12, Color(1, 0.8, 0.5))
	x = 70.0
	for cid in [""] + G.meta["unlocked_comps"]:
		if cid == sel["char"]:
			continue
		var cc2: String = cid
		UI.button(p, "无" if cid == "" else D.companions[cid]["n"], Rect2(x, y - 2, 90, 24), func():
			sel["comp"] = cc2
			reopen.call(), Color(0.7, 0.9, 1) if sel["comp"] == cid else Color(0.4, 0.4, 0.4), 8)
		x += 96
	# 模式 / 章节
	y += 34
	UI.label(p, "模式", Vector2(20, y), 12, Color(1, 0.8, 0.5))
	x = 70.0
	var modes := [["story", "征途"]]
	if int(G.meta["buildings"].get("tower", 0)) > 0:
		modes.append(["endless", "无尽·天火塔"])
	for md in modes:
		var mm: String = md[0]
		UI.button(p, md[1], Rect2(x, y - 2, 110, 24), func():
			sel["mode"] = mm
			reopen.call(), Color(1, 0.7, 0.3) if sel["mode"] == md[0] else Color(0.4, 0.4, 0.4), 8)
		x += 116
	if sel["mode"] == "story":
		x += 20
		UI.label(p, "起始章节", Vector2(x, y), 12, Color(1, 0.8, 0.5))
		x += 70
		for c in range(1, D.chapters.size()):
			var avail: bool = c == 1 or (c - 1) in G.meta["chapters_cleared"]
			var ci: int = c
			var bb := UI.button(p, D.chapters[c]["n"], Rect2(x, y - 2, 80, 24), func():
				sel["chapter"] = ci
				reopen.call(), Color(0.6, 1, 0.5) if sel["chapter"] == c else Color(0.4, 0.4, 0.4), 8)
			bb.disabled = not avail
			x += 86
	# 难度
	y += 34
	UI.label(p, "难度", Vector2(20, y), 12, Color(1, 0.8, 0.5))
	x = 70.0
	for di in D.DIFFS.size():
		var dd: int = di
		var bd := UI.button(p, D.DIFFS[di]["n"], Rect2(x, y - 2, 80, 24), func():
			sel["diff"] = dd
			reopen.call(), Color(1, 0.5, 0.3) if sel["diff"] == di else Color(0.4, 0.4, 0.4), 8)
		bd.tooltip_text = D.DIFFS[di]["d"]
		x += 86
	UI.label(p, D.DIFFS[sel["diff"]]["d"] + "（奖励×%.1f）" % D.DIFFS[sel["diff"]]["rew"], Vector2(x + 10, y + 2), 8, Color(0.8, 0.8, 0.75))
	# 天劫
	y += 32
	var tjp := 0
	for tj in D.TIANJIE:
		if tj["id"] in sel["tj"]:
			tjp += int(tj["pt"])
	UI.label(p, "天劫（每点奖励+15%%）已选 %d 点" % tjp, Vector2(20, y), 12, Color(0.8, 0.6, 1))
	y += 20
	for i in D.TIANJIE.size():
		var tj: Dictionary = D.TIANJIE[i]
		var on: bool = tj["id"] in sel["tj"]
		var tid: String = tj["id"]
		var bt := UI.button(p, "%s(%d)" % [tj["n"], tj["pt"]], Rect2(20 + (i % 6) * 136, y + (i / 6) * 28, 130, 24), func():
			if tid in sel["tj"]:
				sel["tj"].erase(tid)
			else:
				sel["tj"].append(tid)
			reopen.call(), Color(0.8, 0.5, 1) if on else Color(0.35, 0.35, 0.4), 8)
		bt.tooltip_text = tj["d"]
	UI.button(p, "出　征！", Rect2(330, 434, 200, 36), func():
		root.queue_free()
		_start_run(), Color(1, 0.55, 0.25), 16).grab_focus()

func _start_run() -> void:
	G.meta["last_char"] = sel["char"]
	G.meta["last_atk"] = sel["atk"]
	G.meta["last_comp"] = sel["comp"]
	G.meta["diff"] = sel["diff"]
	G.meta["tianjie"] = sel["tj"].duplicate()
	G.save_meta()
	Au.sfx("door")
	if sel["mode"] == "endless":
		G.new_run(sel["char"], 2, sel["atk"], sel["comp"], sel["diff"], sel["tj"].duplicate(), "endless")
		m.fade_to(Flow.start_endless.bind(m))
		return
	var chap: int = sel["chapter"]
	G.new_run(sel["char"], chap, sel["atk"], sel["comp"], sel["diff"], sel["tj"].duplicate())
	m.fade_to(Flow.start_chapter.bind(m, chap))
