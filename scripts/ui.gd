class_name UI
extends RefCounted
## UI 工具：按章节主题的面板、按钮、标签、技能卡片

static func theme_cols() -> Dictionary:
	var ch := 1
	if not G.run.is_empty():
		ch = int(G.run.get("chapter", 1))
	return D.chapters[clampi(ch, 0, D.chapters.size() - 1)]["ui"]

static func panel_style(bg:Color=Color(-1, 0, 0), border:Color=Color(-1, 0, 0), bw:int=2) -> StyleBoxFlat:
	var th := theme_cols()
	var s := StyleBoxFlat.new()
	s.bg_color = th["bg"] if bg.r < 0 else bg
	s.border_color = th["border"] if border.r < 0 else border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	s.set_content_margin_all(10)
	return s

static func panel(parent:Node, rect:Rect2, bg:Color=Color(-1, 0, 0), border:Color=Color(-1, 0, 0)) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	parent.add_child(p)
	# 角饰
	var deco := CornerDeco.new()
	deco.col = (theme_cols()["border"] if border.r < 0 else border)
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(deco)
	return p

static func label(parent:Node, text:String, pos:Vector2, size:int=12, col:Color=Color(0.95, 0.92, 0.85), width:float=-1, align:int=HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	size = max(size, 10)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", G.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3 if size >= 12 else 2)
	l.horizontal_alignment = align
	if width > 0:
		l.size.x = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func button(parent:Node, text:String, rect:Rect2, cb:Callable, col:Color=Color(-1, 0, 0), size:int=12) -> Button:
	var th := theme_cols()
	var b := Button.new()
	size = max(size, 10)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", G.font)
	b.add_theme_font_size_override("font_size", size)
	var accent: Color = th["border"] if col.r < 0 else col
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.05, 0.06, 0.92)
	n.border_color = accent.darkened(0.3)
	n.set_border_width_all(2)
	n.set_corner_radius_all(2)
	n.set_content_margin_all(4)
	var h := n.duplicate()
	h.bg_color = accent.darkened(0.55)
	h.border_color = accent.lightened(0.2)
	var pr := n.duplicate()
	pr.bg_color = accent.darkened(0.35)
	var dis := n.duplicate()
	dis.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	dis.border_color = Color(0.3, 0.3, 0.3)
	var foc := h.duplicate()
	foc.border_color = Color(1, 0.95, 0.7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", foc)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.9))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	b.pressed.connect(func():
		Au.sfx("click")
		cb.call())
	b.mouse_entered.connect(func(): Au.sfx("hover", -8))
	parent.add_child(b)
	return b

static func tex_rect(parent:Node, tex:Texture2D, rect:Rect2, keep:bool=true) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = rect.position
	t.size = rect.size
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep else TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if tex and tex.get_height() > 100 else CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

static func dim(parent:Node, a:float=0.6) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, a)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.size = Vector2(960, 540)
	parent.add_child(c)
	return c

static func skill_desc(id:String) -> String:
	var s: Dictionary = D.skills[id]
	var cat = {"atk": "普攻", "art": "斗技", "ult": "大招", "move": "身法", "gong": "功法", "relic": "法宝"}[s["cat"]]
	var txt := "【%s·%s】%s" % [cat, D.ELEM[s["elem"]]["n"], s["d"]]
	if s["cat"] in ["art", "ult"]:
		txt += "\n伤害 %d  冷却 %.1fs" % [int(s["dmg"]), s["cd"]]
	return txt

static func card(parent:Node, rect:Rect2, title:String, sub:String, desc:String, col:Color, cb:Callable, icon_elem:String="", badge:String="") -> Button:
	var b := button(parent, "", rect, cb, col)
	var ic := SkillIcon.new()
	ic.elem = icon_elem
	ic.col = col
	ic.position = Vector2(rect.size.x * 0.5 - 22, 12)
	ic.size = Vector2(44, 44)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	label(b, title, Vector2(6, 62), 16, col.lightened(0.3), rect.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)
	label(b, sub, Vector2(6, 84), 12, col, rect.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)
	label(b, desc, Vector2(10, 106), 12, Color(0.88, 0.85, 0.8), rect.size.x - 20)
	if badge != "":
		var bl := label(b, badge, Vector2(6, 4), 12, Color(1, 0.85, 0.3))
	return b


class CornerDeco extends Control:
	var col := Color.WHITE
	func _draw() -> void:
		var s := size
		var c := col.lightened(0.2)
		var L := 8.0
		for p in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(s.x, 0), Vector2(-1, 1)], [Vector2(0, s.y), Vector2(1, -1)], [Vector2(s.x, s.y), Vector2(-1, -1)]]:
			var o: Vector2 = p[0]
			var d: Vector2 = p[1]
			draw_line(o + Vector2(2 * d.x, 2 * d.y), o + Vector2(L * d.x, 2 * d.y), c, 2)
			draw_line(o + Vector2(2 * d.x, 2 * d.y), o + Vector2(2 * d.x, L * d.y), c, 2)
			draw_rect(Rect2(o + Vector2(4 * d.x, 4 * d.y) - Vector2(1, 1), Vector2(2, 2)), c)


class SkillIcon extends Control:
	## 程序化技能图标：按元素绘制
	var elem := "fire"
	var col := Color.WHITE
	var cd_k := 0.0
	var t := 0.0
	var label_txt := ""
	func _process(delta:float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var r: float = min(s.x, s.y) * 0.5
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.04, 0.05, 0.9))
		draw_rect(Rect2(Vector2.ZERO, s), col.darkened(0.2), false, 2)
		var ec := D.elem_color(elem) if elem != "" else col
		match elem:
			"fire":
				for i in 3:
					var h := r * (1.4 - i * 0.35)
					var w := r * (0.9 - i * 0.22)
					var pts := PackedVector2Array([c + Vector2(-w, r * 0.55), c + Vector2(0, r * 0.55 - h + sin(t * 6 + i) * 2), c + Vector2(w, r * 0.55)])
					draw_colored_polygon(pts, ec.lerp(Color(1, 1, 0.7), i * 0.35))
			"cold":
				for i in 3:
					var a := PI / 3 * i
					draw_line(c - Vector2.from_angle(a) * r * 0.7, c + Vector2.from_angle(a) * r * 0.7, ec, 3)
				draw_circle(c, r * 0.2, Color.WHITE)
			"thunder":
				var pts2 := PackedVector2Array([c + Vector2(r * 0.1, -r * 0.7), c + Vector2(-r * 0.35, r * 0.05), c + Vector2(0, r * 0.05), c + Vector2(-r * 0.15, r * 0.7), c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.05, -r * 0.1)])
				draw_colored_polygon(pts2, ec)
			"wind":
				for i in 3:
					draw_arc(c + Vector2(0, (i - 1) * r * 0.35), r * 0.55, PI * 1.1, PI * 1.9 + i * 0.2, 10, ec, 3)
			"poison":
				draw_circle(c + Vector2(0, r * 0.1), r * 0.5, ec.darkened(0.3))
				draw_circle(c + Vector2(-r * 0.15, 0), r * 0.18, ec.lightened(0.4))
				draw_circle(c + Vector2(r * 0.25, -r * 0.35), r * 0.12, ec)
			"soul", "void":
				draw_arc(c, r * 0.55, t * 2, t * 2 + PI * 1.5, 16, ec, 3)
				draw_circle(c, r * 0.25, ec.lightened(0.3))
			"gold":
				draw_rect(Rect2(c - Vector2(r * 0.5, r * 0.5), Vector2(r, r)), ec.darkened(0.2))
				draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.3), Vector2(r * 0.6, r * 0.6)), ec.lightened(0.3))
			"earth":
				var pts3 := PackedVector2Array([c + Vector2(-r * 0.7, r * 0.5), c + Vector2(-r * 0.2, -r * 0.5), c + Vector2(r * 0.1, 0), c + Vector2(r * 0.4, -r * 0.3), c + Vector2(r * 0.7, r * 0.5)])
				draw_colored_polygon(pts3, ec)
			_:
				draw_circle(c, r * 0.5, ec)
				draw_line(c - Vector2(r * 0.5, r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color.WHITE, 2)
		if cd_k > 0:
			draw_rect(Rect2(0, 0, s.x, s.y * cd_k), Color(0, 0, 0, 0.65))
		if label_txt != "":
			draw_string_outline(G.font, Vector2(2, s.y - 2), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
			draw_string(G.font, Vector2(2, s.y - 2), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.8))
