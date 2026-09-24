class_name Screens
extends RefCounted
## 所有覆盖式界面

static func _bg(m, a:float=0.7) -> Control:
	var root: Control = m.ui_root()
	var d := UI.dim(root, a)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return root

static func _close(root:Control, cb:Callable) -> void:
	root.queue_free()
	cb.call()

# ---------------------------------------------------------------- 信息框 / 确认框
static func info(m, title:String, body:String, col:Color, done:Callable) -> void:
	var root := _bg(m)
	var p := UI.panel(root, Rect2(230, 140, 500, 260), Color(-1, 0, 0), col)
	UI.label(p, title, Vector2(0, 16), 24, col, 500, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, body, Vector2(30, 64), 12, Color(0.95, 0.92, 0.85), 440)
	var b := UI.button(p, "继续", Rect2(190, 210, 120, 30), func(): _close(root, done), col, 12)
	b.grab_focus()

static func confirm(m, title:String, body:String, yes:String, no:String, cb:Callable, focus_no:bool=false) -> void:
	var root := _bg(m)
	var p := UI.panel(root, Rect2(230, 150, 500, 240))
	UI.label(p, title, Vector2(0, 16), 24, UI.theme_cols()["accent"], 500, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, body, Vector2(30, 64), 12, Color(0.95, 0.92, 0.85), 440)
	var b := UI.button(p, yes, Rect2(90, 190, 140, 30), func(): _close(root, func(): cb.call(true)), Color(1, 0.7, 0.3))
	var nb := UI.button(p, no, Rect2(270, 190, 140, 30), func(): _close(root, func(): cb.call(false)))
	(nb if focus_no else b).grab_focus()

# ---------------------------------------------------------------- 奖励三选一
static func choose_reward(m, opts:Array, title:String, done:Callable) -> void:
	var root := _bg(m, 0.75)
	UI.label(root, title + ("  ·  %s选一" % ["", "一", "二", "三", "四", "五", "六"][clampi(opts.size(), 0, 6)] if opts.size() > 1 else ""), Vector2(0, 40), 24, UI.theme_cols()["accent"], 960, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(root, "斗技槽 %d/%d  ·  大招槽 %d  ·  %s" % [G.run["arts"].size(), G.art_slots(), G.ult_slots(), D.realm_name(int(G.run["realm"]))], Vector2(0, 72), 12, Color(0.8, 0.8, 0.8), 960, HORIZONTAL_ALIGNMENT_CENTER)
	var w := 240.0
	var gap := 20.0
	match opts.size():
		4: w = 204.0; gap = 16.0
		5: w = 172.0; gap = 12.0
		6: w = 147.0; gap = 8.0
	var x0 := 480 - (opts.size() * w + (opts.size() - 1) * gap) * 0.5
	var first: Button = null
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var dsc := Rewards.describe(opt)
		var btn := UI.card(root, Rect2(x0 + i * (w + gap), 100, w, 320), dsc["title"], dsc["sub"], dsc["desc"], dsc["col"], func():
			var res := Rewards.apply(opt)
			if res == "need_replace":
				root.queue_free()
				replace_skill(m, opt, done)
			else:
				root.queue_free()
				if res.begins_with("fused:"):
					var fid := res.substr(6)
					info(m, "斗技融合！", "获得融合斗技【%s】\n%s" % [D.skills[fid]["n"], D.skills[fid]["d"]], Color(1, 0.6, 0.2), done)
				else:
					done.call(), dsc["elem"], dsc["badge"])
		if first == null:
			first = btn
		# 入场动画
		btn.modulate.a = 0
		btn.position.y += 30
		var tw := btn.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(btn, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(btn, "position:y", btn.position.y - 30, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var yb := 440.0
	if int(G.run.get("rerolls", 0)) > 0:
		UI.button(root, "天机重随（剩余%d）" % int(G.run["rerolls"]), Rect2(340, yb, 140, 28), func():
			G.run["rerolls"] = int(G.run["rerolls"]) - 1
			root.queue_free()
			choose_reward(m, Rewards.options(opts.size(), "any"), title, done), Color(0.6, 0.8, 1))
	UI.button(root, "放弃（+30金币）", Rect2(490, yb, 130, 28), func():
		G.run["gold"] = int(G.run["gold"]) + 30
		_close(root, done), Color(0.6, 0.6, 0.6))
	if first:
		first.grab_focus()
	Au.sfx("pickup", -4)

static func replace_skill(m, opt:Dictionary, done:Callable) -> void:
	var root := _bg(m, 0.8)
	var s: Dictionary = D.skills[opt["id"]]
	var is_ult: bool = s["cat"] == "ult"
	UI.label(root, "槽位已满：选择要替换的%s" % ("大招" if is_ult else "斗技"), Vector2(0, 40), 24, Color(1, 0.8, 0.4), 960, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(root, "新获得：%s（%s）" % [s["n"], D.GRADE_NAMES[opt["grade"]]], Vector2(0, 74), 12, D.grade_color(opt["grade"]), 960, HORIZONTAL_ALIGNMENT_CENTER)
	var list: Array = G.run["ults"] if is_ult else G.run["arts"]
	var cols := 3
	for i in list.size():
		var id: String = list[i]
		var g: int = int(G.run["skill_grades"].get(id, 0))
		var x := 120 + (i % cols) * 250
		var y := 110 + (i / cols) * 130
		var aff := ""
		for a in G.run["skill_affix"].get(id, []):
			aff += Rewards.affix_name(a) + " "
		var idx := i
		UI.button(root, "%s\n%s\n%s" % [D.skills[id]["n"], D.GRADE_NAMES[g], aff], Rect2(x, y, 230, 110), func():
			Rewards.apply(opt, idx)
			_close(root, done), D.grade_color(g))
	UI.button(root, "不要了（+30金币）", Rect2(410, 480, 140, 30), func():
		G.run["gold"] = int(G.run["gold"]) + 30
		_close(root, done))

# ---------------------------------------------------------------- 坊市
static func shop(m, done:Callable) -> void:
	var root := _bg(m, 0.8)
	var p := UI.panel(root, Rect2(60, 30, 840, 480))
	UI.label(p, "坊 市", Vector2(0, 10), 24, Color(1, 0.85, 0.3), 840, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, "“客官里边请，魔核、斗技、丹药，应有尽有！”", Vector2(0, 40), 12, Color(0.8, 0.8, 0.7), 840, HORIZONTAL_ALIGNMENT_CENTER)
	var gold_l := UI.label(p, "", Vector2(20, 12), 16, Color(1, 0.85, 0.3))
	var price_mult := 1.5 if "price" in G.run["tianjie"] else 1.0
	var items := []
	for o in Rewards.options(3, "art"):
		items.append(o)
	for o in Rewards.options(2, "relic"):
		items.append(o)
	var up := Rewards.options(1, "upgrade")
	if up.size() > 0:
		items.append(up[0])
	var pill_ids: Array = G.meta["known_pills"].duplicate()
	pill_ids.shuffle()
	var refresh := func(): gold_l.text = "金币 %d" % int(G.run["gold"])
	refresh.call()
	for i in items.size():
		var opt: Dictionary = items[i]
		var dsc := Rewards.describe(opt)
		var price := int((60 + (opt.get("grade", 1)) * 28) * price_mult)
		if opt["type"] == "upgrade":
			price = int(90 * price_mult)
		var x := 20 + (i % 3) * 270
		var y := 70 + (i / 3) * 150
		var bref := [null]
		bref[0] = UI.button(p, "", Rect2(x, y, 260, 140), func():
			if int(G.run["gold"]) < price:
				Au.sfx("fail")
				return
			var res := Rewards.apply(opt)
			if res == "need_replace":
				G.run["gold"] = int(G.run["gold"]) - price
				root.visible = false
				replace_skill(m, opt, func(): root.visible = true; refresh.call())
				bref[0].disabled = true
				return
			G.run["gold"] = int(G.run["gold"]) - price
			bref[0].disabled = true
			Au.sfx("coin")
			if res.begins_with("fused:"):
				m.toast("斗技融合！", D.skills[res.substr(6)]["n"], Color(1, 0.6, 0.2))
			refresh.call(), dsc["col"])
		UI.label(bref[0], dsc["title"], Vector2(8, 6), 16, dsc["col"].lightened(0.3))
		UI.label(bref[0], dsc["sub"], Vector2(8, 26), 8, dsc["col"])
		UI.label(bref[0], dsc["desc"], Vector2(8, 40), 8, Color(0.85, 0.85, 0.8), 244)
		UI.label(bref[0], "%d 金" % price, Vector2(190, 120), 12, Color(1, 0.85, 0.3))
	# 丹药
	for j in min(3, pill_ids.size()):
		var pid: String = pill_ids[j]
		var pd: Dictionary = D.pills[pid]
		var price2 := int((40 + pd["tier"] * 50) * price_mult)
		var bb := [null]
		bb[0] = UI.button(p, "%s  %d金\n%s" % [pd["n"], price2, pd["d"]], Rect2(20 + j * 200, 380, 190, 44), func():
			if int(G.run["gold"]) < price2 or G.run["pills"].size() >= int(G.run["pill_cap"]) + 3:
				Au.sfx("fail")
				return
			G.run["gold"] = int(G.run["gold"]) - price2
			G.run["pills"].append(pid)
			bb[0].disabled = true
			Au.sfx("coin")
			refresh.call(), pd["c"], 8)
	# 回复
	var healb := [null]
	healb[0] = UI.button(p, "疗伤（50金）\n回复40%生命", Rect2(620, 380, 190, 44), func():
		if int(G.run["gold"]) < int(50 * price_mult):
			return
		G.run["gold"] = int(G.run["gold"]) - int(50 * price_mult)
		G.heal_run(0.4)
		healb[0].disabled = true
		refresh.call(), Color(0.5, 1, 0.5), 8)
	UI.button(p, "离开", Rect2(360, 436, 120, 30), func(): _close(root, done)).grab_focus()

# ---------------------------------------------------------------- 拍卖会（竞价小游戏）
static func auction(m, done:Callable) -> void:
	var root := _bg(m, 0.85)
	var p := UI.panel(root, Rect2(130, 40, 700, 460), Color(0.12, 0.06, 0.08, 0.95), Color(1, 0.7, 0.9))
	UI.label(p, "米特尔拍卖场", Vector2(0, 10), 24, Color(1, 0.75, 0.9), 700, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, "雅妃：“接下来这件拍品，诸位可要看仔细了~”", Vector2(0, 42), 12, Color(0.9, 0.8, 0.85), 700, HORIZONTAL_ALIGNMENT_CENTER)
	var opts := Rewards.options(1, "boss")
	if opts.is_empty():
		opts = Rewards.options(1, "art")
	var opt: Dictionary = opts[0]
	if opt["type"] == "skill":
		opt["grade"] = mini(11, int(opt["grade"]) + 2)
	var dsc := Rewards.describe(opt)
	var ic := UI.SkillIcon.new()
	ic.elem = dsc["elem"]
	ic.col = dsc["col"]
	ic.position = Vector2(80, 90)
	ic.size = Vector2(80, 80)
	p.add_child(ic)
	UI.label(p, dsc["title"], Vector2(180, 90), 24, dsc["col"].lightened(0.3))
	UI.label(p, dsc["sub"], Vector2(180, 120), 12, dsc["col"])
	UI.label(p, dsc["desc"], Vector2(180, 140), 12, Color(0.9, 0.9, 0.85), 460)
	var state := {"price": 80 + int(opt.get("grade", 3)) * 20, "leader": "", "round": 0, "done": false}
	var rivals := ["慕兰三老", "加刑天", "法犸", "木辰", "纳兰桀"]
	var status := UI.label(p, "", Vector2(0, 300), 16, Color(1, 0.9, 0.5), 700, HORIZONTAL_ALIGNMENT_CENTER)
	var log_l := UI.label(p, "", Vector2(0, 330), 12, Color(0.85, 0.85, 0.85), 700, HORIZONTAL_ALIGNMENT_CENTER)
	var upd := func():
		status.text = "当前价格：%d 金   领先：%s   你的金币：%d" % [state["price"], state["leader"] if state["leader"] != "" else "无", int(G.run["gold"])]
	upd.call()
	var finish := func(win:bool):
		state["done"] = true
		if win:
			G.run["gold"] = int(G.run["gold"]) - int(state["price"])
			var res := Rewards.apply(opt)
			root.queue_free()
			if res == "need_replace":
				replace_skill(m, opt, done)
			else:
				info(m, "落槌！", "你以 %d 金币拍得【%s】！" % [state["price"], dsc["title"]], Color(1, 0.75, 0.9), done)
		else:
			root.queue_free()
			info(m, "拍卖结束", "%s 以 %d 金币拍走了宝物。" % [state["leader"], state["price"]], Color(0.8, 0.8, 0.8), done)
	var bid := func(inc:int):
		if state["done"]:
			return
		var np: int = int(state["price"]) + inc
		if np > int(G.run["gold"]):
			Au.sfx("fail")
			log_l.text = "金币不足！"
			return
		state["price"] = np
		state["leader"] = "你"
		state["round"] += 1
		Au.sfx("coin")
		# 对手反应
		var val: int = 120 + int(opt.get("grade", 3)) * 45 + randi() % 80
		if np < val and randf() < 0.75:
			var rv: String = rivals[randi() % rivals.size()]
			state["price"] = np + [10, 20, 50][randi() % 3]
			state["leader"] = rv
			log_l.text = "%s 出价 %d！" % [rv, state["price"]]
		else:
			log_l.text = "全场寂静……一次……两次……"
			p.get_tree().create_timer(1.0).timeout.connect(func():
				if not state["done"] and state["leader"] == "你":
					finish.call(true))
		upd.call()
	UI.button(p, "+10", Rect2(140, 380, 90, 30), func(): bid.call(10), Color(1, 0.8, 0.5))
	UI.button(p, "+30", Rect2(240, 380, 90, 30), func(): bid.call(30), Color(1, 0.7, 0.4))
	UI.button(p, "+100", Rect2(340, 380, 90, 30), func(): bid.call(100), Color(1, 0.5, 0.3))
	UI.button(p, "放弃", Rect2(470, 380, 90, 30), func():
		if state["leader"] == "你":
			finish.call(true)
		elif state["leader"] == "":
			_close(root, done)
		else:
			finish.call(false), Color(0.6, 0.6, 0.6))

# ---------------------------------------------------------------- 奇遇
static func event(m, forced:String, done:Callable) -> void:
	var ch: int = int(G.run["chapter"])
	var cands := []
	for e in D.events:
		if ch in e["ch"]:
			if e["id"] == "yixian" and G.is_char_unlocked("xiaoyixian"):
				continue
			if e["id"] == "yunyun_meet" and G.is_char_unlocked("yunyun"):
				continue
			if e["id"] == "ring" and "rl_ring" in G.run["relics"]:
				continue
			cands.append(e)
	var ev: Dictionary = cands[randi() % cands.size()]
	if forced != "":
		for e in D.events:
			if e["id"] == forced:
				ev = e
	var root := _bg(m, 0.8)
	var p := UI.panel(root, Rect2(180, 90, 600, 360))
	UI.label(p, "奇遇 · " + ev["t"], Vector2(0, 14), 24, Color(0.6, 0.85, 1), 600, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, ev["d"], Vector2(40, 64), 16, Color(0.95, 0.92, 0.85), 520)
	var y := 190.0
	for o in ev["opts"]:
		var act: String = o[1]
		UI.button(p, o[0], Rect2(100, y, 400, 34), func():
			root.queue_free()
			_event_act(m, act, done), Color(0.6, 0.85, 1))
		y += 44

static func _event_act(m, act:String, done:Callable) -> void:
	var r: Dictionary = G.run
	var parts := act.split(":")
	match parts[0]:
		"none":
			done.call()
		"gold":
			var g := int(parts[1])
			r["gold"] = max(0, int(r["gold"]) + g)
			m.toast("金币 %+d" % g, "", Color(1, 0.85, 0.3))
			done.call()
		"relic":
			G.add_skill(parts[1])
			info(m, "获得法宝", D.skills[parts[1]]["n"] + "：" + D.skills[parts[1]]["d"], Color(0.8, 0.7, 1), done)
		"art", "art_up":
			Flow.reward_screen(m, "art", done)
		"ice_art":
			choose_reward(m, [{"type": "skill", "id": "art_icebird", "grade": 6, "affix": ["chill"]}, {"type": "skill", "id": "art_bonechill", "grade": 5, "affix": []}], "冰皇的传承", done)
		"pill":
			var ks: Array = G.meta["known_pills"]
			var pid: String = ks[randi() % ks.size()]
			r["pills"].append(pid)
			info(m, "获得丹药", D.pills[pid]["n"] + "：" + D.pills[pid]["d"], D.pills[pid]["c"], done)
		"both":
			G.hurt_run(0.3)
			var ks2: Array = G.meta["known_pills"]
			r["pills"].append(ks2[randi() % ks2.size()])
			Flow.reward_screen(m, "art", done)
		"cub":
			var ok := false
			for h in r["herbs"]:
				if int(r["herbs"][h]) > 0:
					r["herbs"][h] = int(r["herbs"][h]) - 1
					ok = true
					break
			if ok:
				G.add_skill("rl_zijing")
				info(m, "紫晶翼狮王幼崽", "幼崽蹭了蹭你的手，留下一枚紫晶源后离去。\n获得法宝【紫晶源】", Color(0.8, 0.6, 1), done)
			else:
				info(m, "没有药材", "你身上没有药材……幼崽默默离开了。", Color(0.7, 0.7, 0.7), done)
		"herbs":
			var cost := int(parts[1])
			if int(r["gold"]) >= cost:
				r["gold"] = int(r["gold"]) - cost
				var hk: Array = D.herbs.keys()
				for i in 4:
					var h2: String = hk[randi() % hk.size()]
					r["herbs"][h2] = int(r["herbs"].get(h2, 0)) + 1
				if cost == 0:
					var unk := []
					for pid2 in D.pills:
						if not (pid2 in G.meta["known_pills"]):
							unk.append(pid2)
					if unk.size() > 0:
						var np: String = unk[randi() % unk.size()]
						G.meta["known_pills"].append(np)
						m.toast("习得丹方", D.pills[np]["n"], D.pills[np]["c"])
				info(m, "获得药材", "药材 x4 已放入纳戒。", Color(0.5, 1, 0.5), done)
			else:
				info(m, "金币不足", "对方冷哼一声，转身离去。", Color(0.7, 0.7, 0.7), done)
		"gamble":
			var cost2 := int(parts[1])
			if int(r["gold"]) < cost2:
				info(m, "金币不足", "摊主：“没钱赌什么石？”", Color(0.7, 0.7, 0.7), done)
				return
			r["gold"] = int(r["gold"]) - cost2
			var roll := randf() + (0.25 if cost2 >= 150 else 0.0)
			if roll > 1.05:
				var o := Rewards.options(1, "art")
				if o.size() > 0:
					o[0]["grade"] = 9
				G.unlock_ach("ach_gamble")
				Au.sfx("fire_get")
				choose_reward(m, o, "一刀富！开出天阶宝物！", done)
			elif roll > 0.6:
				Flow.reward_screen(m, "relic", done)
			elif roll > 0.35:
				var g2 := cost2 + randi() % cost2
				r["gold"] = int(r["gold"]) + g2
				info(m, "小赚一笔", "开出一块灵玉，转手卖了 %d 金。" % g2, Color(1, 0.85, 0.3), done)
			else:
				info(m, "一刀穷", "……里面是块普通的石头。", Color(0.6, 0.6, 0.6), done)
		"blood_relic":
			G.hurt_run(0.2)
			Flow.reward_screen(m, "relic", done)
		"xuner_gift":
			r["hp"] = -1
			G.meta["bond"]["xuner"] = int(G.meta["bond"].get("xuner", 0)) + 1
			G.save_meta()
			info(m, "薰儿的心意", "生命已回满。与薰儿的好感+1。", Color(1, 0.85, 0.4), done)
		"yixian":
			G.unlock_char("xiaoyixian")
			Dialog.lines(m, [["xiaoyixian", "小医仙", "你……不怕我吗？我碰过的草木都会枯萎。"], ["xiaoyan", "萧炎", "我叫萧炎。你的毒，也许有一天会是你最强的力量。"], ["xiaoyixian", "小医仙", "萧炎……我记住你了。（小医仙已解锁）"]], done)
		"yunyun":
			G.unlock_char("yunyun")
			Dialog.lines(m, [["yunyun", "云韵", "你身上的火焰……很特别。"], ["xiaoyan", "萧炎", "阁下是？"], ["yunyun", "云韵", "……一个过路人罢了。（云韵已解锁，通关本章可正式使用）"]], func():
				Flow.reward_screen(m, "art", done))
		"heal":
			G.heal_run(float(parts[1]))
			info(m, "休憩", "你在泉边休息，伤势恢复了许多。", Color(0.5, 1, 0.7), done)
		"storm":
			G.hurt_run(0.15)
			r["exp"] = float(r["exp"]) + G.exp_needed(int(r["realm"])) * 0.6
			info(m, "沙暴洗礼", "你在沙暴中磨砺斗气，斗气大增！", Color(1, 0.85, 0.5), done)
		"fire":
			var cands := Rewards.fire_candidates()
			if cands.is_empty():
				done.call()
			else:
				Flow.devour_fire(m, cands[randi() % cands.size()], done)
		"trial":
			var ch3: Dictionary = D.chapters[int(r["chapter"])]
			Flow.enter_room(m, {"type": "trial", "boss": ch3["elites"][randi() % ch3["elites"].size()], "biome": ch3["biome"]}, func(res):
				if res == "win":
					Flow.reward_screen(m, "boss", func(): Flow.reward_screen(m, "any", done), 50)
				else:
					Flow.dead(m))
		_:
			done.call()

# ---------------------------------------------------------------- 修炼
static func rest(m, done:Callable) -> void:
	var root := _bg(m, 0.8)
	var p := UI.panel(root, Rect2(230, 120, 500, 300))
	UI.label(p, "修 炼", Vector2(0, 14), 24, Color(0.7, 0.9, 1), 500, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, "找到一处灵气充沛的山洞。", Vector2(0, 50), 12, Color(0.85, 0.85, 0.85), 500, HORIZONTAL_ALIGNMENT_CENTER)
	UI.button(p, "打坐疗伤：回复50%生命", Rect2(100, 90, 300, 36), func():
		G.heal_run(0.5)
		_close(root, done), Color(0.5, 1, 0.6))
	UI.button(p, "闭关苦修：获得大量斗气", Rect2(100, 136, 300, 36), func():
		var r: Dictionary = G.run
		r["exp"] = float(r["exp"]) + G.exp_needed(int(r["realm"])) * 1.2
		while float(r["exp"]) >= G.exp_needed(int(r["realm"])) and int(r["realm"]) < G.realm_cap():
			r["exp"] = float(r["exp"]) - G.exp_needed(int(r["realm"]))
			r["realm"] = int(r["realm"]) + 1
		m.toast("修为精进", D.realm_name(int(r["realm"])), Color(0.7, 0.9, 1))
		_close(root, done), Color(0.7, 0.9, 1))
	UI.button(p, "参悟斗技：随机斗技升阶", Rect2(100, 182, 300, 36), func():
		var arts: Array = G.run["arts"]
		if arts.size() > 0:
			var a: String = arts[randi() % arts.size()]
			G.run["skill_grades"][a] = mini(11, int(G.run["skill_grades"].get(a, 0)) + 2)
			m.toast("参悟成功", D.skills[a]["n"] + " 提升两阶", Color(1, 0.8, 0.4))
		_close(root, done), Color(1, 0.8, 0.4))
	UI.button(p, "炼制丹药", Rect2(100, 228, 300, 36), func():
		root.queue_free()
		alchemy_select(m, true, done), Color(0.5, 1, 0.6))

# ---------------------------------------------------------------- 炼药
static func alchemy_select(m, in_run:bool, done:Callable) -> void:
	var root := _bg(m, 0.85)
	var p := UI.panel(root, Rect2(80, 40, 800, 460), Color(0.07, 0.1, 0.07, 0.95), Color(0.5, 1, 0.6))
	UI.label(p, "炼 药", Vector2(0, 10), 24, Color(0.6, 1, 0.7), 800, HORIZONTAL_ALIGNMENT_CENTER)
	var herbs: Dictionary = G.run["herbs"] if in_run else G.meta["herbs"]
	var htxt := "药材："
	for h in D.herbs:
		htxt += "%s×%d  " % [D.herbs[h]["n"], int(herbs.get(h, 0)) if h != "mohe" or in_run else int(G.meta["mohe"])]
	UI.label(p, htxt, Vector2(20, 44), 8, Color(0.85, 0.95, 0.85), 760)
	var i := 0
	for pid in G.meta["known_pills"]:
		var pd: Dictionary = D.pills[pid]
		var need := ""
		var ok := true
		for h in pd["herbs"]:
			var have: int = int(herbs.get(h, 0)) if (h != "mohe" or in_run) else int(G.meta["mohe"])
			need += "%s×%d " % [D.herbs[h]["n"], pd["herbs"][h]]
			if have < int(pd["herbs"][h]):
				ok = false
		var x := 20 + (i % 3) * 256
		var y := 70 + (i / 3) * 80
		var b := UI.button(p, "", Rect2(x, y, 246, 72), func():
			for h in pd["herbs"]:
				if h == "mohe" and not in_run:
					G.meta["mohe"] = int(G.meta["mohe"]) - int(pd["herbs"][h])
				else:
					herbs[h] = int(herbs[h]) - int(pd["herbs"][h])
			root.queue_free()
			AlchemyGame.start(m, pid, func(quality:int):
				_alchemy_done(m, pid, quality, in_run, done)), pd["c"])
		b.disabled = not ok
		UI.label(b, pd["n"] + "  [" + D.TIER_NAMES[pd["tier"]] + "]", Vector2(8, 4), 12, pd["c"])
		UI.label(b, pd["d"], Vector2(8, 22), 8, Color(0.9, 0.9, 0.85), 230)
		UI.label(b, need, Vector2(8, 54), 8, Color(0.6, 0.9, 0.6) if ok else Color(0.8, 0.4, 0.4))
		i += 1
	UI.button(p, "离开", Rect2(340, 416, 120, 30), func(): _close(root, done))

static func _alchemy_done(m, pid:String, q:int, in_run:bool, done:Callable) -> void:
	var qn = ["失败", "下品", "中品", "上品", "完美"][q]
	var n = [0, 1, 1, 2, 3][q]
	if q == 4:
		G.unlock_ach("ach_perfect_pill")
	if n == 0:
		info(m, "炼丹失败", "药液焦糊，化作一缕黑烟……\n药老：“火候！火候！”", Color(0.8, 0.4, 0.3), done)
		return
	for i in n:
		if in_run:
			G.run["pills"].append(pid)
		else:
			G.meta["pills"][pid] = int(G.meta["pills"].get(pid, 0)) + 1
	if not in_run:
		G.save_meta()
	info(m, "成丹！· " + qn, "%s ×%d\n%s" % [D.pills[pid]["n"], n, D.pills[pid]["d"]], D.pills[pid]["c"], done)

# ---------------------------------------------------------------- 异火
static func fire_intro(m, fid:String, yes:Callable, no:Callable) -> void:
	var f: Dictionary = D.fire_by_id[fid]
	var root := _bg(m, 0.85)
	var p := UI.panel(root, Rect2(200, 90, 560, 360), Color(0.1, 0.05, 0.03, 0.95), f["c"])
	var fl := FlameView.new()
	fl.col = f["c"]
	fl.position = Vector2(230, 40)
	fl.size = Vector2(100, 120)
	p.add_child(fl)
	UI.label(p, f["n"], Vector2(0, 170), 24, f["c"].lightened(0.2), 560, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, "异火榜 第%d位" % f["rank"], Vector2(0, 200), 12, f["c"], 560, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(p, f["d"], Vector2(40, 222), 12, Color(0.95, 0.9, 0.85), 480)
	UI.label(p, "吞噬需要承受异火反噬（小游戏），失败会损失生命。%s" % ("  已服护脉丹：反噬减半" if G.run["flags"].get("humai", false) else ""), Vector2(40, 270), 8, Color(1, 0.7, 0.5), 480)
	UI.button(p, "吞噬它！", Rect2(130, 310, 140, 32), func(): _close(root, yes), f["c"])
	UI.button(p, "放弃", Rect2(290, 310, 140, 32), func(): _close(root, no))

static func fire_replace(m, fid:String, cb:Callable) -> void:
	var root := _bg(m, 0.85)
	UI.label(root, "异火槽已满（%d）：放弃一种异火以容纳【%s】？" % [G.fire_slots(), D.fire_by_id[fid]["n"]], Vector2(0, 80), 16, Color(1, 0.7, 0.4), 960, HORIZONTAL_ALIGNMENT_CENTER)
	var fs: Array = G.run["fires"]
	for i in fs.size():
		var f: Dictionary = D.fire_by_id[fs[i]]
		var idx := i
		UI.button(root, f["n"] + "\n" + f["d"].substr(0, 20), Rect2(120 + (i % 3) * 250, 140 + (i / 3) * 90, 230, 76), func():
			var removed: String = fs[idx]
			fs.remove_at(idx)
			var pairs: Array = G.run["fused_pairs"]
			for pr in pairs.duplicate():
				if removed in pr:
					pairs.erase(pr)
			_close(root, func(): cb.call(true)), f["c"])
	UI.button(root, "不吞噬了", Rect2(410, 450, 140, 30), func(): _close(root, func(): cb.call(false)))

# ---------------------------------------------------------------- 结算
static func results(m, s:Dictionary, r:Dictionary) -> void:
	m.set_scene(Node2D.new())
	var root: Control = m.ui_root()
	UI.dim(root, 1.0)
	var win: bool = s["win"]
	Au.clear_stack()
	Au.music("victory" if win else "defeat")
	var col := Color(1, 0.8, 0.4) if win else Color(0.9, 0.35, 0.3)
	UI.label(root, "征途告捷" if win else "陨 落", Vector2(0, 40), 24, col, 960, HORIZONTAL_ALIGNMENT_CENTER)
	if not win:
		UI.label(root, D.DEATH_LINES[randi() % D.DEATH_LINES.size()], Vector2(0, 80), 16, Color(0.9, 0.85, 0.8), 960, HORIZONTAL_ALIGNMENT_CENTER)
	var por := G.portrait(D.chars[r["char"]]["spr"] + "_full")
	if por:
		UI.tex_rect(root, por, Rect2(90, 120, 200, 300))
	var t := int(r["time"])
	var lines := [
		"角色：%s" % D.chars[r["char"]]["n"],
		"章节：%s · 第 %d 层" % [D.chapters[int(r["chapter"])]["n"], int(r["floor"]) + 1],
		"境界：%s" % D.realm_name(int(r["realm"])),
		"用时：%02d:%02d    击杀：%d" % [t / 60, t % 60, int(r["kills"])],
		"异火：%s" % (", ".join(r["fires"].map(func(x): return D.fire_by_id[x]["n"])) if r["fires"].size() > 0 else "无"),
		"斗技：%s" % ", ".join(r["arts"].map(func(x): return D.skills[x]["n"])),
		"",
		"获得 斗气结晶 +%d" % s["crystal"],
		"获得 贡献点 +%d" % s["contrib"],
		"获得 魔核 +%d" % s["mohe"],
		"天劫加成：%d 点" % s["tj"],
	]
	var y := 130.0
	for l in lines:
		UI.label(root, l, Vector2(330, y), 12, Color(0.95, 0.92, 0.85) if not l.begins_with("获得") else Color(0.6, 0.9, 1), 560)
		y += 24
	UI.button(root, "返回基地", Rect2(420, 470, 140, 34), func(): m.fade_to(func(): m.hub()), col).grab_focus()

# ---------------------------------------------------------------- 暂停 / 功法面板
static func pause(m, panel_only:bool) -> Control:
	var root: Control = m.ui_root()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	UI.dim(root, 0.75)
	var r: Dictionary = G.run
	var p := UI.panel(root, Rect2(30, 20, 900, 500))
	UI.label(p, "功法面板", Vector2(16, 8), 24, UI.theme_cols()["accent"])
	UI.label(p, "%s · %s · %s" % [D.chars[r["char"]]["n"], D.realm_name(int(r["realm"])), D.chapters[int(r["chapter"])]["t"]], Vector2(200, 16), 12, Color(0.9, 0.9, 0.85))
	# 斗技列表 + 自动开关
	UI.label(p, "斗技（点击切换 手动/自动）", Vector2(16, 46), 12, Color(1, 0.8, 0.5))
	var y := 66.0
	var keys := ["Q", "E", "R", "F", "自", "自"]
	for i in r["arts"].size():
		var id: String = r["arts"][i]
		var g: int = int(r["skill_grades"].get(id, 0))
		var aff := ""
		for a in r["skill_affix"].get(id, []):
			aff += "◆" + Rewards.affix_name(a)
		var auto: bool = r["auto"].get(id, true)
		var btn := [null]
		var txt := func() -> String:
			return "[%s] %s  %s  %s  %s" % [keys[min(i, 5)], D.skills[id]["n"], D.GRADE_NAMES[g], "【自动】" if r["auto"].get(id, true) else "【手动】", aff]
		btn[0] = UI.button(p, txt.call(), Rect2(16, y, 430, 26), func():
			r["auto"][id] = not r["auto"].get(id, true)
			btn[0].text = txt.call(), D.grade_color(g), 8)
		btn[0].alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn[0].tooltip_text = D.skills[id]["d"]
		y += 30
	y += 6
	UI.label(p, "大招", Vector2(16, y), 12, Color(1, 0.5, 0.4))
	y += 20
	for i in r["ults"].size():
		var uid: String = r["ults"][i]
		var ub := [null]
		var ut := func() -> String:
			return "[%s] %s  %s" % [["C", "X"][min(i, 1)], D.skills[uid]["n"], "【自动】" if r["auto"].get(uid, false) else "【手动】"]
		ub[0] = UI.button(p, ut.call(), Rect2(16, y, 430, 26), func():
			r["auto"][uid] = not r["auto"].get(uid, false)
			ub[0].text = ut.call(), D.grade_color(int(r["skill_grades"].get(uid, 6))), 8)
		ub[0].alignment = HORIZONTAL_ALIGNMENT_LEFT
		y += 30
	# 右侧：功法/身法/异火/法宝/丹药
	var rx := 470.0
	var info_txt := "功法：%s — %s\n身法：%s — %s\n普攻：%s（%s）\n" % [D.skills[r["gong"]]["n"], D.skills[r["gong"]]["d"], D.skills[r["move"]]["n"], D.skills[r["move"]]["d"], D.skills[r["atk"]]["n"], D.GRADE_NAMES[int(r["atk_grade"])]]
	info_txt += "\n异火（%d/%d）：\n" % [r["fires"].size(), G.fire_slots()]
	for f in r["fires"]:
		info_txt += "  %s：%s\n" % [D.fire_by_id[f]["n"], D.fire_by_id[f]["d"]]
	for pr in r["fused_pairs"]:
		if D.fire_pair_bonus.has(pr):
			info_txt += "  ★%s：%s\n" % [D.fire_pair_bonus[pr]["n"], D.fire_pair_bonus[pr]["d"]]
	info_txt += "\n法宝：" + ("、".join(r["relics"].map(func(x): return D.skills[x]["n"])) if r["relics"].size() > 0 else "无")
	info_txt += "\n丹药：" + ("、".join(r["pills"].map(func(x): return D.pills[x]["n"])) if r["pills"].size() > 0 else "无")
	UI.label(p, info_txt, Vector2(rx, 46), 8, Color(0.9, 0.9, 0.85), 410)
	UI.button(p, "继续", Rect2(460, 450, 110, 30), func(): m.toggle_pause(), Color(1, 0.8, 0.4)).grab_focus()
	UI.button(p, "设置", Rect2(580, 450, 110, 30), func():
		root.visible = false
		settings(m, func(): root.visible = true))
	UI.button(p, "放弃本局", Rect2(700, 450, 110, 30), func():
		m.toggle_pause()
		Flow.dead(m), Color(0.8, 0.3, 0.3))
	UI.label(p, "按键：同伴指令 1跟随 2进攻 3守护 4集火 · T合击 · G丹药 · V角色特殊", Vector2(16, 480), 8, Color(0.7, 0.7, 0.7))
	return root

# ---------------------------------------------------------------- 设置
static func settings(m, back:Callable) -> void:
	var root: Control = m.ui_root()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	UI.dim(root, 0.85).mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(root, Rect2(80, 30, 800, 480))
	UI.label(p, "设 置", Vector2(0, 8), 24, UI.theme_cols()["accent"], 800, HORIZONTAL_ALIGNMENT_CENTER)
	var s: Dictionary = G.settings
	var y := 50.0
	for pair in [["vol_master", "总音量"], ["vol_music", "音乐"], ["vol_sfx", "音效"], ["vol_voice", "语音"], ["fx", "特效强度"]]:
		UI.label(p, pair[1], Vector2(30, y + 2), 12, Color(0.9, 0.9, 0.85))
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 1
		sl.step = 0.05
		sl.value = s[pair[0]]
		sl.position = Vector2(120, y + 2)
		sl.size = Vector2(200, 16)
		var key: String = pair[0]
		sl.value_changed.connect(func(v):
			s[key] = v
			G.apply_settings())
		p.add_child(sl)
		y += 30
	for pair in [["shake", "震屏"], ["hitstop", "顿帧"], ["dmgnum", "伤害数字"], ["fullscreen", "全屏 (F11)"]]:
		var cb := CheckButton.new()
		cb.text = pair[1]
		cb.button_pressed = s[pair[0]]
		cb.position = Vector2(30, y)
		cb.add_theme_font_override("font", G.font)
		cb.add_theme_font_size_override("font_size", 12)
		var key2: String = pair[0]
		cb.toggled.connect(func(v):
			s[key2] = v
			G.apply_settings())
		p.add_child(cb)
		y += 30
	UI.label(p, "帧率上限", Vector2(30, y + 4), 12, Color(0.9, 0.9, 0.85))
	var fx := 120.0
	for f in [60, 120, 144, 240]:
		var ff: int = f
		UI.button(p, str(f), Rect2(fx, y, 50, 24), func():
			s["fps"] = ff
			G.apply_settings(), Color(1, 0.8, 0.4) if int(s["fps"]) == f else Color(0.5, 0.5, 0.5), 8)
		fx += 56
	# 按键重绑
	UI.label(p, "按键绑定（点击后按下新按键）", Vector2(380, 50), 12, Color(1, 0.8, 0.5))
	var ky := 72.0
	var kx := 380.0
	var i := 0
	for a in G.ACTIONS:
		var act: String = a
		var bref := [null]
		bref[0] = UI.button(p, "%s：%s" % [G.ACTIONS[a][1], G.key_name(a)], Rect2(kx, ky, 190, 22), func():
			bref[0].text = "按下新按键……"
			var cap := KeyCapture.new()
			cap.cb = func(code:int):
				G.rebind(act, code)
				bref[0].text = "%s：%s" % [G.ACTIONS[act][1], G.key_name(act)]
			root.add_child(cap), Color(0.6, 0.6, 0.7), 8)
		ky += 24
		i += 1
		if i == 14:
			kx += 200
			ky = 72
	UI.button(p, "返回", Rect2(340, 436, 120, 30), func():
		G.save_meta()
		root.queue_free()
		back.call(), Color(1, 0.8, 0.4)).grab_focus()


class KeyCapture extends Node:
	var cb: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(e:InputEvent) -> void:
		if e is InputEventKey and e.pressed:
			get_viewport().set_input_as_handled()
			if e.keycode != KEY_ESCAPE:
				cb.call(e.physical_keycode if e.physical_keycode != 0 else e.keycode)
			queue_free()


class FlameView extends Control:
	var col := Color(1, 0.5, 0.2)
	var t := 0.0
	func _ready() -> void:
		material = Fx.additive()
	func _process(d:float) -> void:
		t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * Vector2(0.5, 0.85)
		for i in 26:
			var k := float(i) / 26
			var h := size.y * (0.9 - k * 0.6)
			var w := size.x * 0.45 * (1.0 - k * 0.7)
			var ph := t * (5 + k * 4) + i
			var pts := PackedVector2Array([c + Vector2(-w, 0), c + Vector2(sin(ph) * w * 0.4, -h), c + Vector2(w, 0)])
			var cc := col.lerp(Color(1, 1, 0.85), k)
			cc.a = 0.12 + k * 0.1
			draw_colored_polygon(pts, cc)
		draw_circle(c + Vector2(0, -size.y * 0.25), size.x * 0.12, Color(1, 1, 0.9, 0.6))
