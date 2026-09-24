extends Node
func _ready() -> void:
	await get_tree().process_frame
	for c in D.char_order:
		for ch in [1, 2]:
			G.new_run(c, ch, D.chars[c]["atks"][0], "yaolao", 1, [])
			G.run["zone"] = Flow.new_zone_state(ch, 0)
			for i in 60:
				var kinds := ["any", "art", "relic", "upgrade", "ult", "move", "gong", "boss"]
				var opts := Rewards.options(3, kinds[i % kinds.size()])
				for o in opts:
					Rewards.describe(o)
				if opts.size() > 0:
					var r := Rewards.apply(opts[0])
					if r == "need_replace":
						Rewards.apply(opts[0], 0)
				G.run["realm"] = mini(G.realm_cap(), int(G.run["realm"]) + (1 if i % 6 == 0 else 0))
			G.run["floor"] = 3
			for f in 12:
				G.run["floor"] = f
				G.run["zone"] = Flow.new_zone_state(ch, f % WD.chapter_zones[ch].size())
			G.save_run()
			G.load_run()
			for id in D.pills:
				Battle.apply_pill(id, null)
			print(c, ch, " arts=", G.run["arts"].size(), " relics=", G.run["relics"].size(), " fires=", G.run["fires"].size(), " realm=", G.run["realm"])
	# 音乐：每个情境的曲目都必须存在
	var miss := 0
	for c in Au.LISTS:
		for f in Au.LISTS[c]:
			if not ResourceLoader.exists("res://assets/music/%s.ogg" % f):
				print("MISSING MUSIC ", c, " ", f)
				miss += 1
	for z in WD.zones:
		if not Au.LISTS.has(Au.zone_ctx(z)):
			miss += 1
	print("music contexts=", Au.LISTS.size(), " missing=", miss)
	print("LOGIC_DONE")
	get_tree().quit()
