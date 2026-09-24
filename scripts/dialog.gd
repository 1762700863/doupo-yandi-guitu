class_name Dialog
extends Control
## 视觉小说式对话：立绘 + 打字机 + 点击/空格推进 + 跳过

var lines_: Array = []
var idx := 0
var shown := 0.0
var done_cb: Callable
var name_l: Label
var text_l: Label
var por_l: TextureRect
var por_r: TextureRect
var box: Panel
var hint: Label
var cur_text := ""
var left_speaker := ""
var theme_pushed := false

## 剧情专属曲：取出场最多、且有专属曲的角色（萧炎除外；萧炎独白不切换）
static func _apply_theme(ls:Array) -> bool:
	if ls.size() < 3 or not Au.calm_now():
		return false
	var cnt := {}
	for l in ls:
		if l is Array and l.size() >= 3:
			var sid: String = str(l[0])
			if sid != "xiaoyan" and Au.theme_ctx(sid) != "":
				cnt[sid] = int(cnt.get(sid, 0)) + 1
	var best := ""
	for k in cnt:
		if best == "" or int(cnt[k]) > int(cnt[best]):
			best = k
	if best == "":
		return false
	Au.push(Au.theme_ctx(best))
	return true

static func play(m, key:String, done:Callable) -> void:
	var ls: Array = D.story.get(key, [])
	if ls.is_empty():
		done.call()
		return
	if not (key in G.meta["story_seen"]):
		G.meta["story_seen"].append(key)
	lines(m, ls, done)

static func lines(m, ls:Array, done:Callable) -> void:
	var d := Dialog.new()
	d.theme_pushed = _apply_theme(ls)
	d.lines_ = ls
	d.done_cb = done
	var root: Control = m.ui_root()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(d)

func _ready() -> void:
	add_to_group("dialog")
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	por_l = TextureRect.new()
	por_r = TextureRect.new()
	for p in [por_l, por_r]:
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.size = Vector2(300, 400)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(p)
	por_l.position = Vector2(20, 110)
	por_r.position = Vector2(640, 110)
	por_r.flip_h = true
	box = UI.panel(self, Rect2(40, 380, 880, 140))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l = UI.label(box, "", Vector2(24, 10), 16, UI.theme_cols()["accent"])
	text_l = UI.label(box, "", Vector2(24, 38), 16, Color(0.96, 0.93, 0.86), 830)
	hint = UI.label(box, "▼ 点击/空格继续   Esc 跳过", Vector2(640, 114), 8, Color(0.7, 0.7, 0.7))
	_show()

func _show() -> void:
	var l: Array = lines_[idx]
	var spk: String = l[0]
	name_l.text = l[1]
	cur_text = l[2]
	shown = 0.0
	text_l.text = ""
	name_l.visible = spk != "" or l[1] != ""
	if spk == "":
		por_l.modulate = Color(0.45, 0.45, 0.45)
		por_r.modulate = Color(0.45, 0.45, 0.45)
		if l[1] == "":
			text_l.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
		return
	text_l.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	var tex := G.portrait(spk + "_full")
	if tex == null:
		tex = G.spr(spk)
	# 萧炎系在左，其他在右
	var left := spk in ["xiaoyan", "yandi"] or (left_speaker == "" and not (spk in ["hun_tiandi", "nalan", "medusa"]))
	if left_speaker != "" and spk == left_speaker:
		left = true
	if left:
		if left_speaker == "":
			left_speaker = spk
		por_l.texture = tex
		_pop(por_l)
		por_l.modulate = Color.WHITE
		por_r.modulate = Color(0.45, 0.45, 0.45)
	else:
		por_r.texture = tex
		_pop(por_r)
		por_r.modulate = Color.WHITE
		por_l.modulate = Color(0.45, 0.45, 0.45)

func _pop(p:TextureRect) -> void:
	var y0 := 110.0
	p.position.y = y0 + 8
	var tw := create_tween()
	tw.tween_property(p, "position:y", y0, 0.15).set_ease(Tween.EASE_OUT)

func _process(d:float) -> void:
	if shown < cur_text.length():
		shown += d * 42.0
		text_l.text = cur_text.substr(0, int(shown))
		hint.modulate.a = 0.3
	else:
		hint.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)

func _advance() -> void:
	if shown < cur_text.length():
		shown = cur_text.length()
		text_l.text = cur_text
		return
	idx += 1
	Au.sfx("click", -10)
	if idx >= lines_.size():
		_finish()
	else:
		_show()

func _finish() -> void:
	set_process(false)
	var root := get_parent()
	root.queue_free()
	if theme_pushed:
		Au.pop()
	done_cb.call()

func _gui_input(e:InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()

func _unhandled_input(e:InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if e.is_action_pressed("ui_accept") or e.is_action_pressed("dodge"):
		get_viewport().set_input_as_handled()
		_advance()
	elif e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
