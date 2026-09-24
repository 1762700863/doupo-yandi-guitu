extends Node
## 音频管理
## · BGM：单播放器「先淡出 → 静默 → 再淡入」，绝不叠放两首曲子
## · 曲库按「情境(ctx)」组织成歌单，一首结束后稍停再淡入下一首（不硬循环）
## · 探索/城镇等情境记住播放位置，战斗结束后从原处淡入续播
## · 剧情对话按主要说话角色切换「角色专属曲」（push/pop 情境栈）
## 所有曲目已预先做过响度统一（-18 LUFS）并烘焙了淡入淡出，见 dev/tools/music_build.py

var mp: AudioStreamPlayer
var ctx := ""              # 当前情境
var cur_file := ""         # 当前曲目文件名（无扩展名）
var play_ctx := ""         # 当前曲目所属情境
var stack: Array = []      # push/pop 情境栈
var pos := {}              # ctx -> [file, 秒]  可续播情境的播放位置
var order := {}            # ctx -> 打乱后的歌单
var gen := 0               # 切换代号：新的切换会让旧的异步流程作废
var pool: Array[AudioStreamPlayer] = []
var cache := {}
var last_play := {}

const MUSIC_DB := -9.0
const SILENT_DB := -48.0
const FADE_OUT := 1.2
const GAP := 0.35
const FADE_IN := 2.0
const TRACK_GAP := 1.5     # 同一情境内换曲的静默间隔

## 情境 -> 曲目（assets/music/<name>.ogg）
const LISTS := {
	"title": ["title_jade_throne"],
	"hub": ["hub_tea_in_china"],
	"prologue": ["prologue_oriental"],
	# —— 区域 ——
	"zone_wutan": ["zone_wutan", "zone_wutan_b"],
	"zone_mt_out": ["zone_mt_out"],
	"zone_mt_deep": ["zone_mt_deep", "zone_mt_deep_b"],
	"zone_desert": ["zone_desert", "zone_desert_b"],
	"zone_jiama": ["zone_jiama", "zone_jiama_b"],
	"zone_yunlan": ["zone_yunlan", "zone_yunlan_b"],
	"cave": ["cave_a", "cave_b", "cave_c"],
	# —— 战斗 ——
	"battle": ["battle_a", "battle_b", "battle_c", "battle_d", "battle_e", "battle_f"],
	"battle_desert": ["battle_desert", "battle_b", "battle_d"],
	"elite": ["elite_a", "elite_b", "elite_c"],
	"boss": ["boss_default"],
	"boss_wolfking": ["boss_wolfking"],
	"boss_mushe": ["boss_mushe"],
	"boss_medusa": ["boss_medusa"],
	"boss_fire_spirit": ["boss_fire"],
	"boss_yunshan": ["boss_yunshan"],
	"boss_heart_demon": ["boss_heart"],
	"boss_hun_tiandi": ["boss_hun"],
	"boss_nalan": ["boss_nalan"],
	"boss_jialie": ["boss_jialie"],
	"boss_mulie": ["elite_b"],
	"boss_soul_elder": ["theme_hun"],
	# —— 功能 ——
	"shop": ["shop"],
	"alchemy": ["alchemy"],
	"rest": ["rest"],
	"fire": ["fire_devour"],
	"breakthrough": ["breakthrough"],
	"victory": ["victory"],
	"clear": ["chapter_clear"],
	"defeat": ["defeat"],
	"sad": ["story_sad"],
	"memory": ["story_memory"],
	# —— 角色专属曲 ——
	"theme_xiaoyan": ["theme_xiaoyan"],
	"theme_yandi": ["theme_yandi"],
	"theme_xuner": ["theme_xuner"],
	"theme_yunyun": ["theme_yunyun"],
	"theme_medusa": ["theme_medusa"],
	"theme_xiaoyixian": ["theme_xiaoyixian"],
	"theme_yaolao": ["theme_yaolao"],
	"theme_nalan": ["theme_nalan"],
	"theme_hun_tiandi": ["theme_hun"],
	"theme_yunshan": ["theme_yunshan"],
}
## 无缝循环素材：不烘焙淡入淡出，直接循环
const LOOPS := ["zone_desert_b", "battle_desert"]
## 不记位置的情境（每次都从头播放）
const NO_RESUME := ["battle", "battle_desert", "elite", "victory", "clear", "defeat", "breakthrough", "fire", "prologue"]
## 旧调用名兼容
const LEGACY := {"calm": "victory", "battle1": "battle", "battle2": "battle", "boss": "boss"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mp = AudioStreamPlayer.new()
	mp.bus = "Music"
	mp.volume_db = SILENT_DB
	add_child(mp)
	mp.finished.connect(_on_track_end)
	for i in 24:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)

func _stream(path:String) -> AudioStream:
	if cache.has(path):
		return cache[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	cache[path] = s
	return s

# ================================================================ BGM 公共接口
## 切换到情境（相同情境则不打断）
func music(c:String) -> void:
	c = LEGACY.get(c, c)
	if not LISTS.has(c):
		push_warning("未知音乐情境: " + c)
		return
	if c == ctx and (mp.playing or _pending):
		return
	_switch(c)

## 临时切换（剧情/商店等），pop() 回到之前的情境并续播
func push(c:String) -> void:
	c = LEGACY.get(c, c)
	if not LISTS.has(c):
		stack.append("")
		return
	stack.append(ctx)
	music(c)

func pop() -> void:
	if stack.is_empty():
		return
	var prev: String = stack.pop_back()
	if prev != "":
		music(prev)

## 清空临时栈（切场景时，避免旧 pop 把音乐拉回错误情境）
func clear_stack() -> void:
	stack.clear()

func stop_music(fade:float=FADE_OUT) -> void:
	_remember()
	gen += 1
	ctx = ""
	_pending = false
	_fade_out(fade, gen)

## 各区域 / 战斗 / Boss 的情境名
func zone_ctx(zone_id:String) -> String:
	return "zone_" + zone_id if LISTS.has("zone_" + zone_id) else "zone_wutan"

func battle_ctx(biome:String="") -> String:
	return "battle_desert" if biome == "desert" else "battle"

func boss_ctx(bid:String) -> String:
	return "boss_" + bid if LISTS.has("boss_" + bid) else "boss"

## 可被剧情专属曲覆盖的「平静」情境
func calm_now() -> bool:
	return ctx.begins_with("zone_") or ctx.begins_with("theme_") or ctx in ["", "hub", "cave", "prologue", "title", "rest"]

## 对话主角 -> 专属曲情境（没有专属曲返回 ""）
func theme_ctx(char_id:String) -> String:
	return "theme_" + char_id if LISTS.has("theme_" + char_id) else ""

# ================================================================ BGM 内部
var _pending := false
var _tw: Tween

func _new_tween() -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	return _tw

func _remember() -> void:
	if play_ctx == "" or cur_file == "" or not mp.playing or play_ctx in NO_RESUME:
		return
	var t := mp.get_playback_position()
	var total := mp.stream.get_length() if mp.stream else 0.0
	if total - t > 10.0:
		pos[play_ctx] = [cur_file, t]
	else:
		pos.erase(play_ctx)

func _switch(c:String) -> void:
	_remember()
	gen += 1
	var g := gen
	ctx = c
	_pending = true
	if mp.playing and mp.volume_db > SILENT_DB + 1:
		await _fade_out(FADE_OUT, g)
		if g != gen:
			return
		await get_tree().create_timer(GAP, true, false, true).timeout
	else:
		mp.stop()
	if g != gen:
		return
	_start(g)

func _fade_out(d:float, g:int) -> void:
	var tw := _new_tween()
	tw.tween_property(mp, "volume_db", SILENT_DB, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if g == gen:
		mp.stop()

func _next_file(c:String) -> String:
	var l: Array = LISTS[c]
	if l.size() == 1:
		return l[0]
	var o: Array = order.get(c, [])
	if o.is_empty():
		o = l.duplicate()
		o.shuffle()
		if o[0] == cur_file:
			o.push_back(o.pop_front())
	var f: String = o.pop_front()
	order[c] = o
	return f

func _start(g:int, fresh:bool=false) -> void:
	var file := ""
	var from := 0.0
	if not fresh and pos.has(ctx):
		file = pos[ctx][0]
		from = pos[ctx][1]
		pos.erase(ctx)
	else:
		file = _next_file(ctx)
	var s := _stream("res://assets/music/%s.ogg" % file)
	_pending = false
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = file in LOOPS
	cur_file = file
	play_ctx = ctx
	mp.stream = s
	mp.volume_db = SILENT_DB
	mp.play(from)
	var tw := _new_tween()
	# 从头播放时文件本身已有淡入，续播时用稍长的淡入
	var fi := FADE_IN if from > 0.5 else 1.0
	tw.tween_property(mp, "volume_db", MUSIC_DB, fi).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_track_end() -> void:
	if ctx == "" or _pending:
		return
	var g := gen
	_pending = true
	await get_tree().create_timer(TRACK_GAP, true, false, true).timeout
	if g != gen:
		return
	_start(g, true)

# ================================================================ 音效 / 语音
func sfx(name:String, vol:float=0.0, pitch:float=1.0, rand_pitch:float=0.08) -> void:
	var now := Time.get_ticks_msec()
	if last_play.get(name, 0) + 35 > now:
		return
	last_play[name] = now
	var s := _stream("res://assets/sfx/%s.wav" % name)
	if s == null:
		s = _stream("res://assets/sfx/%s.ogg" % name)
	if s == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol
			p.pitch_scale = pitch * randf_range(1.0 - rand_pitch, 1.0 + rand_pitch)
			p.play()
			return

func voice(name:String) -> void:
	var s := _stream("res://assets/voice/%s.ogg" % name)
	if s == null:
		s = _stream("res://assets/voice/%s.mp3" % name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Voice"
	p.stream = s
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
