extends Node
## 音频管理：BGM 交叉淡入淡出 + 音效池

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var cur_music := ""
var pool: Array[AudioStreamPlayer] = []
var cache := {}
var last_play := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_a = AudioStreamPlayer.new(); music_a.bus = "Music"; add_child(music_a)
	music_b = AudioStreamPlayer.new(); music_b.bus = "Music"; add_child(music_b)
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

func music(name:String) -> void:
	if name == cur_music:
		return
	cur_music = name
	var s := _stream("res://assets/music/%s.ogg" % name)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = true
	var old := music_a
	music_a = music_b
	music_b = old
	music_a.stream = s
	music_a.volume_db = -40
	music_a.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(music_a, "volume_db", 0.0, 1.2)
	tw.tween_property(music_b, "volume_db", -40.0, 1.2)
	tw.chain().tween_callback(music_b.stop)

func sfx(name:String, vol:float=0.0, pitch:float=1.0, rand_pitch:float=0.08) -> void:
	var now := Time.get_ticks_msec()
	if last_play.get(name, 0) + 35 > now:
		return
	last_play[name] = now
	var s := _stream("res://assets/sfx/%s.wav" % name)
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
