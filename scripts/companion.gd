class_name Companion
extends Node2D
## AI 同伴：跟随/进攻/守护/集火 四种指令 + 合击技

var b
var cid := ""
var data: Dictionary
var spr: Sprite2D
var mode := "follow"
var cd := 1.0
var t := 0.0
var vel := Vector2.ZERO
var facing := 1.0
var combo_cd := 0.0
var focus_target = null
const MODES := {"follow": "跟随", "attack": "进攻", "guard": "守护", "focus": "集火"}

func setup(battle, id:String) -> void:
	b = battle
	cid = id
	data = D.companions[id]
	spr = Sprite2D.new()
	spr.texture = G.spr(data["spr"])
	if spr.texture:
		spr.offset = Vector2(0, -spr.texture.get_height() * 0.5)
		var s := 44.0 / spr.texture.get_height()
		spr.scale = Vector2(s, s)
	spr.modulate = Color(1, 1, 1, 0.92) if id != "yaolao" else Color(0.85, 0.95, 1, 0.75)
	add_child(spr)

func _physics_process(delta:float) -> void:
	if G.run.is_empty():
		return
	if b == null or b.paused_logic or b.player == null:
		return
	t += delta
	cd -= delta
	combo_cd -= delta
	for i in 4:
		if Input.is_action_just_pressed("cmd%d" % (i + 1)):
			mode = MODES.keys()[i]
			b.float_text(global_position + Vector2(0, -50), data["n"] + "：" + MODES[mode], Color(0.9, 0.9, 1), false)
			Au.sfx("click")
			if mode == "focus":
				focus_target = b.nearest_enemy(b.player.get_global_mouse_position(), 200)
	if Input.is_action_just_pressed("combo"):
		_combo()
	var p = b.player
	var target_pos: Vector2 = p.global_position + Vector2(-46 * p.facing, 8)
	var enemy = null
	match mode:
		"attack":
			enemy = b.nearest_enemy(global_position, 500)
			if enemy:
				target_pos = enemy.global_position + (global_position - enemy.global_position).normalized() * 110
		"guard":
			target_pos = p.global_position + Vector2(cos(t * 1.5), sin(t * 1.5) * 0.6) * 40
			enemy = b.nearest_enemy(p.global_position, 200)
		"focus":
			if focus_target == null or not is_instance_valid(focus_target) or focus_target.dead:
				focus_target = b.nearest_enemy(p.global_position, 500)
			enemy = focus_target
			if enemy:
				target_pos = enemy.global_position + (global_position - enemy.global_position).normalized() * 90
		_:
			enemy = b.nearest_enemy(global_position, 320)
	var d := target_pos - global_position
	var want := Vector2.ZERO
	if d.length() > 12:
		want = d.normalized() * min(d.length() * 4, 200)
	vel = vel.lerp(want, clampf(delta * 6, 0, 1))
	global_position += vel * delta
	b.clamp_to_arena(self, true)
	if enemy and cd <= 0:
		_attack(enemy)
	if abs(vel.x) > 5:
		facing = sign(vel.x)
	var bob = sin(t * 3) * 3 if cid == "yaolao" else abs(sin(t * 8 * min(1.0, vel.length() / 80))) * 2
	spr.position.y = -bob - (6 if cid == "yaolao" else 0)
	spr.scale.x = abs(spr.scale.x) * facing
	queue_redraw()

func _attack(enemy) -> void:
	var rate: float = data["rate"]
	cd = rate
	var dmg: float = data["atk"] * (1.0 + G.rpow() * 0.09) * (1.0 + b.player.st["comp_dmg"]) * (1.0 + G.meta["bond"].get(cid, 0) * 0.06)
	var dir: Vector2 = (enemy.global_position - global_position).normalized()
	var col := D.elem_color(data["elem"])
	var info := {"speed": 360, "r": 6, "dmg": dmg, "elem": data["elem"], "pierce": 0, "life": 1.3, "homing": 3.0}
	match data["elem"]:
		"cold":
			info["chill"] = 1.2
		"poison":
			info["poison"] = 1
			if cid == "xiaoyixian" and b.player.hp < b.player.st["hp_max"]:
				b.player.heal(1.5 + G.rpow() * 0.2, false)
		"wind":
			info["pierce"] = 2
			info["crescent"] = true
	b.fire_proj(global_position + Vector2(0, -22), dir, info, col)

func _combo() -> void:
	if combo_cd > 0:
		b.float_text(global_position + Vector2(0, -50), "合击冷却 %d" % int(combo_cd), Color(0.7, 0.7, 0.7), false)
		return
	if b.combo_energy < 100:
		b.float_text(global_position + Vector2(0, -50), "默契值 %d%%" % int(b.combo_energy), Color(0.7, 0.7, 0.7), false)
		return
	b.combo_energy = 0
	combo_cd = 3.0
	var p = b.player
	var dmg: float = 60 * p.dmg_mult(data["elem"]) * (1.0 + G.meta["bond"].get(cid, 0) * 0.15)
	b.ult_banner("合击·" + data["combo"], D.elem_color(data["elem"]))
	var col := D.elem_color(data["elem"])
	match cid:
		"yaolao":
			b.cast_wave(p.global_position, 260, 400, {"dmg": dmg, "elem": "cold", "freeze": 1.5}, Color(0.7, 0.9, 1))
			b.cast_wave(p.global_position, 200, 300, {"dmg": dmg * 0.6, "elem": "fire", "burn": 3}, Color(1, 0.5, 0.2))
		"xuner":
			for i in 8:
				var pos: Vector2 = p.global_position + Vector2.RIGHT.rotated(TAU * i / 8) * 110
				b._delayed_aoe(pos, 60, 0.5 + i * 0.05, {"dmg": dmg * 0.6, "elem": "gold", "burn": 2}, col, 3, false, true)
		"xiaoyixian":
			b.spawn_zone(p.global_position, 200, 6.0, 0.3, dmg * 0.12, col, {"poison": 2}, "poison", true)
			p.add_buff("regen", 6.0, 6.0)
		"medusa":
			for e in b.enemies:
				e.petrify = 2.5 if not e.is_boss else 0.8
			b.aoe_damage(p.global_position, 600, {"dmg": dmg * 0.8, "elem": "poison", "poison": 3})
			b.H.screen_flash(Color(0.7, 0.4, 1))
		"yunyun":
			for i in 16:
				var pos2: Vector2 = p.global_position + Vector2(randf_range(-200, 200), randf_range(-140, 140))
				b._delayed_aoe(pos2, 40, 0.4 + i * 0.04, {"dmg": dmg * 0.4, "elem": "wind", "knock": 100}, col, 2, false, true)
	b.shake(8)
	Au.sfx("big_explode", -3)

func _draw() -> void:
	if cid != "yaolao":
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		draw_circle(Vector2(0, -24), 22, Color(0.6, 0.85, 1, 0.08 + 0.04 * sin(t * 3)))
