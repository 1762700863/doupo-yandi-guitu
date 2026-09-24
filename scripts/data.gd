extends Node
## 全部静态数据：角色、斗技、异火、功法、身法、法宝、丹药、敌人、Boss、章节、剧情、成就……

const GRADE_NAMES := ["黄阶低级","黄阶中级","黄阶高级","玄阶低级","玄阶中级","玄阶高级","地阶低级","地阶中级","地阶高级","天阶低级","天阶中级","天阶高级"]
const TIER_NAMES := ["黄阶","玄阶","地阶","天阶"]
const TIER_COLORS := [Color("d9b45a"), Color("6fb4ff"), Color("c07cff"), Color("ff6a3d")]

const ELEM := {
	"phys": {"n":"物理","c":Color(0.92,0.9,0.86)},
	"fire": {"n":"火","c":Color(1.0,0.5,0.18)},
	"cold": {"n":"冰","c":Color(0.6,0.88,1.0)},
	"wind": {"n":"风","c":Color(0.55,1.0,0.8)},
	"thunder": {"n":"雷","c":Color(0.72,0.62,1.0)},
	"poison": {"n":"毒","c":Color(0.55,0.95,0.3)},
	"soul": {"n":"魂","c":Color(0.65,0.35,1.0)},
	"gold": {"n":"金","c":Color(1.0,0.84,0.3)},
	"earth": {"n":"土","c":Color(0.8,0.6,0.35)},
	"void": {"n":"虚无","c":Color(0.45,0.25,0.7)},
}

# 境界（每章限制上限）。每个境界分 初/中/后 三个小阶段
const REALMS := ["斗之气","斗者","斗师","大斗师","斗灵","斗王","斗皇","斗宗","斗尊","半圣","斗圣","斗帝"]
const REALM_COLORS := [Color(0.7,0.7,0.7),Color(0.6,0.9,0.6),Color(0.4,0.8,1),Color(0.3,0.5,1),Color(0.7,0.5,1),Color(1,0.75,0.3),Color(1,0.5,0.2),Color(1,0.3,0.3),Color(1,0.25,0.6),Color(0.9,0.9,1),Color(1,0.95,0.6),Color(1,1,1)]
const SUB_STAGES := ["一","二","三","四","五","六","七","八","九"]
# 境界编号 r：大境界 = r / 9，小阶 = r % 9（斗之气为“段”，其余为“星”）；斗帝 = 99
# 战力换算表（每个大境界起点的战力值），用于属性成长
const REALM_POW := [0.0, 6.0, 11.0, 14.0, 17.0, 20.0, 23.0, 26.0, 28.0, 30.0, 31.0, 33.0, 33.0]

# 天劫（加难词条）
const TIANJIE := [
	{"id":"hp","n":"魔兽狂化","d":"敌人生命+40%","pt":1},
	{"id":"dmg","n":"杀机四伏","d":"敌人伤害+35%","pt":1},
	{"id":"spd","n":"疾风魔影","d":"敌人移速+20%","pt":1},
	{"id":"elite","n":"群雄并起","d":"普通房间有概率出现精英","pt":2},
	{"id":"boss","n":"绝境之主","d":"Boss 生命+50%，招式更快","pt":2},
	{"id":"price","n":"坊市黑心","d":"商品价格+50%","pt":1},
	{"id":"heal","n":"断脉之伤","d":"治疗效果-40%","pt":2},
	{"id":"bullet","n":"漫天杀意","d":"敌人弹幕数量+50%","pt":2},
	{"id":"nochoice","n":"天道吝啬","d":"奖励三选一变为二选一","pt":2},
	{"id":"time","n":"限时之约","d":"每个战斗房间限时90秒，超时持续掉血","pt":3},
	{"id":"cursed","n":"异火反噬","d":"吞噬异火失败伤害翻倍","pt":1},
	{"id":"nopill","n":"丹药禁令","d":"无法携带局外丹药","pt":2},
]
const DIFFS := [
	{"n":"凡人","hp":0.65,"dmg":0.55,"rew":0.7,"d":"适合体验剧情"},
	{"n":"斗者","hp":1.0,"dmg":1.0,"rew":1.0,"d":"标准难度"},
	{"n":"斗宗","hp":1.35,"dmg":1.4,"rew":1.4,"d":"需要熟练的走位与构筑"},
	{"n":"斗帝","hp":1.8,"dmg":1.9,"rew":2.0,"d":"莫欺少年穷？先活下来再说"},
]

# ------------------------------------------------------------------ 角色
var chars := {
	"xiaoyan": {"n":"萧炎","t":"炎帝传人","spr":"xiaoyan","hp":110,"spd":118,"elem":"fire","mech":"异火吞噬：拥有的异火越多，火属性伤害与佛怒火莲越强。可在多种普攻风格间选择。",
		"atks":["atk_ruler","atk_fist","atk_flame","atk_claw","atk_blade"],"ult":"ult_lotus","move":"mv_roll","gong":"gong_fenjue","arts":["art_xizhang"],"unlock":"default","color":Color(1,0.45,0.2)},
	"xuner": {"n":"萧薰儿","t":"古族天之骄女","spr":"xuner","hp":95,"spd":122,"elem":"gold","mech":"古族血脉：造成伤害积累血脉值，满值时按 V 觉醒为金色形态（伤害+60%，普攻变为金炎光束）。",
		"atks":["atk_goldorb"],"ult":"ult_golden","move":"mv_goldlight","gong":"gong_guzu","arts":["art_goldseal"],"unlock":"ch1","color":Color(1,0.85,0.35)},
	"medusa": {"n":"美杜莎","t":"蛇人族女王","spr":"medusa","hp":125,"spd":112,"elem":"poison","mech":"双形态：按 V 切换人形（远程紫芒）/蛇形（近战横扫、减伤30%）。攻击叠加毒层，凝视可石化敌人。",
		"atks":["atk_serpent"],"ult":"ult_python","move":"mv_snake","gong":"gong_bishe","arts":["art_petrify"],"unlock":"defeat_medusa","color":Color(0.75,0.4,1)},
	"yunyun": {"n":"云韵","t":"云岚宗宗主","spr":"yunyun","hp":100,"spd":130,"elem":"wind","mech":"风之剑舞：连击数每满10，自动放出一道追踪风刃；连击越高攻速越快。受伤会清空连击。",
		"atks":["atk_windsword"],"ult":"ult_windkill","move":"mv_wind","gong":"gong_yunlan","arts":["art_windblade"],"unlock":"ch2","color":Color(0.6,0.9,1)},
	"xiaoyixian": {"n":"小医仙","t":"厄难毒体","spr":"xiaoyixian","hp":90,"spd":116,"elem":"poison","mech":"厄难毒体：施放斗技可消耗生命换取+50%伤害（按 V 开关）。毒层可被“毒爆”引爆，生命越低伤害越高。",
		"atks":["atk_poison"],"ult":"ult_ernan","move":"mv_mist","gong":"gong_ernan","arts":["art_poisonburst"],"unlock":"ch1_story","color":Color(0.6,1,0.4)},
}
var char_order := ["xiaoyan","xuner","medusa","yunyun","xiaoyixian"]
var skins := {
	"xiaoyan": [{"id":"default","n":"少年萧炎","spr":"xiaoyan","req":""},{"id":"yandi","n":"炎帝","spr":"yandi","req":"ach_yandi"}],
}

# 同伴（AI 跟随，可指令）
var companions := {
	"yaolao": {"n":"药老","spr":"yaolao","elem":"cold","atk":14,"rate":1.2,"combo":"骨灵冷火·寒炎潮","d":"发射骨灵冷火，合击：大范围冰火冲击","unlock":"default"},
	"xuner": {"n":"萧薰儿","spr":"xuner","elem":"gold","atk":12,"rate":0.9,"combo":"金帝天火阵","d":"金炎球追击，合击：金色火阵","unlock":"ch1"},
	"xiaoyixian": {"n":"小医仙","spr":"xiaoyixian","elem":"poison","atk":8,"rate":0.8,"combo":"厄难毒雾","d":"毒球并治疗主角，合击：毒雾领域+回血","unlock":"ch1_story"},
	"medusa": {"n":"美杜莎","spr":"medusa","elem":"poison","atk":18,"rate":1.4,"combo":"碧蛇三花瞳","d":"紫芒穿刺，合击：全屏石化","unlock":"defeat_medusa"},
	"yunyun": {"n":"云韵","spr":"yunyun","elem":"wind","atk":13,"rate":0.7,"combo":"风之极·落日耀","d":"风刃连斩，合击：风暴剑阵","unlock":"ch2"},
}

# ------------------------------------------------------------------ 斗技 / 普攻 / 大招 / 身法 / 功法 / 法宝
# cat: atk 普攻, art 斗技, ult 大招, move 身法, gong 功法, relic 法宝
# kind: proj nova aoe arc dash beam zone orbit rain chain summon buff pull wave trap lotus
var skills := {}
var art_pool := []   # 通用斗技 id
var ult_pool := []
var move_pool := []
var gong_pool := []
var relic_pool := []

func S(id:String, n:String, cat:String, elem:String, kind:String, dmg:float, cd:float, p:Dictionary={}, d:String="", ch:String="", tier:int=0) -> void:
	var s := {"id":id,"n":n,"cat":cat,"elem":elem,"kind":kind,"dmg":dmg,"cd":cd,"p":p,"d":d,"ch":ch,"tier":tier}
	skills[id] = s
	if ch == "" and not p.get("hidden", false):
		match cat:
			"art": art_pool.append(id)
			"ult": ult_pool.append(id)
			"move": move_pool.append(id)
			"gong": gong_pool.append(id)
			"relic": relic_pool.append(id)

func _build_skills() -> void:
	# ---------- 普攻风格 ----------
	S("atk_ruler","玄重尺","atk","phys","arc",20,0.52,{"range":62,"angle":150,"combo":3,"knock":170,"heavy":true,"shake":3},"萧炎的招牌重尺。三段横扫，第三段震地并击退。","xiaoyan")
	S("atk_fist","八极拳掌","atk","phys","arc",10,0.22,{"range":40,"angle":90,"combo":4,"knock":60,"finisher_wave":true},"迅捷四连击，第四击爆发八极崩冲击波。","xiaoyan")
	S("atk_flame","焰掌","atk","fire","proj",11,0.3,{"speed":420,"size":7,"pierce":0,"count":1},"凝聚异火成掌，远程射击。随异火数量增加额外火球。","xiaoyan")
	S("atk_claw","骨灵冷火爪","atk","cold","arc",13,0.3,{"range":48,"angle":120,"combo":3,"chill":true},"药老所授冷火化爪，命中减速，第三击冻结。","xiaoyan")
	S("atk_blade","异火飞刃","atk","fire","proj",12,0.42,{"speed":380,"size":8,"pierce":99,"boomerang":true,"count":1},"掷出回旋的异火刃，往返穿透。","xiaoyan")
	S("atk_goldorb","金炎灵珠","atk","gold","proj",10,0.28,{"speed":400,"size":7,"homing":2.5,"count":1},"金帝焚天炎凝成灵珠，轻微追踪。","xuner")
	S("atk_serpent","紫芒/蛇尾","atk","poison","proj",12,0.34,{"speed":430,"size":6,"pierce":1,"count":1,"poison":1},"人形：紫芒穿刺；蛇形：蛇尾横扫。","medusa")
	S("atk_windsword","流云剑","atk","wind","arc",8,0.18,{"range":50,"angle":110,"combo":3,"knock":40,"wave_on_3":true},"极快的三连剑，第三剑放出剑气。","yunyun")
	S("atk_poison","毒蛊弹","atk","poison","proj",8,0.3,{"speed":360,"size":7,"count":1,"poison":2,"split_on_death":true},"毒弹叠加毒层，毒死的敌人会爆出毒雾。","xiaoyixian")
	# ---------- 角色专属斗技（初始） ----------
	S("art_xizhang","吸掌","art","phys","pull",14,5.0,{"radius":130,"pull":260,"at_self":false},"黄阶斗技。将敌人吸至掌前并重击。","xiaoyan",0)
	S("art_goldseal","古帝金印","art","gold","aoe",40,5.5,{"radius":70,"delay":0.35,"stun":0.8},"金印从天而降，眩晕敌人。","xuner",1)
	S("art_petrify","石化凝视","art","poison","beam",6,7.0,{"len":260,"width":26,"dur":0.8,"petrify":1.5},"碧蛇三花瞳，射线石化前方敌人。","medusa",1)
	S("art_windblade","风之极·刃","art","wind","proj",16,3.0,{"speed":520,"size":10,"count":5,"spread":40,"pierce":2},"扇形放出五道风刃。","yunyun",1)
	S("art_poisonburst","毒爆","art","poison","aoe",10,4.5,{"radius":150,"delay":0.1,"detonate":true,"at_self":true},"引爆周围敌人身上的毒层，每层造成额外伤害。","xiaoyixian",1)
	# ---------- 通用斗技（原著 + 玄幻衍生） ----------
	S("art_baji","八极崩","art","phys","aoe",34,3.5,{"radius":60,"delay":0.0,"at_self":false,"range":70,"knock":260,"shake":5},"萧炎早期招牌，以寸劲震碎敌人，距离越近伤害越高。","",0)
	S("art_yanfen","焰分噬浪尺","art","fire","wave",26,6.0,{"radius":190,"speed":340,"burn":3},"玄阶高级。以尺引火，掀起火浪横扫四周。","",1)
	S("art_chuihuo","吹火掌","art","fire","proj",14,2.2,{"speed":330,"size":9,"count":3,"spread":22,"burn":2},"吐出三团火焰。","",0)
	S("art_dazaohua","大天造化掌","art","gold","aoe",70,9.0,{"radius":95,"delay":0.5,"shake":8},"地阶斗技。巨掌自天而降。","",2)
	S("art_fireRain","流星火雨","art","fire","rain",22,6.5,{"count":10,"radius":36,"area":150,"delay":0.5,"burn":2},"召唤火雨覆盖区域。","",1)
	S("art_vortex","烈焰漩涡","art","fire","zone",8,7.0,{"radius":80,"dur":4.0,"tick":0.3,"pull":80},"持续灼烧并牵引敌人的火焰漩涡。","",1)
	S("art_dragonroar","炎龙吼","art","fire","beam",9,6.0,{"len":320,"width":34,"dur":1.2,"burn":3},"化火为龙，持续喷吐。","",2)
	S("art_pillar","焚天火柱","art","fire","rain",40,7.0,{"count":4,"radius":44,"area":120,"delay":0.7,"knock":120},"四道火柱拔地而起。","",2)
	S("art_featherblades","火羽千刃","art","fire","nova",9,4.0,{"count":16,"speed":360,"size":6,"pierce":1},"火羽向四周爆射。","",1)
	S("art_chainexp","炎爆连环","art","fire","chain",20,4.5,{"jumps":5,"range":150,"explode":34},"连锁爆炎，在敌人间跳跃。","",1)
	S("art_firewheel","回旋火轮","art","fire","orbit",10,8.0,{"count":3,"radius":62,"dur":5.0,"size":12},"三枚火轮环绕周身。","",0)
	S("art_flameslash","烈焰刀芒","art","fire","proj",30,2.8,{"speed":520,"size":14,"count":1,"pierce":99,"crescent":true},"月牙形刀芒，穿透所有敌人。","",0)
	S("art_flamering","焰环斩","art","fire","wave",16,3.8,{"radius":120,"speed":420,"burn":1},"以身为轴斩出火环。","",0)
	S("art_icecone","寒冰锥","art","cold","proj",14,2.4,{"speed":460,"size":8,"count":3,"spread":14,"chill":true},"三枚冰锥，命中减速。","",0)
	S("art_icefield","冰封千里","art","cold","zone",5,9.0,{"radius":120,"dur":4.0,"tick":0.4,"freeze":0.9,"at_self":true},"冰封周身，冻结踏入者。","",2)
	S("art_thunder","天雷引","art","thunder","rain",30,5.5,{"count":6,"radius":30,"area":160,"delay":0.45,"stun":0.4},"引天雷轰击。","",1)
	S("art_thunderchain","雷霆锁链","art","thunder","chain",16,3.2,{"jumps":6,"range":170,"stun":0.25},"闪电在敌人之间跳跃。","",0)
	S("art_windcut","疾风刃","art","wind","proj",12,1.6,{"speed":560,"size":7,"count":2,"spread":8,"pierce":3},"两道快速风刃。","",0)
	S("art_tornado","风卷残云","art","wind","zone",7,7.5,{"radius":60,"dur":4.0,"tick":0.25,"pull":150,"moving":true},"移动的龙卷风卷入敌人。","",1)
	S("art_poisonfield","毒蛊阵","art","poison","zone",4,7.0,{"radius":100,"dur":5.0,"tick":0.5,"poison":1},"布下毒蛊阵，持续叠加毒层。","",0)
	S("art_soulchain","魂锁链","art","soul","chain",14,5.0,{"jumps":4,"range":160,"weaken":3},"魂殿秘术，锁链束缚敌人并削弱。","",1)
	S("art_devour","吞灵漩涡","art","void","pull",20,8.0,{"radius":180,"pull":320,"lifesteal":0.3},"吞噬周围生灵之力，回复生命。","",2)
	S("art_crush","碎山拳","art","earth","aoe",36,3.6,{"radius":52,"delay":0.1,"range":60,"stun":0.5,"shake":4},"一拳碎山，眩晕敌人。","",0)
	S("art_quake","裂地击","art","earth","wave",22,5.0,{"radius":150,"speed":300,"stun":0.4},"震裂大地，冲击波扩散。","",1)
	S("art_spikes","地刺","art","earth","rain",18,4.0,{"count":7,"radius":22,"area":110,"delay":0.25,"line":true},"一列地刺向前突出。","",0)
	S("art_shadowpalm","千影掌","art","phys","proj",8,3.0,{"speed":480,"size":8,"count":8,"spread":50},"掌影如雨。","",1)
	S("art_flamedash","焰翼突进","art","fire","dash",28,4.0,{"dist":170,"burn":2},"化作火光向前突进，沿途灼烧。","",1)
	S("art_purpleblade","紫焰刃","art","fire","proj",20,3.0,{"speed":440,"size":10,"count":2,"spread":10,"pierce":1,"homing":3.0,"burn":2},"追踪的紫色焰刃。","",1)
	S("art_coreblast","魔核爆裂","art","earth","trap",40,5.0,{"count":3,"radius":60,"arm":0.6},"布下魔核地雷。","",1)
	S("art_bahuang","八荒掌","art","phys","wave",30,6.5,{"radius":170,"speed":500,"knock":300,"shake":6},"掌劲横扫八荒。","",2)
	S("art_jingang","金刚护体","art","gold","buff",0,12.0,{"dur":5.0,"shield":40,"armor":0.4},"获得护盾与减伤。","",0)
	S("art_berserk","狂暴战意","art","phys","buff",0,14.0,{"dur":6.0,"dmg":0.5,"aspd":0.3},"伤害与攻速提升。","",1)
	S("art_soulshock","灵魂冲击","art","soul","nova",14,5.0,{"count":10,"speed":300,"size":9,"pierce":99,"weaken":2},"灵魂之力向四周冲击。","",1)
	S("art_beasts","万兽灵火·召","art","fire","summon",10,12.0,{"count":2,"dur":10.0},"召唤火焰灵兽协同作战。","",1)
	S("art_icebird","冰凰","art","cold","proj",36,5.0,{"speed":260,"size":16,"count":1,"pierce":99,"chill":true,"freeze":0.6},"海波东绝技，冰凰冲击。","",2)
	S("art_meteor","陨星坠","art","fire","aoe",90,11.0,{"radius":110,"delay":1.1,"shake":10,"burn":4},"召唤陨星坠落。","",2)
	S("art_yinyang","阴阳双炎","art","fire","orbit",14,7.0,{"count":2,"radius":80,"dur":6.0,"size":14,"yinyang":true},"黑白双炎环绕，一冷一热。","",1)
	S("art_heartfire","心火","art","fire","buff",0,15.0,{"dur":8.0,"dmg":0.3,"regen":2.0},"陨落心炎之力，心火焚身，攻击与回复提升。","",2)
	S("art_seaheart","海心屏障","art","cold","buff",0,13.0,{"dur":6.0,"shield":60,"reflect":0.3},"海心焰屏障，反弹部分伤害。","",1)
	S("art_bladerain","剑雨","art","wind","rain",16,5.0,{"count":12,"radius":24,"area":170,"delay":0.35},"万剑齐落。","",1)
	S("art_starfall","三千焱炎·星陨","art","fire","nova",20,6.0,{"count":24,"speed":300,"size":8,"burn":2,"homing":1.5},"星辰之火四散追击。","",3)
	S("art_thunderstep","雷动斩","art","thunder","dash",24,3.5,{"dist":200,"stun":0.3},"三千雷动化作斩击。","",1)
	S("art_goldpalm","金帝天火掌","art","gold","proj",40,4.0,{"speed":360,"size":18,"count":1,"pierce":99,"burn":3},"金色巨掌推进。","",2)
	S("art_mistcloud","云雾迷踪","art","wind","trap",20,6.0,{"count":4,"radius":50,"arm":0.4,"stun":0.6},"布下风云陷阱。","",0)
	S("art_bloodlotus","血莲爆","art","fire","aoe",50,6.0,{"radius":80,"delay":0.4,"lifesteal":0.2},"血色火莲绽放，吸取生命。","",2)
	S("art_skyfire","天火三玄变","art","fire","buff",0,20.0,{"dur":8.0,"dmg":0.8,"spd":0.3,"selfdmg":0.02},"燃烧自身，三段暴涨实力，持续掉血。","",2)
	S("art_iceswords","寒冰剑阵","art","cold","orbit",12,8.0,{"count":6,"radius":70,"dur":5.0,"size":9,"chill":true},"冰剑环绕。","",1)
	S("art_soulflame","魂火","art","soul","proj",18,2.6,{"speed":300,"size":11,"count":2,"spread":20,"homing":4.0,"weaken":2},"追踪魂火。","",1)
	S("art_venomrain","毒雨","art","poison","rain",8,5.0,{"count":10,"radius":34,"area":150,"delay":0.4,"poison":2},"毒雨倾盆。","",1)
	S("art_stonewall","石墙","art","earth","wave",10,6.0,{"radius":100,"speed":200,"knock":400},"大地隆起击退敌人。","",0)
	S("art_voidslash","虚空斩","art","void","beam",14,6.0,{"len":360,"width":18,"dur":0.5,"pierce":true},"斩裂虚空的一线。","",3)
	S("art_flamespear","焰枪","art","fire","proj",24,2.0,{"speed":640,"size":8,"count":1,"pierce":3,"burn":1},"高速火焰长枪。","",0)
	S("art_firesnake","火蛇","art","fire","proj",10,3.2,{"speed":260,"size":10,"count":3,"spread":30,"homing":3.5,"burn":2},"三条火蛇追咬。","",0)
	S("art_lionroar","狮王怒吼","art","phys","wave",12,7.0,{"radius":140,"speed":400,"stun":1.0},"震慑咆哮，大范围眩晕。","",1)
	S("art_purplewing","紫晶翼斩","art","soul","nova",16,5.0,{"count":8,"speed":380,"size":10,"pierce":2},"紫晶羽刃四射。","",1)
	S("art_fireball","大火球","art","fire","proj",45,4.0,{"speed":280,"size":16,"count":1,"explode":70,"burn":2},"缓慢但会爆炸的巨大火球。","",0)
	S("art_healpill","回春术","art","poison","buff",0,16.0,{"dur":4.0,"regen":6.0},"持续回复大量生命。","",1)
	S("art_thundercloud","雷云","art","thunder","zone",12,9.0,{"radius":90,"dur":5.0,"tick":0.5,"stun":0.2,"moving":true},"跟随敌人的雷云。","",2)
	S("art_windwall","风墙","art","wind","buff",0,11.0,{"dur":5.0,"deflect":true,"armor":0.2},"风墙环身，偏转敌方弹幕。","",1)
	S("art_goldrain","金炎天降","art","gold","rain",26,6.0,{"count":8,"radius":32,"area":150,"delay":0.5,"burn":2},"金色火雨。","",2)
	S("art_bonechill","骨灵冷焰","art","cold","wave",16,5.0,{"radius":160,"speed":360,"freeze":0.5},"冷火环形扩散，冻结敌人。","",1)
	S("art_multifist","百裂拳","art","phys","arc",7,3.0,{"range":55,"angle":80,"multi":8,"interval":0.06},"瞬间八连击。","",0)
	S("art_earthdragon","地龙翻身","art","earth","dash",30,5.0,{"dist":220,"stun":0.5,"underground":true},"化作地龙穿行。","",2)
	S("art_nightmare","九幽风炎","art","wind","zone",6,8.0,{"radius":110,"dur":5.0,"tick":0.4,"weaken":1,"burn":1,"at_self":true},"阴风随身，敌人心神大乱。","",2)
	S("art_nineDragon","九龙雷罡","art","thunder","nova",22,7.0,{"count":9,"speed":340,"size":12,"pierce":3,"homing":2.0,"stun":0.2},"九条银龙四出。","",3)
	S("art_redlotus","红莲业火","art","fire","zone",14,9.0,{"radius":90,"dur":4.0,"tick":0.3,"burn":3},"红莲盛开，业火焚身。","",3)
	S("art_lifeflame","生灵之焱","art","poison","buff",0,15.0,{"dur":6.0,"regen":5.0,"dmg":0.2},"生机之火。","",3)

	# ---------- 大招 ----------
	S("ult_lotus","佛怒火莲","ult","fire","lotus",120,14.0,{"radius":130,"delay":0.9,"shake":14},"萧炎自创的毁灭火莲。融合的异火越多，火莲颜色越多、威力越强。","xiaoyan",2)
	S("ult_golden","金帝焚天·觉醒","ult","gold","nova",40,15.0,{"count":20,"speed":340,"size":12,"pierce":99,"awaken":true},"金炎爆发并立即进入血脉觉醒。","xuner",2)
	S("ult_python","七彩吞天蟒","ult","poison","dash",90,15.0,{"dist":360,"width":60,"poison":5,"petrify":1.0},"化作七彩吞天蟒横冲直撞。","medusa",3)
	S("ult_windkill","风之极·陨杀","ult","wind","rain",45,14.0,{"count":14,"radius":40,"area":200,"delay":0.5,"knock":160},"风之极，陨杀！","yunyun",2)
	S("ult_ernan","厄难毒体·爆发","ult","poison","zone",18,16.0,{"radius":170,"dur":6.0,"tick":0.3,"poison":2,"at_self":true,"heal_self":true},"毒体全面爆发。","xiaoyixian",3)
	S("ult_diyin","帝印决","ult","gold","aoe",200,22.0,{"radius":150,"delay":1.3,"shake":16,"stun":1.5},"天阶斗技。帝印镇压。","",3)
	S("ult_yaolao","药老附身","ult","cold","buff",0,30.0,{"dur":10.0,"dmg":1.0,"possess":true,"spd":0.2},"“老师，借我力量！”药老附身十秒，伤害翻倍，冷火随身。","",2)
	S("ult_sanqian","三千焱炎火·焚天","ult","fire","rain",40,18.0,{"count":24,"radius":44,"area":260,"delay":0.6,"burn":4},"三千焱炎火漫天坠落。","",3)
	S("ult_dazaohua2","大天造化掌·极","ult","gold","aoe",160,18.0,{"radius":130,"delay":0.8,"shake":12,"knock":400},"造化之掌，横压一方。","",3)
	S("ult_flamewings","斗气化翼·焚天","ult","fire","dash",70,14.0,{"dist":320,"width":70,"burn":4,"trail":true},"斗气化翼，焚天而过。","",2)
	S("ult_bahuang","八荒破灭焱","ult","fire","wave",80,20.0,{"radius":320,"speed":260,"burn":5,"shake":10},"破灭之焱席卷八荒。","",3)
	S("ult_icerealm","冰皇·万里冰封","ult","cold","zone",10,20.0,{"radius":260,"dur":5.0,"tick":0.4,"freeze":1.2,"at_self":true},"冰皇海波东的绝技。","",3)

	# ---------- 身法（决定闪避形态） ----------
	S("mv_roll","翻滚","move","phys","roll",0,0.75,{"dist":95,"iframe":0.28,"charges":1},"基础闪避。")
	S("mv_leidong","三千雷动","move","thunder","blink",0,0.9,{"dist":150,"iframe":0.2,"charges":2,"shock":14},"瞬移闪现，出发点留下雷击。","",1)
	S("mv_ziyun","紫云翼","move","soul","fly",0,1.4,{"dist":170,"iframe":0.55,"charges":1,"trail":8},"展翼飞起，越过障碍，留下紫焰。")
	S("mv_douqiwing","斗气化翼","move","fire","fly",0,1.2,{"dist":200,"iframe":0.5,"charges":1,"trail":10},"斗王方能施展的斗气双翼。")
	S("mv_ghost","鬼影迷踪","move","soul","roll",0,1.0,{"dist":110,"iframe":0.35,"charges":1,"decoy":2.0},"留下残影吸引敌人。")
	S("mv_wind","风之步","move","wind","roll",0,0.6,{"dist":100,"iframe":0.25,"charges":3},"三段轻灵步伐。","yunyun")
	S("mv_snake","蛇影步","move","poison","roll",0,0.8,{"dist":120,"iframe":0.3,"charges":2,"poison_trail":true},"蛇行留下毒迹。","medusa")
	S("mv_goldlight","金光遁","move","gold","blink",0,0.9,{"dist":140,"iframe":0.25,"charges":2},"化作金光。","xuner")
	S("mv_mist","毒雾遁","move","poison","roll",0,0.9,{"dist":110,"iframe":0.35,"charges":2,"poison_trail":true},"化雾而行。","xiaoyixian")
	S("mv_ice","冰影步","move","cold","blink",0,1.0,{"dist":130,"iframe":0.25,"charges":2,"chill_burst":true},"冰影闪现，冻结附近敌人。")

	# ---------- 功法（被动，1 槽） ----------
	S("gong_fenjue","焚决","gong","fire","passive",0,0,{"fire_per":0.12},"可吞噬异火进化的功法。每拥有一种异火，全伤害+12%。","xiaoyan")
	S("gong_guzu","古族秘法","gong","gold","passive",0,0,{"blood_gain":0.3},"血脉值积累+30%。","xuner")
	S("gong_bishe","碧蛇三花功","gong","poison","passive",0,0,{"poison_dmg":0.4},"毒伤+40%。","medusa")
	S("gong_yunlan","云岚风诀","gong","wind","passive",0,0,{"spd":0.12,"combo_keep":true},"移速+12%，受伤只清一半连击。","yunyun")
	S("gong_ernan","厄难毒经","gong","poison","passive",0,0,{"low_hp_dmg":0.8},"生命越低伤害越高（最多+80%）。","xiaoyixian")
	S("gong_kuangshi","狂狮怒罡","gong","phys","passive",0,0,{"low_hp_dmg":0.5,"hp":20},"生命+20，生命越低伤害越高。")
	S("gong_fengLei","风雷诀","gong","thunder","passive",0,0,{"cdr":0.15,"spd":0.08},"冷却-15%，移速+8%。")
	S("gong_tunling","吞灵诀","gong","void","passive",0,0,{"lifesteal":0.04},"所有伤害吸血4%。")
	S("gong_jingang","金刚琉璃体","gong","gold","passive",0,0,{"armor":0.2,"hp":30},"减伤20%，生命+30。")
	S("gong_bingling","冰灵诀","gong","cold","passive",0,0,{"chill_all":0.2},"所有攻击20%概率减速。")
	S("gong_tianyao","天妖凰诀","gong","fire","passive",0,0,{"revive":1},"每局一次浴火重生。")
	S("gong_leidong","雷动诀","gong","thunder","passive",0,0,{"move_charges":1},"身法次数+1。")

	# ---------- 法宝（被动，可叠加） ----------
	_R("rl_ring","骨灵戒",{"comp_dmg":0.5},"药老栖身的古戒。同伴伤害+50%。")
	_R("rl_nachi","纳戒",{"pill_slots":2,"gold":0.1},"储物戒指。丹药上限+2，金币+10%。")
	_R("rl_zijing","紫晶源",{"crit":0.08},"紫晶翼狮王的精华。暴击+8%。")
	_R("rl_mohe","三阶魔核",{"dmg":0.1},"伤害+10%。")
	_R("rl_mohe5","五阶魔核",{"dmg":0.2},"伤害+20%。",1)
	_R("rl_mohe7","七阶魔核",{"dmg":0.35},"伤害+35%。",2)
	_R("rl_yaoding","药鼎",{"heal":0.3},"治疗效果+30%。")
	_R("rl_fengyu","风羽靴",{"spd":0.1},"移速+10%。")
	_R("rl_huoyun","火云袍",{"fire_dmg":0.2},"火属性伤害+20%。")
	_R("rl_bingpo","冰魄珠",{"cold_dmg":0.25},"冰属性伤害+25%。")
	_R("rl_leizhu","雷灵珠",{"thunder_dmg":0.25},"雷属性伤害+25%。")
	_R("rl_duzhu","万毒珠",{"poison_dmg":0.25},"毒属性伤害+25%。")
	_R("rl_jinsi","金丝软甲",{"armor":0.1},"减伤10%。")
	_R("rl_xuemai","血脉之石",{"hp":25},"最大生命+25。")
	_R("rl_lingxi","灵犀玉",{"cdr":0.1},"冷却-10%。")
	_R("rl_kuangbao","狂暴兽血",{"aspd":0.15},"攻速+15%。")
	_R("rl_tianyan","天眼石",{"crit_dmg":0.4},"暴击伤害+40%。",1)
	_R("rl_huanling","唤灵符",{"energy":0.3},"大招能量获取+30%。")
	_R("rl_shouhu","守护玉佩",{"shield_room":20},"每个房间开始获得20点护盾。")
	_R("rl_tuntian","吞天葫芦",{"lifesteal":0.03},"吸血3%。",1)
	_R("rl_jinbi","招财金蟾",{"gold":0.35},"金币获取+35%。")
	_R("rl_jingyan","聚灵阵盘",{"exp":0.25},"斗气获取+25%。")
	_R("rl_citie","磁灵石",{"magnet":60},"拾取范围+60。")
	_R("rl_shuangren","双刃符",{"proj":1},"投射类斗技数量+1。",2)
	_R("rl_jufeng","巨风符",{"area":0.25},"范围+25%。",1)
	_R("rl_zhongtian","重天印",{"knock":0.5,"dmg":0.05},"击退+50%，伤害+5%。")
	_R("rl_huiyin","回音铃",{"echo":0.15},"斗技有15%概率再释放一次。",2)
	_R("rl_fenxin","焚心玉",{"burn_dmg":0.5},"灼烧伤害+50%。")
	_R("rl_hanxin","寒心玉",{"freeze_ch":0.08},"命中8%概率冻结。",1)
	_R("rl_zhanyi","战意旗",{"kill_dmg":0.01},"每击杀一个敌人，本房间伤害+1%（上限30%）。")
	_R("rl_huixue","回血草囊",{"room_heal":8},"每清完一个房间回复8生命。")
	_R("rl_bosskill","屠龙令",{"boss_dmg":0.25},"对精英与Boss伤害+25%。",1)
	_R("rl_dodge","灵猴佩",{"dodge":0.08},"8%概率闪避伤害。")
	_R("rl_thorns","荆棘甲",{"thorns":0.5},"受伤时反弹50%伤害。")
	_R("rl_fireseed","火种之心",{"fire_slot":1},"异火槽+1。",2)
	_R("rl_skillslot","玉简匣",{"art_slot":1},"斗技槽+1。",2)
	_R("rl_lucky","气运珠",{"luck":0.2},"高阶奖励概率提升。")
	_R("rl_bloodpact","血契",{"dmg":0.3,"hp":-20},"伤害+30%，最大生命-20。",1)

func _R(id:String, n:String, p:Dictionary, d:String, tier:int=0) -> void:
	S(id, n, "relic", "phys", "passive", 0, 0, p, d, "", tier)

var fusion_recipes := [
	# [a, b, result]
	["art_baji","art_yanfen","art_yanbeng"],
	["art_chuihuo","art_vortex","art_fireStorm"],
	["art_thunder","art_fireRain","art_thunderfire"],
	["art_icecone","art_flamespear","art_icefire"],
	["art_xizhang","art_devour","art_tuntian"],
	["art_featherblades","art_purplewing","art_ziyanyu"],
	["art_crush","art_quake","art_bengshan"],
	["art_windcut","art_flameslash","art_fengyan"],
	["art_poisonfield","art_vortex","art_duyan"],
	["art_firewheel","art_yinyang","art_taiji"],
	["art_meteor","art_pillar","art_tianzhu"],
	["art_thunderchain","art_chainexp","art_leiyan"],
]
func _build_fusions() -> void:
	S("art_yanbeng","焰崩","art","fire","aoe",90,4.5,{"radius":90,"delay":0.0,"range":80,"knock":300,"shake":8,"burn":4,"hidden":true},"【融合】八极崩×焰分噬浪尺：近身爆发焰崩，火浪二次扩散。","",2)
	S("art_fireStorm","焚天火暴","art","fire","zone",16,7.0,{"radius":120,"dur":5.0,"tick":0.25,"pull":120,"burn":3,"hidden":true},"【融合】吹火掌×烈焰漩涡：巨型火焰风暴。","",2)
	S("art_thunderfire","雷火劫","art","thunder","rain",38,6.0,{"count":16,"radius":38,"area":200,"delay":0.45,"burn":2,"stun":0.4,"hidden":true},"【融合】天雷引×流星火雨：雷火齐落。","",3)
	S("art_icefire","冰火两重天","art","cold","proj",40,2.5,{"speed":600,"size":10,"count":2,"spread":6,"pierce":5,"chill":true,"burn":3,"hidden":true},"【融合】寒冰锥×焰枪：冰火双枪。","",2)
	S("art_tuntian","吞天掌","art","void","pull",60,6.0,{"radius":260,"pull":420,"lifesteal":0.4,"hidden":true},"【融合】吸掌×吞灵漩涡：吞天噬地。","",3)
	S("art_ziyanyu","紫焰羽暴","art","soul","nova",16,3.5,{"count":28,"speed":380,"size":8,"pierce":3,"burn":2,"hidden":true},"【融合】火羽千刃×紫晶翼斩。","",2)
	S("art_bengshan","崩山裂地","art","earth","wave",60,5.0,{"radius":200,"speed":320,"stun":1.0,"shake":8,"hidden":true},"【融合】碎山拳×裂地击。","",2)
	S("art_fengyan","风炎斩","art","wind","proj",36,1.8,{"speed":600,"size":14,"count":3,"spread":16,"pierce":99,"crescent":true,"burn":2,"hidden":true},"【融合】疾风刃×烈焰刀芒。","",2)
	S("art_duyan","毒焰漩涡","art","poison","zone",12,7.0,{"radius":110,"dur":5.0,"tick":0.3,"pull":100,"poison":2,"burn":2,"hidden":true},"【融合】毒蛊阵×烈焰漩涡。","",2)
	S("art_taiji","阴阳太极轮","art","fire","orbit",24,6.0,{"count":6,"radius":80,"dur":7.0,"size":14,"yinyang":true,"hidden":true},"【融合】回旋火轮×阴阳双炎。","",3)
	S("art_tianzhu","天柱陨","art","fire","rain",90,9.0,{"count":8,"radius":56,"area":180,"delay":0.9,"shake":12,"burn":4,"hidden":true},"【融合】陨星坠×焚天火柱。","",3)
	S("art_leiyan","雷炎连锁","art","thunder","chain",34,3.5,{"jumps":10,"range":200,"explode":50,"stun":0.3,"hidden":true},"【融合】雷霆锁链×炎爆连环。","",3)

# 随机词条（让同一斗技产生无数变化）
const AFFIXES := [
	{"id":"dmg","n":"锋锐","d":"伤害+25%","w":10},
	{"id":"cd","n":"迅疾","d":"冷却-20%","w":10},
	{"id":"count","n":"分化","d":"数量+1","w":7},
	{"id":"size","n":"浩大","d":"范围/体积+30%","w":8},
	{"id":"burn","n":"焚烧","d":"命中附加灼烧","w":7},
	{"id":"chill","n":"寒霜","d":"命中附加减速","w":6},
	{"id":"poison","n":"淬毒","d":"命中叠加毒层","w":6},
	{"id":"crit","n":"致命","d":"此技暴击+20%","w":7},
	{"id":"pierce","n":"贯穿","d":"穿透+2","w":6},
	{"id":"leech","n":"嗜血","d":"此技吸血6%","w":5},
	{"id":"stun","n":"震慑","d":"命中眩晕0.3秒","w":5},
	{"id":"echo","n":"回响","d":"25%概率再释放一次","w":4},
	{"id":"knock","n":"崩劲","d":"击退大幅提升","w":5},
	{"id":"weaken","n":"破甲","d":"命中使敌人受伤+15%","w":5},
	{"id":"exec","n":"斩杀","d":"对生命<30%的敌人伤害翻倍","w":4},
	{"id":"energy","n":"蓄势","d":"命中额外获得大招能量","w":5},
	{"id":"thunder","n":"引雷","d":"命中20%概率落雷","w":4},
	{"id":"explode","n":"爆裂","d":"击杀时爆炸","w":4},
	{"id":"elite","n":"屠魔","d":"对精英/Boss伤害+40%","w":4},
	{"id":"speed","n":"疾行","d":"释放后移速+30%持续2秒","w":4},
]

# ------------------------------------------------------------------ 异火榜（23种）
var fires := [
	{"id":"dy","rank":1,"n":"帝炎","c":Color(1,1,1),"elem":"fire","d":"由其余二十二种异火融合而成。全属性大幅提升，可号令万火。","fx":{"dmg":0.8,"fire_dmg":0.5,"burn":2,"all":true},"ch":99},
	{"id":"xwty","rank":2,"n":"虚无吞炎","c":Color(0.25,0.12,0.35),"elem":"void","d":"生于虚无，吞噬万物。击杀回复生命，攻击牵引敌人。","fx":{"dmg":0.45,"lifesteal":0.05,"pull_hit":true},"ch":7},
	{"id":"jlyh","rank":3,"n":"净莲妖火","c":Color(0.95,0.95,0.98),"elem":"fire","d":"净化万物。攻击削弱敌人并有概率直接焚尽低血量敌人。","fx":{"dmg":0.4,"weaken_hit":true,"exec":0.1},"ch":6},
	{"id":"jdft","rank":4,"n":"金帝焚天炎","c":Color(1,0.82,0.25),"elem":"gold","d":"古族传承之火。燃烧敌人斗气，攻击附带破甲。","fx":{"dmg":0.35,"armor_break":true},"ch":7},
	{"id":"slzy","rank":5,"n":"生灵之焱","c":Color(0.45,1,0.45),"elem":"poison","d":"生机之火，持续回复生命，治疗提升。","fx":{"regen":1.5,"heal":0.4},"ch":5},
	{"id":"bhpm","rank":6,"n":"八荒破灭焱","c":Color(0.9,0.2,0.1),"elem":"fire","d":"炎族至高之火。爆炸范围与伤害提升。","fx":{"dmg":0.3,"area":0.3,"explode_kill":true},"ch":7},
	{"id":"jyjz","rank":7,"n":"九幽金祖火","c":Color(0.85,0.7,0.15),"elem":"gold","d":"可与金帝焚天炎抗衡。暴击伤害大幅提升。","fx":{"crit_dmg":0.6,"crit":0.05},"ch":6},
	{"id":"hlyh","rank":8,"n":"红莲业火","c":Color(0.95,0.15,0.25),"elem":"fire","d":"形如红莲。灼烧可叠加，灼烧伤害翻倍。","fx":{"burn_dmg":1.0,"burn":1},"ch":6},
	{"id":"sqyy","rank":9,"n":"三千焱炎火","c":Color(0.35,0.55,1),"elem":"fire","d":"不死之火，汲取星辰之力。极强恢复，获得一次复活。","fx":{"regen":2.0,"revive":1},"ch":5},
	{"id":"jyfy","rank":10,"n":"九幽风炎","c":Color(0.35,0.6,0.55),"elem":"wind","d":"阴风阵阵，扰乱心神。敌人移速降低，攻击附带击退。","fx":{"enemy_slow":0.15,"knock":0.4},"ch":5},
	{"id":"glly","rank":11,"n":"骨灵冷火","c":Color(0.75,0.92,1),"elem":"cold","d":"药老之火，极寒极热。命中减速并有概率冻结。","fx":{"chill_all":0.35,"freeze_ch":0.06,"cold_dmg":0.3},"ch":1},
	{"id":"jllg","rank":12,"n":"九龙雷罡火","c":Color(0.8,0.85,1),"elem":"thunder","d":"九条银龙腾升。攻击有概率引发连锁闪电。","fx":{"chain_hit":0.15,"thunder_dmg":0.3},"ch":4},
	{"id":"gldh","rank":13,"n":"龟灵地火","c":Color(0.55,0.4,0.2),"elem":"earth","d":"酷似乌龟的褐色火焰。大幅减伤。","fx":{"armor":0.2,"hp":30},"ch":4},
	{"id":"ylxy","rank":14,"n":"陨落心炎","c":Color(0.85,0.3,0.9),"elem":"fire","d":"心火焚身，加快修炼。斗气获取大幅提升，攻速提升。","fx":{"exp":0.4,"aspd":0.15},"ch":3},
	{"id":"hxy","rank":15,"n":"海心焰","c":Color(0.15,0.35,0.9),"elem":"cold","d":"深蓝色的火焰。每个房间获得护盾，护盾存在时伤害提升。","fx":{"shield_room":30,"shield_dmg":0.2},"ch":2},
	{"id":"hysy","rank":16,"n":"火云水炎","c":Color(0.4,0.75,1),"elem":"cold","d":"蕴含水之力。击杀回复生命。","fx":{"kill_heal":1.5},"ch":2},
	{"id":"hssy","rank":17,"n":"火山石焰","c":Color(0.75,0.3,0.1),"elem":"earth","d":"诞生于火山深处。击杀敌人时爆炸。","fx":{"explode_kill":true,"dmg":0.1},"ch":2},
	{"id":"fnly","rank":18,"n":"风怒龙炎","c":Color(0.95,0.6,0.3),"elem":"wind","d":"沙漠火焰龙卷之眼。移速与投射物速度提升，暴击时卷起火旋风。","fx":{"spd":0.12,"crit_tornado":true},"ch":2},
	{"id":"qldx","rank":19,"n":"青莲地心火","c":Color(0.2,0.95,0.7),"elem":"fire","d":"诞生于地心的青色火莲。火属性伤害提升，灼烧会向附近敌人蔓延。","fx":{"fire_dmg":0.35,"burn":1,"burn_spread":true},"ch":2},
	{"id":"ymdh","rank":20,"n":"幽冥毒火","c":Color(0.4,0.8,0.2),"elem":"poison","d":"毒属性的火焰。所有攻击叠加毒层。","fx":{"poison_hit":1,"poison_dmg":0.3},"ch":1},
	{"id":"yyy","rank":21,"n":"阴阳炎","c":Color(0.6,0.6,0.6),"elem":"fire","d":"一阴一阳两种火焰。攻击有概率造成两次伤害。","fx":{"double_hit":0.2},"ch":1},
	{"id":"wsly","rank":22,"n":"万兽灵火","c":Color(0.95,0.45,0.2),"elem":"fire","d":"由无数兽火聚集而成。周期召唤火焰灵兽。","fx":{"beast":true,"dmg":0.08},"ch":1},
	{"id":"xhy","rank":23,"n":"玄黄炎","c":Color(0.85,0.65,0.2),"elem":"earth","d":"诞生于百万大山之内。生命与减伤提升。","fx":{"hp":25,"armor":0.08},"ch":1},
]
var fire_by_id := {}
# 双火融合的额外效果（未列出的组合给通用加成）
var fire_pair_bonus := {
	"glly+qldx": {"n":"冰火两仪","d":"冷火与青莲相融：灼烧与冻结同时触发，伤害+20%","fx":{"dmg":0.2,"freeze_ch":0.05}},
	"hssy+qldx": {"n":"地心熔岩","d":"击杀爆炸附带灼烧蔓延","fx":{"area":0.2,"burn":1}},
	"fnly+qldx": {"n":"青莲风暴","d":"暴击火旋风变为青色，伤害翻倍","fx":{"crit":0.06,"dmg":0.1}},
	"glly+ylxy": {"n":"寒心焚意","d":"斗气获取与冷却大幅提升","fx":{"cdr":0.12,"exp":0.2}},
	"hxy+hysy": {"n":"沧海双焰","d":"护盾与击杀回复强化","fx":{"shield_room":20,"kill_heal":1.0}},
	"wsly+xhy": {"n":"百兽玄黄","d":"火焰灵兽体型更大、更耐打","fx":{"beast_power":1.0,"hp":20}},
	"yyy+glly": {"n":"阴阳冷火","d":"双重打击有概率冻结","fx":{"double_hit":0.1,"freeze_ch":0.04}},
	"ymdh+qldx": {"n":"青莲毒焰","d":"灼烧同时叠毒","fx":{"poison_hit":1,"burn":1}},
}

# ------------------------------------------------------------------ 丹药
var pills := {
	"huiqi": {"n":"回气丹","c":Color(0.5,1,0.6),"d":"回复40%生命","herbs":{"zyl":1},"tier":0},
	"juqi": {"n":"聚气散","c":Color(0.6,0.8,1),"d":"获得大量斗气（经验）","herbs":{"zyl":1,"xgh":1},"tier":0},
	"zhuji": {"n":"筑基灵液","c":Color(0.9,0.9,0.6),"d":"本局最大生命+20","herbs":{"xgh":2},"tier":0},
	"sanwen": {"n":"三纹青灵丹","c":Color(0.3,0.9,0.7),"d":"本局伤害+12%","herbs":{"swql":2},"tier":1},
	"bingling": {"n":"冰灵焰草丹","c":Color(0.6,0.9,1),"d":"本局冷却-10%","herbs":{"blyc":1,"swql":1},"tier":1},
	"humai": {"n":"护脉丹","c":Color(1,0.7,0.5),"d":"吞噬异火时反噬伤害减半","herbs":{"xgh":1,"blyc":1},"tier":1},
	"kuangbao": {"n":"狂暴丹","c":Color(1,0.35,0.3),"d":"下一场战斗伤害+50%","herbs":{"xlj":1,"zyl":1},"tier":1},
	"pozong": {"n":"破宗丹","c":Color(1,0.85,0.3),"d":"立即突破一个小境界","herbs":{"xlj":1,"swql":1,"mohe":1},"tier":2},
	"huanhun": {"n":"还魂丹","c":Color(0.9,0.5,1),"d":"死亡时自动复活（回复50%）","herbs":{"xlj":2,"mohe":1},"tier":2},
	"xuelian": {"n":"血莲丹","c":Color(1,0.3,0.4),"d":"本局吸血+3%","herbs":{"xlj":2},"tier":2},
	"leiting": {"n":"雷霆丹","c":Color(0.75,0.65,1),"d":"本局暴击+8%","herbs":{"blyc":1,"mohe":1},"tier":2},
	"xisui": {"n":"洗髓丹","c":Color(1,1,1),"d":"重置并重新随机一个斗技的词条","herbs":{"xgh":1,"swql":1},"tier":1},
}
var herbs := {
	"zyl": {"n":"紫叶兰草","c":Color(0.7,0.5,1)},
	"xgh": {"n":"洗骨花","c":Color(1,0.95,0.8)},
	"swql": {"n":"三纹青灵草","c":Color(0.3,0.9,0.6)},
	"blyc": {"n":"冰灵焰草","c":Color(0.6,0.9,1)},
	"xlj": {"n":"血莲精","c":Color(1,0.3,0.35)},
	"mohe": {"n":"魔核","c":Color(1,0.7,0.3)},
}

# ------------------------------------------------------------------ 敌人
# ai: melee dasher ranged caster swarm tank
var enemies := {
	"wolf_grey": {"n":"疾风狼","spr":"e_wolf_grey","hp":22,"dmg":8,"spd":120,"ai":"swarm","r":12,"exp":3,"gold":1},
	"wolf": {"n":"魔狼","spr":"e_wolf","hp":40,"dmg":11,"spd":95,"ai":"melee","r":16,"exp":5,"gold":2},
	"wolf_purple": {"n":"紫影魔狼","spr":"e_wolf_purple","hp":55,"dmg":14,"spd":85,"ai":"dasher","r":16,"exp":7,"gold":3},
	"wolf_red": {"n":"火纹魔狼","spr":"e_wolf_red","hp":60,"dmg":10,"spd":80,"ai":"ranged","r":16,"exp":7,"gold":3,"bullet":"fire"},
	"bandit": {"n":"狼头佣兵","spr":"e_bandit","hp":70,"dmg":16,"spd":80,"ai":"tank","r":14,"exp":8,"gold":5},
	"disciple": {"n":"云岚宗弟子","spr":"e_disciple","hp":60,"dmg":12,"spd":90,"ai":"ranged","r":13,"exp":8,"gold":4,"bullet":"wind"},
	"snake": {"n":"蛇人战士","spr":"e_snake","hp":80,"dmg":15,"spd":85,"ai":"dasher","r":16,"exp":9,"gold":4},
	"snake_mage": {"n":"蛇人祭司","spr":"e_snake","hp":60,"dmg":10,"spd":70,"ai":"caster","r":16,"exp":10,"gold":5,"bullet":"poison","tint":Color(0.8,0.7,1)},
	"soul": {"n":"魂殿护法","spr":"e_soul","hp":110,"dmg":16,"spd":75,"ai":"caster","r":16,"exp":14,"gold":8,"bullet":"soul"},
	"wisp": {"n":"火灵","spr":"","hp":30,"dmg":9,"spd":100,"ai":"ranged","r":10,"exp":4,"gold":1,"bullet":"fire","wisp":Color(1,0.5,0.2)},
	"wisp_green": {"n":"青莲火灵","spr":"","hp":45,"dmg":12,"spd":105,"ai":"swarm","r":10,"exp":5,"gold":2,"wisp":Color(0.2,1,0.7)},
	"sand_wisp": {"n":"沙魂","spr":"","hp":40,"dmg":10,"spd":90,"ai":"caster","r":11,"exp":6,"gold":2,"bullet":"earth","wisp":Color(0.9,0.75,0.4)},
}
# Boss / 精英。phases: 每阶段的招式列表与台词
var bosses := {
	"jialie": {"n":"加列奥","t":"加列家族少主","spr":"e_bandit","scale":1.25,"hp":420,"dmg":14,"spd":95,"elite":true,"tint":Color(1,0.8,0.7),
		"phases":[{"hp":1.0,"moves":["charge","slam","fan3"],"line":"萧炎？一个废物也敢拦我！"},{"hp":0.5,"moves":["charge","slam","fan5","summon_wolf"],"line":"来人！给我废了他！"}]},
	"mulie": {"n":"穆力","t":"狼头佣兵团副团长","spr":"e_bandit","scale":1.35,"hp":520,"dmg":16,"spd":90,"elite":true,"tint":Color(0.9,0.9,1),
		"phases":[{"hp":1.0,"moves":["charge","slam","ring"],"line":"小子，魔兽山脉可不是你该来的地方。"},{"hp":0.45,"moves":["charge","slam","ring","summon_wolf","fan5"],"line":"狼头佣兵团听令！"}]},
	"wolfking": {"n":"嗜血狼王","t":"魔兽山脉·五阶魔兽","spr":"b_wolfking","scale":1.0,"hp":1400,"dmg":20,"spd":110,"boss":true,
		"phases":[{"hp":1.0,"moves":["charge","claw3","howl_wolves","ring"],"line":"（狼王的咆哮震动整座山脉）"},
			{"hp":0.6,"moves":["charge3","claw3","ring2","howl_wolves","spiral"],"line":"（狼王双目泛起血光……）"},
			{"hp":0.25,"moves":["charge3","spiral","ring2","rage_rain"],"line":"药老：小心，它要拼命了！"}]},
	"mushe": {"n":"穆蛇","t":"狼头佣兵团团长","spr":"e_bandit","scale":1.5,"hp":1600,"dmg":22,"spd":95,"boss":true,"tint":Color(1,0.7,0.6),
		"phases":[{"hp":1.0,"moves":["charge","slam","fan5","summon_bandit"],"line":"杀我弟弟的，就是你？"},
			{"hp":0.55,"moves":["charge3","slam","ring2","fan7","summon_bandit"],"line":"斗师之力，你一个斗者拿什么挡？"},
			{"hp":0.2,"moves":["charge3","spiral","rage_rain","slam"],"line":"萧炎：三十年河东，三十年河西——"}]},
	"medusa": {"n":"美杜莎女王","t":"蛇人族女王","spr":"medusa","scale":1.35,"hp":2400,"dmg":24,"spd":100,"boss":true,
		"phases":[{"hp":1.0,"moves":["fan7","spiral","petrify_beam","summon_snake"],"line":"人类，擅闯蛇人族圣地，死！"},
			{"hp":0.6,"moves":["spiral2","petrify_beam","charge3","ring2","poison_rain"],"line":"区区斗师……竟能伤我？"},
			{"hp":0.3,"moves":["python","spiral2","poison_rain","ring3"],"line":"七彩吞天蟒——！"}]},
	"fire_spirit": {"n":"青莲地心火","t":"异火榜第十九","spr":"","scale":1.0,"hp":2000,"dmg":22,"spd":80,"boss":true,"wisp":Color(0.2,1,0.7),"wisp_r":34,
		"phases":[{"hp":1.0,"moves":["spiral","ring","summon_wisp","fire_rain"],"line":"（岩浆翻涌，一朵青色火莲缓缓升起）"},
			{"hp":0.5,"moves":["spiral2","ring3","fire_rain","summon_wisp","lotus_bomb"],"line":"药老：它在反抗！压制住它，就能吞噬！"}]},
	"nalan": {"n":"纳兰嫣然","t":"云岚宗少宗主","spr":"nalan","scale":1.15,"hp":1500,"dmg":20,"spd":120,"elite":true,
		"phases":[{"hp":1.0,"moves":["dash_slash","fan5","wind_blades"],"line":"三年之约，今日了结！"},
			{"hp":0.5,"moves":["dash_slash3","fan7","wind_blades","ring2"],"line":"风之极……陨杀！"}]},
	"yunshan": {"n":"云山","t":"云岚宗老宗主·斗宗","spr":"b_yunshan","scale":1.4,"hp":4000,"dmg":28,"spd":110,"boss":true,
		"phases":[{"hp":1.0,"moves":["fan7","dash_slash3","wind_blades","ring2"],"line":"萧炎小儿，敢在云岚宗撒野！"},
			{"hp":0.66,"moves":["spiral2","wind_blades","ring3","summon_disciple","dash_slash3"],"line":"斗宗之威，岂是你能想象？（斗气化翼）"},
			{"hp":0.33,"moves":["spiral3","rage_rain","ring3","wind_storm","dash_slash3"],"line":"我借魂殿之力……今日你必死！"}]},
	"soul_elder": {"n":"魂殿护法","t":"魂殿","spr":"e_soul","scale":1.5,"hp":1800,"dmg":22,"spd":85,"elite":true,
		"phases":[{"hp":1.0,"moves":["spiral","soul_chain","summon_soul"],"line":"药尘的灵魂……魂殿要了。"},{"hp":0.5,"moves":["spiral2","ring3","soul_chain","summon_soul"],"line":"区区小辈！"}]},
	"heart_demon": {"n":"心魔","t":"斗王劫","spr":"__player","scale":1.1,"hp":1600,"dmg":22,"spd":130,"boss":true,"tint":Color(0.25,0.1,0.3),
		"phases":[{"hp":1.0,"moves":["dash_slash3","fan7","spiral"],"line":"心魔：你以为……你真的配得上这份力量？"},{"hp":0.5,"moves":["dash_slash3","spiral2","ring3","rage_rain"],"line":"心魔：你永远是那个斗之力三段的废物！"}]},
	"hun_tiandi": {"n":"魂天帝","t":"魂族族长·斗帝之下第一人","spr":"hun_tiandi","scale":1.4,"hp":6000,"dmg":30,"spd":120,"boss":true,
		"phases":[{"hp":1.0,"moves":["spiral3","ring3","soul_chain","dash_slash3"],"line":"萧炎，你终究还是来了。"},{"hp":0.5,"moves":["spiral3","rage_rain","ring3","soul_chain"],"line":"帝境……只能有一个！"}]},
}

# ------------------------------------------------------------------ 章节
# map: branch = 分支地图, doors = 房间门选择, linear = 线性
var chapters := [
	{"id":0,"n":"序章","t":"炎帝归来","biome":"void","map":"linear","cap":99,"start_realm":99,"music":"prologue",
		"ui":{"bg":Color(0.08,0.05,0.12,0.94),"border":Color(0.75,0.55,1),"accent":Color(1,0.8,0.4)},"tint":Color(0.75,0.7,0.95)},
	{"id":1,"n":"第一章","t":"乌坦城·魔兽山脉","biome":"forest","biome2":"wutan","map":"branch","cap":17,"start_realm":0,"floors":11,"music":"battle1",
		"pool":[["wolf_grey","wolf"],["wolf","wolf_purple","wolf_grey"],["wolf_purple","wolf_red","bandit"],["bandit","wolf_red","wolf_purple","wisp"]],
		"elites":["jialie","mulie"],"boss":"mushe","boss2":"wolfking",
		"ui":{"bg":Color(0.1,0.13,0.08,0.94),"border":Color(0.72,0.6,0.36),"accent":Color(0.6,1,0.5)},"tint":Color(1,0.98,0.92)},
	{"id":2,"n":"第二章","t":"塔戈尔沙漠·云岚宗","biome":"desert","biome2":"yunlan","map":"doors","cap":35,"start_realm":18,"floors":12,"music":"battle2",
		"pool":[["snake","sand_wisp","wisp"],["snake","snake_mage","sand_wisp"],["disciple","snake_mage","wisp_green"],["disciple","soul","disciple","wisp_green"]],
		"elites":["nalan","soul_elder"],"boss":"yunshan","mid":"medusa","fire_boss":"fire_spirit",
		"ui":{"bg":Color(0.16,0.12,0.07,0.94),"border":Color(0.95,0.75,0.35),"accent":Color(1,0.85,0.4)},"tint":Color(1,0.96,0.88)},
]

# 势力（局外基地）随进度进化
const FACTIONS := ["萧家","磐门","炎盟","星陨阁","萧族"]

# 局外建筑
var buildings := {
	"alchemy": {"n":"炼药房","spr":"b_alchemy","max":5,"d":"炼制丹药（炼丹小游戏），丹药可带入下一局。等级提升丹方与携带数量。"},
	"library": {"n":"藏经阁","spr":"b_library","max":5,"d":"花费斗气结晶永久解锁斗技、大招、身法、功法进入奖励池。"},
	"train": {"n":"修炼室","spr":"b_train","max":5,"d":"修炼焚决天赋：永久提升属性。"},
	"tower": {"n":"天火塔","spr":"b_tower","max":5,"d":"以异火火种培养已收服过的异火；开启无尽模式。"},
	"forge": {"n":"炼器坊","spr":"b_forge","max":5,"d":"用魔核锻造法宝、解锁普攻风格。"},
	"inn": {"n":"招待所","spr":"b_inn","max":5,"d":"同伴与羁绊：赠礼提升好感，解锁合击与专属剧情。"},
	"codex": {"n":"图鉴馆","spr":"b_codex","max":1,"d":"查看角色、敌人、斗技、异火与成就图鉴。"},
	"challenge": {"n":"挑战塔","spr":"b_challenge","max":1,"d":"每日挑战与Boss车轮战。"},
}
# 修炼室天赋
var talents := [
	{"id":"hp","n":"淬体","d":"最大生命+8","max":10,"cost":20,"fx":{"hp":8}},
	{"id":"dmg","n":"斗气凝练","d":"伤害+4%","max":10,"cost":25,"fx":{"dmg":0.04}},
	{"id":"crit","n":"灵眼","d":"暴击+2%","max":5,"cost":30,"fx":{"crit":0.02}},
	{"id":"spd","n":"轻身","d":"移速+3%","max":5,"cost":20,"fx":{"spd":0.03}},
	{"id":"cdr","n":"心法流转","d":"冷却-3%","max":5,"cost":35,"fx":{"cdr":0.03}},
	{"id":"gold","n":"家族供奉","d":"开局金币+30","max":5,"cost":15,"fx":{"start_gold":30}},
	{"id":"reroll","n":"天机","d":"每局重随奖励次数+1","max":3,"cost":60,"fx":{"reroll":1}},
	{"id":"revive","n":"不灭","d":"每局复活次数+1","max":1,"cost":200,"fx":{"revive":1}},
	{"id":"armor","n":"铁骨","d":"减伤+2%","max":5,"cost":30,"fx":{"armor":0.02}},
	{"id":"exp","n":"悟性","d":"斗气获取+8%","max":5,"cost":25,"fx":{"exp":0.08}},
	{"id":"luck","n":"气运","d":"高阶奖励概率提升","max":5,"cost":40,"fx":{"luck":0.06}},
	{"id":"heal","n":"药理","d":"治疗+6%","max":5,"cost":20,"fx":{"heal":0.06}},
]

# 成就（梗多）
var achievements := {
	"ach_first_death":{"n":"斗之力，三段","d":"第一次死亡。“萧炎，斗之力，三段！级别：低级！”"},
	"ach_ch1":{"n":"三十年河东","d":"通关第一章"},
	"ach_ch2":{"n":"三十年河西","d":"通关第二章"},
	"ach_mqsnq":{"n":"莫欺少年穷","d":"以斗者以下境界击败精英"},
	"ach_fire1":{"n":"初得异火","d":"第一次吞噬异火"},
	"ach_fire3":{"n":"焚决大成","d":"单局拥有3种异火"},
	"ach_fusion":{"n":"佛怒火莲","d":"第一次融合斗技"},
	"ach_perfect_pill":{"n":"药老的骄傲","d":"炼出完美品质丹药"},
	"ach_pill_thunder":{"n":"丹雷滚滚","d":"炼丹时引发丹雷"},
	"ach_rich":{"n":"米特尔的VIP","d":"单局持有1000金币"},
	"ach_kill500":{"n":"魔兽山脉清道夫","d":"累计击杀500个敌人"},
	"ach_yandi":{"n":"炎帝","d":"通关序章与第二章，解锁炎帝皮肤"},
	"ach_nohit":{"n":"身法大师","d":"无伤击败一个Boss"},
	"ach_tianjie5":{"n":"逆天改命","d":"以5点以上天劫通关任意章节"},
	"ach_medusa":{"n":"女王大人","d":"击败美杜莎女王"},
	"ach_yunshan":{"n":"云岚宗之殇","d":"击败云山"},
	"ach_bond":{"n":"红颜知己","d":"任意同伴好感达到5级"},
	"ach_endless10":{"n":"天火塔十层","d":"无尽模式达到第10波"},
	"ach_gamble":{"n":"赌石大王","d":"赌石开出天阶宝物"},
	"ach_yaolao":{"n":"老师，借我力量","d":"使用药老附身"},
}

const TIPS := [
	"药老：炼药师的地位，比同阶斗者高得多。",
	"三十年河东，三十年河西，莫欺少年穷！",
	"异火融合越多，佛怒火莲的颜色越多、威力越大。",
	"按 Tab 可以打开功法面板，设置每个斗技手动/自动释放。",
	"装备“三千雷动”后，闪避会变成瞬移；装备“紫云翼”则会飞起来。",
	"吞噬异火前，最好带上护脉丹。",
	"斗之力，三段！……那都是过去的事了。",
	"某些斗技组合会触发融合，得到更强的新斗技。",
	"拍卖场里，米特尔家族的拍卖师总有好东西。",
	"赌石有风险，开出天阶宝物的概率……也许只有一点点。",
	"境界突破时会全屏演出，斗王以上需要渡劫。",
	"药老：小家伙，别急着出手，先观察它的招式。",
	"天劫点数越高，结算时获得的斗气结晶越多。",
	"同伴可以用 1~4 下达指令：跟随、进攻、守护、集火。",
	"异火榜第一：帝炎。据说是二十二种异火融合而成。",
]
const DEATH_LINES := [
	"“萧炎，斗之力，三段！级别：低级！”",
	"药老：小家伙，这次太冒失了。",
	"纳兰嫣然：看来三年之约，你是赴不了了。",
	"薰儿：萧炎哥哥……不要放弃。",
	"药老：跌倒了，就再爬起来。",
	"三十年河东，三十年河西……再来一次！",
]

# 奇遇事件
var events := [
	{"id":"ring","t":"古朴戒指","d":"你在旧物中发现一枚黑色古戒，隐约有灵魂波动……","opts":[["滴血认主","relic:rl_ring"],["卖掉换钱","gold:80"]],"ch":[1]},
	{"id":"cave","t":"前人洞府","d":"山壁后隐藏着一座洞府，石台上放着一卷玉简和一瓶丹药。","opts":[["取走玉简","art"],["取走丹药","pill:random"],["两个都拿（触发机关，受伤30%）","both"]],"ch":[1,2]},
	{"id":"beast_cub","t":"魔兽幼崽","d":"一只受伤的魔兽幼崽蜷缩在树下。","opts":[["救治它（消耗1株药材）","cub"],["离开","none"]],"ch":[1]},
	{"id":"merchant","t":"神秘药商","d":"一名黑袍人压低声音：“小兄弟，要药材吗？”","opts":[["购买药材包（60金）","herbs:60"],["不感兴趣","none"]],"ch":[1,2]},
	{"id":"gamble","t":"赌石摊","d":"摊主拍着一块原石：“一刀穷，一刀富，一刀穿麻布！”","opts":[["赌一块（50金）","gamble:50"],["赌大的（150金）","gamble:150"],["离开","none"]],"ch":[1,2]},
	{"id":"altar","t":"血祭石台","d":"古老石台上刻着符文：“以血换力”。","opts":[["献祭20%生命，获得法宝","blood_relic"],["离开","none"]],"ch":[1,2]},
	{"id":"xuner_meet","t":"薰儿","d":"薰儿：“萧炎哥哥，这个给你。”她递来一枚丹药，眼里满是信任。","opts":[["收下（回满生命，好感+1）","xuner_gift"]],"ch":[1]},
	{"id":"yixian","t":"山谷少女","d":"山谷中，一个灰发少女正在采药，身旁草木尽数枯萎。","opts":[["上前帮忙（解锁小医仙）","yixian"],["悄悄离开","none"]],"ch":[1]},
	{"id":"sand_storm","t":"沙暴","d":"遮天蔽日的沙暴袭来！","opts":[["硬抗（受伤15%，获得斗气）","storm"],["绕行（损失40金）","gold:-40"]],"ch":[2]},
	{"id":"oasis","t":"绿洲","d":"沙漠深处的一片绿洲，泉水清冽。","opts":[["休息（回复35%生命）","heal:0.35"],["寻找宝物","art"]],"ch":[2]},
	{"id":"haibodong","t":"冰皇海波东","d":"一个落魄老人盯着你手中的地图残片：“小子，那张地图……”","opts":[["交出地图（获得冰系斗技）","ice_art"],["拒绝","none"]],"ch":[2]},
	{"id":"yunyun_meet","t":"云韵","d":"一位白衣女子立于云端：“你……就是萧炎？”","opts":[["交谈（解锁云韵）","yunyun"]],"ch":[2]},
	{"id":"fire_seed","t":"异火气息","d":"你感觉到附近有一缕异火气息……","opts":[["追寻（进入吞火挑战）","fire"],["不冒险","none"]],"ch":[1,2]},
	{"id":"yaolao_teach","t":"药老指点","d":"药老：“小家伙，为师传你一门斗技。”","opts":[["学习斗技","art_up"],["请教炼药（获得丹方与药材）","herbs:0"]],"ch":[1,2]},
	{"id":"trial","t":"试炼石碑","d":"石碑上写着：“击败心中之敌，方得真传。”","opts":[["接受试炼（精英战，奖励翻倍）","trial"],["离开","none"]],"ch":[1,2]},
]

var story := {}
func _build_story() -> void:
	# 每条: [说话人id(用于头像，""为旁白), 名字, 文本]
	story.merge(WD.stories())
	story["prologue_start"] = [
		["","","中州，天墓之巅。万族陨落，苍穹破碎。"],
		["hun_tiandi","魂天帝","萧炎，这斗气大陆，只能有一个帝！"],
		["yandi","炎帝·萧炎","那就让我看看，你的帝境，能不能挡住我这一路走来的火焰。"],
		["","","【序章·演示关】你现在拥有炎帝的全部力量。尽情施展吧！"],
	]
	story["prologue_end"] = [
		["hun_tiandi","魂天帝","不可能……区区一个小家族的废物，怎么会……"],
		["yandi","炎帝·萧炎","废物？……是啊，很久以前，我也被人这样叫过。"],
		["","","时光倒流，回到一切开始的地方——"],
		["","","乌坦城，萧家。三年前。"],
	]
	story["ch1_start"] = [
		["","测验员","萧炎，斗之力，三段！级别：低级！"],
		["","族人","哈哈，曾经的天才，现在连斗之气都凝聚不起来了！"],
		["xuner","萧薰儿","萧炎哥哥……我相信你。"],
		["yaolao","药老","（戒指里传出苍老的声音）小家伙，你的斗之气，是被老夫吸走的。"],
		["xiaoyan","萧炎","……你是谁？！"],
		["yaolao","药老","老夫药尘。想要找回力量吗？那就先活下来吧。"],
		["","","纳兰家族的人来了——纳兰嫣然当众要求退婚。"],
		["nalan","纳兰嫣然","萧炎，你我之间差距太大，这婚约，就此作罢。"],
		["xiaoyan","萧炎","三十年河东，三十年河西，莫欺少年穷！三年之后，我去云岚宗找你！"],
		["","","【第一章：乌坦城·魔兽山脉】目标：变强。击败狼头佣兵团团长穆蛇。"],
	]
	story["ch1_boss"] = [
		["","穆蛇","就是你杀了我的人？斗者小子，今天你走不了！"],
		["yaolao","药老","别慌，他只是斗师初期。用你学到的一切！"],
	]
	story["ch1_end"] = [
		["xiaoyan","萧炎","呼……终于。"],
		["yaolao","药老","不错，小家伙。但真正的强者之路，才刚刚开始。"],
		["yaolao","药老","塔戈尔沙漠深处，有一种异火——青莲地心火。去吞了它。"],
		["xuner","萧薰儿","萧炎哥哥，薰儿会一直等你。（萧薰儿已加入可选角色）"],
	]
	story["ch2_start"] = [
		["","","加玛帝国西北，塔戈尔大沙漠。"],
		["yaolao","药老","青莲地心火就藏在蛇人族的地盘之下。小心美杜莎女王。"],
		["xiaoyan","萧炎","三年之约……时间不多了。"],
		["","","【第二章：塔戈尔沙漠·云岚宗】本章采用“房间门”推进：清理房间后，选择一扇门。"],
	]
	story["ch2_medusa"] = [
		["medusa","美杜莎女王","人类，你闯进了不该来的地方。"],
		["xiaoyan","萧炎","我只为异火而来，女王陛下若要拦，那就得罪了！"],
	]
	story["ch2_medusa_win"] = [
		["medusa","美杜莎女王","……哼，今日暂且放过你。"],
		["","","美杜莎在渡劫进化时虚弱，化作一条七彩小蛇……（美杜莎已可解锁）"],
	]
	story["ch2_fire"] = [
		["yaolao","药老","就是现在！压制它，吞噬它！准备好承受焚心之痛！"],
	]
	story["ch2_nalan"] = [
		["nalan","纳兰嫣然","萧炎，你真的来了。"],
		["xiaoyan","萧炎","三年之约，我萧炎从不食言。"],
	]
	story["ch2_boss"] = [
		["","云山","魂殿的大人会给我力量！萧炎，今日云岚宗就是你的葬身之地！"],
		["yunyun","云韵","老师……不要！"],
		["xiaoyan","萧炎","老师，借我力量——！"],
	]
	story["ch2_end"] = [
		["","","云岚宗之战落幕，萧炎之名，响彻加玛帝国。"],
		["yunyun","云韵","萧炎……你走吧。云岚宗，终究是我的宗门。"],
		["yaolao","药老","……魂殿已经盯上老夫了。小家伙，接下来的路，你要自己走。"],
		["","","【v1 内容到此结束】第三章：迦南学院·陨落心炎，将在下一版本推出！"],
	]

func _ready() -> void:
	_build_skills()
	_build_fusions()
	_build_story()
	for f in fires:
		fire_by_id[f["id"]] = f

# ------------------------------------------------------------------ 工具
func grade_tier(g:int) -> int:
	return clampi(g / 3, 0, 3)

func grade_color(g:int) -> Color:
	return TIER_COLORS[grade_tier(g)]

func elem_color(e:String) -> Color:
	return ELEM.get(e, ELEM["phys"])["c"]

func realm_name(r:int) -> String:
	var major := clampi(r / 9, 0, REALMS.size()-1)
	if major == REALMS.size() - 1:
		return "斗帝"
	if major == 0:
		return "斗之气·%s段" % SUB_STAGES[r % 9]
	return "%s·%s星" % [REALMS[major], SUB_STAGES[r % 9]]

func realm_major(r:int) -> int:
	return clampi(r / 9, 0, REALMS.size()-1)

## 战力（属性成长用），在大境界之间线性插值
func realm_pow(r:int) -> float:
	var major := clampi(r / 9, 0, REALMS.size()-1)
	var sub := float(r % 9) / 9.0 if major < REALMS.size() - 1 else 0.0
	return lerpf(REALM_POW[major], REALM_POW[major + 1], sub)

func fire_pair_key(a:String, b:String) -> String:
	var arr := [a, b]
	arr.sort()
	return arr[0] + "+" + arr[1]
