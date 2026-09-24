class_name WD
## 探索式地图数据（v0.2 起）：
##  - 野外：一整张连续的大区域，怪物成群分布（靠近才会苏醒），宝箱/奇遇/修炼点/商人散布其中，
##    洞口可进入“洞穴/营地”等房间制子场景；区域边缘的出口通往下一个区域。
##  - 城镇：可以自由行走的街道，走到 坊市 / 拍卖场 / 丹药铺 / 客栈 门口按互动键进入。
##  - 原著斗技：萧炎在原著中学会的斗技，只能在对应地点通过剧情获得（canon）。

## 每章由哪些区域组成（按顺序）
static var chapter_zones := {
	1: ["wutan", "mt_out", "mt_deep"],
	2: ["desert", "jiama", "yunlan"],
}

## 原著斗技（萧炎专属，剧情获得；不会出现在随机奖励里）
## id -> {ch: 所属章节, story: 剧情key, grade: 获得时品阶}
static var canon := {
	"art_xizhang": {"ch": 1, "story": "canon_xizhang", "grade": 1},
	"art_baji": {"ch": 1, "story": "canon_baji", "grade": 2},
	"art_yanfen": {"ch": 1, "story": "canon_yanfen", "grade": 3},
	"mv_ziyun": {"ch": 1, "story": "canon_ziyun", "grade": 3},
	"ult_lotus": {"ch": 2, "story": "canon_lotus", "grade": 3},
	"ult_yaolao": {"ch": 2, "story": "canon_yaolao", "grade": 6},
	"art_skyfire": {"ch": 3, "story": "", "grade": 6},
	"mv_leidong": {"ch": 4, "story": "", "grade": 6},
	"ult_diyin": {"ch": 7, "story": "", "grade": 9},
	"ult_sanqian": {"ch": 5, "story": "", "grade": 9},
	"art_dazaohua": {"ch": 6, "story": "", "grade": 9},
}

## POI 类型：
##  story(原著剧情/斗技) shop auction alchemy rest event chest cave duel(剧情对决) boss(章节Boss) exit(下一区域)
## at: 相对坐标(0~1)，不写则随机放置。bld: 城镇建筑贴图。
static var zones := {
	# ------------------------------------------------------------------ 第一章
	"wutan": {"n": "乌坦城", "kind": "town", "biome": "wutan", "w": 2000, "h": 1250, "start": [0.16, 0.5],
		"pois": [
			{"id": "xiaojia", "t": "story", "canon": "art_xizhang", "n": "萧家·后山", "bld": "b_train", "at": [0.16, 0.24]},
			{"id": "shop", "t": "shop", "n": "坊市", "bld": "b_codex", "at": [0.38, 0.24]},
			{"id": "auction", "t": "auction", "n": "米特尔拍卖场", "bld": "b_library", "at": [0.6, 0.24]},
			{"id": "alchemy", "t": "alchemy", "n": "丹药铺", "bld": "b_alchemy", "at": [0.83, 0.24]},
			{"id": "inn", "t": "rest", "n": "客栈", "bld": "b_inn", "at": [0.3, 0.7]},
			{"id": "jialie", "t": "duel", "boss": "jialie", "story": "z_jialie", "n": "加列家族", "bld": "b_challenge", "at": [0.72, 0.7]},
			{"id": "ev1", "t": "event", "n": "街角的怪人", "at": [0.5, 0.52]},
			{"id": "exit", "t": "exit", "to": 1, "n": "城门 → 魔兽山脉", "bld": "b_gate", "at": [0.5, 0.86]},
		]},
	"mt_out": {"n": "魔兽山脉·外围", "kind": "wild", "biome": "forest", "w": 2600, "h": 1700, "start": [0.06, 0.5],
		"tiers": [0, 1], "packs": 7, "elite_packs": 0, "dens": 0.5,
		"pois": [
			{"id": "baji", "t": "story", "canon": "art_baji", "n": "山涧空地"},
			{"id": "camp", "t": "cave", "n": "狼头佣兵团营地", "rooms": [{"type": "fight"}, {"type": "elite", "boss": "mulie"}], "story": "z_camp"},
			{"t": "chest"}, {"t": "chest"}, {"t": "chest"},
			{"t": "event", "n": "奇遇"}, {"t": "event", "n": "奇遇"},
			{"t": "rest", "n": "灵泉"},
			{"t": "shop", "n": "行脚商人"},
			{"id": "exit", "t": "exit", "to": 2, "n": "深入山脉", "at": [0.95, 0.5]},
		]},
	"mt_deep": {"n": "魔兽山脉·深处", "kind": "wild", "biome": "forest", "w": 2800, "h": 1800, "start": [0.05, 0.5], "tint": Color(0.82, 0.88, 0.82),
		"tiers": [2, 3], "packs": 8, "elite_packs": 1, "dens": 0.62,
		"pois": [
			{"id": "yanfen", "t": "story", "canon": "art_yanfen", "n": "山间瀑布"},
			{"id": "lion", "t": "cave", "n": "紫晶翼狮王巢穴", "rooms": [{"type": "fight"}, {"type": "fight"}], "end": "canon:mv_ziyun", "story": "z_lion"},
			{"id": "wolfking", "t": "duel", "boss": "wolfking", "boss_room": true, "story": "z_wolfking", "n": "狼王领地"},
			{"t": "chest"}, {"t": "chest"}, {"t": "chest"},
			{"t": "event", "n": "奇遇"}, {"t": "event", "n": "奇遇"},
			{"t": "alchemy", "n": "药老的丹炉"},
			{"t": "rest", "n": "隐秘山洞"},
			{"id": "boss", "t": "boss", "n": "狼头佣兵团·大营", "at": [0.95, 0.5]},
		]},
	# ------------------------------------------------------------------ 第二章
	"desert": {"n": "塔戈尔大沙漠", "kind": "wild", "biome": "desert", "w": 2800, "h": 1800, "start": [0.05, 0.5],
		"tiers": [0, 1], "packs": 8, "elite_packs": 0, "dens": 0.32,
		"pois": [
			{"id": "lava", "t": "cave", "n": "蛇人族·地底熔岩", "rooms": [{"type": "fight"}, {"type": "fight"}], "end": "fire:qldx", "story": "z_lava"},
			{"id": "medusa", "t": "duel", "boss": "medusa", "boss_room": true, "story": "ch2_medusa", "n": "蛇人族王城"},
			{"t": "chest"}, {"t": "chest"}, {"t": "chest"},
			{"t": "event", "n": "奇遇"}, {"t": "event", "n": "奇遇"},
			{"t": "rest", "n": "绿洲"},
			{"t": "shop", "n": "沙漠商队"},
			{"id": "exit", "t": "exit", "to": 1, "n": "前往加玛帝都", "at": [0.95, 0.5]},
		]},
	"jiama": {"n": "加玛帝都", "kind": "town", "biome": "wutan", "w": 2000, "h": 1250, "start": [0.1, 0.5],
		"pois": [
			{"id": "auction", "t": "auction", "n": "米特尔拍卖场", "bld": "b_library", "at": [0.2, 0.24]},
			{"id": "guild", "t": "alchemy", "n": "炼药师公会", "bld": "b_alchemy", "at": [0.42, 0.24]},
			{"id": "shop", "t": "shop", "n": "坊市", "bld": "b_codex", "at": [0.64, 0.24]},
			{"id": "palace", "t": "event", "n": "皇城告示", "bld": "b_tower", "at": [0.86, 0.22]},
			{"id": "inn", "t": "rest", "n": "客栈", "bld": "b_inn", "at": [0.3, 0.7]},
			{"id": "forge", "t": "shop", "n": "兵器铺", "bld": "b_forge", "at": [0.55, 0.7]},
			{"id": "ev1", "t": "event", "n": "街头奇遇", "at": [0.75, 0.52]},
			{"id": "exit", "t": "exit", "to": 2, "n": "城门 → 云岚宗", "bld": "b_gate", "at": [0.86, 0.72]},
		]},
	"yunlan": {"n": "云岚宗", "kind": "wild", "biome": "yunlan", "w": 2600, "h": 1700, "start": [0.5, 0.94],
		"tiers": [2, 3], "packs": 8, "elite_packs": 1, "dens": 0.3,
		"pois": [
			{"id": "nalan", "t": "duel", "boss": "nalan", "story": "z_nalan", "n": "三年之约·演武台", "at": [0.5, 0.5]},
			{"id": "yaolao", "t": "story", "canon": "ult_yaolao", "n": "云岚宗·后山"},
			{"t": "chest"}, {"t": "chest"},
			{"t": "event", "n": "奇遇"},
			{"t": "rest", "n": "静室"},
			{"t": "shop", "n": "宗门杂役"},
			{"id": "boss", "t": "boss", "n": "云岚宗·大殿", "at": [0.5, 0.05]},
		]},
}

## 剧情文本（原著斗技 + 区域剧情）
static func stories() -> Dictionary:
	return {
		"canon_xizhang": [
			["yaolao", "药老", "小家伙，想重新修炼，就先从最基础的斗技开始。"],
			["yaolao", "药老", "这门「吸掌」，以斗气隔空摄物，可将敌人扯到身前。看好了——"],
			["xiaoyan", "萧炎", "（掌心一引，远处的木桩呼啸着飞到身前）……成了！"],
			["", "", "【习得斗技 · 吸掌】"],
		],
		"canon_baji": [
			["yaolao", "药老", "八极崩，玄阶高级斗技。一拳之中暗含八道劲力，层层叠加，专破护体斗气。"],
			["xiaoyan", "萧炎", "（一拳落在巨石上，石面完好无损——片刻后，巨石从内部轰然崩碎）"],
			["yaolao", "药老", "嘿，悟性不错。记住，暗劲在内，而非在外。"],
			["", "", "【习得斗技 · 八极崩】"],
		],
		"canon_yanfen": [
			["", "", "瀑布轰鸣，萧炎背着玄重尺，在激流之下一站便是数月。"],
			["yaolao", "药老", "焰分噬浪尺，地阶低级。斗气如浪，一浪高过一浪，最后一击，叠加前面所有的力量。"],
			["xiaoyan", "萧炎", "（尺落之处，瀑布被硬生生劈开一道缺口）"],
			["yaolao", "药老", "三年之约，这一招便是你的底牌。"],
			["", "", "【习得斗技 · 焰分噬浪尺】"],
		],
		"canon_ziyun": [
			["", "", "紫晶翼狮王的巢穴深处，石台上静静躺着一卷泛着紫光的卷轴。"],
			["yaolao", "药老", "紫云翼！地阶低级的飞行斗技，有了它，你也能暂时翱翔天际。"],
			["xiaoyan", "萧炎", "（背后斗气凝聚，化作一对紫色云翼）……飞起来了！"],
			["", "", "【习得身法 · 紫云翼】可越过障碍"],
		],
		"canon_lotus": [
			["yaolao", "药老", "如今你体内有了青莲地心火，老夫再借你一缕骨灵冷火。"],
			["yaolao", "药老", "将两种异火压缩在掌心，让它们相互冲撞——但要控制住，否则先炸死的是你自己。"],
			["xiaoyan", "萧炎", "（掌心之中，一朵青白相间的火莲缓缓成形）佛……怒……火……莲！"],
			["yaolao", "药老", "好！这便是属于你自己的斗技。以后每吞噬一种异火，它就会更强一分。"],
			["", "", "【习得大招 · 佛怒火莲】"],
		],
		"canon_yaolao": [
			["", "", "云岚宗后山，风声鹤唳。"],
			["yaolao", "药老", "小家伙，云山已入斗宗，凭你现在的实力，还不是他的对手。"],
			["xiaoyan", "萧炎", "老师……"],
			["yaolao", "药老", "到了关键时刻，喊老夫一声。老夫借你力量！"],
			["", "", "【习得大招 · 药老附身】"],
		],
		"z_jialie": [
			["", "加列奥", "萧家的小废物？听说你最近神气得很啊！"],
			["xiaoyan", "萧炎", "加列家欺我萧家多年，今天一并算清！"],
		],
		"z_camp": [
			["", "", "林间的营地里，狼头佣兵团的旗帜迎风招展。"],
			["yaolao", "药老", "狼头佣兵团的人。副团长穆力就在里面，小心些。"],
		],
		"z_lion": [
			["", "", "洞口弥漫着紫色的晶光，隐约传来魔兽低沉的呼吸声。"],
			["yaolao", "药老", "紫晶翼狮王的巢穴……它不在，里面的东西，值得冒险。"],
		],
		"z_wolfking": [
			["", "", "狼嚎四起。一头体型庞大的狼王从阴影中缓缓走出。"],
		],
		"z_lava": [
			["", "", "沙丘之下，隐藏着一条通往地底的裂缝，热浪扑面而来。"],
			["yaolao", "药老", "青莲地心火的气息……就在这下面！"],
		],
		"z_nalan": [
			["nalan", "纳兰嫣然", "萧炎……你真的来了。"],
			["xiaoyan", "萧炎", "三年之约，今日了结。当年你给的，我今天原样奉还！"],
		],
	}
