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

var args_g := {}
# ---- 真实鼠标点击测试（模拟用户操作路径）
func _scene_name() -> String:
	if current == null: return "null"
	var sc = current.get_script()
	return sc.get_global_name() if sc else current.get_class()

func _find_btn(txt:String) -> Button:
	var all := []
	_collect_btns(ui_layer, all)
	for i in range(all.size() - 1, -1, -1):
		if all[i].text == txt or all[i].text.begins_with(txt):
			return all[i]
	return null

func _click_at(pos:Vector2) -> void:
	var wp := pos * (Vector2(get_window().size) / Vector2(960, 540))
	var mv := InputEventMouseMotion.new()
	mv.position = wp
	mv.global_position = wp
	Input.parse_input_event(mv)
	await get_tree().process_frame
	for pr in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pr
		ev.position = wp
		ev.global_position = wp
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame

func _click(txt:String) -> bool:
	var b := _find_btn(txt)
	if b == null:
		print("CT FAIL no button [", txt, "] scene=", _scene_name())
		return false
	await _click_at(b.get_global_rect().get_center())
	await get_tree().create_timer(0.6).timeout
	return true

func _ct_dialogs(maxn:int=60) -> void:
	for i in maxn:
		if get_tree().get_nodes_in_group("dialog").is_empty():
			return
		await _click_at(Vector2(480, 470))
		await get_tree().create_timer(0.25).timeout

func _ct_shot(args:Dictionary, tag:String) -> void:
	if args.has("shotdir"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["shotdir"] + "/" + tag + ".png")

func _clicktest(args:Dictionary) -> void:
	var mode: String = args.get("mode", "legacy_new")
	# 模拟旧版本遗留存档：序章已通关、出征过2次、无未完成征途
	G.reset_all()
	if mode != "fresh":
		G.meta["prologue_done"] = true
		G.meta["runs"] = 2
		G.save_meta()
	title_screen()
	await get_tree().create_timer(1.0).timeout
	print("CT title buttons: 继续=", _find_btn("继续游戏") != null, " 新=", _find_btn("新游戏") != null)
	await _ct_shot(args, "01_title")
	if mode == "legacy_continue" or mode == "launch_only":
		await _click("继续游戏")
		await get_tree().create_timer(1.0).timeout
		print("CT after 继续游戏 scene=", _scene_name())
		await _ct_dialogs()
	if mode == "legacy_continue":
		# 设置按钮不能穿透到建筑
		await _click("设置")
		await get_tree().create_timer(0.5).timeout
		print("CT after 设置: settings_open=", _find_btn("返回") != null or _find_btn("关闭") != null, " building_panel=", _find_btn("升级建筑") != null)
		await _ct_shot(args, "02_settings")
		if not await _click("返回"):
			await _click("关闭")
		await get_tree().create_timer(0.5).timeout
		await _click("标题")
		await get_tree().create_timer(1.0).timeout
		print("CT after 标题 scene=", _scene_name())
		await _click("继续游戏")
	if mode == "legacy_continue" or mode == "launch_only":
		await get_tree().create_timer(1.0).timeout
		# 城门 → 出征
		var hs = current
		await _click_at(hs.bld_rects["gate"].get_center())
		await get_tree().create_timer(0.8).timeout
		await _ct_shot(args, "03_launch")
		await _click("出　征")
		await get_tree().create_timer(1.5).timeout
		print("CT after 出征 scene=", _scene_name(), " dialogs=", get_tree().get_nodes_in_group("dialog").size())
		await _ct_dialogs()
		await get_tree().create_timer(1.5).timeout
		print("CT after ch dialog scene=", _scene_name())
		await _ct_shot(args, "04_map")
		print("CT explore=", current is Explore)
	else:
		await _click("新游戏")
		await get_tree().create_timer(0.5).timeout
		if mode != "fresh":
			await _ct_shot(args, "02_confirm")
			await _click("清除并开始")
		await get_tree().create_timer(1.5).timeout
		print("CT after 新游戏 scene=", _scene_name(), " prologue_done=", G.meta["prologue_done"], " runs=", G.meta["runs"], " dialogs=", get_tree().get_nodes_in_group("dialog").size(), " run_ch=", G.run.get("chapter", -1))
		await _ct_shot(args, "03_prologue")
		await _ct_dialogs()
		await get_tree().create_timer(1.5).timeout
		print("CT after prologue dialog scene=", _scene_name())
		await _ct_shot(args, "04_fight")
	print("CT_DONE")

func _collect_btns(n:Node, out:Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree() and not c.disabled:
			out.append(c)
		_collect_btns(c, out)

func _autoplay() -> void:
	while true:
		await get_tree().create_timer(0.35, true, false, true).timeout
		var b := battle()
		if b and is_instance_valid(b.player):
			b.player.hp = b.player.st["hp_max"]
			if args_g.get("real", "") != "1":
				for e in b.enemies.duplicate():
					if is_instance_valid(e) and not e.get("dead"):
						b.deal(e, {"dmg": e.hp_max * 0.26, "elem": "fire"}, b.player.global_position)
			else:
				# 模拟玩家：朝最近敌人移动并攻击（通过输入动作）
				var ne = b.nearest_enemy(b.player.global_position, 2000)
				if ne:
					var dv: Vector2 = ne.global_position - b.player.global_position
					Input.action_release("left"); Input.action_release("right"); Input.action_release("up"); Input.action_release("down")
					if dv.length() > 90:
						if dv.x > 20: Input.action_press("right")
						if dv.x < -20: Input.action_press("left")
						if dv.y > 20: Input.action_press("down")
						if dv.y < -20: Input.action_press("up")
					Input.action_press("attack")
					for a in ["art1", "art2", "art3", "art4", "ult", "ult2", "special"]:
						if randf() < 0.3:
							Input.action_press(a)
						else:
							Input.action_release(a)
		for d in get_tree().get_nodes_in_group("dialog"):
			d._advance()
		if get_tree().get_nodes_in_group("dialog").size() > 0:
			continue
		var btns := []
		var kids := ui_layer.get_children().filter(func(k): return not k.is_queued_for_deletion())
		kids.reverse()
		for k in kids:
			var tmp := []
			_collect_btns(k, tmp)
			tmp = tmp.filter(func(b): return not (b.text in ["设置", "标题", "功法", "退出游戏", "放弃本局"]))
			if tmp.size() > 0:
				btns = tmp
				break
		var pri := ["继续", "离开", "返回基地", "不要了", "吞噬它", "放弃（", "关闭"]
		var pick: Button = null
		for bt in btns:
			for k in pri:
				if bt.text.begins_with(k) or bt.text == "继续征途":
					pick = bt
					break
			if pick: break
		if pick == null:
			for bt in btns:
				if bt.text == "":
					pick = bt
					break
		if pick == null:
			for bt in btns:
				if not (bt.text in ["设置", "标题", "功法", "退出游戏", "放弃本局", "+10", "+30", "+100"]):
					pick = bt
					break
		if pick:
			if false: print("STATE scene=", current.get_script().get_global_name() if current and current.get_script() else "?", " fade=", snapped(fade.color.a, 0.01), " fading=", fading, " paused=", get_tree().paused, " ui=", ui_layer.get_child_count())
			print("AUTO_PICK [", pick.text.replace("\n", " ").substr(0, 20), "] floor=", G.run.get("floor", -1), " ch=", G.run.get("chapter", -1))
			pick.pressed.emit()

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
		"clicktest":
			await _clicktest(args)
		"chclear":
			G.new_run(c, 1, D.chars[c]["atks"][0], "yaolao", 1, [])
			Flow.show_map(self)
			await get_tree().create_timer(0.5).timeout
			Flow.chapter_clear(self)
		"explore":
			G.new_run(c, int(args.get("ch", "1")), D.chars[c]["atks"][0], "yaolao", 1, [])
			G.run["zone"] = Flow.new_zone_state(int(args.get("ch", "1")), int(args.get("zi", "0")))
			Flow.enter_zone(self)
			if args.has("tp"):
				await get_tree().create_timer(1.0).timeout
				var ex = current
				for po in ex.pois:
					if po["t"] == args["tp"]:
						ex.player.global_position = po["p"] + Vector2(0, 40)
						break
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
	args_g = args
	if args.get("auto", "") == "1":
		_autoplay()
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
	if not fading:
		_fade_out()

var fading := false
var fade_tw: Tween
var black_t := 0.0

func _fade_out() -> void:
	if fade_tw and fade_tw.is_valid():
		fade_tw.kill()
	fade.color.a = max(fade.color.a, 0.6)
	fade_tw = create_tween().set_ignore_time_scale(true)
	fade_tw.tween_property(fade, "color:a", 0.0, 0.35)

## 渐黑 → 执行回调 → 无论回调是否切换场景，都保证渐亮（修复黑屏）
func fade_to(cb:Callable) -> void:
	if fading:
		return
	fading = true
	if fade_tw and fade_tw.is_valid():
		fade_tw.kill()
	fade_tw = create_tween().set_ignore_time_scale(true)
	fade_tw.tween_property(fade, "color:a", 1.0, 0.22)
	fade_tw.tween_callback(func():
		fading = false
		cb.call()
		_fade_out())

## 操作模式：鼠标模式下不显示“默认选中”的高亮；按方向键/手柄时才启用焦点导航
var kb_mode := false
var pref_focus: WeakRef = null

func _input(e:InputEvent) -> void:
	if e is InputEventMouseMotion and e.relative.length() > 1.5 or e is InputEventMouseButton:
		kb_mode = false
	elif (e is InputEventKey or e is InputEventJoypadButton) and e.is_pressed() or e is InputEventJoypadMotion and absf(e.axis_value) > 0.6:
		var nav := e.is_action("ui_up") or e.is_action("ui_down") or e.is_action("ui_left") or e.is_action("ui_right") or e.is_action("ui_accept") or e.is_action("ui_focus_next")
		if nav and not kb_mode:
			kb_mode = true
			if get_viewport().gui_get_focus_owner() == null:
				var target: Control = null
				if pref_focus and pref_focus.get_ref() and pref_focus.get_ref().is_visible_in_tree():
					target = pref_focus.get_ref()
				else:
					var btns := []
					var kids := ui_layer.get_children()
					kids.reverse()
					for k in kids:
						_collect_btns(k, btns)
						if btns.size() > 0:
							break
					if btns.size() > 0:
						target = btns[0]
				if target:
					target.grab_focus()
					get_viewport().set_input_as_handled()

func _process(d:float) -> void:
	if not kb_mode:
		var fo := get_viewport().gui_get_focus_owner()
		if fo is BaseButton:
			pref_focus = weakref(fo)
			fo.release_focus()
	if battle() == null and Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	# 保险：黑幕停留超过1.2秒自动揭开
	if fade.color.a > 0.9 and not fading:
		black_t += d
		if black_t > 1.2:
			_fade_out()
	else:
		black_t = 0.0

func ui_root() -> Control:
	var c := Control.new()
	c.size = Vector2(960, 540)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var y := 290.0
	var progress := G.has_progress()
	var first: Button = null
	# 继续游戏：有任何进度就显示（有未完成的一局→回到地图；否则→回到基地）
	if progress:
		first = UI.button(root, "继续游戏", Rect2(130, y, 180, 34), func(): _continue_run(), Color(1, 0.75, 0.3), 16)
		UI.label(root, _run_summary(), Vector2(322, y + 8), 12, Color(0.9, 0.85, 0.7))
		y += 42
	# 新游戏：总是从序章（萧炎成为炎帝）开始；有进度时先确认并清空全部存档
	var nb := UI.button(root, "新游戏", Rect2(130, y, 180, 34), func():
		if progress:
			Screens.confirm(self, "开始新游戏？", "将清除全部存档进度（基地建筑、天赋、解锁角色、异火、成就、未完成的征途），\n从序章重新开始。设置会保留。此操作不可撤销！", "清除并开始", "取消", func(yes):
				if yes:
					G.reset_all()
					fade_to(func(): _start_prologue()), true)
		else:
			fade_to(func(): _start_prologue()), Color(1, 0.6, 0.3), 16)
	if first == null:
		first = nb
	y += 42
	UI.button(root, "设置", Rect2(130, y, 180, 34), func(): Screens.settings(self, func(): title_screen()), Color(-1, 0, 0), 16)
	y += 42
	UI.button(root, "退出游戏", Rect2(130, y, 180, 34), func(): get_tree().quit(), Color(0.6, 0.6, 0.6), 16)
	first.call_deferred("grab_focus")
	UI.label(root, "v0.1.3 · 同人作品，仅供个人娱乐 · 字体：霞鹜文楷 / 缝合像素字体 (OFL)", Vector2(10, 520), 8, Color(0.6, 0.6, 0.6))
	UI.label(root, "WASD移动 鼠标瞄准 左键普攻 Q/E/R/F斗技 C/X大招 空格身法 Tab功法面板 Esc暂停 F11全屏", Vector2(0, 500), 8, Color(0.8, 0.75, 0.65), 960, HORIZONTAL_ALIGNMENT_CENTER)

func _run_summary() -> String:
	var f := FileAccess.open(G.RUN_PATH, FileAccess.READ)
	if f == null:
		return "返回%s · 已出征 %d 次" % [G.faction_name(), int(G.meta["runs"])]
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary) or not d.has("char"):
		return "返回%s" % G.faction_name()
	return "征途中：%s · %s · 第%d层" % [D.chars[d["char"]]["n"], D.chapters[int(d["chapter"])]["t"], int(d.get("floor", 0)) + 1]

func _start_flow() -> void:
	if not G.meta["prologue_done"]:
		fade_to(func(): _start_prologue())
	else:
		fade_to(func(): hub())

func _continue_run() -> void:
	if G.has_run() and G.load_run():
		fade_to(func(): Flow.show_map(self))
	elif not G.meta["prologue_done"]:
		fade_to(func(): _start_prologue())
	else:
		fade_to(func(): hub())

func _start_prologue() -> void:
	G.new_run("xiaoyan", 0, "atk_flame", "", 1, [])
	set_scene(StoryBG.make("void"))
	Au.music("prologue")
	Dialog.play(self, "prologue_start", func():
		Flow.enter_room(self, {"type": "fight", "biome": "void"}, func(res):
			if res == "win":
				Flow.enter_room(self, {"type": "boss", "boss": "hun_tiandi", "biome": "void"}, func(res2):
					_prologue_end())
			else:
				_prologue_end()))

func _prologue_end() -> void:
	set_scene(StoryBG.make("void"))
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
