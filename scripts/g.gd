extends Node
## 全局状态：存档（局外）、当前一局（局内）、设置

const SAVE_PATH := "user://save.json"
const RUN_PATH := "user://run.json"

var meta := {}      # 局外进度
var run := {}       # 当前一局
var settings := {}

var tex_cache := {}
var font: FontFile
var font_pixel: FontFile

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/wenkai.ttf")
	font_pixel = load("res://assets/fonts/fusion.ttf")
	_default_settings()
	load_meta()
	apply_settings()
	_setup_input()

# ------------------------------------------------------------ 资源
func tex(path:String) -> Texture2D:
	if tex_cache.has(path):
		return tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	tex_cache[path] = t
	return t

func spr(name:String) -> Texture2D:
	return tex("res://assets/sprites/%s.png" % name)

func portrait(name:String) -> Texture2D:
	return tex("res://assets/portraits/%s.png" % name)

# ------------------------------------------------------------ 设置
func _default_settings() -> void:
	settings = {
		"vol_master": 0.8, "vol_music": 0.3, "vol_sfx": 0.8, "vol_voice": 0.9,
		"fx": 1.0, "shake": true, "hitstop": true, "dmgnum": true,
		"fullscreen": true, "fps": 144, "keys": {},
	}

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, settings["vol_master"])))
	AudioServer.set_bus_volume_db(1, linear_to_db(max(0.0001, settings["vol_music"])))
	AudioServer.set_bus_volume_db(2, linear_to_db(max(0.0001, settings["vol_sfx"])))
	AudioServer.set_bus_volume_db(3, linear_to_db(max(0.0001, settings["vol_voice"])))
	if settings["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Engine.max_fps = int(settings["fps"])

const ACTIONS := {
	"up": ["W", "上移"], "down": ["S", "下移"], "left": ["A", "左移"], "right": ["D", "右移"],
	"dodge": ["Space", "身法/闪避"], "art1": ["Q", "斗技1"], "art2": ["E", "斗技2"], "art3": ["R", "斗技3"],
	"art4": ["F", "斗技4"], "ult": ["C", "大招"], "ult2": ["X", "第二大招"], "special": ["V", "角色特殊"],
	"pill": ["G", "使用丹药"], "combo": ["T", "同伴合击"], "interact": ["Z", "互动"], "panel": ["Tab", "功法面板"],
	"cmd1": ["1", "同伴：跟随"], "cmd2": ["2", "同伴：进攻"], "cmd3": ["3", "同伴：守护"], "cmd4": ["4", "同伴：集火"],
}
const PAD := {
	"dodge": JOY_BUTTON_A, "art1": JOY_BUTTON_X, "art2": JOY_BUTTON_Y, "art3": JOY_BUTTON_B,
	"art4": JOY_BUTTON_LEFT_SHOULDER, "ult": JOY_BUTTON_RIGHT_SHOULDER, "special": JOY_BUTTON_LEFT_STICK,
	"pill": JOY_BUTTON_DPAD_DOWN, "combo": JOY_BUTTON_DPAD_UP, "interact": JOY_BUTTON_A, "panel": JOY_BUTTON_BACK,
	"ult2": JOY_BUTTON_RIGHT_STICK, "cmd1": JOY_BUTTON_DPAD_LEFT, "cmd2": JOY_BUTTON_DPAD_RIGHT,
}

func _setup_input() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a, 0.3)
		var key: String = settings["keys"].get(a, ACTIONS[a][0])
		var ev := InputEventKey.new()
		ev.physical_keycode = OS.find_keycode_from_string(key)
		InputMap.action_add_event(a, ev)
		if PAD.has(a):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD[a]
			InputMap.action_add_event(a, jb)
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0]}
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axes[a][0]
		jm.axis_value = axes[a][1]
		InputMap.action_add_event(a, jm)
	for arrow in [["up", KEY_UP], ["down", KEY_DOWN], ["left", KEY_LEFT], ["right", KEY_RIGHT]]:
		var ek := InputEventKey.new()
		ek.physical_keycode = arrow[1]
		InputMap.action_add_event(arrow[0], ek)
	# 攻击：鼠标左键 / 手柄右扳机
	if InputMap.has_action("attack"):
		InputMap.erase_action("attack")
	InputMap.add_action("attack", 0.3)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	var jt := InputEventJoypadMotion.new()
	jt.axis = JOY_AXIS_TRIGGER_RIGHT
	jt.axis_value = 1.0
	InputMap.action_add_event("attack", jt)
	if InputMap.has_action("attack2"):
		InputMap.erase_action("attack2")
	InputMap.add_action("attack2", 0.3)
	var mb2 := InputEventMouseButton.new()
	mb2.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("attack2", mb2)
	var jt2 := InputEventJoypadMotion.new()
	jt2.axis = JOY_AXIS_TRIGGER_LEFT
	jt2.axis_value = 1.0
	InputMap.action_add_event("attack2", jt2)

func rebind(action:String, keycode:int) -> void:
	settings["keys"][action] = OS.get_keycode_string(keycode)
	_setup_input()
	save_meta()

func key_name(action:String) -> String:
	return settings["keys"].get(action, ACTIONS.get(action, ["?"])[0])

# ------------------------------------------------------------ 局外存档
func default_meta() -> Dictionary:
	return {
		"ver": 1,
		"crystal": 0, "contrib": 0, "fire_seed": 0, "mohe": 0,
		"herbs": {"zyl": 3, "xgh": 2},
		"pills": {}, "known_pills": ["huiqi", "juqi", "zhuji"],
		"buildings": {"alchemy": 1, "library": 1, "train": 1, "tower": 0, "forge": 0, "inn": 0, "codex": 1, "challenge": 0},
		"talents": {},
		"unlocked_chars": ["xiaoyan"],
		"unlocked_comps": ["yaolao"],
		"unlocked_skills": [],   # 藏经阁永久解锁的（额外进入奖励池）
		"unlocked_atks": ["atk_ruler", "atk_fist"],
		"seen_fires": [],
		"fire_levels": {},
		"relics_unlocked": [],
		"chapters_cleared": [],
		"prologue_done": false,
		"story_seen": [],
		"bond": {},
		"ach": [],
		"kills": 0, "runs": 0, "deaths": 0, "best_endless": 0,
		"codex_enemies": [], "codex_skills": [],
		"last_char": "xiaoyan", "last_atk": "atk_ruler", "last_comp": "yaolao",
		"skin": {}, "tianjie": [], "diff": 1,
		"daily_done": "",
	}

func load_meta() -> void:
	meta = default_meta()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text())
		if data is Dictionary:
			for k in data:
				if k == "settings":
					for sk in data[k]:
						settings[sk] = data[k][sk]
				else:
					meta[k] = data[k]
	_migrate_settings()

func _migrate_settings() -> void:
	if int(settings.get("mver", 0)) < 1:
		settings["mver"] = 1
		settings["vol_music"] = min(float(settings.get("vol_music", 0.3)), 0.3)
	if int(settings.get("mver", 0)) < 2:
		settings["mver"] = 2
		settings["fullscreen"] = true

func save_meta() -> void:
	var data := meta.duplicate(true)
	data["settings"] = settings
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func save_run() -> void:
	if run.is_empty():
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(run))

func load_run() -> bool:
	if not FileAccess.file_exists(RUN_PATH):
		return false
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and data.has("char"):
		run = data
		return true
	return false

func clear_run() -> void:
	run = {}
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))

func has_progress() -> bool:
	return bool(meta.get("prologue_done", false)) or int(meta.get("runs", 0)) > 0 or has_run()

## 新游戏：清空全部进度（保留设置）
func reset_all() -> void:
	run = {}
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))
	meta = default_meta()
	save_meta()

func has_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)

func unlock_ach(id:String) -> bool:
	if id in meta["ach"]:
		return false
	meta["ach"].append(id)
	save_meta()
	var m = get_tree().get_first_node_in_group("main")
	if m and m.has_method("toast"):
		m.toast("成就解锁：" + D.achievements[id]["n"], D.achievements[id]["d"], Color(1, 0.85, 0.3))
	return true

func talent_fx() -> Dictionary:
	var out := {}
	for t in D.talents:
		var lv: int = int(meta["talents"].get(t["id"], 0))
		if lv <= 0:
			continue
		for k in t["fx"]:
			out[k] = out.get(k, 0.0) + t["fx"][k] * lv
	return out

func faction_name() -> String:
	var n: int = meta["chapters_cleared"].size()
	return D.FACTIONS[clampi(n, 0, D.FACTIONS.size() - 1)]

func is_char_unlocked(c:String) -> bool:
	return c in meta["unlocked_chars"]

func unlock_char(c:String) -> void:
	if not (c in meta["unlocked_chars"]):
		meta["unlocked_chars"].append(c)
		var m = get_tree().get_first_node_in_group("main")
		if m and m.has_method("toast"):
			m.toast("新角色解锁：" + D.chars[c]["n"], D.chars[c]["t"], D.chars[c]["color"])
	if D.companions.has(c) and not (c in meta["unlocked_comps"]):
		meta["unlocked_comps"].append(c)
	save_meta()

# ------------------------------------------------------------ 新局
func new_run(char_id:String, chapter:int, atk:String, comp:String, diff:int, tianjie:Array, mode:String="story") -> void:
	var c: Dictionary = D.chars[char_id]
	var ch: Dictionary = D.chapters[chapter]
	var tf := talent_fx()
	run = {
		"char": char_id, "chapter": chapter, "mode": mode,
		"diff": diff, "tianjie": tianjie, "seed": randi(),
		"realm": int(ch.get("start_realm", 0)) * 3, "exp": 0.0,
		"hp": -1, "max_hp_bonus": 0,
		"gold": 60 + int(tf.get("start_gold", 0)),
		"herbs": {}, "pills": [], "pill_cap": 3,
		"atk": atk, "atk_grade": 0,
		"arts": [], "ults": [], "move": c["move"], "gong": c["gong"],
		"relics": [], "fires": [], "fused_pairs": [],
		"skill_grades": {}, "skill_affix": {}, "auto": {},
		"comp": comp, "floor": 0, "map": {}, "node": -1,
		"buffs": {}, "revives": int(tf.get("revive", 0)), "rerolls": int(tf.get("reroll", 0)),
		"kills": 0, "time": 0.0, "crystal_earned": 0,
		"blood": 0.0, "flags": {},
	}
	# 角色初始斗技
	for a in c["arts"]:
		add_skill(a)
	run["ults"].append(c["ult"])
	run["skill_grades"][c["ult"]] = D.skills[c["ult"]]["tier"] * 3
	if char_id == "xiaoyan" and chapter >= 2:
		add_fire("qldx", false)
	if chapter == 0:
		_setup_prologue()
	# 局外丹药带入
	if not ("nopill" in tianjie):
		for p in meta["pills"].keys():
			var n: int = int(meta["pills"][p])
			while n > 0 and run["pills"].size() < run["pill_cap"] + int(meta["buildings"].get("alchemy", 1)) - 1:
				run["pills"].append(p)
				n -= 1
			meta["pills"][p] = n
		save_meta()

func _setup_prologue() -> void:
	run["realm"] = 32
	run["atk"] = "atk_flame"
	run["atk_grade"] = 9
	for a in ["art_starfall", "art_yanfen", "art_dragonroar", "art_fireRain"]:
		add_skill(a, 9)
	run["ults"] = ["ult_lotus", "ult_diyin"]
	run["skill_grades"]["ult_lotus"] = 11
	run["skill_grades"]["ult_diyin"] = 11
	run["move"] = "mv_douqiwing"
	for f in ["qldx", "ylxy", "glly", "hxy", "sqyy", "jlyh", "xwty"]:
		add_fire(f, false)
	run["relics"] = ["rl_mohe7", "rl_tianyan", "rl_lingxi", "rl_xuemai"]

func add_skill(id:String, grade:int=-1) -> void:
	var s: Dictionary = D.skills[id]
	if grade < 0:
		grade = s["tier"] * 3
	match s["cat"]:
		"art":
			if not (id in run["arts"]):
				run["arts"].append(id)
		"ult":
			if not (id in run["ults"]):
				run["ults"].append(id)
		"move":
			run["move"] = id
		"gong":
			run["gong"] = id
		"relic":
			run["relics"].append(id)
		"atk":
			run["atk"] = id
	run["skill_grades"][id] = max(int(run["skill_grades"].get(id, 0)), grade)
	if not (id in meta["codex_skills"]):
		meta["codex_skills"].append(id)

func add_fire(id:String, notify:bool=true) -> void:
	if id in run["fires"]:
		return
	run["fires"].append(id)
	if not (id in meta["seen_fires"]):
		meta["seen_fires"].append(id)
	if notify:
		unlock_ach("ach_fire1")
		if run["fires"].size() >= 3:
			unlock_ach("ach_fire3")

func art_slots() -> int:
	# 随境界增加：斗之气2 → 斗者3 → 斗师3 → 大斗师4 → 斗王以上5 +法宝
	var major: int = int(run["realm"]) / 3
	var n := 2
	if major >= 1: n = 3
	if major >= 3: n = 4
	if major >= 5: n = 5
	if major >= 8: n = 6
	for r in run["relics"]:
		n += int(D.skills[r]["p"].get("art_slot", 0))
	return n

func ult_slots() -> int:
	var major: int = int(run["realm"]) / 3
	return 2 if major >= 2 else 1

func fire_slots() -> int:
	var major: int = int(run["realm"]) / 3
	var n := 1 + major / 2
	for r in run["relics"]:
		n += int(D.skills[r]["p"].get("fire_slot", 0))
	return max(1, n)

func exp_needed(realm:int) -> float:
	return 20.0 + realm * 14.0 + pow(realm, 1.6) * 3.0

func realm_cap() -> int:
	var ch: Dictionary = D.chapters[int(run["chapter"])]
	return int(ch["cap"]) * 3 + 2

## 局外（地图界面）估算生命上限 / 回复
func est_hp_max() -> float:
	var c: Dictionary = D.chars[run["char"]]
	return max(20.0, float(c["hp"]) + int(run["realm"]) * 11.0 + float(run.get("max_hp_bonus", 0)))

func heal_run(pct:float) -> void:
	if float(run["hp"]) < 0:
		return
	var mx := est_hp_max()
	var nh := float(run["hp"]) + mx * pct
	run["hp"] = -1 if nh >= mx else nh

func hurt_run(pct:float) -> void:
	var mx := est_hp_max()
	var h: float = mx if float(run["hp"]) < 0 else float(run["hp"])
	run["hp"] = max(1.0, h - mx * pct)
