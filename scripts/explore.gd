class_name Explore
extends Battle
## 探索场景：一整张可以自由行走的区域（野外 / 城镇）。
## 复用 Battle 的全部战斗系统；在此之上增加：
##  - 程序生成的地形（道路网 + 障碍群 + 边界），同一局同一区域的布局固定（按种子生成）
##  - 成群的怪物（靠近才苏醒），清完一群掉落“机缘”（五选一）
##  - 可互动地点 POI：宝箱 / 奇遇 / 修炼 / 商人 / 炼药 / 洞穴入口 / 剧情对决 / 原著斗技剧情 / 出口 / Boss
##  - 小地图（右上角）+ 大地图（M 键）+ 迷雾探索
##  - 自动存档：清怪、使用地点、每隔一段时间都会保存位置与状态

const CELL := 100.0

var zone_id := ""
var zdef: Dictionary = {}
var zst: Dictionary = {}
var pois: Array = []      # {id,t,p,r,n,done,node,def}
var packs: Array = []     # {id,p,alive,elite,woke,kinds}
var paths: Array = []     # [Vector2, Vector2]
var near_poi = null
var gw := 0
var gh := 0
var seen := PackedByteArray()
var seen_t := 0.0
var save_t := 0.0
var calm_t := 0.0
var minimap: MiniMap
var prompt_l: Label
var busy := false
var start_pos := Vector2.ZERO

func setup_zone(m, zid:String) -> void:
	zone_id = zid
	zdef = WD.zones[zid]
	zst = G.run["zone"]
	setup(m, {"type": "explore", "biome": zdef["biome"]})
	arena = Rect2(0, 0, float(zdef["w"]), float(zdef["h"]))
	gw = int(ceil(arena.size.x / CELL))
	gh = int(ceil(arena.size.y / CELL))
	seen = Marshalls.base64_to_raw(zst.get("seen", "")) if zst.get("seen", "") != "" else PackedByteArray()
	if seen.size() != gw * gh:
		seen = PackedByteArray()
		seen.resize(gw * gh)

func _ready() -> void:
	cleared = true   # 探索场景没有“清房间结束”的概念
	super._ready()
	# 玩家位置：存档位置或区域起点
	var sp: Array = zdef.get("start", [0.5, 0.9])
	start_pos = Vector2(arena.size.x * float(sp[0]), arena.size.y * float(sp[1]))
	var pos := start_pos
	if zst.has("pos") and zst["pos"] is Array and zst["pos"].size() == 2:
		pos = Vector2(float(zst["pos"][0]), float(zst["pos"][1]))
	player.position = pos
	if comp:
		comp.position = pos + Vector2(-40, 10)
	cam.position = pos
	cam.reset_smoothing()
	if zdef.has("tint"):
		for c in get_children():
			if c is CanvasModulate:
				c.color = zdef["tint"]
	# 小地图 + 互动提示
	minimap = MiniMap.new()
	minimap.ex = self
	H.add_child(minimap)
	prompt_l = UI.label(minimap, "", Vector2(0, 404), 14, Color(1, 0.92, 0.7), 960, HORIZONTAL_ALIGNMENT_CENTER)
	prompt_l.add_theme_constant_override("outline_size", 6)
	prompt_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_reveal(true)
	if not zst.get("intro", false):
		zst["intro"] = true
		H.banner(zdef["n"], Color(1, 0.85, 0.5))
	G.save_run()

# ---------------------------------------------------------------- 地形生成
func _rng(salt:int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(zst.get("seed", 1)) * 31 + salt
	return r

func _build_decor() -> void:
	var rng := _rng(7)
	var sp: Array = zdef.get("start", [0.5, 0.9])
	var spos := Vector2(arena.size.x * float(sp[0]), arena.size.y * float(sp[1]))
	# 1) 地点
	var placed: Array = [spos]
	var idx := 0
	for pd in zdef["pois"]:
		var d: Dictionary = pd
		var p: Vector2
		if d.has("at"):
			p = Vector2(arena.size.x * float(d["at"][0]), arena.size.y * float(d["at"][1]))
		else:
			p = _free_spot(rng, placed, 300.0, spos, 380.0)
		placed.append(p)
		var id: String = d.get("id", "p%d" % idx)
		idx += 1
		pois.append({"id": id, "t": d["t"], "p": p, "r": 70.0 if d.has("bld") else 56.0, "n": d.get("n", _poi_default_name(d["t"])), "done": id in zst.get("done", []), "def": d, "node": null})
	# 2) 怪物群
	var npk: int = int(zdef.get("packs", 0))
	var nel: int = int(zdef.get("elite_packs", 0))
	for i in npk + nel:
		var p2 := _free_spot(rng, placed, 280.0, spos, 480.0)
		placed.append(p2)
		packs.append({"id": "k%d" % i, "p": p2, "alive": 0, "elite": i >= npk, "woke": false, "dead": ("k%d" % i) in zst.get("dead", []), "tier_i": i})
	# 3) 道路：从起点出发的最小生成树
	var nodes: Array = [spos]
	for po in pois:
		nodes.append(po["p"] + (Vector2(0, 58) if po["def"].has("bld") else Vector2.ZERO))
	var in_tree := [0]
	var rest := range(1, nodes.size())
	while rest.size() > 0:
		var best := [-1, -1, INF]
		for a in in_tree:
			for b2 in rest:
				var dd: float = nodes[a].distance_to(nodes[b2])
				if dd < best[2]:
					best = [a, b2, dd]
		paths.append([nodes[best[0]], nodes[best[1]]])
		in_tree.append(best[1])
		rest.erase(best[1])
	# 4) 边界装饰
	var sets := {
		"forest": ["tree", "tree", "bush", "rock", "tree"], "wutan": ["tree", "bush", "lantern"],
		"desert": ["rock_desert", "cactus", "rock_desert"], "yunlan": ["pillar", "lantern", "rock", "tree"],
		"lava": ["rock_lava"], "void": ["crystal_void"],
	}
	var objs: Array = sets.get(biome, ["rock"])
	var step := 64.0
	var x := arena.position.x - 30
	while x < arena.end.x + 30:
		for side in [arena.position.y - 24, arena.end.y + 36]:
			_add_obj(objs[rng.randi() % objs.size()], Vector2(x + rng.randf_range(-16, 16), side + rng.randf_range(-12, 12)), false)
		x += step
	var y := arena.position.y
	while y < arena.end.y:
		for side in [arena.position.x - 36, arena.end.x + 36]:
			_add_obj(objs[rng.randi() % objs.size()], Vector2(side + rng.randf_range(-12, 12), y + rng.randf_range(-16, 16)), false)
		y += step
	# 5) 城镇建筑 / 野外障碍群
	if zdef["kind"] == "town":
		_build_town(rng)
	else:
		var dens: float = float(zdef.get("dens", 0.5))
		var gx := arena.position.x + 90
		while gx < arena.end.x - 60:
			var gy := arena.position.y + 80
			while gy < arena.end.y - 60:
				var p3 := Vector2(gx + rng.randf_range(-40, 40), gy + rng.randf_range(-40, 40))
				gy += 105
				if rng.randf() > dens:
					continue
				if not _clear_of_features(p3, 95.0, 150.0, 170.0, spos):
					continue
				var o: String = objs[rng.randi() % objs.size()]
				_add_obj(o, p3, o != "bush")
			gx += 105
	# 6) 道路图层 + 地点节点
	var pl := PathLayer.new()
	pl.ex = self
	pl.z_index = -18
	world.add_child(pl)
	for po in pois:
		var n := PoiNode.new()
		n.ex = self
		n.poi = po
		n.position = po["p"]
		ysort.add_child(n)
		po["node"] = n
		if po["def"].has("bld"):
			# 建筑作为障碍（底边几个圆）
			for k in [-50.0, -17.0, 17.0, 50.0]:
				obstacles.append([po["p"] + Vector2(k, -6), 30.0])

func _build_town(rng:RandomNumberGenerator) -> void:
	# 行道灯笼 + 行人
	var y0 := arena.size.y * 0.47
	var x := 120.0
	while x < arena.size.x - 80:
		_add_obj("lantern", Vector2(x, y0 - 70), true)
		_add_obj("lantern", Vector2(x + 60, y0 + 90), true)
		x += 260.0
	for i in 14:
		var p := Vector2(rng.randf_range(80, arena.size.x - 80), rng.randf_range(arena.size.y * 0.4, arena.size.y * 0.58))
		if _clear_of_features(p, 0.0, 120.0, 0.0, Vector2(-999, -999)):
			_add_obj(["bush", "tree"][rng.randi() % 2], Vector2(p.x, [arena.size.y * 0.08, arena.size.y * 0.96][rng.randi() % 2]), false)
	var walkers := ["xuner", "nalan", "yaolao", "xiaoyixian", "yunyun"]
	for i in 6:
		var w := Walker.new()
		w.spr_id = walkers[rng.randi() % walkers.size()]
		w.position = Vector2(rng.randf_range(200, arena.size.x - 200), y0 + rng.randf_range(-20, 40))
		w.lim = Rect2(120, y0 - 30, arena.size.x - 240, 110)
		ysort.add_child(w)

func _poi_default_name(t:String) -> String:
	return {"chest": "宝箱", "event": "奇遇", "rest": "修炼之地", "shop": "商人", "alchemy": "丹炉", "cave": "洞穴", "exit": "出口", "boss": "首领", "story": "机缘", "duel": "强敌", "fire": "异火"}.get(t, t)

func _free_spot(rng:RandomNumberGenerator, placed:Array, min_d:float, spos:Vector2, start_d:float) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -INF
	for i in 60:
		var p := Vector2(rng.randf_range(arena.position.x + 150, arena.end.x - 150), rng.randf_range(arena.position.y + 150, arena.end.y - 150))
		var md := INF
		for q in placed:
			md = min(md, p.distance_to(q))
		if p.distance_to(spos) < start_d:
			md = min(md, p.distance_to(spos) - start_d + min_d)
		if md >= min_d:
			return p
		if md > best_score:
			best_score = md
			best = p
	return best

func _seg_dist(p:Vector2, a:Vector2, b2:Vector2) -> float:
	var ab := b2 - a
	var t := clampf((p - a).dot(ab) / max(1.0, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _clear_of_features(p:Vector2, path_d:float, poi_d:float, pack_d:float, spos:Vector2) -> bool:
	if p.distance_to(spos) < 190:
		return false
	for s in paths:
		if _seg_dist(p, s[0], s[1]) < path_d:
			return false
	for po in pois:
		if p.distance_to(po["p"]) < poi_d + (60.0 if po["def"].has("bld") else 0.0):
			return false
	for pk in packs:
		if p.distance_to(pk["p"]) < pack_d:
			return false
	return true

# ---------------------------------------------------------------- 怪物群
func _start_room() -> void:
	time_in_room = 0
	waves_left = 0
	var ch: Dictionary = D.chapters[int(G.run["chapter"])]
	var pools: Array = ch.get("pool", [["wolf"]])
	var tiers: Array = zdef.get("tiers", [0, 1])
	var rng := _rng(99)
	for pk in packs:
		var tier: int = int(tiers[0]) + (int(pk["tier_i"]) * (int(tiers[-1]) - int(tiers[0]) + 1)) / max(1, packs.size())
		tier = clampi(tier, 0, pools.size() - 1)
		pk["tier"] = tier
		if pk["dead"]:
			continue
		var pool: Array = pools[tier]
		var n := 3 + rng.randi_range(0, 2) + tier
		var m := _pack_mult(tier)
		if pk["elite"]:
			var els: Array = ch.get("elites", ["jialie"])
			var eid: String = els[rng.randi() % els.size()]
			var e := _spawn_dormant(eid, pk["p"], m * 0.85, true, pk)
			e.is_elite = true
			n = 3
		for i in n:
			var ang := TAU * i / n + rng.randf() * 0.6
			var p: Vector2 = pk["p"] + Vector2(cos(ang), sin(ang)) * rng.randf_range(40, 95)
			_spawn_dormant(pool[rng.randi() % pool.size()], p, m, false, pk)

func _pack_mult(tier:int) -> float:
	var ch: int = int(G.run.get("chapter", 1))
	var zi: int = int(zst.get("i", 0))
	return 1.0 + (zi * 2 + tier) * 0.16 + (ch - 1) * 1.6

func _mult() -> float:
	return _pack_mult(2)

func _spawn_dormant(kind:String, pos:Vector2, mult:float, boss:bool, pk:Dictionary) -> Enemy:
	var e := Enemy.new()
	e.position = pos
	e.dormant = true
	e.pack = pk["id"]
	e.home = pos
	ysort.add_child(e)
	e.setup(self, kind, boss, mult)
	e.spawn_t = 0.0
	enemies.append(e)
	pk["alive"] = int(pk["alive"]) + 1
	if not (kind in G.meta["codex_enemies"]):
		G.meta["codex_enemies"].append(kind)
	return e

func wake_pack(pid:String) -> void:
	for pk in packs:
		if pk["id"] == pid and not pk["woke"]:
			pk["woke"] = true
			for e in enemies:
				if is_instance_valid(e) and e.pack == pid and e.dormant:
					e.dormant = false
					if e.is_boss:
						boss_ref = e
						boss_active = true
						H.show_boss(e)
						Au.sfx("bosswarn", -4)
			Au.sfx("hover", -6, 0.6)
			return

func enemy_died(e:Enemy) -> void:
	super.enemy_died(e)
	if e.pack == "":
		return
	for pk in packs:
		if pk["id"] == e.pack:
			pk["alive"] = int(pk["alive"]) - 1
			if int(pk["alive"]) <= 0 and not pk["dead"]:
				pk["dead"] = true
				zst["dead"] = zst.get("dead", []) + [pk["id"]]
				if e == boss_ref or pk["elite"]:
					boss_active = false
					H.hide_boss()
				_drop_orb(e.global_position, 6 if pk["elite"] else 5)
				G.run["hp"] = player.hp
				_save()
			return

## 清完一群怪 → 掉落“机缘”光球，拾取后五选一（精英六选一）
func _drop_orb(pos:Vector2, n:int) -> void:
	var po := {"id": "orb%d" % Time.get_ticks_msec(), "t": "orb", "p": pos, "r": 30.0, "n": "机缘", "done": false, "def": {"n": n}, "node": null}
	var node := PoiNode.new()
	node.ex = self
	node.poi = po
	node.position = pos
	ysort.add_child(node)
	po["node"] = node
	pois.append(po)
	spawn_fx("ring", pos, {"r": 90, "col": Color(1, 0.85, 0.4), "life": 0.7, "width": 5})
	H.banner("清剿完毕 · 机缘现世", Color(1, 0.85, 0.4))

# ---------------------------------------------------------------- 主循环
func _physics_process(delta:float) -> void:
	super._physics_process(delta)
	if G.run.is_empty() or paused_logic or ended:
		return
	seen_t -= delta
	if seen_t <= 0:
		seen_t = 0.2
		_reveal(false)
	save_t += delta
	if save_t > 20.0:
		_save()
	# 附近的可互动地点
	near_poi = null
	var bestd := INF
	for po in pois:
		if po["done"]:
			continue
		var d: float = player.global_position.distance_to(po["p"] + (Vector2(0, 50) if po["def"].has("bld") else Vector2.ZERO))
		if po["t"] == "orb" and d < 34:
			_use_poi(po)
			return
		if d < float(po["r"]) and d < bestd:
			bestd = d
			near_poi = po
	if near_poi != null:
		prompt_l.text = "【%s】%s" % [G.key_name("interact"), _poi_verb(near_poi)]
		if Input.is_action_just_pressed("interact") and not busy:
			_use_poi(near_poi)
	else:
		prompt_l.text = ""
	# 战斗平息后，发放升级/突破积攒的机缘
	var hot := false
	for e in enemies:
		if is_instance_valid(e) and not e.dormant and e.global_position.distance_to(player.global_position) < 520:
			hot = true
			break
	calm_t = 0.0 if hot else calm_t + delta
	if calm_t > 0.8 and not pending_picks.is_empty() and not busy:
		_offer_pick()

func _unhandled_input(e:InputEvent) -> void:
	if e.is_action_pressed("bigmap"):
		minimap.big = not minimap.big
		minimap.queue_redraw()

func _poi_verb(po:Dictionary) -> String:
	match po["t"]:
		"chest": return "打开 · " + po["n"]
		"cave", "exit": return "进入 · " + po["n"]
		"boss": return "挑战首领 · " + po["n"]
		"duel": return "前往 · " + po["n"]
		"story": return "查看 · " + po["n"]
		"rest": return "修炼 · " + po["n"]
		"alchemy": return "炼药 · " + po["n"]
		"shop", "auction": return "进入 · " + po["n"]
		"event": return "交谈 · " + po["n"]
	return po["n"]

func _reveal(all_near:bool) -> void:
	var pc := player.global_position
	var rad := 380.0 if not all_near else 460.0
	var r := int(ceil(rad / CELL))
	var cx := int(pc.x / CELL)
	var cy := int(pc.y / CELL)
	for yy in range(max(0, cy - r), min(gh, cy + r + 1)):
		for xx in range(max(0, cx - r), min(gw, cx + r + 1)):
			if Vector2((xx + 0.5) * CELL, (yy + 0.5) * CELL).distance_to(pc) < rad:
				seen[yy * gw + xx] = 1
	# 城镇：整张地图一开始就是已知的
	if zdef["kind"] == "town" and all_near:
		for i in seen.size():
			seen[i] = 1

func is_seen(p:Vector2) -> bool:
	var xx := clampi(int(p.x / CELL), 0, gw - 1)
	var yy := clampi(int(p.y / CELL), 0, gh - 1)
	return seen[yy * gw + xx] == 1

func _save() -> void:
	save_t = 0.0
	zst["pos"] = [player.global_position.x, player.global_position.y]
	zst["seen"] = Marshalls.raw_to_base64(seen)
	G.run["hp"] = player.hp
	G.save_run()

# ---------------------------------------------------------------- 使用地点
func _mark_done(po:Dictionary) -> void:
	po["done"] = true
	if not (po["id"] in zst.get("done", [])):
		zst["done"] = zst.get("done", []) + [po["id"]]
	if po["node"]:
		po["node"].queue_redraw()

## 打开覆盖式界面（坊市/奇遇等）：暂停战斗逻辑，关闭后恢复
func overlay(fn:Callable) -> void:
	busy = true
	paused_logic = true
	in_menu = true
	G.run["hp"] = player.hp
	prompt_l.text = ""
	fn.call(func():
		busy = false
		paused_logic = false
		in_menu = false
		if float(G.run["hp"]) > 0:
			player.hp = min(float(G.run["hp"]), player.st["hp_max"])
		player.recalc()
		player.hp = min(player.hp, player.st["hp_max"])
		_save())

func _use_poi(po:Dictionary) -> void:
	if po["done"] or busy:
		return
	Au.sfx("click")
	var m = main
	var t: String = po["t"]
	match t:
		"orb":
			_mark_done(po)
			po["node"].queue_free()
			pois.erase(po)
			pending_picks.append(int(po["def"]["n"]))
			_offer_pick()
		"chest":
			_mark_done(po)
			var gg := randi_range(40, 90) + int(zst.get("i", 0)) * 20
			G.run["gold"] = int(G.run["gold"]) + gg
			float_text(po["p"] + Vector2(0, -40), "+%d 金币" % gg, Color(1, 0.85, 0.3), true)
			burst_particles(po["p"], Color(1, 0.85, 0.3), 30, 200, 3)
			if randf() < 0.35:
				var hk: Array = D.herbs.keys()
				for i in 2:
					_drop("herb:" + hk[randi() % hk.size()], po["p"], 1)
			overlay(func(done): Flow.reward_screen(m, "any", done, 0, 5))
		"event":
			_mark_done(po)
			overlay(func(done): Screens.event(m, po["def"].get("ev", ""), done))
		"rest":
			_mark_done(po)
			overlay(func(done): Screens.rest(m, done))
		"shop":
			overlay(func(done): Screens.shop(m, done))
		"auction":
			_mark_done(po)
			overlay(func(done): Screens.auction(m, done))
		"alchemy":
			_mark_done(po)
			overlay(func(done): Screens.alchemy_select(m, true, done))
		"story":
			var cid: String = po["def"].get("canon", "")
			if G.run["char"] == "xiaoyan" and cid != "" and not G.has_skill(cid):
				_mark_done(po)
				overlay(func(done): Flow.learn_canon(m, cid, done))
			else:
				# 非萧炎角色：普通奇遇
				_mark_done(po)
				overlay(func(done): Screens.event(m, "", done))
		"cave", "duel", "boss", "exit":
			_save()
			overlay(func(done): Flow.explore_poi(m, self, po, done))

func _offer_pick() -> void:
	if pending_picks.is_empty() or busy:
		return
	var n: int = pending_picks.pop_front()
	overlay(func(done): Flow.reward_screen(main, "boss" if n >= 6 else "any", done, 0, n))

# ================================================================ 内部类
class PathLayer extends Node2D:
	var ex
	func _draw() -> void:
		var town: bool = ex.zdef["kind"] == "town"
		var c1 := Color(0.42, 0.36, 0.28, 0.55) if not town else Color(0.55, 0.5, 0.44, 0.75)
		var c2 := Color(0.55, 0.47, 0.36, 0.45) if not town else Color(0.66, 0.62, 0.55, 0.7)
		match ex.biome:
			"desert": c1 = Color(0.78, 0.62, 0.4, 0.5); c2 = Color(0.86, 0.72, 0.5, 0.45)
			"yunlan": c1 = Color(0.72, 0.72, 0.75, 0.7); c2 = Color(0.84, 0.84, 0.86, 0.6)
		for s in ex.paths:
			draw_line(s[0], s[1], c1, 64.0 if town else 50.0)
			draw_circle(s[0], 32.0 if town else 25.0, c1)
			draw_circle(s[1], 32.0 if town else 25.0, c1)
		for s in ex.paths:
			draw_line(s[0], s[1], c2, 40.0 if town else 26.0)
		if town:
			# 主街
			var y0: float = ex.arena.size.y * 0.47
			draw_rect(Rect2(60, y0 - 50, ex.arena.size.x - 120, 150), c1)
			draw_rect(Rect2(60, y0 - 34, ex.arena.size.x - 120, 118), c2)

class PoiNode extends Node2D:
	var ex
	var poi: Dictionary
	var t := 0.0
	func _process(d:float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var f: Font = G.font
		var done: bool = poi["done"]
		var ty: String = poi["t"]
		var bob := sin(t * 3.0) * 3.0
		var near: bool = ex.near_poi == poi
		if poi["def"].has("bld"):
			var tex := G.tex("res://assets/obj/%s.png" % poi["def"]["bld"])
			if tex:
				var sz := Vector2(150, 190) if poi["def"]["bld"] == "b_tower" else (Vector2(150, 120) if poi["def"]["bld"] == "b_gate" else Vector2(160, 110))
				draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2, -sz.y + 8), sz), false, Color(1.12, 1.08, 1.0) if near else Color.WHITE)
			_label(f, Vector2(0, 30), poi["n"], near)
			if not done and ty != "exit":
				_marker(Vector2(0, -130 if poi["def"]["bld"] != "b_tower" else -205) + Vector2(0, bob), ty)
			return
		match ty:
			"chest":
				var c := Color(0.55, 0.33, 0.16) if not done else Color(0.3, 0.22, 0.15)
				draw_rect(Rect2(-16, -22, 32, 22), c)
				draw_rect(Rect2(-16, -22, 32, 22), Color(0.95, 0.75, 0.3), false, 2.0)
				if not done:
					draw_rect(Rect2(-17, -30, 34, 10), c.lightened(0.1))
					draw_rect(Rect2(-17, -30, 34, 10), Color(0.95, 0.75, 0.3), false, 2.0)
					draw_rect(Rect2(-3, -24, 6, 7), Color(1, 0.85, 0.3))
					draw_circle(Vector2(0, -14), 26 + sin(t * 4) * 3, Color(1, 0.85, 0.3, 0.12))
				else:
					draw_rect(Rect2(-17, -40, 34, 6), c)
			"cave":
				draw_circle(Vector2(0, -10), 46, Color(0.18, 0.15, 0.12))
				draw_circle(Vector2(0, -8), 36, Color(0.03, 0.02, 0.03))
				for k in 7:
					var a := PI + PI * k / 6.0
					draw_circle(Vector2(cos(a) * 44, -8 + sin(a) * 40), 11, Color(0.35, 0.32, 0.28))
				if not done:
					draw_circle(Vector2(0, -10), 52 + sin(t * 2) * 3, Color(1, 0.6, 0.3, 0.1))
			"exit", "boss":
				var col := Color(1, 0.3, 0.25) if ty == "boss" else Color(0.5, 0.85, 1)
				for k in 3:
					draw_arc(Vector2(0, -30), 34 - k * 8 + sin(t * 3 + k) * 2, 0, TAU, 32, Color(col, 0.7 - k * 0.2), 3.0)
				draw_circle(Vector2(0, -30), 18, Color(col, 0.25))
			"story":
				draw_circle(Vector2(0, -6), 30 + sin(t * 3) * 2, Color(1, 0.8, 0.3, 0.18 if not done else 0.04))
				draw_rect(Rect2(-14, -20, 28, 18), Color(0.85, 0.75, 0.5) if not done else Color(0.4, 0.38, 0.33))
				draw_line(Vector2(0, -20), Vector2(0, -2), Color(0.5, 0.35, 0.2), 2.0)
			"rest":
				draw_circle(Vector2(0, -6), 26, Color(0.3, 0.6, 0.9, 0.3 if not done else 0.08))
				draw_arc(Vector2(0, -6), 20, 0, TAU, 24, Color(0.6, 0.85, 1, 0.8 if not done else 0.2), 2.0)
			"alchemy":
				var ct := G.tex("res://assets/obj/cauldron.png")
				if ct:
					draw_texture(ct, Vector2(-ct.get_width() / 2.0, -ct.get_height()), Color.WHITE if not done else Color(0.5, 0.5, 0.5))
			"shop":
				draw_rect(Rect2(-30, -34, 60, 30), Color(0.45, 0.28, 0.16))
				draw_rect(Rect2(-36, -46, 72, 14), Color(0.75, 0.2, 0.18))
				for k in 4:
					draw_rect(Rect2(-36 + k * 18, -46, 9, 14), Color(0.95, 0.85, 0.7))
				draw_circle(Vector2(-18, -38), 5, Color(1, 0.85, 0.3))
			"event":
				draw_circle(Vector2(0, -8), 14, Color(0.3, 0.5, 0.9, 0.5 if not done else 0.1))
			"duel":
				var sid: String = D.enemies[poi["def"]["boss"]].get("spr", "") if D.enemies.has(poi["def"]["boss"]) else ""
				var st := G.spr(sid)
				if st and not done:
					var sc := minf(1.0, 70.0 / st.get_height())
					draw_texture_rect(st, Rect2(Vector2(-st.get_width() * sc / 2, -st.get_height() * sc), st.get_size() * sc), false, Color(1, 0.9, 0.9))
				draw_arc(Vector2(0, 0), 40, 0, TAU, 32, Color(1, 0.3, 0.3, 0.5 if not done else 0.1), 2.0)
			"orb":
				draw_circle(Vector2(0, -20 + bob), 16 + sin(t * 6) * 2, Color(1, 0.85, 0.4, 0.3))
				draw_circle(Vector2(0, -20 + bob), 9, Color(1, 0.95, 0.7))
				return
		if ty != "orb":
			_label(f, Vector2(0, 18), poi["n"], near)
			if not done and ty in ["story", "event", "duel", "boss"]:
				_marker(Vector2(0, -70 if ty != "duel" else -92) + Vector2(0, bob), ty)
	func _marker(p:Vector2, ty:String) -> void:
		var f: Font = G.font
		var col := {"story": Color(1, 0.8, 0.3), "event": Color(0.5, 0.75, 1), "duel": Color(1, 0.35, 0.3), "boss": Color(1, 0.25, 0.2), "shop": Color(1, 0.85, 0.3), "auction": Color(1, 0.7, 0.4), "alchemy": Color(0.5, 1, 0.6), "rest": Color(0.6, 0.85, 1)}.get(ty, Color.WHITE)
		var ch := {"story": "!", "event": "?", "duel": "战", "boss": "王", "shop": "市", "auction": "拍", "alchemy": "丹", "rest": "修"}.get(ty, "·")
		draw_circle(p, 13, Color(0, 0, 0, 0.6))
		draw_arc(p, 13, 0, TAU, 24, col, 2.0)
		draw_string(f, p + Vector2(-20, 6), ch, HORIZONTAL_ALIGNMENT_CENTER, 40, 15, col)
	func _label(f:Font, p:Vector2, s:String, near:bool) -> void:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14
		draw_rect(Rect2(p.x - w / 2, p.y - 13, w, 19), Color(0, 0, 0, 0.7 if near else 0.45))
		draw_string(f, Vector2(p.x - w / 2 + 7, p.y + 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.88, 0.5) if near else (Color(0.95, 0.92, 0.85) if not poi["done"] else Color(0.6, 0.6, 0.6)))

## 城镇里走动的行人（纯装饰）
class Walker extends Node2D:
	var spr_id := ""
	var lim := Rect2()
	var tgt := Vector2.ZERO
	var wait := 0.0
	var t := 0.0
	var tex: Texture2D
	func _ready() -> void:
		tex = G.spr(spr_id)
		tgt = position
		modulate = Color(0.9, 0.9, 0.9)
	func _process(d:float) -> void:
		t += d
		if wait > 0:
			wait -= d
		elif position.distance_to(tgt) < 4:
			tgt = Vector2(randf_range(lim.position.x, lim.end.x), randf_range(lim.position.y, lim.end.y))
			wait = randf_range(1.0, 4.0)
		else:
			position += (tgt - position).normalized() * 40 * d
		queue_redraw()
	func _draw() -> void:
		if tex == null:
			return
		var sc := 44.0 / tex.get_height()
		var moving := wait <= 0
		var bob := absf(sin(t * 9)) * 2.0 if moving else 0.0
		var flip := tgt.x < position.x
		draw_circle(Vector2(0, 0), 9, Color(0, 0, 0, 0.25))
		var sz := tex.get_size() * sc
		var r := Rect2(Vector2(-sz.x / 2, -sz.y - bob), sz)
		if flip:
			r = Rect2(Vector2(sz.x / 2, -sz.y - bob), Vector2(-sz.x, sz.y))
		draw_texture_rect(tex, r, false)

## 小地图（右上角）/ 大地图（M 键）
class MiniMap extends Control:
	var ex
	var big := false
	var t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(960, 540)
	func _process(d:float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		if ex == null or not is_instance_valid(ex.player):
			return
		var r := Rect2(778, 74, 172, 112) if not big else Rect2(130, 60, 700, 420)
		var sc: float = min(r.size.x / ex.arena.size.x, r.size.y / ex.arena.size.y)
		var off: Vector2 = r.position + (r.size - ex.arena.size * sc) / 2
		draw_rect(r.grow(3), Color(0, 0, 0, 0.72 if not big else 0.88))
		draw_rect(r.grow(3), Color(0.9, 0.75, 0.45, 0.8), false, 1.5)
		# 已探索区域
		var cs: float = ex.CELL * sc
		for yy in ex.gh:
			for xx in ex.gw:
				if ex.seen[yy * ex.gw + xx] == 1:
					draw_rect(Rect2(off + Vector2(xx, yy) * cs, Vector2(cs + 0.6, cs + 0.6)), Color(0.35, 0.33, 0.28, 0.8))
		for s in ex.paths:
			if ex.is_seen(s[0]) or ex.is_seen(s[1]):
				draw_line(off + s[0] * sc, off + s[1] * sc, Color(0.75, 0.65, 0.45, 0.8), 2.0 if not big else 4.0)
		for pk in ex.packs:
			if not pk["dead"] and ex.is_seen(pk["p"]):
				draw_circle(off + pk["p"] * sc, 2.5 if not big else 5.0, Color(1, 0.3, 0.25) if not pk["elite"] else Color(1, 0.15, 0.6))
		var f: Font = G.font
		for po in ex.pois:
			if not ex.is_seen(po["p"]) or po["t"] == "orb":
				continue
			var col := _col(po["t"])
			if po["done"]:
				col = Color(0.5, 0.5, 0.5)
			var p: Vector2 = off + po["p"] * sc
			draw_circle(p, 3.5 if not big else 8.0, col)
			if big:
				draw_string(f, p + Vector2(-60, 22), po["n"], HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)
		var pp: Vector2 = off + ex.player.global_position * sc
		draw_circle(pp, 3.0 if not big else 6.0, Color.WHITE)
		draw_arc(pp, (5.0 if not big else 10.0) + sin(t * 5), 0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
		if big:
			draw_string(f, Vector2(r.position.x, r.position.y - 12), "%s   （%s 关闭地图）" % [ex.zdef["n"], G.key_name("bigmap")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.5))
			var lg := "● 怪物群  ● 精英  ● 宝箱  ● 商店/炼药  ● 奇遇/剧情  ● 洞穴/出口  ● 首领"
			draw_string(f, Vector2(r.position.x, r.end.y + 22), lg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.85))
		else:
			draw_string(f, Vector2(r.position.x, r.end.y + 14), "%s  [%s]地图" % [ex.zdef["n"], G.key_name("bigmap")], HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 10, Color(0.9, 0.85, 0.7))
	func _col(t2:String) -> Color:
		match t2:
			"chest": return Color(1, 0.85, 0.3)
			"shop", "auction", "alchemy", "rest": return Color(0.5, 1, 0.6)
			"event", "story": return Color(0.55, 0.75, 1)
			"cave", "exit": return Color(0.75, 0.6, 1)
			"boss", "duel": return Color(1, 0.3, 0.25)
		return Color.WHITE
