class_name Flow
extends RefCounted
## 局流程：章节开始、探索地图（区域/洞穴/对决/首领）、奖励、吞火、渡劫、章节推进、结算

## 从基地出发（静态函数：回调不能绑定在即将被释放的基地场景上）
static func start_chapter(m, chap:int) -> void:
	G.run["zone"] = new_zone_state(chap, 0)
	G.save_run()
	m.set_scene(StoryBG.make(D.chapters[chap]["biome"]))
	Dialog.play(m, "ch%d_start" % chap, func(): enter_zone(m))

static func start_endless(m) -> void:
	enter_room(m, {"type": "endless", "biome": "lava"}, func(_res): results(m, false))

static func start_bossrush(m) -> void:
	enter_room(m, {"type": "bossrush", "biome": "yunlan"}, func(res):
		if res == "win":
			G.run["crystal_earned"] = 300
		results(m, res == "win"))

# ---------------------------------------------------------------- 探索地图
static func new_zone_state(chap:int, i:int) -> Dictionary:
	var zl: Array = WD.chapter_zones.get(chap, WD.chapter_zones[1])
	i = clampi(i, 0, zl.size() - 1)
	return {"i": i, "id": zl[i], "seed": randi(), "done": [], "dead": []}

## 进入（或返回）当前区域
static func enter_zone(m) -> void:
	var r: Dictionary = G.run
	if not r.has("zone") or not (r["zone"] is Dictionary) or not WD.zones.has(r["zone"].get("id", "")):
		r["zone"] = new_zone_state(int(r["chapter"]), 0)
	var ex := Explore.new()
	ex.process_mode = Node.PROCESS_MODE_PAUSABLE
	ex.setup_zone(m, r["zone"]["id"])
	m.set_scene(ex)
	var ch: Dictionary = D.chapters[int(r["chapter"])]
	Au.clear_stack()
	Au.music(Au.zone_ctx(r["zone"]["id"]))
	ex.finished.connect(func(res):
		if res == "dead":
			dead(m), CONNECT_ONE_SHOT)

## 继续游戏 / 从战斗返回：回到探索地图（渡劫待定时先渡劫）
static func show_map(m) -> void:
	var r: Dictionary = G.run
	G.save_run()
	if r["flags"].get("trib_pending", false):
		r["flags"]["trib_pending"] = false
		r["flags"]["trib_done"] = true
		Dialog.lines(m, [["yaolao", "药老", "小家伙，你已触及斗王门槛……心魔劫来了！守住本心！"]], func():
			enter_room(m, {"type": "boss", "boss": "heart_demon", "biome": "void"}, func(res):
				if res == "win":
					m.toast("渡劫成功", "斗气化翼！身法强化为「斗气化翼」", Color(1, 0.75, 0.3))
					if r["move"] == "mv_roll":
						r["move"] = "mv_douqiwing"
					reward_screen(m, "boss", func(): show_map(m), 0, 6)
				else:
					dead(m)))
		return
	enter_zone(m)

## 探索地图中需要切换场景的地点：出口 / 洞穴 / 对决 / 首领
static func explore_poi(m, ex, po:Dictionary, cancel:Callable) -> void:
	var d: Dictionary = po["def"]
	var z: Dictionary = G.run["zone"]
	var zdef: Dictionary = WD.zones[z["id"]]
	var back := func(): enter_zone(m)
	match po["t"]:
		"exit":
			var zl: Array = WD.chapter_zones[int(G.run["chapter"])]
			var to: int = int(d.get("to", int(z["i"]) + 1))
			var nm: String = WD.zones[zl[clampi(to, 0, zl.size() - 1)]]["n"]
			Screens.confirm(m, "前往 %s？" % nm, "离开后将无法返回「%s」。\n还没去过的地点会错过。" % zdef["n"], "出发", "再看看", func(yes):
				if yes:
					G.run["zone"] = new_zone_state(int(G.run["chapter"]), to)
					G.save_run()
					m.fade_to(func(): enter_zone(m))
				else:
					cancel.call())
		"cave":
			Screens.confirm(m, po["n"], "进入后需要连续闯过 %d 个房间，途中无法返回。" % d["rooms"].size(), "进入", "再看看", func(yes):
				if yes:
					m.fade_to(func():
						m.set_scene(StoryBG.make(zdef["biome"]))
						Au.music("cave")
						Dialog.play(m, d.get("story", ""), func(): _cave_room(m, po, 0)))
				else:
					cancel.call())
		"duel":
			var bid: String = d["boss"]
			Dialog.play(m, d.get("story", ""), func():
				enter_room(m, {"type": "boss" if d.get("boss_room", false) else "elite", "boss": bid, "biome": zdef["biome"]}, func(res):
					if res != "win":
						dead(m)
						return
					_zone_done(po["id"])
					if bid == "nalan":
						G.run["flags"]["nalan_done"] = true
					if bid == "medusa":
						G.unlock_ach("ach_medusa")
						Dialog.play(m, "ch2_medusa_win", func():
							G.unlock_char("medusa")
							reward_screen(m, "boss", back, 120, 6))
						return
					reward_screen(m, "boss", back, 80, 6)))
		"boss":
			var ch: Dictionary = D.chapters[int(G.run["chapter"])]
			var bid2: String = ch["boss"]
			Screens.confirm(m, "挑战首领？", "前方就是本章的首领。\n确定准备好了吗？", "挑战", "再看看", func(yes):
				if not yes:
					cancel.call()
					return
				m.fade_to(func():
					m.set_scene(StoryBG.make(ch.get("biome2", zdef["biome"])))
					Dialog.play(m, "ch%d_boss" % int(G.run["chapter"]), func():
						enter_room(m, {"type": "boss", "boss": bid2, "biome": ch.get("biome2", zdef["biome"])}, func(res):
							if res == "win":
								if bid2 == "yunshan":
									G.unlock_ach("ach_yunshan")
								chapter_clear(m)
							else:
								dead(m)))))
		_:
			cancel.call()

static func _zone_done(id:String) -> void:
	var z: Dictionary = G.run["zone"]
	if not (id in z["done"]):
		z["done"].append(id)
	z.erase("pos_override")
	G.save_run()

static func _cave_room(m, po:Dictionary, i:int) -> void:
	var d: Dictionary = po["def"]
	var rooms: Array = d["rooms"]
	if i >= rooms.size():
		_cave_end(m, po)
		return
	var rm: Dictionary = rooms[i]
	var zdef: Dictionary = WD.zones[G.run["zone"]["id"]]
	G.run["floor"] = int(G.run["zone"]["i"]) * 3 + i + 2
	enter_room(m, {"type": rm["type"], "boss": rm.get("boss", ""), "biome": d.get("biome", zdef["biome"])}, func(res):
		if res != "win":
			dead(m)
			return
		var nxt := func(): _cave_room(m, po, i + 1)
		if rm["type"] == "elite":
			reward_screen(m, "boss", nxt, 60, 6)
		else:
			reward_screen(m, "any", nxt, 0, 5))

static func _cave_end(m, po:Dictionary) -> void:
	_zone_done(po["id"])
	var back := func(): enter_zone(m)
	var e: String = po["def"].get("end", "")
	if e.begins_with("canon:"):
		var cid := e.substr(6)
		if G.run["char"] == "xiaoyan" and not G.has_skill(cid):
			m.set_scene(StoryBG.make(WD.zones[G.run["zone"]["id"]]["biome"]))
			learn_canon(m, cid, back)
		else:
			reward_screen(m, "boss", back, 60, 6)
	elif e.begins_with("fire:"):
		var fid := e.substr(5)
		enter_room(m, {"type": "boss", "boss": "fire_spirit", "biome": "lava"}, func(res):
			if res != "win":
				dead(m)
				return
			Dialog.play(m, "ch2_fire", func():
				devour_fire(m, fid, func():
					if G.run["char"] == "xiaoyan" and not G.has_skill("ult_lotus"):
						learn_canon(m, "ult_lotus", back)
					else:
						reward_screen(m, "boss", back, 80, 6))))
	else:
		reward_screen(m, "boss", back, 60, 6)

## 原著斗技：播放剧情并获得
static func learn_canon(m, cid:String, done:Callable) -> void:
	var cd: Dictionary = WD.canon[cid]
	Dialog.play(m, cd.get("story", ""), func():
		G.learn_canon(cid)
		m.toast("习得原著斗技", D.skills[cid]["n"], Color(1, 0.8, 0.35))
		Au.sfx("breakthrough", -6)
		G.save_run()
		done.call())

static func enter_room(m, cfg:Dictionary, cb:Callable) -> void:
	var b := Battle.new()
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	b.setup(m, cfg)
	m.set_scene(b)
	Au.clear_stack()
	match cfg["type"]:
		"boss":
			pass  # Battle._start_room 按 Boss 播放专属战曲
		"elite", "trial":
			var bid: String = cfg.get("boss", "")
			Au.music(Au.boss_ctx(bid) if Au.LISTS.has("boss_" + bid) else "elite")
		_:
			if int(G.run.get("chapter", 1)) == 0:
				Au.music("theme_yandi")
			else:
				Au.music(Au.battle_ctx(cfg.get("biome", "")))
	b.finished.connect(func(res):
		if is_instance_valid(b.player) and not b.player.dead:
			G.run["hp"] = b.player.hp
		cb.call(res), CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- 奖励
static func reward_screen(m, kind:String, done:Callable, gold:int=0, n:int=5) -> void:
	var r: Dictionary = G.run
	if gold > 0:
		r["gold"] = int(r["gold"]) + int(gold * D.DIFFS[int(r["diff"])]["rew"])
	match kind:
		"gold":
			var gg := randi_range(60, 110) + int(r["floor"]) * 6
			r["gold"] = int(r["gold"]) + gg
			m.toast("获得金币", "+%d 金币" % gg, Color(1, 0.85, 0.3))
			done.call()
			return
		"herb":
			var hk: Array = D.herbs.keys()
			var txt := ""
			for i in 3:
				var h: String = hk[randi() % hk.size()]
				r["herbs"][h] = int(r["herbs"].get(h, 0)) + 1
				txt += D.herbs[h]["n"] + " "
			m.toast("获得药材", txt, Color(0.5, 1, 0.5))
			done.call()
			return
	var opts := Rewards.options(n, kind if kind in ["art", "relic", "upgrade", "ult", "move", "gong", "boss"] else "any")
	Screens.choose_reward(m, opts, "选择你的机缘", done)

# ---------------------------------------------------------------- 吞噬异火
static func devour_fire(m, fid:String, done:Callable) -> void:
	var r: Dictionary = G.run
	if r["fires"].size() >= G.fire_slots():
		Screens.fire_replace(m, fid, func(ok):
			if ok:
				_devour_game(m, fid, done)
			else:
				done.call())
	else:
		_devour_game(m, fid, done)

static func _devour_game(m, fid:String, done:Callable) -> void:
	var diff := clampf(1.0 - float(D.fire_by_id[fid]["rank"]) / 25.0, 0.1, 1.0)
	FireGame.start(m, fid, diff, func(success:bool):
		var r: Dictionary = G.run
		if success:
			var existing: Array = r["fires"].duplicate()
			G.add_fire(fid)
			for e in existing:
				var key := D.fire_pair_key(e, fid)
				if not (key in r["fused_pairs"]):
					r["fused_pairs"].append(key)
			var f: Dictionary = D.fire_by_id[fid]
			var extra := ""
			for e in existing:
				var k2 := D.fire_pair_key(e, fid)
				if D.fire_pair_bonus.has(k2):
					extra += "\n异火融合·" + D.fire_pair_bonus[k2]["n"] + "：" + D.fire_pair_bonus[k2]["d"]
			G.meta["fire_seed"] = int(G.meta["fire_seed"]) + 1
			Screens.info(m, "吞噬成功：" + f["n"], "异火榜第%d · %s%s\n\n佛怒火莲增添一色！" % [f["rank"], f["d"], extra], f["c"], done)
		else:
			var dmg := 0.3 * (0.5 if r["flags"].get("humai", false) else 1.0) * (2.0 if "cursed" in r["tianjie"] else 1.0)
			G.hurt_run(dmg)
			Screens.info(m, "吞噬失败", "异火反噬，经脉受创！\n生命减少%d%%。" % int(dmg * 100), Color(1, 0.3, 0.3), done))

# ---------------------------------------------------------------- 章节推进 / 结算
static func chapter_clear(m) -> void:
	var r: Dictionary = G.run
	var c: int = int(r["chapter"])
	var first: bool = not (c in G.meta["chapters_cleared"])
	if first:
		G.meta["chapters_cleared"].append(c)
	r["crystal_earned"] = int(r.get("crystal_earned", 0)) + 80 * c
	G.unlock_ach("ach_ch%d" % c)
	Au.clear_stack()
	Au.music("clear")
	if r["tianjie"].size() >= 5:
		G.unlock_ach("ach_tianjie5")
	Dialog.play(m, "ch%d_end" % c, func():
		if c == 1:
			G.unlock_char("xuner")
		if c == 2:
			G.unlock_char("yunyun")
			if G.meta["prologue_done"]:
				G.unlock_ach("ach_yandi")
		G.save_meta()
		if c + 1 < D.chapters.size() and r["mode"] == "story":
			Screens.confirm(m, "第%d章 通关！" % c, "继续前往 %s·%s（保留当前构筑与境界）？\n或者返回基地结算。" % [D.chapters[c + 1]["n"], D.chapters[c + 1]["t"]], "继续征途", "返回结算", func(yes):
				if yes:
					r["chapter"] = c + 1
					r["floor"] = 0
					r["hp"] = -1
					var nc: Dictionary = D.chapters[c + 1]
					r["realm"] = max(int(r["realm"]), int(nc["start_realm"]))
					start_chapter(m, c + 1)
				else:
					results(m, true))
		else:
			results(m, true))

static func dead(m) -> void:
	G.meta["deaths"] = int(G.meta["deaths"]) + 1
	G.unlock_ach("ach_first_death")
	results(m, false)

static func results(m, win:bool) -> void:
	var r: Dictionary = G.run
	var tj := 0
	for t in r["tianjie"]:
		for d in D.TIANJIE:
			if d["id"] == t:
				tj += int(d["pt"])
	var mult: float = D.DIFFS[int(r["diff"])]["rew"] * (1.0 + tj * 0.15)
	var crystal := int((int(r["floor"]) * 6 + int(r["kills"]) / 4 + int(r.get("crystal_earned", 0)) + int(G.rpow() * 3)) * mult)
	if r["mode"] == "endless":
		crystal += int(r.get("endless_wave", 0)) * 8
	var contrib := int(r["floor"]) * 3 + (30 if win else 0)
	var mohe: int = int(r["herbs"].get("mohe", 0)) + int(r["kills"]) / 60
	G.meta["crystal"] = int(G.meta["crystal"]) + crystal
	G.meta["contrib"] = int(G.meta["contrib"]) + contrib
	G.meta["mohe"] = int(G.meta["mohe"]) + mohe
	for h in r["herbs"]:
		if h != "mohe":
			G.meta["herbs"][h] = int(G.meta["herbs"].get(h, 0)) + int(r["herbs"][h])
	G.meta["runs"] = int(G.meta["runs"]) + 1
	G.meta["last_char"] = r["char"]
	G.save_meta()
	var summary := {"win": win, "crystal": crystal, "contrib": contrib, "mohe": mohe, "tj": tj}
	G.clear_run()
	Screens.results(m, summary, r)
