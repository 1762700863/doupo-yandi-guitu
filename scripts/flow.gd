class_name Flow
extends RefCounted
## 局流程：地图生成、节点进入、奖励、坊市、拍卖、奇遇、修炼、吞火、渡劫、章节推进、结算

const NODE_INFO := {
	"fight": {"n": "战斗", "c": Color(0.9, 0.85, 0.75), "icon": "剑"},
	"elite": {"n": "精英", "c": Color(1, 0.45, 0.3), "icon": "煞"},
	"boss": {"n": "首领", "c": Color(1, 0.2, 0.2), "icon": "王"},
	"midboss": {"n": "强敌", "c": Color(1, 0.3, 0.5), "icon": "凶"},
	"shop": {"n": "坊市", "c": Color(1, 0.85, 0.3), "icon": "市"},
	"event": {"n": "奇遇", "c": Color(0.6, 0.8, 1), "icon": "？"},
	"alchemy": {"n": "炼药房", "c": Color(0.5, 1, 0.6), "icon": "丹"},
	"rest": {"n": "修炼", "c": Color(0.7, 0.9, 1), "icon": "修"},
	"auction": {"n": "拍卖会", "c": Color(1, 0.7, 0.9), "icon": "拍"},
	"fire": {"n": "异火", "c": Color(1, 0.55, 0.2), "icon": "火"},
	"firebeast": {"n": "异火守护", "c": Color(0.2, 1, 0.7), "icon": "莲"},
	"story": {"n": "剧情", "c": Color(1, 1, 1), "icon": "卷"},
}
const DOOR_REWARDS := {
	"art": {"n": "斗技", "c": Color(1, 0.6, 0.3)}, "relic": {"n": "法宝", "c": Color(0.8, 0.7, 1)},
	"upgrade": {"n": "升阶", "c": Color(0.5, 0.9, 1)}, "gold": {"n": "金币", "c": Color(1, 0.85, 0.3)},
	"herb": {"n": "药材", "c": Color(0.5, 1, 0.5)}, "ult": {"n": "大招", "c": Color(1, 0.3, 0.3)},
	"move": {"n": "身法", "c": Color(0.7, 1, 0.9)}, "gong": {"n": "功法", "c": Color(1, 0.9, 0.6)},
}

# ---------------------------------------------------------------- 地图生成
static func gen_map() -> void:
	var r: Dictionary = G.run
	var ch: Dictionary = D.chapters[int(r["chapter"])]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r["seed"]) + int(r["chapter"]) * 1000
	var floors: int = int(ch.get("floors", 10))
	var m := {"type": ch["map"], "floors": [], "pos": [-1, -1]}
	if ch["map"] == "branch":
		for f in floors:
			var row := []
			var n := rng.randi_range(2, 4)
			if f == 0 or f == floors - 1 or f == 5:
				n = 1
			for i in n:
				var t := _roll_type(rng, f, floors)
				if f == 0: t = "fight"
				if f == 5: t = "midboss"
				if f == floors - 1: t = "boss"
				if f == floors - 2: t = "rest" if i == 0 else ("shop" if i == 1 else t)
				row.append({"t": t, "links": [], "x": 0.0})
			m["floors"].append(row)
		# 保证第一章有小医仙奇遇
		if int(r["chapter"]) == 1 and not G.is_char_unlocked("xiaoyixian"):
			m["floors"][3][0]["t"] = "event"
			m["floors"][3][0]["ev"] = "yixian"
		# 连线
		for f in floors - 1:
			var a: Array = m["floors"][f]
			var b: Array = m["floors"][f + 1]
			for i in a.size():
				var j := int(round(float(i) / max(1, a.size() - 1) * (b.size() - 1))) if a.size() > 1 else rng.randi_range(0, b.size() - 1)
				a[i]["links"].append(j)
				if rng.randf() < 0.4 and b.size() > 1:
					var j2 := clampi(j + (1 if rng.randf() < 0.5 else -1), 0, b.size() - 1)
					if not (j2 in a[i]["links"]):
						a[i]["links"].append(j2)
			for j in b.size():
				var has := false
				for i in a.size():
					if j in a[i]["links"]:
						has = true
				if not has:
					a[rng.randi_range(0, a.size() - 1)]["links"].append(j)
	else:
		m["rooms"] = floors
	r["map"] = m
	r["floor"] = 0

static func _roll_type(rng:RandomNumberGenerator, f:int, floors:int) -> String:
	var w := {"fight": 44, "elite": 10 if f >= 2 else 0, "shop": 10, "event": 16, "alchemy": 8, "rest": 5, "auction": 4 if f >= 3 else 0, "fire": 4 if f >= 3 else 0}
	var tot := 0
	for k in w: tot += w[k]
	var x := rng.randi() % tot
	for k in w:
		x -= w[k]
		if x < 0:
			return k
	return "fight"

static func _door_options() -> Array:
	var r: Dictionary = G.run
	var ch: Dictionary = D.chapters[int(r["chapter"])]
	var f: int = int(r["floor"])
	var total: int = int(ch.get("floors", 12))
	# 固定剧情房间
	if int(r["chapter"]) == 2:
		if f == 4: return [{"t": "midboss", "boss": "medusa"}]
		if f == 7: return [{"t": "firebeast", "boss": "fire_spirit"}]
		if f == 10: return [{"t": "elite", "boss": "nalan", "story": "ch2_nalan"}]
		if f == total - 1: return [{"t": "boss"}]
		if f == 2 and not G.is_char_unlocked("yunyun"):
			return [{"t": "event", "ev": "yunyun_meet"}, {"t": "fight", "rw": "art"}]
	var opts := []
	var n := 2 + (1 if randf() < 0.5 else 0)
	var types := ["fight", "fight", "fight", "fight", "elite", "shop", "event", "event", "alchemy", "rest", "auction", "fire"]
	for i in n:
		var t: String = types[randi() % types.size()]
		if t == "elite" and f < 2:
			t = "fight"
		var o := {"t": t}
		if t in ["fight", "elite"]:
			var rws := ["art", "art", "art", "relic", "relic", "upgrade", "upgrade", "gold", "herb", "move", "gong"]
			if t == "elite" or randf() < 0.08:
				rws.append("ult")
			o["rw"] = rws[randi() % rws.size()]
		opts.append(o)
	return opts

# ---------------------------------------------------------------- 地图界面
static func show_map(m) -> void:
	var r: Dictionary = G.run
	if r.get("map", {}).is_empty():
		gen_map()
	G.save_run()
	# 渡劫
	if r["flags"].get("trib_pending", false):
		r["flags"]["trib_pending"] = false
		r["flags"]["trib_done"] = true
		Dialog.lines(m, [["yaolao", "药老", "小家伙，你已触及斗王门槛……心魔劫来了！守住本心！"]], func():
			enter_room(m, {"type": "boss", "boss": "heart_demon", "biome": "void"}, func(res):
				if res == "win":
					m.toast("渡劫成功", "斗气化翼！身法强化为「斗气化翼」", Color(1, 0.75, 0.3))
					if r["move"] == "mv_roll":
						r["move"] = "mv_douqiwing"
					reward_screen(m, "boss", func(): show_map(m))
				else:
					dead(m)))
		return
	var ch: Dictionary = D.chapters[int(r["chapter"])]
	var sc := MapScene.new()
	m.set_scene(sc)
	Au.music(ch.get("music", "battle1") if int(r["floor"]) > 0 else "calm")
	sc.build(m)

static func node_selected(m, node:Dictionary) -> void:
	var r: Dictionary = G.run
	var ch: Dictionary = D.chapters[int(r["chapter"])]
	var t: String = node["t"]
	var biome: String = ch["biome"]
	if ch.has("biome2") and int(r["floor"]) >= int(ch.get("floors", 10)) / 2:
		biome = ch["biome2"]
	var after := func(): advance(m)
	match t:
		"fight":
			enter_room(m, {"type": "fight", "biome": biome}, func(res):
				if res == "win":
					reward_screen(m, node.get("rw", "any"), after)
				else:
					dead(m))
		"elite":
			var boss: String = node.get("boss", ch["elites"][randi() % ch["elites"].size()])
			var go := func():
				enter_room(m, {"type": "elite", "boss": boss, "biome": biome}, func(res):
					if res == "win":
						if boss == "nalan":
							G.run["flags"]["nalan_done"] = true
						reward_screen(m, "boss", after, 60)
					else:
						dead(m))
			if node.has("story"):
				Dialog.play(m, node["story"], go)
			else:
				go.call()
		"midboss":
			var mb: String = node.get("boss", ch.get("boss2", ch.get("mid", "wolfking")))
			var story := "ch2_medusa" if mb == "medusa" else ""
			var go2 := func():
				enter_room(m, {"type": "boss", "boss": mb, "biome": "desert" if mb == "medusa" else "forest"}, func(res):
					if res == "win":
						if mb == "medusa":
							G.unlock_ach("ach_medusa")
							Dialog.play(m, "ch2_medusa_win", func():
								G.unlock_char("medusa")
								reward_screen(m, "boss", after, 120))
						else:
							reward_screen(m, "boss", after, 100)
					else:
						dead(m))
			if story != "":
				Dialog.play(m, story, go2)
			else:
				go2.call()
		"firebeast":
			enter_room(m, {"type": "boss", "boss": node.get("boss", "fire_spirit"), "biome": "lava"}, func(res):
				if res == "win":
					Dialog.play(m, "ch2_fire", func():
						devour_fire(m, "qldx", func(): reward_screen(m, "boss", after, 80)))
				else:
					dead(m))
		"boss":
			var bid: String = ch["boss"]
			var st := "ch%d_boss" % int(r["chapter"])
			Dialog.play(m, st, func():
				enter_room(m, {"type": "boss", "boss": bid, "biome": ch.get("biome2", biome)}, func(res):
					if res == "win":
						if bid == "yunshan":
							G.unlock_ach("ach_yunshan")
						chapter_clear(m)
					else:
						dead(m)))
		"shop":
			Screens.shop(m, after)
		"event":
			Screens.event(m, node.get("ev", ""), after)
		"alchemy":
			Screens.alchemy_select(m, true, after)
		"rest":
			Screens.rest(m, after)
		"auction":
			Screens.auction(m, after)
		"fire":
			var cands := Rewards.fire_candidates()
			if cands.is_empty():
				m.toast("异火已散", "此处的异火气息已经消失", Color(0.7, 0.7, 0.7))
				reward_screen(m, "any", after)
			else:
				var fid: String = cands[randi() % cands.size()]
				Screens.fire_intro(m, fid, func(): devour_fire(m, fid, after), after)
		_:
			after.call()

static func advance(m) -> void:
	var r: Dictionary = G.run
	r["floor"] = int(r["floor"]) + 1
	G.save_run()
	show_map(m)

static func enter_room(m, cfg:Dictionary, cb:Callable) -> void:
	var b := Battle.new()
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	b.setup(m, cfg)
	m.set_scene(b)
	if cfg["type"] != "boss":
		var ch: Dictionary = D.chapters[int(G.run["chapter"])]
		Au.music(ch.get("music", "battle1"))
	b.finished.connect(func(res):
		if is_instance_valid(b.player) and not b.player.dead:
			G.run["hp"] = b.player.hp
		cb.call(res), CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- 奖励
static func reward_screen(m, kind:String, done:Callable, gold:int=0) -> void:
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
	var n := 3
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
					r["map"] = {}
					r["floor"] = 0
					r["hp"] = -1
					var nc: Dictionary = D.chapters[c + 1]
					r["realm"] = max(int(r["realm"]), int(nc["start_realm"]) * 3)
					Dialog.play(m, "ch%d_start" % (c + 1), func(): show_map(m))
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
	var crystal := int((int(r["floor"]) * 6 + int(r["kills"]) / 4 + int(r.get("crystal_earned", 0)) + int(r["realm"]) * 3) * mult)
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
