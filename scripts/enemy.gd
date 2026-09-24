class_name Enemy
extends Node2D
## 敌人与 Boss：多种 AI、状态（灼烧/中毒/冰冻/眩晕/石化/破甲）、Boss 多阶段招式

var b
var id := ""
var data: Dictionary
var is_boss := false
var is_elite := false
var hp := 10.0
var hp_max := 10.0
var dmg := 5.0
var spd := 80.0
var radius := 12.0
var spr: Sprite2D
var mat: ShaderMaterial
var vel := Vector2.ZERO
var knock := Vector2.ZERO
var flash := 0.0
var dead := false
var t := 0.0
var think := 0.0
var state := "chase"
var state_t := 0.0
var atk_cd := 1.0
var target_dir := Vector2.ZERO
var facing := 1.0
var walk := 0.0
var wisp_col := Color.TRANSPARENT
var scale_base := 1.0
var tint := Color.WHITE
var spawn_t := 0.5
# 状态
var burn := 0.0
var burn_dps := 0.0
var poison := 0
var poison_t := 0.0
var chill := 0.0
var freeze := 0.0
var stun := 0.0
var petrify := 0.0
var weaken := 0.0
var tick_t := 0.0
# Boss
var phase := 0
var phases: Array = []
var move_queue: Array = []
var casting := ""
var cast_t := 0.0
var cast_data := {}
var enraged := false
var summon_wave := 0
var dormant := false     # 探索地图：休眠中（玩家靠近或受击才苏醒）
var pack := ""           # 所属怪物群
var home := Vector2.ZERO

func setup(battle, eid:String, boss:bool, mult:float) -> void:
	b = battle
	id = eid
	is_boss = boss
	data = D.bosses[eid] if boss else D.enemies[eid]
	is_elite = boss and data.get("elite", false)
	var ch: int = int(G.run.get("chapter", 1))
	var diff: Dictionary = D.DIFFS[int(G.run.get("diff", 1))]
	var tj: Array = G.run.get("tianjie", [])
	var hpm: float = diff["hp"] * mult * (1.4 if "hp" in tj else 1.0)
	if boss and not is_elite and "boss" in tj:
		hpm *= 1.5
	hp_max = float(data["hp"]) * hpm
	hp = hp_max
	dmg = float(data["dmg"]) * diff["dmg"] * (1.35 if "dmg" in tj else 1.0) * (0.85 + 0.15 * mult)
	spd = float(data["spd"]) * (1.2 if "spd" in tj else 1.0)
	tint = data.get("tint", Color.WHITE)
	scale_base = float(data.get("scale", 1.0))
	if data.get("wisp", null) != null:
		wisp_col = data["wisp"]
		radius = float(data.get("wisp_r", data.get("r", 10)))
	else:
		var sname: String = data.get("spr", "")
		if sname == "__player":
			sname = D.chars[G.run["char"]]["spr"]
		spr = Sprite2D.new()
		spr.texture = G.spr(sname)
		if spr.texture:
			spr.offset = Vector2(0, -spr.texture.get_height() * 0.5)
			radius = float(data.get("r", spr.texture.get_width() * 0.3 * scale_base))
			if boss:
				radius = spr.texture.get_width() * 0.28 * scale_base
		mat = ShaderMaterial.new()
		mat.shader = preload("res://scripts/flash.gdshader")
		mat.set_shader_parameter("tint", tint)
		spr.material = mat
		add_child(spr)
	if boss:
		phases = data["phases"]
		atk_cd = 1.5
	else:
		atk_cd = randf_range(0.8, 2.0)
	z_index = 0

func _physics_process(delta:float) -> void:
	if G.run.is_empty():
		return
	if dead or b.paused_logic:
		return
	t += delta
	flash = max(0.0, flash - delta * 6)
	spawn_t -= delta
	_status(delta)
	if spawn_t > 0:
		_anim(delta)
		return
	var p = b.player
	if p == null or p.dead:
		_anim(delta)
		return
	if dormant:
		# 原地徘徊；玩家靠近则整群苏醒
		if p.global_position.distance_to(global_position) < (330.0 if is_boss else 270.0):
			b.wake_pack(pack)
		else:
			walk += delta * 0.4
			global_position = global_position.lerp(home + Vector2(sin(t * 0.7 + home.x) * 18, cos(t * 0.5 + home.y) * 12), delta * 0.8)
			_anim(delta)
			return
	var frozen := freeze > 0 or stun > 0 or petrify > 0
	var slow := 1.0
	if chill > 0:
		slow *= 0.55
	slow *= 1.0 - float(p.st.get("enemy_slow", 0.0))
	if not frozen:
		if is_boss:
			_boss_ai(delta, p, slow)
		else:
			_ai(delta, p, slow)
	global_position += knock * delta
	knock = knock.lerp(Vector2.ZERO, clampf(delta * 8, 0, 1))
	b.clamp_to_arena(self, true)
	_anim(delta)

func _status(delta:float) -> void:
	chill -= delta
	freeze -= delta
	stun -= delta
	petrify -= delta
	weaken -= delta
	tick_t -= delta
	if tick_t <= 0:
		tick_t = 0.5
		if burn > 0:
			burn -= 0.5
			var bd := burn_dps * 0.5
			_raw_damage(bd, D.elem_color("fire"), false)
			if b.player and b.player.st.get("burn_spread", false) and randf() < 0.2:
				var other = b.nearest_enemy(global_position, 80, self)
				if other:
					other.apply_burn(burn_dps, 2.0)
		if poison > 0:
			poison_t -= 0.5
			var pm: float = 1.0 + (float(b.player.st.get("poison_dmg", 0.0)) if b.player else 0.0)
			_raw_damage(poison * 1.6 * pm * (1.0 + G.rpow() * 0.06), D.elem_color("poison"), false)
			if poison_t <= 0:
				poison = max(0, poison - 1)
				poison_t = 3.0

func apply_burn(dps:float, dur:float) -> void:
	burn = max(burn, dur)
	burn_dps = max(burn_dps, dps)

func _raw_damage(v:float, col:Color, big:bool) -> void:
	if dead or v <= 0:
		return
	hp -= v
	if G.settings["dmgnum"] and randf() < 0.6:
		b.float_text(global_position + Vector2(randf_range(-8, 8), -radius * 2 - 6), str(int(max(1, v))), col, false)
	if hp <= 0:
		die()

func hurt(info:Dictionary, from:Vector2) -> float:
	if dead or spawn_t > 0.2:
		return 0.0
	if dormant and b.has_method("wake_pack"):
		b.wake_pack(pack)
	var p = b.player
	var v: float = info.get("dmg", 5.0)
	var crit := false
	var cc: float = p.st["crit"] + float(info.get("crit_bonus", 0.0))
	if randf() < cc:
		crit = true
		v *= 1.0 + p.st["crit_dmg"] + 0.9
	if weaken > 0:
		v *= 1.15
	if petrify > 0:
		v *= 1.3
	if is_boss or is_elite:
		v *= 1.0 + p.st["boss_dmg"] + float(info.get("elite_bonus", 0.0))
	if info.get("exec", false) and hp < hp_max * 0.3:
		v *= 2.0
	if p.st["exec"] > 0 and not is_boss and hp < hp_max * 0.15 and randf() < p.st["exec"]:
		v = hp + 1
	var elem: String = info.get("elem", "phys")
	hp -= v
	flash = 1.0
	# 击退
	var kb: float = float(info.get("knock", 30.0)) * (1.0 + p.st["knock"])
	if is_boss:
		kb *= 0.08 if not is_elite else 0.2
	var dir := (global_position - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	knock += dir * kb
	# 状态
	if info.has("burn") or p.st["burn"] > 0:
		var stacks: float = float(info.get("burn", 0)) + p.st["burn"]
		if stacks > 0:
			apply_burn(3.0 * stacks * (1.0 + p.st["burn_dmg"]) * (1 + G.rpow() * 0.05), 3.0)
	var pz: int = int(info.get("poison", 0)) + int(p.st["poison_hit"])
	if pz > 0:
		poison = min(poison + pz, 30)
		poison_t = 3.0
	if info.has("chill") or randf() < p.st["chill_all"]:
		chill = max(chill, float(info.get("chill", 1.5)))
	var fz: float = float(info.get("freeze", 0.0))
	if fz <= 0 and randf() < p.st["freeze_ch"]:
		fz = 0.8
	if fz > 0:
		freeze = max(freeze, fz * (0.35 if is_boss else 1.0))
	if info.has("stun"):
		stun = max(stun, float(info["stun"]) * (0.3 if is_boss else 1.0))
	if info.has("petrify"):
		petrify = max(petrify, float(info["petrify"]) * (0.3 if is_boss else 1.0))
	if info.has("weaken") or p.st["weaken_hit"] or p.st["armor_break"]:
		weaken = max(weaken, 3.0)
	if p.st["pull_hit"] and not is_boss:
		knock += (p.global_position - global_position).normalized() * 40
	# 伤害数字
	if G.settings["dmgnum"]:
		var col: Color = D.elem_color(elem)
		if crit:
			col = Color(1, 0.95, 0.3)
		b.float_text(global_position + Vector2(randf_range(-10, 10), -radius * 2 - 8), str(int(v)) + ("!" if crit else ""), col, crit)
	if crit and p.st["crit_tornado"] and randf() < 0.3:
		b.spawn_zone(global_position, 40, 1.5, 0.25, 6 * p.dmg_mult("wind"), Color(1, 0.6, 0.3), {"pull": 60}, "wind")
	if randf() < p.st["chain_hit"]:
		b.chain_lightning(global_position, 3, 150, {"dmg": v * 0.4, "elem": "thunder"}, self)
	if randf() < p.st["double_hit"] and not info.get("is_double", false):
		var i2 := info.duplicate()
		i2["is_double"] = true
		i2["dmg"] = v * 0.5
		get_tree().create_timer(0.08, false).timeout.connect(func():
			if is_instance_valid(self) and not dead:
				hurt(i2, from))
	Au.sfx("hit", -10 if not crit else -5, 1.0 if not crit else 0.8)
	b.hitspark(global_position + Vector2(0, -radius), D.elem_color(elem), crit)
	if hp <= 0:
		die()
	return v

func die() -> void:
	if dead:
		return
	dead = true
	b.enemy_died(self)
	# 死亡动画：闪白+溶解
	var tw := create_tween()
	if mat:
		mat.set_shader_parameter("flash", 1.0)
		mat.set_shader_parameter("flash_col", Color(1, 0.9, 0.7))
		tw.tween_method(func(v): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.45 if not is_boss else 1.4)
	else:
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

# ---------------------------------------------------------------- 普通 AI
func _ai(delta:float, p, slow:float) -> void:
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to.normalized()
	var decoy = b.decoy_pos()
	if decoy != null:
		to = decoy - global_position
		dist = to.length()
		dir = to.normalized()
	atk_cd -= delta
	state_t -= delta
	var ai: String = data["ai"]
	match state:
		"chase":
			var want := dir
			if ai in ["ranged", "caster"]:
				var keep := 170.0 if ai == "ranged" else 210.0
				if dist < keep - 30:
					want = -dir
				elif dist < keep + 30:
					want = dir.orthogonal() * (1 if int(t * 0.5) % 2 == 0 else -1)
			# 分离
			want += b.separation(self) * 1.3
			vel = vel.lerp(want.normalized() * spd * slow, clampf(delta * 6, 0, 1))
			global_position += vel * delta
			if atk_cd <= 0:
				if ai in ["melee", "swarm", "tank"] and dist < radius + 26:
					_start("windup", 0.35 if ai != "tank" else 0.55)
				elif ai == "dasher" and dist < 190:
					target_dir = dir
					b.telegraph_line(global_position, dir.angle(), 180, radius * 2, 0.5, Color(1, 0.3, 0.3))
					_start("dash_wind", 0.5)
				elif ai == "ranged" and dist < 330:
					_start("shoot_wind", 0.4)
				elif ai == "caster" and dist < 360:
					_start("cast_wind", 0.7)
		"windup":
			vel = vel.lerp(Vector2.ZERO, 0.3)
			if state_t <= 0:
				b.enemy_melee(self, global_position + dir * radius, radius + 24, dmg)
				atk_cd = randf_range(1.0, 1.6)
				state = "chase"
		"dash_wind":
			if state_t <= 0:
				_start("dashing", 0.32)
		"dashing":
			global_position += target_dir * 560 * delta * slow
			if (p.global_position - global_position).length() < radius + p.radius:
				p.take_damage(dmg, global_position)
			if state_t <= 0:
				atk_cd = randf_range(1.6, 2.4)
				state = "chase"
		"shoot_wind":
			if state_t <= 0:
				var n := 1 if data["hp"] < 50 else 3
				if "bullet" in G.run["tianjie"]:
					n += 1
				for i in n:
					b.enemy_bullet(global_position + Vector2(0, -radius), dir.rotated((i - (n - 1) * 0.5) * 0.25), 190, dmg * 0.8, data.get("bullet", "fire"))
				atk_cd = randf_range(1.6, 2.4)
				state = "chase"
		"cast_wind":
			if state_t <= 0:
				var pos: Vector2 = p.global_position + p.vel * 0.4
				b.enemy_aoe(pos, 46, 0.8, dmg * 1.2, D.elem_color(data.get("bullet", "soul")))
				if randf() < 0.5:
					for i in 8:
						b.enemy_bullet(global_position + Vector2(0, -radius), Vector2.RIGHT.rotated(TAU * i / 8.0 + t), 150, dmg * 0.6, data.get("bullet", "soul"))
				atk_cd = randf_range(2.0, 3.0)
				state = "chase"
	if abs(vel.x) > 5:
		facing = sign(vel.x) if state != "dashing" else sign(target_dir.x)
	walk += delta * vel.length() / 30.0

func _start(s:String, dur:float) -> void:
	state = s
	state_t = dur
	if s in ["windup", "shoot_wind", "cast_wind", "dash_wind"]:
		flash = 0.4

# ---------------------------------------------------------------- Boss AI
func _boss_ai(delta:float, p, slow:float) -> void:
	# 阶段转换
	if phase + 1 < phases.size() and hp / hp_max <= float(phases[phase + 1]["hp"]):
		phase += 1
		casting = ""
		b.boss_phase(self, phase, phases[phase]["line"])
		atk_cd = 2.0
		return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	var dir := to.normalized()
	var spd_mult := 1.0 + phase * 0.12
	if "boss" in G.run["tianjie"]:
		spd_mult += 0.15
	if casting != "":
		cast_t -= delta * spd_mult
		_boss_cast_tick(delta, p, dir)
		if cast_t <= 0:
			casting = ""
			atk_cd = randf_range(0.5, 1.1) / spd_mult
		return
	atk_cd -= delta * spd_mult
	# 走位：保持中距离绕行
	var keep := 150.0
	var want := dir if dist > keep + 40 else (dir.orthogonal() * (1 if int(t / 3.0) % 2 == 0 else -1) if dist > keep - 40 else -dir)
	vel = vel.lerp(want * spd * 0.7 * slow, clampf(delta * 4, 0, 1))
	global_position += vel * delta
	if abs(to.x) > 5:
		facing = sign(to.x)
	walk += delta * vel.length() / 30.0
	if atk_cd <= 0:
		if move_queue.is_empty():
			move_queue = phases[phase]["moves"].duplicate()
			move_queue.shuffle()
		_boss_begin(move_queue.pop_front(), p, dir)

func _boss_begin(mv:String, p, dir:Vector2) -> void:
	casting = mv
	cast_data = {"dir": dir, "i": 0, "tick": 0.0, "pos": p.global_position}
	var c := D.elem_color(_belem())
	match mv:
		"charge", "dash_slash":
			cast_t = 1.1
			cast_data["n"] = 1
			b.telegraph_line(global_position, dir.angle(), 320, radius * 2, 0.55, Color(1, 0.25, 0.2))
		"charge3", "dash_slash3":
			cast_t = 2.8
			cast_data["n"] = 3
			b.telegraph_line(global_position, dir.angle(), 320, radius * 2, 0.55, Color(1, 0.25, 0.2))
		"slam":
			cast_t = 1.2
			b.enemy_aoe(p.global_position, 80, 0.9, dmg * 1.5, Color(1, 0.4, 0.2))
		"claw3":
			cast_t = 1.4
			for i in 3:
				var pp: Vector2 = global_position + dir.rotated((i - 1) * 0.5) * 70
				b.enemy_aoe(pp, 44, 0.5 + i * 0.25, dmg, Color(1, 0.3, 0.3))
		"fan3", "fan5", "fan7":
			cast_t = 1.0
			cast_data["n"] = int(mv.substr(3))
			b.telegraph_fan(global_position, dir.angle(), 0.9, 200, 0.5, c)
		"ring", "ring2", "ring3":
			var k := 1 if mv == "ring" else (2 if mv == "ring2" else 3)
			cast_t = 0.6 + k * 0.5
			cast_data["n"] = k
		"spiral", "spiral2", "spiral3":
			cast_t = 2.5
			cast_data["n"] = 1 if mv == "spiral" else (2 if mv == "spiral2" else 3)
		"summon_wolf", "howl_wolves", "summon_bandit", "summon_snake", "summon_disciple", "summon_soul", "summon_wisp":
			cast_t = 1.0
			b.float_text(global_position + Vector2(0, -radius * 2 - 20), "召唤！", c, true)
			Au.sfx("bosswarn")
		"rage_rain", "fire_rain", "poison_rain":
			cast_t = 3.0
		"petrify_beam":
			cast_t = 1.6
			b.telegraph_line(global_position, dir.angle(), 420, 30, 0.8, Color(0.7, 0.4, 1))
		"python":
			cast_t = 2.2
			b.telegraph_line(global_position, dir.angle(), 460, radius * 2.5, 0.9, Color(0.8, 0.5, 1))
			b.float_text(global_position + Vector2(0, -radius * 2 - 30), "七彩吞天蟒！", Color(0.9, 0.6, 1), true)
		"lotus_bomb":
			cast_t = 1.8
			for i in 5:
				var pp: Vector2 = p.global_position + Vector2(randf_range(-120, 120), randf_range(-90, 90))
				b.enemy_aoe(pp, 55, 1.2, dmg * 1.4, Color(0.2, 1, 0.7), true)
		"wind_blades":
			cast_t = 1.5
		"wind_storm":
			cast_t = 3.5
		"soul_chain":
			cast_t = 1.4
			b.telegraph_line(global_position, dir.angle(), 380, 20, 0.6, Color(0.6, 0.3, 1))
		_:
			cast_t = 0.5

func _belem() -> String:
	match id:
		"medusa", "fire_spirit": return "poison" if id == "medusa" else "fire"
		"yunshan", "nalan": return "wind"
		"soul_elder", "hun_tiandi": return "soul"
		"heart_demon": return "void"
	return "fire"

func _boss_cast_tick(delta:float, p, dir:Vector2) -> void:
	var c := D.elem_color(_belem())
	var el := _belem()
	var extra := 1.5 if "bullet" in G.run["tianjie"] else 1.0
	match casting:
		"charge", "charge3", "dash_slash", "dash_slash3":
			var n: int = cast_data["n"]
			var per := cast_t
			var seg := fmod(cast_t, 0.93)
			# 每段: 0.55 预警 -> 0.38 冲刺
			var total := n * 0.93
			var elapsed: float = (n * 0.93 + 0.2) - cast_t
			var k := int(elapsed / 0.93)
			var local := fmod(elapsed, 0.93)
			if k != int(cast_data["i"]) and k < n:
				cast_data["i"] = k
				cast_data["dir"] = (p.global_position - global_position).normalized()
				b.telegraph_line(global_position, cast_data["dir"].angle(), 320, radius * 2, 0.55, Color(1, 0.25, 0.2))
			if local > 0.55 and local < 0.93:
				global_position += cast_data["dir"] * 820 * delta
				if (p.global_position - global_position).length() < radius + p.radius + 6:
					p.take_damage(dmg * 1.3, global_position)
				if casting.begins_with("dash_slash") and randf() < 0.3:
					b.enemy_bullet(global_position, cast_data["dir"].orthogonal() * (1 if randf() < 0.5 else -1), 160, dmg * 0.6, el)
				b.afterimage(self)
		"fan3", "fan5", "fan7":
			if cast_data["i"] == 0 and cast_t < 0.5:
				cast_data["i"] = 1
				var n := int(cast_data["n"] * extra)
				var d0: Vector2 = cast_data["dir"]
				for i in n:
					b.enemy_bullet(global_position + Vector2(0, -radius), d0.rotated((i - (n - 1) * 0.5) * 0.9 / max(1, n - 1) * 2), 230, dmg * 0.8, el)
				Au.sfx("shoot", -4, 0.7)
		"ring", "ring2", "ring3":
			cast_data["tick"] -= delta
			if cast_data["tick"] <= 0:
				cast_data["tick"] = 0.5
				var m := int(18 * extra)
				var off: float = cast_data["i"] * 0.17
				cast_data["i"] += 1
				for i in m:
					b.enemy_bullet(global_position + Vector2(0, -radius), Vector2.RIGHT.rotated(TAU * i / m + off), 170, dmg * 0.7, el)
				Au.sfx("shoot", -6, 0.6)
				b.spawn_fx("ring", global_position, {"r": 60, "col": c, "life": 0.3, "width": 4})
		"spiral", "spiral2", "spiral3":
			cast_data["tick"] -= delta
			if cast_data["tick"] <= 0:
				cast_data["tick"] = 0.09
				var arms: int = cast_data["n"] + 1
				cast_data["i"] += 1
				for a in arms:
					var ang: float = cast_data["i"] * 0.28 + TAU * a / arms
					b.enemy_bullet(global_position + Vector2(0, -radius), Vector2.RIGHT.rotated(ang), 150, dmg * 0.6, el)
		"slam":
			if cast_data["i"] == 0 and cast_t < 0.3:
				cast_data["i"] = 1
				b.shake(6)
		"summon_wolf", "howl_wolves", "summon_bandit", "summon_snake", "summon_disciple", "summon_soul", "summon_wisp":
			if cast_data["i"] == 0 and cast_t < 0.5:
				cast_data["i"] = 1
				var kind = {"summon_wolf": "wolf", "howl_wolves": "wolf_grey", "summon_bandit": "bandit", "summon_snake": "snake", "summon_disciple": "disciple", "summon_soul": "soul", "summon_wisp": "wisp_green"}[casting]
				var cnt := 4 if kind == "wolf_grey" else 2
				if b.enemy_count() < 14:
					for i in cnt:
						b.spawn_enemy(kind, global_position + Vector2.RIGHT.rotated(TAU * i / cnt) * 80, 0.8 + phase * 0.2)
		"rage_rain", "fire_rain", "poison_rain":
			cast_data["tick"] -= delta
			if cast_data["tick"] <= 0:
				cast_data["tick"] = 0.22 / extra
				var pp: Vector2 = p.global_position + Vector2(randf_range(-140, 140), randf_range(-100, 100))
				if randf() < 0.35:
					pp = p.global_position + p.vel * 0.5
				b.enemy_aoe(pp, 40, 0.9, dmg, c)
		"petrify_beam":
			if cast_data["i"] == 0 and cast_t < 0.8:
				cast_data["i"] = 1
				b.enemy_beam(global_position + Vector2(0, -radius), cast_data["dir"], 420, 30, 0.6, dmg * 1.2, Color(0.8, 0.5, 1))
		"python":
			if cast_t < 1.3 and cast_t > 0.3:
				global_position += cast_data["dir"] * 520 * delta
				b.afterimage(self)
				if (p.global_position - global_position).length() < radius * 1.3 + p.radius:
					p.take_damage(dmg * 1.8, global_position)
				if randf() < 0.4:
					b.enemy_aoe(global_position, 34, 0.8, dmg * 0.6, Color(0.6, 1, 0.3))
		"wind_blades":
			cast_data["tick"] -= delta
			if cast_data["tick"] <= 0:
				cast_data["tick"] = 0.3
				var d0: Vector2 = (p.global_position - global_position).normalized()
				for i in 3:
					b.enemy_bullet(global_position + Vector2(0, -radius), d0.rotated((i - 1) * 0.2), 300, dmg * 0.7, "wind", true)
		"wind_storm":
			cast_data["tick"] -= delta
			if cast_data["tick"] <= 0:
				cast_data["tick"] = 0.15
				cast_data["i"] += 1
				for a in 4:
					b.enemy_bullet(global_position, Vector2.RIGHT.rotated(cast_data["i"] * 0.2 + TAU * a / 4.0), 200, dmg * 0.55, "wind")
				# 吸引
				p.global_position += (global_position - p.global_position).normalized() * 40 * delta
		"soul_chain":
			if cast_data["i"] == 0 and cast_t < 0.8:
				cast_data["i"] = 1
				b.enemy_beam(global_position + Vector2(0, -radius), cast_data["dir"], 380, 20, 0.5, dmg, Color(0.6, 0.3, 1))

func _anim(delta:float) -> void:
	var sc := scale_base * (0.5 + 0.5 * clampf(1.0 - spawn_t / 0.5, 0, 1))
	if spr:
		var bob = abs(sin(walk)) * 2.0
		var squ := 1.0
		if state in ["windup", "shoot_wind", "cast_wind", "dash_wind"] or casting != "":
			squ = 1.0 + 0.08 * sin(t * 30)
		spr.scale = Vector2(facing * sc * squ, sc / squ)
		spr.position.y = -bob
		var f := flash
		var fc := Color(1, 1, 1)
		if freeze > 0:
			f = max(f, 0.55)
			fc = Color(0.6, 0.9, 1)
		elif petrify > 0:
			f = max(f, 0.6)
			fc = Color(0.55, 0.55, 0.55)
		elif poison > 0 and flash <= 0:
			f = 0.15 + 0.1 * sin(t * 6)
			fc = Color(0.5, 1, 0.3)
		elif burn > 0 and flash <= 0:
			f = 0.12 + 0.08 * sin(t * 12)
			fc = Color(1, 0.5, 0.2)
		if is_boss and phase >= 2 and flash <= 0:
			f = max(f, 0.08 + 0.06 * sin(t * 8))
			fc = Color(1, 0.2, 0.2)
		mat.set_shader_parameter("flash", f)
		mat.set_shader_parameter("flash_col", fc)
	queue_redraw()

func _draw() -> void:
	var w := radius * 1.1
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if wisp_col.a > 0:
		# 火灵：程序化火焰球
		var h := -radius - 6 - sin(t * 4) * 3
		var sc := clampf(1.0 - spawn_t / 0.5, 0.2, 1)
		for i in 5:
			var rr := radius * (1.0 - i * 0.16) * sc
			var c := wisp_col.lerp(Color.WHITE, i * 0.2)
			c.a = 0.35 + i * 0.13
			var off := Vector2(sin(t * 7 + i) * 2, -i * radius * 0.25)
			draw_circle(Vector2(0, h) + off, rr, c)
		if flash > 0:
			draw_circle(Vector2(0, h), radius, Color(1, 1, 1, flash))
		# 眼睛
		draw_circle(Vector2(-radius * 0.3 * facing, h - 2), 2, Color(0.1, 0, 0))
		draw_circle(Vector2(radius * 0.3 * facing, h - 2), 2, Color(0.1, 0, 0))
	# 状态图标
	if not is_boss:
		var y = -radius * 2.4 - (spr.texture.get_height() * 0.6 * scale_base if spr and spr.texture else 10)
		if hp < hp_max:
			var bw := max(20.0, radius * 2)
			draw_rect(Rect2(-bw / 2, y, bw, 3), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(-bw / 2, y, bw * hp / hp_max, 3), Color(0.9, 0.25, 0.2) if not is_elite else Color(1, 0.7, 0.2))
		var ix := -10.0
		if poison > 0:
			draw_string(G.font, Vector2(ix, y - 3), "毒%d" % poison, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1, 0.3))
			ix += 18
		if burn > 0:
			draw_string(G.font, Vector2(ix, y - 3), "焚", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.5, 0.2))
			ix += 10
		if freeze > 0 or stun > 0 or petrify > 0:
			draw_string(G.font, Vector2(ix, y - 3), "定", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.9, 1))
