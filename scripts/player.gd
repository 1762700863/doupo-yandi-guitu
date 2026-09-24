class_name Player
extends Node2D
## 玩家：属性计算、移动、普攻连段、斗技释放（手动/自动）、多形态身法、角色特殊机制、程序化动画

var b  # battle
var cid := "xiaoyan"
var cdata: Dictionary
var st := {}          # 计算后的属性
var hp := 100.0
var shield := 0.0
var spr: Sprite2D
var shadow_r := 12.0
var mat: ShaderMaterial
var aim := Vector2.RIGHT
var vel := Vector2.ZERO
var facing := 1.0
var walk_t := 0.0
var radius := 11.0

var atk_cd := 0.0
var combo := 0
var combo_t := 0.0
var cds := {}          # 技能冷却
var dodge_charges := 1
var dodge_recharge := 0.0
var dodging := 0.0
var dodge_dir := Vector2.ZERO
var dodge_kind := "roll"
var dodge_total := 0.3
var iframe := 0.0
var flying := 0.0
var fly_h := 0.0
var hurt_flash := 0.0
var lunge := Vector2.ZERO
var squash := 0.0
var dead := false
var buffs := {}        # name -> {t, ...}
var special_on := false   # 美杜莎蛇形 / 小医仙燃血 / 薰儿觉醒
var awaken_t := 0.0
var blood := 0.0      # 薰儿血脉
var hits_combo := 0   # 云韵连击
var hits_combo_t := 0.0
var regen_acc := 0.0
var kill_stack := 0
var revive_used := 0
var afterimg_t := 0.0
var trail_t := 0.0
var beast_t := 0.0
var no_hit_boss := true
var atk_style_idx := 0
var room_dmg_taken := 0.0
var possess_t := 0.0

func setup(battle, char_id:String) -> void:
	b = battle
	cid = char_id
	cdata = D.chars[cid]
	spr = Sprite2D.new()
	var skin_spr: String = cdata["spr"]
	var sk = G.meta["skin"].get(cid, "")
	if sk != "" and D.skins.has(cid):
		for s in D.skins[cid]:
			if s["id"] == sk:
				skin_spr = s["spr"]
	if G.run.get("chapter", 1) == 0 and cid == "xiaoyan":
		skin_spr = "yandi"
	mat = Puppet.apply(spr, skin_spr, 0)
	if spr.texture:
		var osz := Puppet.size_of(spr)
		shadow_r = min(26.0, osz.x * 0.28)
		if osz.x > 90:
			spr.scale = Vector2(0.72, 0.72)
			shadow_r *= 0.72
	add_child(spr)
	recalc()
	var saved_hp: float = float(G.run.get("hp", -1))
	hp = st["hp_max"] if saved_hp <= 0 else min(saved_hp, st["hp_max"])
	dodge_charges = int(st["dodge_charges"])
	shield = st["shield_room"]
	var owned: Array = G.meta["unlocked_atks"]
	atk_style_idx = max(0, owned.find(G.run["atk"]))

# ---------------------------------------------------------------- 属性
func recalc() -> void:
	var r: Dictionary = G.run
	var realm: float = G.rpow()
	var s := {
		"hp_max": float(cdata["hp"]) + realm * 11.0 + float(r.get("max_hp_bonus", 0)),
		"dmg": 1.0 + realm * 0.095, "crit": 0.05, "crit_dmg": 0.6, "cdr": 0.0, "spd": float(cdata["spd"]),
		"spd_mult": 1.0, "armor": 0.0, "lifesteal": 0.0, "aspd": 0.0, "area": 0.0, "proj": 0, "knock": 0.0,
		"exp": 0.0, "gold": 0.0, "heal": 0.0, "regen": 0.0, "burn_dmg": 0.0, "burn": 0, "freeze_ch": 0.0,
		"chill_all": 0.0, "poison_hit": 0, "double_hit": 0.0, "chain_hit": 0.0, "explode_kill": false,
		"kill_heal": 0.0, "shield_room": 0.0, "revive": 0, "dodge": 0.0, "thorns": 0.0, "echo": 0.0,
		"magnet": 70.0, "energy": 0.0, "boss_dmg": 0.0, "luck": 0.0, "comp_dmg": 0.0, "enemy_slow": 0.0,
		"weaken_hit": false, "exec": 0.0, "armor_break": false, "pull_hit": false, "burn_spread": false,
		"crit_tornado": false, "beast": false, "beast_power": 0.0, "low_hp_dmg": 0.0, "shield_dmg": 0.0,
		"dodge_charges": 1, "room_heal": 0.0, "kill_dmg": 0.0, "blood_gain": 0.0, "combo_keep": false,
	}
	for e in D.ELEM:
		s[e + "_dmg"] = 0.0
	var add := func(fx:Dictionary) -> void:
		for k in fx:
			if k == "spd" and fx[k] is float and fx[k] < 1.0:
				s["spd_mult"] += fx[k]
			elif s.has(k) and (s[k] is bool):
				s[k] = s[k] or bool(fx[k])
			elif s.has(k):
				s[k] += fx[k]
			else:
				s[k] = fx[k]
	# 天赋
	add.call(G.talent_fx())
	# 功法
	var gong: Dictionary = D.skills[r["gong"]]
	add.call(gong["p"])
	if r["gong"] == "gong_fenjue":
		s["dmg"] += 0.12 * r["fires"].size()
	s["dodge_charges"] += int(gong["p"].get("move_charges", 0))
	# 法宝
	for rl in r["relics"]:
		add.call(D.skills[rl]["p"])
	# 异火
	for f in r["fires"]:
		var fd: Dictionary = D.fire_by_id[f]
		var lv: int = int(G.meta["fire_levels"].get(f, 0))
		var fx: Dictionary = fd["fx"].duplicate()
		for k in fx:
			if fx[k] is float:
				fx[k] = fx[k] * (1.0 + lv * 0.15)
		add.call(fx)
	for pr in r["fused_pairs"]:
		if D.fire_pair_bonus.has(pr):
			add.call(D.fire_pair_bonus[pr]["fx"])
		else:
			add.call({"dmg": 0.08})
	# 丹药等本局增益
	for k in r["buffs"]:
		if s.has(k):
			if s[k] is bool:
				s[k] = true
			else:
				s[k] += r["buffs"][k]
	# 身法次数
	var mv: Dictionary = D.skills[r["move"]]
	s["dodge_charges"] += int(mv["p"].get("charges", 1)) - 1
	# 难度：治疗
	if "heal" in r["tianjie"]:
		s["heal"] -= 0.4
	s["hp_max"] = max(20.0, s["hp_max"])
	s["armor"] = min(s["armor"], 0.75)
	s["cdr"] = min(s["cdr"], 0.6)
	st = s
	if hp > st["hp_max"]:
		hp = st["hp_max"]

func speed() -> float:
	var sp: float = st["spd"] * st["spd_mult"]
	if buffs.has("spd"):
		sp *= 1.0 + buffs["spd"]["v"]
	if cid == "medusa" and special_on:
		sp *= 0.92
	if possess_t > 0:
		sp *= 1.2
	return sp

func dmg_mult(elem:String) -> float:
	var m: float = st["dmg"] + float(st.get(elem + "_dmg", 0.0))
	if buffs.has("dmg"):
		m += buffs["dmg"]["v"]
	if st["low_hp_dmg"] > 0:
		m += st["low_hp_dmg"] * (1.0 - hp / st["hp_max"])
	if shield > 0 and st["shield_dmg"] > 0:
		m += st["shield_dmg"]
	m += min(0.3, kill_stack * st["kill_dmg"])
	if cid == "xuner" and awaken_t > 0:
		m += 0.6
	if cid == "xiaoyixian" and special_on:
		m += 0.5
	if possess_t > 0:
		m += 1.0
	if G.run["buffs"].has("next_fight_dmg") and b.room_type != "":
		m += G.run["buffs"]["next_fight_dmg"]
	return m

func cd_of(id:String) -> float:
	var s: Dictionary = D.skills[id]
	var g: int = int(G.run["skill_grades"].get(id, 0))
	var cd: float = s["cd"] * (1.0 - 0.025 * g) * (1.0 - st["cdr"])
	if "cd" in G.run["skill_affix"].get(id, []):
		cd *= 0.8
	return max(0.08, cd)

# ---------------------------------------------------------------- 循环
func _physics_process(delta:float) -> void:
	if G.run.is_empty():
		return
	if dead or b == null or b.paused_logic:
		return
	_timers(delta)
	_move(delta)
	_combat(delta)
	_anim(delta)

func _timers(delta:float) -> void:
	atk_cd -= delta
	combo_t -= delta
	if combo_t <= 0:
		combo = 0
	iframe -= delta
	hurt_flash = max(0.0, hurt_flash - delta * 5)
	for k in cds.keys():
		cds[k] -= delta
	for k in buffs.keys():
		buffs[k]["t"] -= delta
		if buffs[k]["t"] <= 0:
			buffs.erase(k)
	if dodge_charges < st["dodge_charges"]:
		dodge_recharge -= delta
		if dodge_recharge <= 0:
			dodge_charges += 1
			dodge_recharge = cd_move()
	# 回复
	var reg: float = st["regen"]
	if buffs.has("regen"):
		reg += buffs["regen"]["v"]
	if reg > 0:
		heal(reg * delta, false)
	if buffs.has("selfdmg"):
		hp = max(1.0, hp - st["hp_max"] * buffs["selfdmg"]["v"] * delta)
	awaken_t -= delta
	possess_t -= delta
	hits_combo_t -= delta
	if hits_combo_t <= 0:
		hits_combo = 0
	if cid == "xiaoyixian" and special_on:
		pass
	# 万兽灵火
	if st["beast"]:
		beast_t -= delta
		if beast_t <= 0:
			beast_t = 9.0
			b.spawn_summon(global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 10.0 * (1 + st["beast_power"]), 9.0, Color(1, 0.5, 0.2))

func cd_move() -> float:
	return D.skills[G.run["move"]]["cd"] * (1.0 - st["cdr"] * 0.5)

func _input_dir() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")

func _update_aim() -> void:
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if joy.length() > 0.35:
		aim = joy.normalized()
		b.using_pad = true
	elif not b.using_pad:
		var m := get_global_mouse_position() - (global_position + Vector2(0, -16))
		if m.length() > 4:
			aim = m.normalized()
	else:
		var mv := _input_dir()
		if mv.length() > 0.3:
			aim = mv.normalized()
		var near = b.nearest_enemy(global_position, 360)
		if near:
			aim = (near.global_position - global_position).normalized()

func _move(delta:float) -> void:
	_update_aim()
	var dir := _input_dir()
	if dodging > 0:
		dodging -= delta
		var dist: float = D.skills[G.run["move"]]["p"]["dist"]
		var sp := dist / dodge_total
		if dodge_kind == "fly":
			var k := 1.0 - dodging / dodge_total
			fly_h = sin(k * PI) * 34.0
			global_position += dodge_dir * sp * delta
			b.clamp_to_arena(self, false)
			trail_t -= delta
			if trail_t <= 0:
				trail_t = 0.05
				var tr: float = D.skills[G.run["move"]]["p"].get("trail", 0)
				if tr > 0:
					b.spawn_zone(global_position, 26, 1.2, 0.3, tr * dmg_mult("fire"), D.elem_color(D.skills[G.run["move"]]["elem"]), {"burn": 1}, "fire")
			b.particles_trail(global_position + Vector2(0, -fly_h - 16), D.elem_color(D.skills[G.run["move"]]["elem"]))
		else:
			global_position += dodge_dir * sp * delta
			b.clamp_to_arena(self, true)
			afterimg_t -= delta
			if afterimg_t <= 0:
				afterimg_t = 0.035
				b.afterimage(self)
			if D.skills[G.run["move"]]["p"].get("poison_trail", false):
				trail_t -= delta
				if trail_t <= 0:
					trail_t = 0.07
					b.spawn_zone(global_position, 22, 1.5, 0.4, 3.0 * dmg_mult("poison"), Color(0.5, 1, 0.3), {"poison": 1}, "poison")
		if dodging <= 0:
			fly_h = 0
			flying = 0
		return
	var sp2 := speed()
	if atk_cd > 0.1 and D.skills[G.run["atk"]]["kind"] == "arc" and D.skills[G.run["atk"]]["p"].get("heavy", false):
		sp2 *= 0.55
	var target := dir * sp2
	vel = vel.lerp(target, clampf(delta * 14.0, 0, 1))
	global_position += (vel + lunge) * delta
	lunge = lunge.lerp(Vector2.ZERO, clampf(delta * 12.0, 0, 1))
	b.clamp_to_arena(self, true)
	if vel.length() > 20:
		walk_t += delta * vel.length() / 40.0
	else:
		walk_t = lerpf(walk_t, round(walk_t / PI) * PI, delta * 10)
	if abs(aim.x) > 0.15:
		facing = sign(aim.x)
	if Input.is_action_just_pressed("dodge") and dodge_charges > 0:
		_do_dodge(dir if dir.length() > 0.2 else aim)

func _do_dodge(dir:Vector2) -> void:
	var mv: Dictionary = D.skills[G.run["move"]]
	dodge_charges -= 1
	if dodge_recharge <= 0:
		dodge_recharge = cd_move()
	dodge_dir = dir.normalized()
	dodge_kind = mv["kind"]
	iframe = mv["p"]["iframe"]
	if dodge_kind == "blink":
		var from := global_position
		var dist: float = mv["p"]["dist"]
		global_position += dodge_dir * dist
		b.clamp_to_arena(self, true)
		b.blink_fx(from, global_position, D.elem_color(mv["elem"]))
		if mv["p"].has("shock"):
			b.aoe_damage(from, 60, {"dmg": mv["p"]["shock"] * dmg_mult("thunder"), "elem": "thunder", "stun": 0.4})
		if mv["p"].get("chill_burst", false):
			b.aoe_damage(global_position, 70, {"dmg": 8 * dmg_mult("cold"), "elem": "cold", "freeze": 0.8})
		Au.sfx("thunder_small" if mv["elem"] == "thunder" else "dash", -4)
		dodging = 0.0
		iframe = max(iframe, 0.18)
		return
	if dodge_kind == "fly":
		dodge_total = 0.5
		dodging = dodge_total
		flying = dodge_total
		Au.sfx("whoosh_fire", -2)
		b.spawn_fx("ring", global_position, {"r": 50, "col": D.elem_color(mv["elem"]), "life": 0.35, "width": 6})
	else:
		dodge_total = 0.2
		dodging = dodge_total
		Au.sfx("dash", -3)
	if mv["p"].has("decoy"):
		b.spawn_decoy(global_position, mv["p"]["decoy"])

func _combat(delta:float) -> void:
	if b.in_menu:
		return
	# 普攻
	var atk_id: String = G.run["atk"]
	if Input.is_action_pressed("attack") and atk_cd <= 0 and dodging <= 0:
		_basic_attack(atk_id)
	# 斗技
	var keys := ["art1", "art2", "art3", "art4"]
	var arts: Array = G.run["arts"]
	var slots: int = G.art_slots()
	for i in min(arts.size(), slots):
		var id: String = arts[i]
		var ready: bool = cds.get(id, 0.0) <= 0
		if not ready:
			continue
		var manual = i < 4 and Input.is_action_just_pressed(keys[i])
		var auto: bool = G.run["auto"].get(id, true) or i >= 4
		if manual or (auto and b.enemy_count() > 0 and b.nearest_enemy(global_position, 330) != null):
			var dir := aim
			if not manual:
				var ne = b.nearest_enemy(global_position, 330)
				if ne:
					dir = (ne.global_position - global_position).normalized()
			cast(id, dir)
	# 大招
	var ults: Array = G.run["ults"]
	var ukeys := ["ult", "ult2"]
	for i in min(ults.size(), G.ult_slots()):
		var uid: String = ults[i]
		if cds.get(uid, 0.0) <= 0:
			var auto2: bool = G.run["auto"].get(uid, false)
			if Input.is_action_just_pressed(ukeys[i]) or (auto2 and b.nearest_enemy(global_position, 300) != null):
				cast(uid, aim)
	if Input.is_action_just_pressed("special"):
		_special()
	if Input.is_action_just_pressed("pill"):
		b.use_pill()

func _basic_attack(atk_id:String) -> void:
	var s: Dictionary = D.skills[atk_id]
	var g: int = int(G.run.get("atk_grade", 0))
	var rate: float = s["cd"] / (1.0 + st["aspd"] + (buffs["aspd"]["v"] if buffs.has("aspd") else 0.0))
	if cid == "yunyun":
		rate /= 1.0 + min(0.6, hits_combo * 0.02)
	if cid == "xuner" and awaken_t > 0:
		atk_id = "atk_goldorb"
		b.cast_beam(global_position + Vector2(0, -18), aim, 280, 16, 0.25, {"dmg": 6.0 * dmg_mult("gold") * (1 + 0.15 * g), "elem": "gold", "burn": 1}, D.elem_color("gold"), 0.08)
		atk_cd = 0.25
		return
	atk_cd = rate
	combo_t = rate + 0.45
	var p: Dictionary = s["p"]
	var base: float = s["dmg"] * (1.0 + 0.15 * g) * dmg_mult(s["elem"])
	var col := D.elem_color(s["elem"])
	if G.run["fires"].size() > 0 and s["elem"] == "fire":
		col = D.fire_by_id[G.run["fires"][-1]]["c"]
	if cid == "medusa":
		if special_on:
			# 蛇形：尾扫
			b.melee_arc(global_position + Vector2(0, -14), aim, 70 * (1 + st["area"]), deg_to_rad(200), {"dmg": base * 1.3, "elem": "poison", "poison": 1, "knock": 120}, Color(0.75, 0.4, 1))
			Au.sfx("swing", -4, 0.8)
			lunge = aim * 60
			return
	match s["kind"]:
		"arc":
			var cmax: int = int(p.get("combo", 3))
			combo = (combo % cmax) + 1
			var fin := combo == cmax
			var rng: float = p["range"] * (1 + st["area"] * 0.5) * (1.25 if fin else 1.0)
			var info := {"dmg": base * (1.8 if fin else 1.0), "elem": s["elem"], "knock": float(p.get("knock", 50)) * (2.0 if fin else 0.6) * (1 + st["knock"])}
			if p.get("chill", false):
				info["chill"] = 1.5
				if fin:
					info["freeze"] = 0.7
			b.melee_arc(global_position + Vector2(0, -14), aim.rotated(0.35 * (1 if combo % 2 == 0 else -1) if not fin else 0.0), rng, deg_to_rad(p["angle"]), info, col if s["elem"] != "phys" else Color(1, 0.85, 0.6), fin)
			lunge = aim * (140 if fin else 70)
			squash = 1.0
			if p.get("heavy", false):
				Au.sfx("heavy" if fin else "swing", -3, 0.8 if fin else 0.7)
				if fin:
					b.shake(float(p.get("shake", 3)))
					b.spawn_fx("ring", global_position + aim * 40, {"r": 70, "col": Color(1, 0.8, 0.5), "life": 0.3, "width": 6})
					b.aoe_damage(global_position + aim * 40, 60 * (1 + st["area"]), {"dmg": base * 0.8, "elem": "phys", "knock": 200, "stun": 0.25})
			else:
				Au.sfx("swing", -6, 1.2 if fin else 1.0)
			if fin and p.get("finisher_wave", false):
				b.cast_wave(global_position, 110, 380, {"dmg": base * 1.2, "elem": "phys", "knock": 220}, Color(1, 0.9, 0.7))
				b.shake(3)
			if fin and p.get("wave_on_3", false):
				b.fire_proj(global_position + Vector2(0, -14), aim, {"speed": 520, "r": 10, "dmg": base * 1.4, "elem": s["elem"], "pierce": 99, "crescent": true, "life": 0.6}, col)
		"proj":
			var cnt: int = int(p.get("count", 1)) + (G.run["fires"].size() / 2 if atk_id == "atk_flame" else 0) + g / 4
			var spread := 0.18
			for i in cnt:
				var off := (i - (cnt - 1) * 0.5) * spread
				var info := {"speed": p["speed"], "r": p["size"], "dmg": base, "elem": s["elem"], "pierce": int(p.get("pierce", 0)), "life": 1.2,
					"homing": float(p.get("homing", 0.0)), "boomerang": p.get("boomerang", false), "poison": int(p.get("poison", 0)), "split_poison": p.get("split_on_death", false)}
				b.fire_proj(global_position + Vector2(0, -18) + aim * 10, aim.rotated(off), info, col)
			Au.sfx("shoot", -8, 1.1)
			lunge = -aim * 20

func cast(id:String, dir:Vector2, echo:bool=false) -> void:
	var s: Dictionary = D.skills[id]
	if not echo:
		cds[id] = cd_of(id)
	var g: int = int(G.run["skill_grades"].get(id, 0))
	var aff: Array = G.run["skill_affix"].get(id, [])
	var cost_hp := cid == "xiaoyixian" and special_on
	if cost_hp:
		hp = max(1.0, hp - st["hp_max"] * 0.03)
	b.cast_skill(self, id, s, g, aff, dir)
	squash = 1.0
	lunge = dir * 40
	if s["cat"] == "ult":
		b.ult_banner(s["n"], D.elem_color(s["elem"]))
		if id == "ult_yaolao":
			G.unlock_ach("ach_yaolao")
	if not echo:
		var ech: float = st["echo"] + (0.25 if "echo" in aff else 0.0)
		if s["cat"] == "art" and randf() < ech:
			get_tree().create_timer(0.25, false).timeout.connect(func():
				if is_instance_valid(self) and not dead:
					cast(id, aim, true))
		if "speed" in aff:
			add_buff("spd", 0.3, 2.0)

func add_buff(k:String, v:float, t:float) -> void:
	if buffs.has(k):
		buffs[k]["t"] = max(buffs[k]["t"], t)
		buffs[k]["v"] = max(buffs[k]["v"], v)
	else:
		buffs[k] = {"v": v, "t": t}

func _special() -> void:
	match cid:
		"xiaoyan":
			var owned: Array = G.meta["unlocked_atks"]
			if owned.size() > 1:
				atk_style_idx = (atk_style_idx + 1) % owned.size()
				G.run["atk"] = owned[atk_style_idx]
				b.float_text(global_position + Vector2(0, -70), "普攻：" + D.skills[G.run["atk"]]["n"], Color(1, 0.8, 0.4), false)
				Au.sfx("click")
		"xuner":
			if blood >= 100:
				blood = 0
				awaken_t = 10.0
				b.spawn_fx("ring", global_position, {"r": 140, "col": Color(1, 0.85, 0.3), "life": 0.6, "width": 10})
				b.float_text(global_position + Vector2(0, -70), "古族血脉·觉醒！", Color(1, 0.85, 0.3), true)
				Au.sfx("breakthrough", -6)
				b.shake(6)
			else:
				b.float_text(global_position + Vector2(0, -60), "血脉值不足 %d%%" % int(blood), Color(0.8, 0.8, 0.8), false)
		"medusa", "xiaoyixian":
			special_on = not special_on
			var nm := ""
			if cid == "medusa":
				nm = "蛇形" if special_on else "人形"
				spr.scale = Vector2(1.15, 1.15) if special_on else Vector2(1, 1)
			else:
				nm = "厄难燃血：开" if special_on else "厄难燃血：关"
			b.float_text(global_position + Vector2(0, -70), nm, cdata["color"], false)
			b.spawn_fx("ring", global_position, {"r": 60, "col": cdata["color"], "life": 0.4, "width": 5})
			Au.sfx("poison" if cid == "xiaoyixian" else "whoosh_fire")
		"yunyun":
			if hits_combo >= 20:
				hits_combo -= 20
				b.spawn_zone(global_position, 120, 5.0, 0.25, 8 * dmg_mult("wind"), Color(0.6, 1, 0.9), {"knock": 40}, "wind", true)
				b.float_text(global_position + Vector2(0, -70), "风之领域", Color(0.6, 1, 0.9), true)
				Au.sfx("wind")

func on_hit_enemy(info:Dictionary, dealt:float) -> void:
	if cid == "xuner" and awaken_t <= 0:
		blood = min(100.0, blood + dealt * 0.04 * (1.0 + st["blood_gain"]))
	if cid == "yunyun":
		hits_combo += 1
		hits_combo_t = 2.5
		if hits_combo % 10 == 0:
			var ne = b.nearest_enemy(global_position, 400)
			if ne:
				b.fire_proj(global_position + Vector2(0, -16), (ne.global_position - global_position).normalized(), {"speed": 460, "r": 9, "dmg": 18 * dmg_mult("wind"), "elem": "wind", "pierce": 3, "homing": 5.0, "life": 1.5, "crescent": true}, Color(0.6, 1, 0.9))
	var ls: float = st["lifesteal"] + float(info.get("lifesteal", 0.0))
	if ls > 0:
		heal(dealt * ls, false)

func on_kill(e) -> void:
	kill_stack += 1
	if st["kill_heal"] > 0:
		heal(st["kill_heal"], false)

func heal(v:float, show:bool=true) -> void:
	if dead:
		return
	v *= max(0.1, 1.0 + st["heal"])
	var before := hp
	hp = min(st["hp_max"], hp + v)
	if show and hp - before >= 1:
		b.float_text(global_position + Vector2(0, -50), "+%d" % int(hp - before), Color(0.4, 1, 0.5), false)

func take_damage(v:float, src_pos:Vector2=Vector2.ZERO, elem:String="phys") -> void:
	if dead or iframe > 0 or flying > 0 or b.in_menu:
		return
	if randf() < st["dodge"]:
		b.float_text(global_position + Vector2(0, -50), "闪避", Color(0.8, 0.9, 1), false)
		return
	var armor: float = st["armor"]
	if buffs.has("armor"):
		armor += buffs["armor"]["v"]
	if cid == "medusa" and special_on:
		armor += 0.3
	armor = min(armor, 0.8)
	v *= (1.0 - armor)
	if shield > 0:
		var ab: float = min(shield, v)
		shield -= ab
		v -= ab
		b.spawn_fx("ring", global_position + Vector2(0, -20), {"r": 24, "col": Color(0.5, 0.8, 1), "life": 0.2, "width": 3})
	if buffs.has("reflect") and src_pos != Vector2.ZERO:
		pass
	hp -= v
	room_dmg_taken += v
	if b.boss_active:
		no_hit_boss = false
	if cid == "yunyun":
		hits_combo = hits_combo / 2 if st["combo_keep"] else 0
	iframe = 0.45
	hurt_flash = 1.0
	b.float_text(global_position + Vector2(0, -40), "-%d" % int(max(1, v)), Color(1, 0.3, 0.3), false)
	b.shake(4)
	b.hit_vignette()
	Au.sfx("hurt", -2)
	if st["thorns"] > 0 and src_pos != Vector2.ZERO:
		b.aoe_damage(src_pos, 30, {"dmg": v * st["thorns"] * 3, "elem": "phys"})
	if hp <= 0:
		_try_die()

func _try_die() -> void:
	# 复活顺序：功法/异火复活 → 还魂丹 → 天赋复活
	if int(st["revive"]) > revive_used:
		revive_used += 1
		_revive(0.5, "浴火重生！")
		return
	var pills: Array = G.run["pills"]
	var i := pills.find("huanhun")
	if i >= 0:
		pills.remove_at(i)
		_revive(0.5, "还魂丹！")
		return
	if int(G.run.get("revives", 0)) > 0:
		G.run["revives"] = int(G.run["revives"]) - 1
		_revive(0.4, "不灭！")
		return
	dead = true
	hp = 0
	b.player_died()

func _revive(pct:float, txt:String) -> void:
	hp = st["hp_max"] * pct
	iframe = 2.0
	b.spawn_fx("lotus", global_position, {"r": 110, "life": 1.2, "colors": [Color(1, 0.5, 0.2), Color(1, 0.9, 0.5)]})
	b.float_text(global_position + Vector2(0, -80), txt, Color(1, 0.8, 0.3), true)
	b.aoe_damage(global_position, 160, {"dmg": 60 * dmg_mult("fire"), "elem": "fire", "knock": 300})
	Au.sfx("breakthrough", -4)

func _anim(delta:float) -> void:
	squash = max(0.0, squash - delta * 6.0)
	var bob = abs(sin(walk_t)) * 2.5
	var lean := clampf(vel.x / 200.0, -1, 1) * 0.12
	var sx := facing * (1.0 + squash * 0.12)
	var sy = 1.0 - squash * 0.1 + abs(sin(walk_t)) * 0.04
	var base_scale := 0.72 if spr.texture and Puppet.size_of(spr).x > 90 else 1.0
	if cid == "medusa" and special_on:
		base_scale *= 1.15
	spr.scale = Vector2(sx, sy) * base_scale
	spr.rotation = lean * 0.25
	var spd: float = maxf(1.0, float(st.get("speed", 200.0)))
	Puppet.tick(mat, delta, walk_t, vel.length() / spd, clampf(vel.x / spd, -1, 1) * 1.5 + squash * 3.0 * signf(aim.x), facing)
	spr.position = Vector2(0, -bob - fly_h)
	var fl := hurt_flash
	var fc := Color(1, 0.2, 0.2)
	if iframe > 0 and dodging <= 0 and hurt_flash <= 0:
		spr.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.04)
	else:
		spr.modulate.a = 1.0
	if possess_t > 0:
		fl = 0.25 + 0.1 * sin(Time.get_ticks_msec() * 0.01)
		fc = Color(0.6, 0.9, 1)
	elif cid == "xuner" and awaken_t > 0:
		fl = 0.3
		fc = Color(1, 0.85, 0.3)
	mat.set_shader_parameter("flash", fl)
	mat.set_shader_parameter("flash_col", fc)
	queue_redraw()

func _draw() -> void:
	# 影子
	var s := 1.0 - fly_h / 80.0
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, shadow_r * s, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 瞄准指示
	var a := aim * 34
	draw_line(a * 0.8, a * 1.15, Color(1, 0.9, 0.6, 0.55), 2.0)
