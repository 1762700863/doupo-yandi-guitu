extends Node
## 主控：场景切换、主菜单、局流程（地图 → 房间 → 奖励）、全局提示

var current: Node = null
var ui_layer: CanvasLayer
var toast_layer: CanvasLayer
var toasts: Array = []
var menu_open := false
var pause_menu: Control = null
var fade: ColorRect

func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	toast_layer = CanvasLayer.new()
	toast_layer.layer = 50
	add_child(toast_layer)
	var fl := CanvasLayer.new()
	fl.layer = 60
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.size = Vector2(960, 540)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)
	get_window().min_size = Vector2i(960, 540)
	title_screen()
	_autotest()

# ---------------------------------------------------------------- 自动测试（命令行 -- scene=hub shot=/path.png t=3）
func _autotest() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.is_empty():
		return
	await get_tree().create_timer(0.5).timeout
	var sc: String = args.get("scene", "")
	var c: String = args.get("char", "xiaoyan")
	match sc:
		"hub":
			hub()
		"flow":
			G.new_run(c, int(args.get("ch", "1")), D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.show_map(self)
			await get_tree().create_timer(0.5).timeout
			var node := {"t": args.get("node", "fight")}
			if args.has("boss"):
				node["boss"] = args["boss"]
			Flow.node_selected(self, node)
			for i in 40:
				await get_tree().create_timer(0.4).timeout
				var b := battle()
				if b:
					b.player.hp = b.player.st["hp_max"]
					for e in b.enemies.duplicate():
						if is_instance_valid(e):
							e.hp = 0.0
							e.die()
		"map1", "map2":
			G.new_run(c, 1 if sc == "map1" else 2, D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.show_map(self)
		"battle", "boss", "elite":
			G.new_run(c, int(args.get("ch", "1")), D.chars[c]["atks"][0], args.get("comp", "yaolao"), 1, [])
			G.run["realm"] = int(args.get("realm", "3"))
			var cfg := {"type": "fight" if sc == "battle" else sc, "biome": args.get("biome", "forest")}
			if args.has("boss"):
				cfg["boss"] = args["boss"]
			Flow.enter_room(self, cfg, func(res): print("ROOM_RESULT ", res))
		"prologue":
			_start_prologue()
		"reward":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.reward_screen(self, "any", func(): pass)
		"shop":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			G.run["gold"] = 500
			Screens.shop(self, func(): pass)
		"auction":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			G.run["gold"] = 500
			Screens.auction(self, func(): pass)
		"event":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			Screens.event(self, args.get("ev", ""), func(): pass)
		"fire":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			FireGame.start(self, "qldx", 0.5, func(ok): print("FIRE ", ok))
		"alchemy":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			AlchemyGame.start(self, "huiqi", func(q): print("ALC ", q))
		"alchemy_sel":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			G.run["herbs"] = {"zyl": 3, "xgh": 3}
			Screens.alchemy_select(self, true, func(): pass)
		"pause":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.enter_room(self, {"type": "fight", "biome": "forest"}, func(res): pass)
			await get_tree().create_timer(1.0).timeout
			toggle_pause(true)
		"settings":
			Screens.settings(self, func(): pass)
		"results":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.results(self, false)
		"dialog":
			Dialog.play(self, args.get("key", "ch1_start"), func(): pass)
		"launch":
			hub()
			await get_tree().create_timer(0.3).timeout
			current._launch_panel()
		"hubpanel":
			hub()
			await get_tree().create_timer(0.3).timeout
			current._open(args.get("b", "train"))
	var t := float(args.get("t", "3"))
	var shots: String = args.get("shot", "")
	if shots != "":
		var n := int(args.get("n", "1"))
		for i in n:
			await get_tree().create_timer(t / n, true, false, true).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png(shots.replace(".png", "_%d.png" % i) if n > 1 else shots)
		get_tree().quit()

func _unhandled_input(e:InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		var b := battle()
		if b and not b.ended:
			toggle_pause()
	if e.is_action_pressed("panel"):
		var b2 := battle()
		if b2 and not b2.ended and pause_menu == null:
			toggle_pause(true)
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11:
		G.settings["fullscreen"] = not G.settings["fullscreen"]
		G.apply_settings()
		G.save_meta()

func battle() -> Battle:
	if current is Battle:
		return current
	return null

# ---------------------------------------------------------------- 切换
func clear_ui() -> void:
	for c in ui_layer.get_children():
		c.queue_free()

func set_scene(n:Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	pause_menu = null
	if current:
		current.queue_free()
	clear_ui()
	current = n
	if n:
		add_child(n)
		move_child(n, 0)
	fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.35)

func fade_to(cb:Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(cb)

func ui_root() -> Control:
	var c := Control.new()
	c.size = Vector2(960, 540)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(c)
	return c

func toast(title:String, sub:String, col:Color) -> void:
	var p := UI.panel(toast_layer, Rect2(960 - 290, 60 + toasts.size() * 58, 280, 52), Color(0.05, 0.04, 0.05, 0.92), col)
	UI.label(p, title, Vector2(10, 4), 12, col)
	UI.label(p, sub, Vector2(10, 22), 8, Color(0.9, 0.9, 0.9), 260)
	toasts.append(p)
	Au.sfx("levelup", -8, 1.3)
	var tw := p.create_tween()
	p.modulate.a = 0
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		toasts.erase(p)
		p.queue_free())

# ---------------------------------------------------------------- 标题
func title_screen() -> void:
	set_scene(TitleScene.new())
	Au.music("hub")
	var root := ui_root()
	var y := 300.0
	var has_run := G.has_run()
	if has_run:
		UI.button(root, "继续征途", Rect2(130, y, 180, 32), func(): _continue_run(), Color(1, 0.7, 0.3), 16)
		y += 38
	UI.button(root, "开始游戏", Rect2(130, y, 180, 32), func(): _start_flow(), Color(1, 0.6, 0.3), 16)
	y += 38
	UI.button(root, "设置", Rect2(130, y, 180, 32), func(): Screens.settings(self, func(): title_screen()), Color(-1, 0, 0), 16)
	y += 38
	UI.button(root, "退出", Rect2(130, y, 180, 32), func(): get_tree().quit(), Color(0.6, 0.6, 0.6), 16)
	UI.label(root, "v0.1.0 · 同人作品，仅供个人娱乐 · 字体：缝合像素字体 (OFL)", Vector2(10, 520), 8, Color(0.6, 0.6, 0.6))
	UI.label(root, "WASD移动 鼠标瞄准 左键普攻 Q/E/R/F斗技 C/X大招 空格身法 Tab功法面板 Esc暂停 F11全屏", Vector2(0, 500), 8, Color(0.8, 0.75, 0.65), 960, HORIZONTAL_ALIGNMENT_CENTER)

func _start_flow() -> void:
	if not G.meta["prologue_done"]:
		fade_to(func(): _start_prologue())
	else:
		fade_to(func(): hub())

func _continue_run() -> void:
	if G.load_run():
		fade_to(func(): Flow.show_map(self))
	else:
		hub()

func _start_prologue() -> void:
	G.new_run("xiaoyan", 0, "atk_flame", "", 1, [])
	Dialog.play(self, "prologue_start", func():
		Flow.enter_room(self, {"type": "fight", "biome": "void"}, func(res):
			if res == "win":
				Flow.enter_room(self, {"type": "boss", "boss": "hun_tiandi", "biome": "void"}, func(res2):
					_prologue_end())
			else:
				_prologue_end()))

func _prologue_end() -> void:
	G.meta["prologue_done"] = true
	G.save_meta()
	G.clear_run()
	Dialog.play(self, "prologue_end", func(): fade_to(func(): hub()))

func hub() -> void:
	if G.run.get("mode", "") == "":
		G.clear_run()
	set_scene(HubScene.new())
	Au.music("hub")

# ---------------------------------------------------------------- 暂停/功法面板
func toggle_pause(panel_only:bool=false) -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
		get_tree().paused = false
		var b := battle()
		if b:
			b.in_menu = false
		return
	get_tree().paused = true
	var b2 := battle()
	if b2:
		b2.in_menu = true
	pause_menu = Screens.pause(self, panel_only)
