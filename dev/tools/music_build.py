# 游戏文件名 : 候选源 key
FILES = {
 'title_jade_throne':'views-from-atop-the-jade-kings-throne',
 'hub_tea_in_china':'sm_all-the-tea-in-china',
 'prologue_oriental':'gq01_oriental_I',
 'zone_wutan':'harmony-of-the-scholar',
 'zone_wutan_b':'tea-serenity',
 'zone_mt_out':'rpg-misty-mountains',
 'zone_mt_deep':'wandering-spirit',
 'zone_mt_deep_b':'whispers-of-bamboo',
 'zone_desert':'fantasy-music-the-eternal-sands',
 'zone_desert_b':'negev_desert',
 'zone_jiama':'path-of-the-sage',
 'zone_jiama_b':'asian-duet',
 'zone_yunlan':'ancient-temple',
 'zone_yunlan_b':'moonlit-melodies',
 'cave_a':'rpg-the-cave-ambient','cave_b':'caves-of-sorrow','cave_c':'the-peculiar-habits-of-the-cave-hermits',
 'battle_a':'a-fight-in-the-fields-rpg-orchestral-essentials-combat-music','battle_b':'battle-music-the-battle-of-atheria','battle_c':'rpg-to-arms-battle-music-1','battle_d':'brave-soldiers','battle_e':'land-of-fearless','battle_f':'light-is-on-our-blades',
 'battle_desert':'negev_fight',
 'elite_a':'shadows-clash','elite_b':'warriors-of-the-night','elite_c':'spirit-of-the-dragon',
 'boss_wolfking':'showdown-of-misdeeds-rpg-orchestral-essentials-boss-music',
 'boss_mushe':'final-confrontation',
 'boss_medusa':'jrpg-desert-boss-theme',
 'boss_fire':'epic-fall',
 'boss_yunshan':'colossal-boss-battle-theme',
 'boss_heart':'dark-descent-extended-cut',
 'boss_hun':'the-final-battle',
 'boss_nalan':'undisputed',
 'boss_jialie':'the-battle',
 'boss_default':'the-patriarch-2-part-boss-theme',
 'shop':'fantasy-music-the-savvy-merchant',
 'alchemy':'asian-string-suite',
 'rest':'dreaming-strings',
 'fire_devour':'dragons-path',
 'breakthrough':'epic-transformation-124',
 'victory':'the-precipice-of-victory-rpg-orchestral-essentials-battle-results-music',
 'chapter_clear':'training-is-over-rpg-orchestral-essentials-battle-results-music',
 'defeat':'homesick-116',
 'story_sad':'wipe-away-those-tears-rpg-orchestral-essentials-sad-happy-music',
 'story_memory':'full-of-memories',
 # 角色曲
 'theme_xiaoyan':'leap-into-eternity-live-orchestra',
 'theme_yandi':'sm_imperial-china-cinematic',
 'theme_xuner':'palatial-serenade',
 'theme_yunyun':'mystical-breeze',
 'theme_medusa':'awakening-of-the-dragon',
 'theme_xiaoyixian':'whispers-of-the-erhu',
 'theme_yaolao':'liyan',
 'theme_nalan':'strings-in-harmony',
 'theme_hun':'darkness-march',
 'theme_yunshan':'confrontation-0',
}

# ---- 编码流程（音源列表由 FILES 匹配 dev/audio_src/music_cand 生成）
# import subprocess, json, re, sys
# from concurrent.futures import ThreadPoolExecutor
# LOOPS={'zone_desert_b','battle_desert'}
# STING={'victory','chapter_clear','breakthrough'}
# rows=[l.rstrip('\n').split('\t') for l in open('/var/tmp/w/music_src.txt')]
# def dur(f): return float(subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f],capture_output=True,text=True).stdout)
# def job(r):
#     g,f=r; d=dur(f)
#     m=subprocess.run(['ffmpeg','-hide_banner','-i',f,'-af','loudnorm=I=-18:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True).stderr
#     j=json.loads(m[m.rfind('{'):m.rfind('}')+1])
#     ln=f"loudnorm=I=-18:TP=-1.5:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}:measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true"
#     af=[ln]
#     if g not in LOOPS:
#         fi=0.4 if g in STING else 1.5
#         af+= [f'afade=t=in:d={fi}', f'afade=t=out:st={max(0,d-4):.2f}:d=4']
#     subprocess.run(['ffmpeg','-v','error','-y','-i',f,'-af',','.join(af),'-ar','44100','-ac','2','-c:a','libvorbis','-q:a','3',f'/var/tmp/w/musout/{g}.ogg'])
#     return g, round(d)
# res=list(ThreadPoolExecutor(2).map(job,rows))
# print(res)
