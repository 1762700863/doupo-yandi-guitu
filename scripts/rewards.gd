class_name Rewards
extends RefCounted
## 奖励生成：斗技/大招/身法/功法/法宝/升阶/异火，含品阶、词条、融合检测

static func roll_affixes(n:int) -> Array:
	var out := []
	var pool := D.AFFIXES.duplicate()
	for i in n:
		var tot := 0
		for a in pool:
			tot += a["w"]
		var r = randi() % max(1, tot)
		for a in pool:
			r -= a["w"]
			if r < 0:
				out.append(a["id"])
				pool.erase(a)
				break
	return out

static func affix_name(id:String) -> String:
	for a in D.AFFIXES:
		if a["id"] == id:
			return a["n"]
	return id

static func affix_desc(id:String) -> String:
	for a in D.AFFIXES:
		if a["id"] == id:
			return a["d"]
	return ""

static func _roll_grade(base_tier:int, luck:float) -> int:
	var ch: int = int(G.run.get("chapter", 1))
	var fl: int = int(G.run.get("floor", 0))
	var g := base_tier * 3
	var up := randf()
	var bonus := luck + ch * 0.05 + fl * 0.01
	if up < 0.25 + bonus:
		g += 1
	if up < 0.08 + bonus * 0.5:
		g += 1
	if up < 0.02 + bonus * 0.25:
		g += 2
	return clampi(g, 0, 11)

## 生成 n 个奖励选项。kind: "any" / "art" / "ult" / "relic" / "move" / "gong" / "upgrade" / "boss"
static func options(n:int, kind:String="any") -> Array:
	var r: Dictionary = G.run
	var luck: float = float(G.talent_fx().get("luck", 0.0))
	for rl in r["relics"]:
		luck += float(D.skills[rl]["p"].get("luck", 0.0))
	if "nochoice" in r["tianjie"]:
		n = max(1, n - 1)
	var out := []
	var used := {}
	var tries := 0
	while out.size() < n and tries < 80:
		tries += 1
		var k := kind
		if kind == "any" or kind == "boss":
			var roll := randf()
			if kind == "boss":
				k = ["ult", "art", "relic", "upgrade"][randi() % 4]
			elif roll < 0.50:
				k = "art"
			elif roll < 0.62:
				k = "upgrade"
			elif roll < 0.80:
				k = "relic"
			elif roll < 0.88:
				k = "move"
			elif roll < 0.94:
				k = "gong"
			else:
				k = "ult"
		var opt := _make(k, luck, used)
		if opt.is_empty():
			continue
		used[opt["id"]] = true
		out.append(opt)
	return out

static func _pool_for(cat:String) -> Array:
	var base: Array
	match cat:
		"art": base = D.art_pool.duplicate()
		"ult": base = D.ult_pool.duplicate()
		"move": base = D.move_pool.duplicate()
		"gong": base = D.gong_pool.duplicate()
		"relic": base = D.relic_pool.duplicate()
	# 高阶斗技需要藏经阁解锁（地阶及以上）
	var out := []
	var lib: int = int(G.meta["buildings"].get("library", 1))
	for id in base:
		var s: Dictionary = D.skills[id]
		if s["tier"] >= 2 and not (id in G.meta["unlocked_skills"]) and s["tier"] > lib / 2 + 1:
			continue
		if s["tier"] >= 3 and int(G.run.get("chapter", 1)) < 2 and not (id in G.meta["unlocked_skills"]):
			continue
		out.append(id)
	return out

static func _make(k:String, luck:float, used:Dictionary) -> Dictionary:
	var r: Dictionary = G.run
	match k:
		"art", "ult", "move", "gong", "relic":
			var pool := _pool_for(k)
			pool.shuffle()
			for id in pool:
				if used.has(id):
					continue
				if k == "art" and id in r["arts"]:
					continue
				if k == "ult" and id in r["ults"]:
					continue
				if k == "move" and id == r["move"]:
					continue
				if k == "gong" and id == r["gong"]:
					continue
				if k == "relic" and id in r["relics"] and D.skills[id]["p"].has("art_slot"):
					continue
				var s: Dictionary = D.skills[id]
				var g := _roll_grade(s["tier"], luck)
				var aff := []
				if k == "art":
					var na := 0
					if g >= 3: na = 1
					if g >= 6: na = 2
					if g >= 9: na = 3
					if randf() < 0.3: na += 1
					aff = roll_affixes(na)
				return {"type": "skill", "id": id, "grade": g, "affix": aff}
		"upgrade":
			var cands := []
			for id in r["arts"] + r["ults"]:
				var g2: int = int(r["skill_grades"].get(id, 0))
				if g2 < 11:
					cands.append(id)
			if int(r.get("atk_grade", 0)) < 11:
				cands.append("__atk")
			if cands.is_empty():
				return {}
			var pick: String = cands[randi() % cands.size()]
			if used.has("up_" + pick):
				return {}
			var id2: String = r["atk"] if pick == "__atk" else pick
			return {"type": "upgrade", "id": "up_" + pick, "target": pick, "skill": id2}
	return {}

static func describe(opt:Dictionary) -> Dictionary:
	# 返回 {title, sub, desc, col, elem, badge}
	var r: Dictionary = G.run
	if opt["type"] == "skill":
		var s: Dictionary = D.skills[opt["id"]]
		var g: int = opt["grade"]
		var desc: String = s["d"]
		if s["cat"] in ["art", "ult"]:
			desc += "\n伤害%d 冷却%.1fs" % [int(s["dmg"] * (1 + 0.12 * g)), s["cd"] * (1 - 0.025 * g)]
		for a in opt.get("affix", []):
			desc += "\n◆" + affix_name(a) + "：" + affix_desc(a)
		var badge := ""
		var fus := fusion_for(opt["id"])
		if fus != "":
			badge = "可融合！"
			desc += "\n★与已有斗技融合 → " + D.skills[fus]["n"]
		var cat = {"art": "斗技", "ult": "大招", "move": "身法", "gong": "功法", "relic": "法宝", "atk": "普攻"}[s["cat"]]
		var sub = cat + " · " + (D.GRADE_NAMES[g] if s["cat"] in ["art", "ult"] else D.TIER_NAMES[D.grade_tier(g)])
		if s["cat"] == "move" and s["id"] != r["move"]:
			desc += "\n（替换：" + D.skills[r["move"]]["n"] + "）"
		if s["cat"] == "gong":
			desc += "\n（替换：" + D.skills[r["gong"]]["n"] + "）"
		if s["cat"] == "art" and r["arts"].size() >= G.art_slots():
			sub += " · 槽满需替换"
		return {"title": s["n"], "sub": sub, "desc": desc, "col": D.grade_color(g), "elem": s["elem"], "badge": badge}
	elif opt["type"] == "upgrade":
		var id: String = opt["skill"]
		var s2: Dictionary = D.skills[id]
		var g2: int = int(r["atk_grade"]) if opt["target"] == "__atk" else int(r["skill_grades"].get(id, 0))
		var ng := mini(11, g2 + 1)
		return {"title": "升阶·" + s2["n"], "sub": D.GRADE_NAMES[g2] + " → " + D.GRADE_NAMES[ng], "desc": "伤害+12%，冷却-2.5%\n每4阶额外增加数量/段数。", "col": D.grade_color(ng), "elem": s2["elem"], "badge": "升阶"}
	return {"title": "?", "sub": "", "desc": "", "col": Color.WHITE, "elem": "", "badge": ""}

static func fusion_for(id:String) -> String:
	for rc in D.fusion_recipes:
		if rc[0] == id and rc[1] in G.run["arts"]:
			return rc[2]
		if rc[1] == id and rc[0] in G.run["arts"]:
			return rc[2]
	return ""

## 应用选项；若斗技槽已满，返回 "need_replace"
static func apply(opt:Dictionary, replace_idx:int=-1) -> String:
	var r: Dictionary = G.run
	if opt["type"] == "upgrade":
		if opt["target"] == "__atk":
			r["atk_grade"] = mini(11, int(r["atk_grade"]) + 1)
		else:
			var id: String = opt["target"]
			r["skill_grades"][id] = mini(11, int(r["skill_grades"].get(id, 0)) + 1)
		return "ok"
	var id2: String = opt["id"]
	var s: Dictionary = D.skills[id2]
	# 融合
	var fus := fusion_for(id2)
	if fus != "" and s["cat"] == "art":
		var other := ""
		for rc in D.fusion_recipes:
			if rc[2] == fus:
				other = rc[0] if rc[1] == id2 else rc[1]
		var idx: int = r["arts"].find(other)
		if idx >= 0:
			var g: int = max(int(opt["grade"]), int(r["skill_grades"].get(other, 0)))
			r["arts"][idx] = fus
			r["skill_grades"][fus] = mini(11, g + 1)
			var aff: Array = r["skill_affix"].get(other, []).duplicate()
			for a in opt.get("affix", []):
				if not (a in aff):
					aff.append(a)
			r["skill_affix"][fus] = aff
			r["auto"][fus] = r["auto"].get(other, true)
			G.unlock_ach("ach_fusion")
			if not (fus in G.meta["codex_skills"]):
				G.meta["codex_skills"].append(fus)
			return "fused:" + fus
	if s["cat"] == "art":
		if r["arts"].size() >= G.art_slots():
			if replace_idx < 0:
				return "need_replace"
			var old: String = r["arts"][replace_idx]
			r["arts"][replace_idx] = id2
			r["skill_grades"].erase(old)
			r["skill_affix"].erase(old)
		else:
			r["arts"].append(id2)
		r["skill_grades"][id2] = opt["grade"]
		r["skill_affix"][id2] = opt.get("affix", [])
		if not (id2 in G.meta["codex_skills"]):
			G.meta["codex_skills"].append(id2)
		return "ok"
	if s["cat"] == "ult":
		if r["ults"].size() >= 2:
			if replace_idx < 0:
				return "need_replace"
			r["ults"][replace_idx] = id2
		else:
			r["ults"].append(id2)
		r["skill_grades"][id2] = opt["grade"]
		return "ok"
	G.add_skill(id2, opt["grade"])
	return "ok"

## 可吞噬的异火（按章节）
static func fire_candidates() -> Array:
	var ch: int = int(G.run.get("chapter", 1))
	var out := []
	for f in D.fires:
		if int(f["ch"]) <= ch and not (f["id"] in G.run["fires"]):
			out.append(f["id"])
	return out
