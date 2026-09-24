class_name Puppet
extends RefCounted
## 程序化动画辅助：给 Sprite2D 套上带透明边的纹理和 puppet 着色器，并每帧更新形变参数

const PAD := 4
static var _cache := {}

## 返回四周加了 PAD 像素透明边的纹理（缓存）
static func padded(name:String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t := G.spr(name)
	if t == null:
		return null
	var src := t.get_image()
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var img := Image.create(src.get_width() + PAD * 2, src.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(PAD, PAD))
	var out := ImageTexture.create_from_image(img)
	_cache[name] = out
	return out

## 设置精灵；kind: 0 人形 1 四足 2 蛇 3 漂浮。返回材质
static func apply(spr:Sprite2D, name:String, kind:int=-1) -> ShaderMaterial:
	var t := padded(name)
	spr.texture = t
	spr.centered = true
	if t:
		spr.offset = Vector2(0, -t.get_height() * 0.5 + PAD)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/puppet.gdshader")
	mat.set_shader_parameter("pad", float(PAD))
	mat.set_shader_parameter("kind", kind if kind >= 0 else kind_of(name))
	mat.set_shader_parameter("breathe", randf() * TAU)
	spr.material = mat
	return mat

static func kind_of(name:String) -> int:
	if name.contains("wolf") or name.contains("lion") or name.contains("beast") or name.contains("tiger"):
		return 1
	if name.contains("snake"):
		return 2
	if name == "e_soul" or name.contains("ghost") or name == "yaolao":
		return 3
	return 0

## 原始（未加边）尺寸
static func size_of(spr:Sprite2D) -> Vector2:
	return spr.texture.get_size() - Vector2(PAD * 2, PAD * 2) if spr and spr.texture else Vector2.ZERO

## 每帧：walk=步伐相位，move=0..1，lean_world=世界空间前倾像素（正=右），facing=±1
static func tick(mat:ShaderMaterial, delta:float, walk:float, move:float, lean_world:float, facing:float) -> void:
	if mat == null:
		return
	var br: float = mat.get_shader_parameter("breathe")
	mat.set_shader_parameter("breathe", fmod(br + delta * 2.2, TAU * 100.0))
	mat.set_shader_parameter("walk", walk)
	mat.set_shader_parameter("move", clampf(move, 0.0, 1.0))
	mat.set_shader_parameter("lean", lean_world * signf(facing if facing != 0 else 1.0))
