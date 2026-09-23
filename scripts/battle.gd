class_name Battle
extends Node2D
## 战斗场景：竞技场生成、弹幕、斗技释放、敌人波次、掉落、境界突破、同伴、HUD

signal finished(result:String)

var main
var cfg := {}
var arena := Rect2(0, 0, 1100, 760)
var world: Node2D
var ysort: Node2D
var fxlayer: Node2D
var bulletlayer: BulletLayer
var cam: Camera2D
var hud: CanvasLayer
var player: Player
var comp: Companion
var enemies: Array = []
var obstacles: Array = []   # [pos, r]
var pprojs: Array = []
var ebullets: Array = []
var zones: Array = []
var orbits: Array = []
var delayed: Array = []
var summons: Array = []
var particles: Array = []
var pickups: Array = []
var beams: Array = []
var traps: Array = []
var decoy := {}
var paused_logic := false
var in_menu := false
var using_pad := false
var room_type := ""
var boss_active := false
var boss_ref: Enemy = null
var waves_left := 0
var wave_timer := 0.0
var cleared := false
var shake_amt := 0.0
var hitstop_t := 0.0
var time_in_room := 0.0
var endless_wave := 0
var boss_queue: Array = []
var ended := false
var vignette_t := 0.0
var biome := "forest"
var amb_t := 0.0
var combo_energy := 0.0
var ult_banner_node: Control
var H: BattleHUD

func setup(m, c:Dictionary) -> void:
	main = m
	cfg = c
	room_type = c.get("type", "fight")
	biome = c.get("biome", "forest")
	var big: bool = room_type in ["boss", "elite", "trial"]
	arena = Rect2(0, 0, 1200 if big else 1080, 800 if big else 720)
	if room_type == "endless":
		arena = Rect2(0, 0, 1400, 900)

func _ready() -> void:
	add_to_group("battle")
	world = Node2D.new()
	add_child(world)
	_build_floor()
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	world.add_child(ysort)
	_build_decor()
	bulletlayer = BulletLayer.new()
	bulletlayer.b = self
	bulletlayer.z_index = 10
	world.add_child(bulletlayer)
	fxlayer = Node2D.new()
	fxlayer.z_index = 20
	world.add_child(fxlayer)
	var cm := CanvasModulate.new()
	var ch: Dictionary = D.chapters[int(G.run.get("chapter", 1))]
	cm.color = ch.get("tint", Color.WHITE)
	if biome == "lava":
		cm.color = Color(0.95, 0.85, 0.8)
	add_child(cm)
	player = Player.new()
	player.position = arena.get_center() + Vector2(0, 200)
	ysort.add_child(player)
	player.setup(self, G.run["char"])
	if G.run.get("comp", "") != "" and G.run["comp"] != G.run["char"]:
		comp = Companion.new()
		comp.position = player.position + Vector2(-40, 10)
		ysort.add_child(comp)
		comp.setup(self, G.run["comp"])
	cam = Camera2D.new()
	cam.position = player.position
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.limit_left = int(arena.position.x - 140)
	cam.limit_top = int(arena.position.y - 160)
	cam.limit_right = int(arena.end.x + 140)
	cam.limit_bottom = int(arena.end.y + 120)
	world.add_child(cam)
	cam.make_current()
	H = BattleHUD.new()
	H.b = self
	add_child(H)
	_start_room()

# ---------------------------------------------------------------- 场景搭建
func _build_floor() -> void:
	var tiles: Texture2D = G.tex("res://assets/tiles/%s.png" % biome)
	if tiles == null:
		return
	var src := tiles.get_image()
	src.convert(Image.FORMAT_RGBA8)
	var pad := 256
	var W := int(arena.size.x) + pad * 2
	var Hh := int(arena.size.y) + pad * 2
	var img := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(G.run.get("seed", 1)) + int(G.run.get("floor", 0)) * 13
	var nvar := src.get_width() / 64
	for y in range(0, Hh, 64):
		for x in range(0, W, 64):
			var v := rng.randi() % nvar
			if biome == "lava" and v >= 2 and rng.randf() < 0.6:
				v = rng.randi() % 2
			var tile := src.get_region(Rect2i(v * 64, 0, 64, 64))
			if biome != "yunlan" and biome != "hub":
				if rng.randf() < 0.5:
					tile.flip_x()
				if rng.randf() < 0.5:
					tile.flip_y()
			img.blit_rect(tile, Rect2i(0, 0, 64, 64), Vector2i(x, y))
	# 竞技场外变暗
	for y in Hh:
		for x in W:
			var px := x - pad
			var py := y - pad
			var dx: float = max(0.0, max(-px, px - arena.size.x))
			var dy: float = max(0.0, max(-py, py - arena.size.y))
			var d := sqrt(dx * dx + dy * dy)
			if d > 0:
				var k: float = clampf(d / 90.0, 0, 0.82)
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.darkened(k))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.position = arena.position - Vector2(pad, pad)
	spr.z_index = -20
	world.add_child(spr)
	var edge := ArenaEdge.new()
	edge.rect = arena
	edge.z_index = -19
	world.add_child(edge)

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(G.run.get("seed", 1)) + int(G.run.get("floor", 0)) * 7 + 3
	var sets := {
		"forest": ["tree", "tree", "bush", "rock"], "wutan": ["tree", "bush", "rock", "lantern"],
		"desert": ["rock_desert", "cactus", "rock_desert"], "yunlan": ["pillar", "lantern", "rock"],
		"lava": ["rock_lava", "rock_lava"], "void": ["crystal_void", "rock_lava"], "hub": ["lantern"],
	}
	var objs: Array = sets.get(biome, ["rock"])
	# 边缘装饰（不可通行）
	var step := 70.0
	var x := arena.position.x - 40
	while x < arena.end.x + 40:
		for side in [arena.position.y - 30, arena.end.y + 40]:
			if rng.randf() < 0.75:
				_add_obj(objs[rng.randi() % objs.size()], Vector2(x + rng.randf_range(-20, 20), side + rng.randf_range(-15, 15)), false)
		x += step
	var y := arena.position.y
	while y < arena.end.y:
		for side in [arena.position.x - 40, arena.end.x + 40]:
			if rng.randf() < 0.75:
				_add_obj(objs[rng.randi() % objs.size()], Vector2(side + rng.randf_range(-15, 15), y + rng.randf_range(-20, 20)), false)
		y += step
	# 场内障碍
	var inner := rng.randi_range(2, 5)
	if room_type in ["boss"]:
		inner = 2
	for i in inner:
		var p := Vector2(rng.randf_range(arena.position.x + 140, arena.end.x - 140), rng.randf_range(arena.position.y + 120, arena.end.y - 220))
		if p.distance_to(arena.get_center() + Vector2(0, 200)) < 150:
			continue
		var o: String = objs[rng.randi() % objs.size()]
		if o == "tree" and rng.randf() < 0.5:
			o = "rock"
		_add_obj(o, p, true)

func _add_obj(name:String, pos:Vector2, collide:bool) -> void:
	var t := G.tex("res://assets/obj/%s.png" % name)
	if t == null:
		return
	var s := Sprite2D.new()
	s.texture = t
	s.offset = Vector2(0, -t.get_height() * 0.5 + 4)
	s.position = pos
	if randf() < 0.5:
		s.flip_h = true
	ysort.add_child(s)
	if collide:
		obstacles.append([pos, t.get_width() * 0.32])

# ---------------------------------------------------------------- 房间流程
func _start_room() -> void:
	time_in_room = 0
	match room_type:
		"fight":
			waves_left = 2 + int(G.run["floor"]) / 4
			_spawn_wave()
		"elite", "trial":
			boss_active = true
			var bid: String = cfg.get("boss", "jialie")
			var e := spawn_enemy(bid, arena.get_center() + Vector2(0, -120), _mult(), true)
			boss_ref = e
			waves_left = 0
			if room_type == "trial":
				spawn_enemy("wolf", arena.get_center() + Vector2(-160, -80), _mult())
				spawn_enemy("wolf", arena.get_center() + Vector2(160, -80), _mult())
		"boss":
			boss_active = true
			var bid2: String = cfg.get("boss", "mushe")
			var e2 := spawn_enemy(bid2, arena.get_center() + Vector2(0, -150), _mult(), true)
			boss_ref = e2
			waves_left = 0
			Au.music("boss")
		"endless":
			endless_wave = 0
			waves_left = 999
			_spawn_wave()
		"bossrush":
			boss_queue = cfg.get("queue", ["wolfking", "mushe", "medusa", "yunshan"]).duplicate()
			_next_rush_boss()
	if room_type in ["elite", "trial"]:
		H.show_boss(boss_ref)
	elif room_type == "boss":
		H.show_boss(boss_ref)
		shake(4)
		Au.sfx("bosswarn", 0)

func _next_rush_boss() -> void:
	if boss_queue.is_empty():
		_room_clear()
		return
	boss_active = true
	var bid: String = boss_queue.pop_front()
	boss_ref = spawn_enemy(bid, arena.get_center() + Vector2(0, -150), 1.0 + (4 - boss_queue.size()) * 0.15, true)
	H.show_boss(boss_ref)
	Au.music("boss")

func _mult() -> float:
	var f: int = int(G.run.get("floor", 0))
	var ch: int = int(G.run.get("chapter", 1))
	if ch == 0:
		return 3.0
	return 1.0 + f * 0.11 + (ch - 1) * 1.6

func _spawn_wave() -> void:
	var ch: Dictionary = D.chapters[int(G.run.get("chapter", 1))]
	var pools: Array = ch.get("pool", [["wolf"]])
	var f: int = int(G.run.get("floor", 0))
	var tier := clampi(f * pools.size() / max(1, int(ch.get("floors", 10))), 0, pools.size() - 1)
	var pool: Array = pools[tier]
	var n := 4 + f / 2 + randi() % 3
	if room_type == "endless":
		endless_wave += 1
		n = 5 + endless_wave
		pool = pools[clampi(endless_wave / 3, 0, pools.size() - 1)]
		H.banner("第 %d 波" % endless_wave, Color(1, 0.7, 0.3))
		if endless_wave % 5 == 0:
			var bl := ["jialie", "mulie", "nalan", "soul_elder"]
			spawn_enemy(bl[(endless_wave / 5 - 1) % bl.size()], arena.get_center(), 1.0 + endless_wave * 0.12, true)
	if int(G.run.get("chapter", 1)) == 0:
		pool = ["soul", "wisp", "soul", "wolf_red"]
		n = 10
	var m := _mult()
	if room_type == "endless":
		m = 1.0 + endless_wave * 0.12
	for i in n:
		var kind: String = pool[randi() % pool.size()]
		var p := _spawn_point()
		spawn_enemy(kind, p, m)
	if "elite" in G.run["tianjie"] and randf() < 0.25 and ch.has("elites"):
		spawn_enemy(ch["elites"][randi() % ch["elites"].size()], _spawn_point(), m * 0.7, true)
	waves_left -= 1

func _spawn_point() -> Vector2:
	for i in 20:
		var p := Vector2(randf_range(arena.position.x + 60, arena.end.x - 60), randf_range(arena.position.y + 60, arena.end.y - 60))
		if p.distance_to(player.global_position) > 230:
			return p
	return arena.position + Vector2(80, 80)

func spawn_enemy(kind:String, pos:Vector2, mult:float, boss:bool=false) -> Enemy:
	var e := Enemy.new()
	e.position = pos
	ysort.add_child(e)
	e.setup(self, kind, boss, mult)
	enemies.append(e)
	spawn_fx("ring", pos, {"r": 30, "col": Color(0.8, 0.3, 1) if not boss else Color(1, 0.3, 0.2), "life": 0.5, "width": 3})
	if not (kind in G.meta["codex_enemies"]):
		G.meta["codex_enemies"].append(kind)
	return e

func enemy_died(e:Enemy) -> void:
	enemies.erase(e)
	G.run["kills"] = int(G.run["kills"]) + 1
	G.meta["kills"] = int(G.meta["kills"]) + 1
	player.on_kill(e)
	var data := e.data
	var ex: float = float(data.get("exp", 5)) if not e.is_boss else (60.0 if e.is_elite else 200.0)
	var gd: int = int(data.get("gold", 2)) if not e.is_boss else (40 if e.is_elite else 120)
	var n := clampi(int(ex / 4.0), 1, 18)
	for i in n:
		_drop("exp", e.global_position, ex / n)
	var gn := clampi(gd / 3, 1, 12)
	for i in gn:
		if randf() < 0.7 or e.is_boss:
			_drop("gold", e.global_position, float(gd) / gn)
	if randf() < (0.06 if not e.is_boss else 1.0):
		var hk: Array = D.herbs.keys()
		_drop("herb:" + hk[randi() % hk.size()], e.global_position, 1)
	if randf() < 0.02:
		_drop("heal", e.global_position, 15)
	if player.st["explode_kill"] or e.poison > 0 and G.run["atk"] == "atk_poison":
		var col := Color(1, 0.5, 0.2) if player.st["explode_kill"] else Color(0.5, 1, 0.3)
		spawn_fx("burst", e.global_position, {"r": 50, "col": col, "life": 0.35})
		aoe_damage(e.global_position, 55, {"dmg": 12 * player.dmg_mult("fire"), "elem": "fire" if player.st["explode_kill"] else "poison", "poison": 2 if col.g > 0.9 else 0}, e)
	if e.is_boss:
		shake(10)
		do_hitstop(0.25)
		Au.sfx("big_explode")
		spawn_fx("burst", e.global_position, {"r": 140, "col": Color(1, 0.8, 0.4), "life": 0.8})
		spawn_fx("ring", e.global_position, {"r": 260, "col": Color(1, 0.6, 0.3), "life": 0.9, "width": 10})
		if e == boss_ref:
			boss_active = false
			H.hide_boss()
			if player.no_hit_boss and not e.is_elite:
				G.unlock_ach("ach_nohit")
			if e.is_elite and int(G.run["realm"]) < 3:
				G.unlock_ach("ach_mqsnq")
			if room_type == "bossrush":
				get_tree().create_timer(2.0, false).timeout.connect(_next_rush_boss)
				return
			# Boss 死亡：清场
			for o in enemies.duplicate():
				o.die()
	else:
		Au.sfx("hit", -6, 0.6)
	if G.meta["kills"] >= 500:
		G.unlock_ach("ach_kill500")

func _drop(kind:String, pos:Vector2, val:float) -> void:
	var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60, 180)
	pickups.append({"k": kind, "p": pos + Vector2(0, -10), "v": v, "val": val, "t": 0.0, "z": 0.0, "vz": randf_range(80, 160)})

func _room_clear() -> void:
	if cleared:
		return
	cleared = true
	# 吸取所有掉落
	for pk in pickups:
		pk["t"] = 10.0
	await get_tree().create_timer(0.9, false).timeout
	if ended:
		return
	var heal_room: float = player.st["room_heal"]
	if heal_room > 0:
		player.heal(heal_room)
	G.run["hp"] = player.hp
	if G.run["buffs"].has("next_fight_dmg"):
		G.run["buffs"].erase("next_fight_dmg")
	H.banner("清剿完毕" if room_type == "fight" else "胜利！", Color(1, 0.85, 0.4))
	Au.sfx("levelup", -4)
	await get_tree().create_timer(1.2, false).timeout
	if ended:
		return
	ended = true
	finished.emit("win")

func player_died() -> void:
	if ended:
		return
	ended = true
	Au.sfx("death")
	do_hitstop(0.5)
	Engine.time_scale = 0.3
	player.spr.modulate = Color(1, 0.4, 0.4)
	H.banner("陨落……", Color(1, 0.3, 0.3))
	await get_tree().create_timer(0.6, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.8, false).timeout
	finished.emit("dead")

# ---------------------------------------------------------------- 主循环
func _physics_process(delta:float) -> void:
	if paused_logic:
		return
	time_in_room += delta
	G.run["time"] = float(G.run.get("time", 0)) + delta
	_update_pickups(delta)
	_update_pprojs(delta)
	_update_ebullets(delta)
	_update_zones(delta)
	_update_orbits(delta)
	_update_delayed(delta)
	_update_summons(delta)
	_update_beams(delta)
	_update_traps(delta)
	_update_particles(delta)
	if decoy.size() > 0:
		decoy["t"] -= delta
		if decoy["t"] <= 0:
			decoy = {}
	# 波次
	if not cleared and not ended and room_type != "bossrush":
		if enemies.is_empty():
			if waves_left > 0:
				wave_timer -= delta
				if wave_timer <= 0:
					_spawn_wave()
					wave_timer = 0.6
			elif room_type != "endless":
				_room_clear()
		elif waves_left > 0 and room_type == "endless" and enemies.size() < 4:
			_spawn_wave()
	if "time" in G.run["tianjie"] and room_type == "fight" and time_in_room > 90 and not cleared:
		player.hp -= player.st["hp_max"] * 0.02 * delta
		if player.hp <= 0 and not player.dead:
			player._try_die()
	# 相机
	var target := player.global_position + Vector2(0, -20) + player.aim * 30
	cam.position = target
	if shake_amt > 0 and G.settings["shake"]:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt = max(0.0, shake_amt - delta * 40)
	else:
		cam.offset = Vector2.ZERO
	# 环境粒子
	amb_t -= delta
	if amb_t <= 0:
		amb_t = 0.12 / max(0.3, G.settings["fx"])
		_ambient()
	bulletlayer.queue_redraw()

func _process(delta:float) -> void:
	if hitstop_t > 0:
		hitstop_t -= delta / max(Engine.time_scale, 0.01)
		if hitstop_t <= 0:
			Engine.time_scale = 1.0

func do_hitstop(t:float) -> void:
	if not G.settings["hitstop"]:
		return
	hitstop_t = t
	Engine.time_scale = 0.05

func shake(v:float) -> void:
	shake_amt = max(shake_amt, v)

func _ambient() -> void:
	var r := Rect2(cam.get_screen_center_position() - Vector2(500, 300), Vector2(1000, 600))
	var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
	match biome:
		"forest", "wutan":
			particles.append({"p": p, "v": Vector2(randf_range(10, 30), randf_range(15, 30)), "t": 0.0, "life": 4.0, "c": Color(0.6, 0.9, 0.4, 0.5), "s": 2.0, "g": 0.0, "add": false})
		"desert":
			particles.append({"p": p, "v": Vector2(randf_range(60, 120), randf_range(-5, 5)), "t": 0.0, "life": 2.0, "c": Color(1, 0.85, 0.6, 0.4), "s": 1.5, "g": 0.0, "add": false})
		"lava", "void":
			particles.append({"p": p, "v": Vector2(randf_range(-10, 10), randf_range(-40, -20)), "t": 0.0, "life": 3.0, "c": Color(1, 0.5, 0.2, 0.8) if biome == "lava" else Color(0.7, 0.5, 1, 0.8), "s": 1.5, "g": 0.0, "add": true})
		"yunlan":
			particles.append({"p": p, "v": Vector2(randf_range(20, 40), randf_range(-5, 5)), "t": 0.0, "life": 4.0, "c": Color(1, 1, 1, 0.25), "s": 3.0, "g": 0.0, "add": false})

# ---------------------------------------------------------------- 工具
func clamp_to_arena(n:Node2D, solid:bool) -> void:
	var p := n.global_position
	p.x = clampf(p.x, arena.position.x + 10, arena.end.x - 10)
	p.y = clampf(p.y, arena.position.y + 20, arena.end.y - 6)
	if solid:
		for o in obstacles:
			var d: Vector2 = p - o[0]
			var rr: float = o[1] + 8
			if d.length() < rr:
				p = o[0] + d.normalized() * rr
	n.global_position = p

func enemy_count() -> int:
	return enemies.size()

func nearest_enemy(pos:Vector2, rng:float, exclude=null):
	var best = null
	var bd := rng
	for e in enemies:
		if e == exclude or e.dead or e.spawn_t > 0.3:
			continue
		var d: float = e.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best

func enemies_in(pos:Vector2, r:float) -> Array:
	var out := []
	for e in enemies:
		if not e.dead and e.global_position.distance_to(pos) < r + e.radius:
			out.append(e)
	return out

func separation(me:Enemy) -> Vector2:
	var f := Vector2.ZERO
	for e in enemies:
		if e == me:
			continue
		var d: Vector2 = me.global_position - e.global_position
		var l := d.length()
		var mn: float = me.radius + e.radius
		if l < mn and l > 0.01:
			f += d / l * (mn - l) / mn
	for o in obstacles:
		var d2: Vector2 = me.global_position - o[0]
		if d2.length() < o[1] + me.radius + 10:
			f += d2.normalized()
	return f

func decoy_pos():
	if decoy.size() > 0:
		return decoy["p"]
	return null

func spawn_decoy(pos:Vector2, dur:float) -> void:
	decoy = {"p": pos, "t": dur}
	afterimage(player, dur)

func spawn_fx(type:String, pos:Vector2, o:Dictionary={}) -> Fx:
	if G.settings["fx"] < 0.3 and type in ["glow", "petal_ring"]:
		return null
	var f := Fx.new()
	f.type = type
	f.position = pos
	for k in o:
		f.set(k, o[k])
	fxlayer.add_child(f)
	return f

func float_text(pos:Vector2, txt:String, col:Color, big:bool) -> void:
	var f := Fx.new()
	f.type = "text"
	f.text = txt
	f.col = col
	f.big = big
	f.life = 0.9 if not big else 1.3
	f.vel = Vector2(randf_range(-30, 30), -120 if not big else -80)
	f.position = pos
	fxlayer.add_child(f)

func afterimage(n:Node2D, life:float=0.25) -> void:
	var s: Sprite2D = n.spr if "spr" in n else null
	if s == null or s.texture == null:
		return
	var a := Sprite2D.new()
	a.texture = s.texture
	a.offset = s.offset
	a.scale = s.scale
	a.rotation = s.rotation
	a.global_position = s.global_position
	a.modulate = Color(0.6, 0.8, 1, 0.5) if n == player else Color(1, 0.4, 0.4, 0.5)
	a.material = Fx.additive()
	fxlayer.add_child(a)
	var tw := a.create_tween()
	tw.tween_property(a, "modulate:a", 0.0, life)
	tw.tween_callback(a.queue_free)

func particles_trail(pos:Vector2, col:Color) -> void:
	for i in 2:
		particles.append({"p": pos + Vector2(randf_range(-8, 8), randf_range(-8, 8)), "v": Vector2(randf_range(-30, 30), randf_range(-60, -10)), "t": 0.0, "life": 0.5, "c": col, "s": 3.0, "g": 0.0, "add": true})

func burst_particles(pos:Vector2, col:Color, n:int, spd:float=200.0, size:float=2.5) -> void:
	n = int(n * G.settings["fx"])
	for i in n:
		var v := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(spd * 0.3, spd)
		particles.append({"p": pos, "v": v, "t": 0.0, "life": randf_range(0.25, 0.6), "c": col, "s": size, "g": 120.0, "add": true})

func hitspark(pos:Vector2, col:Color, crit:bool) -> void:
	burst_particles(pos, col.lerp(Color.WHITE, 0.4), 6 if not crit else 14, 180 if not crit else 280)
	if crit:
		spawn_fx("burst", pos, {"r": 28, "col": col, "life": 0.2})
		do_hitstop(0.04)

func blink_fx(a:Vector2, b2:Vector2, col:Color) -> void:
	var f := spawn_fx("bolt", a + Vector2(0, -20), {"ang": (b2 - a).angle(), "length": a.distance_to(b2), "col": col, "life": 0.25})
	spawn_fx("ring", a, {"r": 40, "col": col, "life": 0.3, "width": 4})
	spawn_fx("ring", b2, {"r": 40, "col": col, "life": 0.3, "width": 4})
	burst_particles(b2 + Vector2(0, -20), col, 10)

func hit_vignette() -> void:
	H.flash_damage()

# ---------------------------------------------------------------- 伤害接口
func deal(e:Enemy, info:Dictionary, from:Vector2) -> void:
	var v: float = e.hurt(info, from)
	if v > 0:
		player.on_hit_enemy(info, v)
		var en: float = v * 0.35 * (1.0 + player.st["energy"]) * (2.0 if info.get("energy_affix", false) else 1.0)
		combo_energy = min(100.0, combo_energy + v * 0.08)
		# 大招冷却加速（能量）
		for u in G.run["ults"]:
			if player.cds.get(u, 0.0) > 0:
				player.cds[u] -= en * 0.004
		if info.get("thunder_affix", false) and randf() < 0.2:
			spawn_fx("pillar", e.global_position, {"r": 14, "col": Color(0.7, 0.6, 1), "life": 0.3})
			deal_area(e.global_position, 40, {"dmg": info["dmg"] * 0.5, "elem": "thunder", "stun": 0.3})

func aoe_damage(pos:Vector2, r:float, info:Dictionary, exclude=null) -> void:
	for e in enemies_in(pos, r):
		if e != exclude:
			deal(e, info, pos)

func deal_area(pos:Vector2, r:float, info:Dictionary) -> void:
	aoe_damage(pos, r, info)

func melee_arc(pos:Vector2, dir:Vector2, rng:float, ang:float, info:Dictionary, col:Color, fin:bool=false) -> void:
	spawn_fx("slash", pos, {"ang": dir.angle(), "arc": ang, "r": rng, "col": col, "life": 0.22 if not fin else 0.3, "width": 10 if not fin else 16})
	var hit := false
	for e in enemies.duplicate():
		if e.dead:
			continue
		var d: Vector2 = (e.global_position + Vector2(0, -e.radius)) - pos
		if d.length() < rng + e.radius and abs(dir.angle_to(d)) < ang * 0.5 + 0.2:
			deal(e, info, player.global_position)
			hit = true
	if hit and fin:
		do_hitstop(0.06)
		shake(3)

func fire_proj(pos:Vector2, dir:Vector2, info:Dictionary, col:Color) -> void:
	var p := info.duplicate()
	p["p"] = pos
	p["v"] = dir.normalized() * float(info.get("speed", 400))
	p["col"] = col
	p["t"] = 0.0
	p["hit"] = {}
	p["origin"] = pos
	if not p.has("life"):
		p["life"] = 1.2
	pprojs.append(p)

func cast_wave(pos:Vector2, r:float, spd:float, info:Dictionary, col:Color) -> void:
	zones.append({"type": "wave", "p": pos, "r": 0.0, "rmax": r, "spd": spd, "info": info, "col": col, "hit": {}, "t": 0.0})
	spawn_fx("ring", pos, {"r": r, "r2": 10, "col": col, "life": r / spd, "width": 12})

func cast_beam(pos:Vector2, dir:Vector2, length:float, width:float, dur:float, info:Dictionary, col:Color, tick:float=0.12) -> void:
	beams.append({"p": pos, "dir": dir, "len": length, "w": width, "t": dur, "info": info, "col": col, "tick": 0.0, "rate": tick, "follow": true})
	spawn_fx("beam", pos, {"ang": dir.angle(), "length": length, "width": width, "col": col, "life": dur, "follow": null})

func spawn_zone(pos:Vector2, r:float, dur:float, tick:float, dmg:float, col:Color, extra:Dictionary, elem:String, follow:bool=false) -> void:
	var info := extra.duplicate()
	info["dmg"] = dmg
	info["elem"] = elem
	zones.append({"type": "zone", "p": pos, "r": r, "t": dur, "life": dur, "tick": 0.0, "rate": tick, "info": info, "col": col, "follow": follow, "pull": float(extra.get("pull", 0)), "moving": extra.get("moving", false)})

func chain_lightning(pos:Vector2, jumps:int, rng:float, info:Dictionary, exclude=null) -> void:
	var cur := pos
	var hit := {}
	if exclude:
		hit[exclude] = true
	for i in jumps:
		var best = null
		var bd := rng
		for e in enemies:
			if e.dead or hit.has(e):
				continue
			var d: float = e.global_position.distance_to(cur)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		hit[best] = true
		var col := D.elem_color(info.get("elem", "thunder"))
		spawn_fx("bolt", cur + Vector2(0, -16), {"ang": (best.global_position - cur).angle(), "length": cur.distance_to(best.global_position), "col": col, "life": 0.22})
		deal(best, info, cur)
		if info.has("explode"):
			spawn_fx("burst", best.global_position, {"r": info["explode"], "col": col, "life": 0.3})
			aoe_damage(best.global_position, info["explode"], {"dmg": info["dmg"] * 0.5, "elem": info["elem"]}, best)
		cur = best.global_position
	Au.sfx("thunder_small", -6)

func spawn_summon(pos:Vector2, dmg:float, dur:float, col:Color) -> void:
	summons.append({"p": pos, "t": dur, "dmg": dmg, "col": col, "cd": 0.0, "v": Vector2.ZERO})
	spawn_fx("ring", pos, {"r": 30, "col": col, "life": 0.4, "width": 4})

# ---------------------------------------------------------------- 斗技释放
func cast_skill(p:Player, id:String, s:Dictionary, g:int, aff:Array, dir:Vector2) -> void:
	var pr: Dictionary = s["p"]
	var elem: String = s["elem"]
	var col := D.elem_color(elem)
	if elem == "fire" and G.run["fires"].size() > 0:
		col = D.fire_by_id[G.run["fires"][randi() % G.run["fires"].size()]]["c"].lerp(col, 0.3)
	var dmg: float = s["dmg"] * (1.0 + 0.12 * g) * p.dmg_mult(elem)
	if "dmg" in aff:
		dmg *= 1.25
	var area: float = 1.0 + p.st["area"] + (0.3 if "size" in aff else 0.0)
	var extra_count: int = int(p.st["proj"]) + (1 if "count" in aff else 0) + g / 4
	var info := {"dmg": dmg, "elem": elem, "knock": float(pr.get("knock", 40))}
	for k in ["burn", "chill", "freeze", "stun", "poison", "petrify", "weaken", "lifesteal"]:
		if pr.has(k):
			info[k] = pr[k]
	if "burn" in aff: info["burn"] = int(info.get("burn", 0)) + 2
	if "chill" in aff: info["chill"] = 1.5
	if "poison" in aff: info["poison"] = int(info.get("poison", 0)) + 2
	if "crit" in aff: info["crit_bonus"] = 0.2
	if "leech" in aff: info["lifesteal"] = float(info.get("lifesteal", 0)) + 0.06
	if "stun" in aff: info["stun"] = max(0.3, float(info.get("stun", 0)))
	if "knock" in aff: info["knock"] = float(info["knock"]) + 250
	if "weaken" in aff: info["weaken"] = 3
	if "exec" in aff: info["exec"] = true
	if "energy" in aff: info["energy_affix"] = true
	if "thunder" in aff: info["thunder_affix"] = true
	if "elite" in aff: info["elite_bonus"] = 0.4
	var origin := p.global_position + Vector2(0, -18)
	var target := p.get_global_mouse_position() if not using_pad else p.global_position + dir * 160
	if using_pad or s["cat"] != "ult" and not Input.is_action_pressed(["art1", "art2", "art3", "art4"][0]) and G.run["auto"].get(id, true):
		var ne = nearest_enemy(p.global_position, 330)
		if ne and G.run["auto"].get(id, true):
			target = ne.global_position
	var tr: float = float(pr.get("range", 260))
	if target.distance_to(p.global_position) > 260:
		target = p.global_position + (target - p.global_position).normalized() * 260
	if pr.get("at_self", false):
		target = p.global_position
	match s["kind"]:
		"proj":
			var cnt: int = int(pr.get("count", 1)) + extra_count
			var spread: float = deg_to_rad(float(pr.get("spread", 12)))
			for i in cnt:
				var off: float = 0.0 if cnt == 1 else (i - (cnt - 1) * 0.5) * spread / max(1, cnt - 1) * 2.0
				var pi := info.duplicate()
				pi["speed"] = pr.get("speed", 400)
				pi["r"] = float(pr.get("size", 8)) * area
				pi["pierce"] = int(pr.get("pierce", 0)) + (2 if "pierce" in aff else 0)
				pi["homing"] = float(pr.get("homing", 0))
				pi["crescent"] = pr.get("crescent", false)
				pi["explode"] = float(pr.get("explode", 0)) * area
				pi["life"] = 1.4
				fire_proj(origin + dir * 8, dir.rotated(off), pi, col)
			Au.sfx("whoosh_fire" if elem == "fire" else ("ice" if elem == "cold" else "shoot"), -4)
		"nova":
			var cnt2: int = int(pr.get("count", 8)) + extra_count * 2
			for i in cnt2:
				var pi2 := info.duplicate()
				pi2["speed"] = pr.get("speed", 350)
				pi2["r"] = float(pr.get("size", 8)) * area
				pi2["pierce"] = int(pr.get("pierce", 0)) + (2 if "pierce" in aff else 0)
				pi2["homing"] = float(pr.get("homing", 0))
				pi2["life"] = 1.2
				fire_proj(origin, Vector2.RIGHT.rotated(TAU * i / cnt2 + randf() * 0.1), pi2, col)
			spawn_fx("ring", p.global_position, {"r": 80 * area, "col": col, "life": 0.35, "width": 6})
			Au.sfx("whoosh_fire", -2)
			if pr.get("awaken", false):
				p.awaken_t = 10.0
				p.blood = 0
		"aoe":
			var r: float = float(pr.get("radius", 60)) * area
			var pos = target if not pr.has("range") else p.global_position + dir * min(float(pr["range"]), target.distance_to(p.global_position))
			var delay: float = float(pr.get("delay", 0.3))
			var ii := info.duplicate()
			_delayed_aoe(pos, r, delay, ii, col, float(pr.get("shake", 3)), s["cat"] == "ult")
		"arc":
			var multi: int = int(pr.get("multi", 1))
			for i in multi:
				var cb := func():
					if is_instance_valid(p) and not p.dead:
						melee_arc(p.global_position + Vector2(0, -14), p.aim.rotated(randf_range(-0.3, 0.3)), float(pr.get("range", 50)) * area, deg_to_rad(float(pr.get("angle", 90))), info, col, i == multi - 1)
						Au.sfx("swing", -8, 1.3)
				if i == 0:
					cb.call()
				else:
					get_tree().create_timer(float(pr.get("interval", 0.06)) * i, false).timeout.connect(cb)
		"dash":
			var dist: float = float(pr.get("dist", 180))
			var from := p.global_position
			var to := from + dir * dist
			to.x = clampf(to.x, arena.position.x + 10, arena.end.x - 10)
			to.y = clampf(to.y, arena.position.y + 20, arena.end.y - 6)
			var w: float = float(pr.get("width", 40)) * area
			for e in enemies.duplicate():
				var cp := Geometry2D.get_closest_point_to_segment(e.global_position, from, to)
				if cp.distance_to(e.global_position) < w * 0.5 + e.radius:
					deal(e, info, from)
			p.global_position = to
			p.iframe = max(p.iframe, 0.3)
			var steps := 8
			for i in steps:
				var pp := from.lerp(to, float(i) / steps)
				spawn_fx("glow", pp + Vector2(0, -16), {"r": w * 0.6, "col": col, "life": 0.3 + i * 0.02})
				if pr.get("trail", false) or pr.has("burn"):
					spawn_zone(pp, w * 0.5, 2.0, 0.3, dmg * 0.15, col, {"burn": 1}, elem)
			spawn_fx("bolt", from + Vector2(0, -16), {"ang": dir.angle(), "length": from.distance_to(to), "col": col, "life": 0.3})
			shake(4)
			Au.sfx("dash", 0)
		"beam":
			cast_beam(origin, dir, float(pr.get("len", 300)) * area, float(pr.get("width", 24)) * area, float(pr.get("dur", 1.0)), info, col, 0.1)
			Au.sfx("charge", -4, 1.5)
		"zone":
			spawn_zone(target, float(pr.get("radius", 80)) * area, float(pr.get("dur", 4)), float(pr.get("tick", 0.3)), dmg, col, info.merged({"pull": pr.get("pull", 0), "moving": pr.get("moving", false)}), elem, pr.get("at_self", false))
			if pr.get("heal_self", false):
				p.add_buff("regen", 4.0, float(pr.get("dur", 4)))
			Au.sfx("poison" if elem == "poison" else ("ice" if elem == "cold" else "whoosh_fire"), -3)
		"orbit":
			var cnt3: int = int(pr.get("count", 3)) + extra_count
			for i in cnt3:
				var c2 := col
				if pr.get("yinyang", false):
					c2 = Color(1, 1, 1) if i % 2 == 0 else Color(0.25, 0.1, 0.35)
				orbits.append({"a": TAU * i / cnt3, "r": float(pr.get("radius", 60)) * area, "t": float(pr.get("dur", 5)), "size": float(pr.get("size", 10)) * area, "info": info, "col": c2, "hit": {}})
			Au.sfx("whoosh_fire", -4)
		"rain":
			var cnt4: int = int(pr.get("count", 8)) + extra_count * 2
			var ar: float = float(pr.get("area", 150)) * area
			for i in cnt4:
				var pos2: Vector2
				if pr.get("line", false):
					pos2 = p.global_position + dir * (40 + i * 30)
				else:
					pos2 = target + Vector2(randf_range(-ar, ar), randf_range(-ar * 0.7, ar * 0.7))
				var ii2 := info.duplicate()
				_delayed_aoe(pos2, float(pr.get("radius", 30)) * area, float(pr.get("delay", 0.4)) + i * 0.06, ii2, col, 2, false, true)
		"chain":
			var st = nearest_enemy(target, 200)
			var ii3 := info.duplicate()
			if pr.has("explode"):
				ii3["explode"] = float(pr["explode"]) * area
			chain_lightning(p.global_position, int(pr.get("jumps", 4)) + extra_count, float(pr.get("range", 150)), ii3)
		"summon":
			for i in int(pr.get("count", 2)) + extra_count:
				spawn_summon(p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 40, dmg, float(pr.get("dur", 10)), col)
		"buff":
			var dur: float = float(pr.get("dur", 5))
			for k in ["dmg", "aspd", "armor", "regen", "spd", "selfdmg"]:
				if pr.has(k):
					p.add_buff(k, float(pr[k]), dur)
			if pr.has("shield"):
				p.shield += float(pr["shield"]) * (1 + g * 0.1)
			if pr.get("possess", false):
				p.possess_t = dur
				H.banner("药老附身！", Color(0.7, 0.9, 1))
			spawn_fx("aura", p.global_position, {"r": 50, "col": col, "life": dur, "follow": p})
			spawn_fx("ring", p.global_position, {"r": 70, "col": col, "life": 0.4, "width": 6})
			Au.sfx("levelup", -6, 1.2)
		"pull":
			var r2: float = float(pr.get("radius", 130)) * area
			var cpos := p.global_position + dir * 50 if not pr.get("at_self", false) else p.global_position
			for e in enemies_in(cpos, r2):
				var strength := float(pr.get("pull", 250)) * (0.25 if e.is_boss else 1.0)
				e.knock += (cpos - e.global_position).normalized() * strength
			spawn_fx("ring", cpos, {"r": 10, "r2": r2, "col": col, "life": 0.35, "width": 6})
			get_tree().create_timer(0.25, false).timeout.connect(func():
				spawn_fx("burst", cpos, {"r": 60 * area, "col": col, "life": 0.3})
				aoe_damage(cpos, 60 * area, info)
				shake(4))
			Au.sfx("charge", -4, 2.0)
		"wave":
			cast_wave(p.global_position, float(pr.get("radius", 150)) * area, float(pr.get("speed", 350)), info, col)
			shake(float(pr.get("shake", 3)))
			Au.sfx("heavy", -3)
		"trap":
			for i in int(pr.get("count", 3)) + extra_count:
				traps.append({"p": target + Vector2(randf_range(-60, 60), randf_range(-40, 40)), "arm": float(pr.get("arm", 0.5)), "r": float(pr.get("radius", 50)) * area, "info": info, "col": col, "t": 12.0})
		"lotus":
			_cast_lotus(p, target, dmg, info, area, pr)
	# 毒爆
	if pr.get("detonate", false):
		for e in enemies_in(p.global_position, float(pr.get("radius", 150)) * area):
			if e.poison > 0:
				var bonus: float = e.poison * 6.0 * p.dmg_mult("poison") * (1.0 + float(p.st.get("poison_dmg", 0)))
				deal(e, {"dmg": bonus, "elem": "poison"}, p.global_position)
				spawn_fx("burst", e.global_position, {"r": 30 + e.poison * 2, "col": Color(0.5, 1, 0.3), "life": 0.3})
				e.poison = 0

func _delayed_aoe(pos:Vector2, r:float, delay:float, info:Dictionary, col:Color, shk:float, big:bool, pillar:bool=false) -> void:
	if delay > 0.05:
		spawn_fx("tele_circle", pos, {"r": r, "col": col, "life": delay})
	delayed.append({"p": pos, "r": r, "t": delay, "info": info, "col": col, "shake": shk, "big": big, "pillar": pillar, "enemy": false})

func _cast_lotus(p:Player, target:Vector2, dmg:float, info:Dictionary, area:float, pr:Dictionary) -> void:
	var cols: Array = []
	for f in G.run["fires"]:
		cols.append(D.fire_by_id[f]["c"])
	if cols.is_empty():
		cols = [Color(1, 0.5, 0.2)]
	var n := cols.size()
	var r: float = float(pr["radius"]) * area * (1.0 + 0.12 * n)
	var d = dmg * (1.0 + 0.35 * n) * (1.0 + 0.15 * G.run["fused_pairs"].size())
	var delay: float = pr["delay"]
	spawn_fx("lotus", target, {"r": r * 0.8, "life": delay + 0.5, "colors": cols})
	spawn_fx("tele_circle", target, {"r": r, "col": cols[0], "life": delay})
	Au.sfx("charge", -2, 0.8)
	var ii := info.duplicate()
	ii["dmg"] = d
	ii["burn"] = 3
	ii["knock"] = 350
	delayed.append({"p": target, "r": r, "t": delay, "info": ii, "col": cols[0], "shake": 16.0, "big": true, "lotus": cols, "enemy": false})

func ult_banner(n:String, col:Color) -> void:
	H.ult_banner(n, col)
	Au.voice(n)

# ---------------------------------------------------------------- 敌方攻击接口
func telegraph_line(pos:Vector2, ang:float, length:float, w:float, dur:float, col:Color) -> void:
	spawn_fx("tele_line", pos, {"ang": ang, "length": length, "width": w, "col": col, "life": dur})

func telegraph_fan(pos:Vector2, ang:float, arc:float, r:float, dur:float, col:Color) -> void:
	spawn_fx("tele_fan", pos, {"ang": ang, "arc": arc, "r": r, "col": col, "life": dur})

func enemy_melee(e:Enemy, pos:Vector2, r:float, dmg:float) -> void:
	spawn_fx("slash", pos + Vector2(0, -e.radius), {"ang": (player.global_position - e.global_position).angle(), "arc": 2.0, "r": r, "col": Color(1, 0.4, 0.3), "life": 0.2, "width": 8})
	if player.global_position.distance_to(pos) < r + player.radius:
		player.take_damage(dmg, e.global_position)

func enemy_bullet(pos:Vector2, dir:Vector2, spd:float, dmg:float, elem:String, big:bool=false) -> void:
	if ebullets.size() > 600:
		return
	ebullets.append({"p": pos, "v": dir.normalized() * spd, "dmg": dmg, "col": D.elem_color(elem), "r": 5.0 if not big else 8.0, "t": 0.0, "elem": elem})

func enemy_aoe(pos:Vector2, r:float, delay:float, dmg:float, col:Color, big:bool=false) -> void:
	spawn_fx("tele_circle", pos, {"r": r, "col": col, "life": delay})
	delayed.append({"p": pos, "r": r, "t": delay, "dmg": dmg, "col": col, "shake": 3.0 if big else 1.5, "enemy": true, "big": big})

func enemy_beam(pos:Vector2, dir:Vector2, length:float, w:float, dur:float, dmg:float, col:Color) -> void:
	spawn_fx("beam", pos, {"ang": dir.angle(), "length": length, "width": w, "col": col, "life": dur})
	var end := pos + dir * length
	var cp := Geometry2D.get_closest_point_to_segment(player.global_position + Vector2(0, -16), pos, end)
	if cp.distance_to(player.global_position + Vector2(0, -16)) < w * 0.5 + player.radius:
		player.take_damage(dmg, pos)
	Au.sfx("charge", -4, 1.6)

func boss_phase(e:Enemy, ph:int, line:String) -> void:
	H.boss_line(e.data["n"], line)
	spawn_fx("ring", e.global_position, {"r": 220, "col": Color(1, 0.3, 0.2), "life": 0.8, "width": 10})
	shake(8)
	Au.sfx("bosswarn", 0)
	Au.sfx("big_explode", -6)
	# 清除弹幕
	ebullets.clear()
	e.flash = 1.0

# ---------------------------------------------------------------- 更新
func _update_pickups(delta:float) -> void:
	var mag: float = player.st["magnet"] + (2000.0 if cleared else 0.0)
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		pk["t"] += delta
		if pk["z"] > 0 or pk["vz"] > 0:
			pk["vz"] -= 500 * delta
			pk["z"] = max(0.0, pk["z"] + pk["vz"] * delta)
			if pk["z"] <= 0:
				pk["vz"] = 0
		pk["p"] += pk["v"] * delta
		pk["v"] *= 0.9
		var d: Vector2 = player.global_position + Vector2(0, -16) - pk["p"]
		var auto = pk["k"] == "exp" and pk["t"] > 0.6
		if (d.length() < mag or auto) and pk["t"] > 0.35:
			pk["v"] = d.normalized() * (380 + pk["t"] * 300)
		if d.length() < 14 and pk["t"] > 0.3:
			_collect(pk)
			pickups.remove_at(i)

func _collect(pk:Dictionary) -> void:
	var k: String = pk["k"]
	if k == "exp":
		gain_exp(pk["val"])
	elif k == "gold":
		var g: float = pk["val"] * (1.0 + player.st["gold"]) * D.DIFFS[int(G.run["diff"])]["rew"]
		G.run["gold"] = int(G.run["gold"]) + max(1, int(round(g)))
		Au.sfx("coin", -10)
		if int(G.run["gold"]) >= 1000:
			G.unlock_ach("ach_rich")
	elif k == "heal":
		player.heal(pk["val"])
		Au.sfx("pill", -6)
	elif k.begins_with("herb:"):
		var h := k.substr(5)
		G.run["herbs"][h] = int(G.run["herbs"].get(h, 0)) + 1
		float_text(player.global_position + Vector2(0, -60), "+ " + D.herbs[h]["n"], D.herbs[h]["c"], false)
		Au.sfx("pickup", -4)

func gain_exp(v:float) -> void:
	if int(G.run["chapter"]) == 0:
		return
	v *= 1.0 + player.st["exp"]
	G.run["exp"] = float(G.run["exp"]) + v
	var need := G.exp_needed(int(G.run["realm"]))
	while float(G.run["exp"]) >= need:
		if int(G.run["realm"]) >= G.realm_cap():
			G.run["exp"] = need
			break
		G.run["exp"] = float(G.run["exp"]) - need
		_realm_up()
		need = G.exp_needed(int(G.run["realm"]))

func _realm_up() -> void:
	var old_major: int = int(G.run["realm"]) / 3
	G.run["realm"] = int(G.run["realm"]) + 1
	var new_major: int = int(G.run["realm"]) / 3
	var old_slots = player.st["hp_max"]
	player.recalc()
	player.hp = min(player.st["hp_max"], player.hp + player.st["hp_max"] * 0.25)
	var col: Color = D.REALM_COLORS[clampi(new_major, 0, D.REALM_COLORS.size() - 1)]
	spawn_fx("ring", player.global_position, {"r": 120, "col": col, "life": 0.6, "width": 8})
	burst_particles(player.global_position + Vector2(0, -20), col, 30, 260, 3)
	if new_major > old_major:
		H.breakthrough(D.realm_name(int(G.run["realm"])), col)
		Au.sfx("breakthrough", -2)
		aoe_damage(player.global_position, 200, {"dmg": 30 * player.dmg_mult("phys"), "elem": "phys", "knock": 400})
		shake(8)
		if new_major >= 5 and not G.run["flags"].get("trib_done", false):
			G.run["flags"]["trib_pending"] = true
	else:
		float_text(player.global_position + Vector2(0, -80), D.realm_name(int(G.run["realm"])), col, true)
		Au.sfx("levelup", -6)

func _update_pprojs(delta:float) -> void:
	for i in range(pprojs.size() - 1, -1, -1):
		var p: Dictionary = pprojs[i]
		p["t"] += delta
		if p.get("homing", 0.0) > 0 and p["t"] > 0.08:
			var ne = nearest_enemy(p["p"], 260)
			if ne:
				var want: Vector2 = (ne.global_position + Vector2(0, -ne.radius) - p["p"]).normalized() * p["v"].length()
				p["v"] = p["v"].lerp(want, clampf(p["homing"] * delta, 0, 1))
		if p.get("boomerang", false) and p["t"] > p["life"] * 0.45:
			var back: Vector2 = (player.global_position + Vector2(0, -18) - p["p"])
			p["v"] = p["v"].lerp(back.normalized() * p["v"].length() * 1.1, clampf(6 * delta, 0, 1))
			if back.length() < 16:
				pprojs.remove_at(i)
				continue
			if p["t"] > p["life"] * 0.45 and not p.get("returned", false):
				p["returned"] = true
				p["hit"] = {}
		p["p"] += p["v"] * delta
		var dead = p["t"] > p["life"] * (1.8 if p.get("boomerang", false) else 1.0)
		var pp: Vector2 = p["p"]
		if not arena.grow(40).has_point(pp):
			dead = true
		if not dead:
			for e in enemies:
				if e.dead or p["hit"].has(e):
					continue
				if (e.global_position + Vector2(0, -e.radius)).distance_to(pp) < e.radius + p["r"]:
					p["hit"][e] = true
					deal(e, p, pp - p["v"].normalized() * 10)
					if p.get("explode", 0.0) > 0:
						spawn_fx("burst", pp, {"r": p["explode"], "col": p["col"], "life": 0.3})
						spawn_fx("ring", pp, {"r": p["explode"], "col": p["col"], "life": 0.3, "width": 5})
						aoe_damage(pp, p["explode"], {"dmg": p["dmg"] * 0.6, "elem": p["elem"], "burn": p.get("burn", 0)}, e)
						Au.sfx("explode", -6)
						shake(3)
					if p.get("split_poison", false) and e.dead:
						spawn_zone(e.global_position, 40, 2.0, 0.4, 3 * player.dmg_mult("poison"), Color(0.5, 1, 0.3), {"poison": 1}, "poison")
					if int(p.get("pierce", 0)) <= 0:
						dead = true
						break
					p["pierce"] = int(p["pierce"]) - 1
		if dead:
			burst_particles(pp, p["col"], 3, 90, 2)
			pprojs.remove_at(i)

func _update_ebullets(delta:float) -> void:
	var pp := player.global_position + Vector2(0, -16)
	var deflect := player.buffs.has("armor") and false
	for i in range(ebullets.size() - 1, -1, -1):
		var bl: Dictionary = ebullets[i]
		bl["t"] += delta
		bl["p"] += bl["v"] * delta
		if bl["t"] > 6.0 or not arena.grow(60).has_point(bl["p"]):
			ebullets.remove_at(i)
			continue
		if bl["p"].distance_to(pp) < bl["r"] + 7:
			if player.iframe <= 0 and player.flying <= 0:
				player.take_damage(bl["dmg"], bl["p"] - bl["v"].normalized() * 60, bl["elem"])
				ebullets.remove_at(i)
				continue
		# 被斗技/普攻抵消：护盾风墙
		if player.buffs.has("deflect") and bl["p"].distance_to(pp) < 50:
			ebullets.remove_at(i)

func _update_zones(delta:float) -> void:
	for i in range(zones.size() - 1, -1, -1):
		var z: Dictionary = zones[i]
		if z["type"] == "wave":
			z["r"] += z["spd"] * delta
			for e in enemies_in(z["p"], z["r"]):
				if z["hit"].has(e):
					continue
				if e.global_position.distance_to(z["p"]) > z["r"] - 40 - e.radius:
					z["hit"][e] = true
					deal(e, z["info"], z["p"])
			if z["r"] >= z["rmax"]:
				zones.remove_at(i)
			continue
		z["t"] -= delta
		if z["follow"]:
			z["p"] = player.global_position
		elif z["moving"]:
			var ne = nearest_enemy(z["p"], 400)
			if ne:
				z["p"] = z["p"].move_toward(ne.global_position, 70 * delta)
		if z["pull"] > 0:
			for e in enemies_in(z["p"], z["r"] * 1.3):
				if not e.is_boss:
					e.global_position = e.global_position.move_toward(z["p"], z["pull"] * delta)
		z["tick"] -= delta
		if z["tick"] <= 0:
			z["tick"] = z["rate"]
			aoe_damage(z["p"], z["r"], z["info"])
		if randf() < 0.5 * G.settings["fx"]:
			var a := randf() * TAU
			var rr: float = sqrt(randf()) * z["r"]
			particles.append({"p": z["p"] + Vector2(cos(a), sin(a) * 0.6) * rr, "v": Vector2(0, randf_range(-50, -20)), "t": 0.0, "life": 0.6, "c": z["col"], "s": 2.5, "g": 0.0, "add": true})
		if z["t"] <= 0:
			zones.remove_at(i)

func _update_orbits(delta:float) -> void:
	for i in range(orbits.size() - 1, -1, -1):
		var o: Dictionary = orbits[i]
		o["t"] -= delta
		o["a"] += delta * 3.2
		var pos = player.global_position + Vector2(0, -14) + Vector2(cos(o["a"]), sin(o["a"]) * 0.7) * o["r"]
		o["p"] = pos
		for e in enemies:
			if e.dead:
				continue
			if (e.global_position + Vector2(0, -e.radius)).distance_to(pos) < e.radius + o["size"]:
				var last: float = o["hit"].get(e, -10.0)
				if time_in_room - last > 0.45:
					o["hit"][e] = time_in_room
					deal(e, o["info"], pos)
		# 抵消子弹
		for j in range(ebullets.size() - 1, -1, -1):
			if ebullets[j]["p"].distance_to(pos) < o["size"] + 4:
				ebullets.remove_at(j)
		if o["t"] <= 0:
			orbits.remove_at(i)

func _update_delayed(delta:float) -> void:
	for i in range(delayed.size() - 1, -1, -1):
		var d: Dictionary = delayed[i]
		d["t"] -= delta
		if d["t"] > 0:
			continue
		delayed.remove_at(i)
		if d["enemy"]:
			spawn_fx("burst", d["p"], {"r": d["r"], "col": d["col"], "life": 0.3})
			spawn_fx("ring", d["p"], {"r": d["r"], "col": d["col"], "life": 0.3, "width": 5})
			if player.global_position.distance_to(d["p"]) < d["r"] + player.radius:
				player.take_damage(d["dmg"], d["p"])
			shake(d["shake"])
			Au.sfx("explode", -10)
		else:
			if d.has("lotus"):
				var cols: Array = d["lotus"]
				for c in cols:
					spawn_fx("ring", d["p"], {"r": d["r"] * randf_range(0.8, 1.3), "col": c, "life": 0.7, "width": 14})
				spawn_fx("burst", d["p"], {"r": d["r"] * 1.2, "col": cols[0], "life": 0.6})
				spawn_fx("glow", d["p"], {"r": d["r"] * 1.4, "col": Color(1, 0.9, 0.7), "life": 0.5})
				spawn_fx("petal_ring", d["p"], {"r": d["r"], "col": cols[-1], "life": 0.8})
				burst_particles(d["p"], cols[0], 60, 400, 4)
				H.screen_flash(cols[0])
				Au.sfx("big_explode", 0)
				do_hitstop(0.12)
			elif d.get("pillar", false):
				spawn_fx("pillar", d["p"], {"r": d["r"] * 0.8, "col": d["col"], "life": 0.45})
				spawn_fx("ring", d["p"], {"r": d["r"], "col": d["col"], "life": 0.3, "width": 4})
				Au.sfx("explode", -10)
			else:
				spawn_fx("burst", d["p"], {"r": d["r"], "col": d["col"], "life": 0.4 if not d["big"] else 0.7})
				spawn_fx("ring", d["p"], {"r": d["r"] * 1.1, "col": d["col"], "life": 0.35, "width": 8 if d["big"] else 5})
				spawn_fx("glow", d["p"], {"r": d["r"], "col": d["col"], "life": 0.35})
				burst_particles(d["p"], d["col"], 20 if d["big"] else 8, 300)
				Au.sfx("big_explode" if d["big"] else "explode", -3 if d["big"] else -6)
				if d["big"]:
					H.screen_flash(d["col"])
			shake(d["shake"])
			aoe_damage(d["p"], d["r"], d["info"])

func _update_summons(delta:float) -> void:
	for i in range(summons.size() - 1, -1, -1):
		var s: Dictionary = summons[i]
		s["t"] -= delta
		s["cd"] -= delta
		var ne = nearest_enemy(s["p"], 500)
		var want := Vector2.ZERO
		if ne:
			var d: Vector2 = ne.global_position - s["p"]
			if d.length() > 22:
				want = d.normalized() * 170
			elif s["cd"] <= 0:
				s["cd"] = 0.6
				deal(ne, {"dmg": s["dmg"], "elem": "fire", "burn": 1, "knock": 60}, s["p"])
				spawn_fx("slash", s["p"], {"ang": d.angle(), "arc": 1.6, "r": 26, "col": s["col"], "life": 0.18, "width": 6})
		else:
			want = (player.global_position + Vector2(30, 0) - s["p"]).normalized() * 120
		s["v"] = s["v"].lerp(want, clampf(delta * 6, 0, 1))
		s["p"] += s["v"] * delta
		if randf() < 0.6:
			particles.append({"p": s["p"] + Vector2(randf_range(-6, 6), -8), "v": Vector2(0, -40), "t": 0.0, "life": 0.4, "c": s["col"], "s": 2.5, "g": 0.0, "add": true})
		if s["t"] <= 0:
			spawn_fx("burst", s["p"], {"r": 20, "col": s["col"], "life": 0.3})
			summons.remove_at(i)

func _update_beams(delta:float) -> void:
	for i in range(beams.size() - 1, -1, -1):
		var bm: Dictionary = beams[i]
		bm["t"] -= delta
		bm["tick"] -= delta
		if bm["follow"]:
			bm["p"] = player.global_position + Vector2(0, -18)
		if bm["tick"] <= 0:
			bm["tick"] = bm["rate"]
			var end: Vector2 = bm["p"] + bm["dir"] * bm["len"]
			for e in enemies.duplicate():
				var cp := Geometry2D.get_closest_point_to_segment(e.global_position + Vector2(0, -e.radius), bm["p"], end)
				if cp.distance_to(e.global_position + Vector2(0, -e.radius)) < bm["w"] * 0.5 + e.radius:
					deal(e, bm["info"], bm["p"])
		if bm["t"] <= 0:
			beams.remove_at(i)

func _update_traps(delta:float) -> void:
	for i in range(traps.size() - 1, -1, -1):
		var tp: Dictionary = traps[i]
		tp["arm"] -= delta
		tp["t"] -= delta
		if tp["arm"] <= 0:
			if not enemies_in(tp["p"], tp["r"] * 0.5).is_empty() or tp["t"] <= 0:
				spawn_fx("burst", tp["p"], {"r": tp["r"], "col": tp["col"], "life": 0.4})
				spawn_fx("ring", tp["p"], {"r": tp["r"], "col": tp["col"], "life": 0.3, "width": 5})
				aoe_damage(tp["p"], tp["r"], tp["info"])
				Au.sfx("explode", -5)
				shake(3)
				traps.remove_at(i)

func _update_particles(delta:float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["t"] += delta
		p["v"].y += p["g"] * delta
		p["p"] += p["v"] * delta
		p["v"] *= 0.97
		if p["t"] > p["life"]:
			particles.remove_at(i)
	if particles.size() > 900:
		particles = particles.slice(particles.size() - 900)

# ---------------------------------------------------------------- 丹药
func use_pill() -> void:
	var pills: Array = G.run["pills"]
	if pills.is_empty():
		float_text(player.global_position + Vector2(0, -60), "没有丹药", Color(0.7, 0.7, 0.7), false)
		return
	var id: String = pills[0]
	if id == "huanhun":
		if pills.size() == 1:
			float_text(player.global_position + Vector2(0, -60), "还魂丹会在死亡时自动生效", Color(0.9, 0.6, 1), false)
			return
		pills.push_back(pills.pop_front())
		id = pills[0]
	pills.remove_at(0)
	apply_pill(id, player)
	Au.sfx("pill")
	spawn_fx("ring", player.global_position, {"r": 50, "col": D.pills[id]["c"], "life": 0.4, "width": 5})
	float_text(player.global_position + Vector2(0, -70), D.pills[id]["n"], D.pills[id]["c"], true)

static func apply_pill(id:String, p) -> void:
	var r: Dictionary = G.run
	match id:
		"huiqi":
			if p: p.heal(p.st["hp_max"] * 0.4)
			else: G.heal_run(0.4)
		"juqi":
			if p and p.b: p.b.gain_exp(G.exp_needed(int(r["realm"])) * 0.8)
			else: r["exp"] = float(r["exp"]) + G.exp_needed(int(r["realm"])) * 0.8
		"zhuji":
			r["max_hp_bonus"] = int(r.get("max_hp_bonus", 0)) + 20
		"sanwen":
			r["buffs"]["dmg"] = float(r["buffs"].get("dmg", 0)) + 0.12
		"bingling":
			r["buffs"]["cdr"] = float(r["buffs"].get("cdr", 0)) + 0.1
		"humai":
			r["flags"]["humai"] = true
		"kuangbao":
			r["buffs"]["next_fight_dmg"] = 0.5
		"pozong":
			if p and p.b:
				p.b.gain_exp(G.exp_needed(int(r["realm"])) * 1.01)
			else:
				r["realm"] = min(int(r["realm"]) + 1, G.realm_cap())
		"xuelian":
			r["buffs"]["lifesteal"] = float(r["buffs"].get("lifesteal", 0)) + 0.03
		"leiting":
			r["buffs"]["crit"] = float(r["buffs"].get("crit", 0)) + 0.08
		"xisui":
			var arts: Array = r["arts"]
			if arts.size() > 0:
				var a: String = arts[randi() % arts.size()]
				r["skill_affix"][a] = Rewards.roll_affixes(2)
	if p:
		p.recalc()
