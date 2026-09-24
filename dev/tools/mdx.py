"""从 MangaDex 下载《斗破苍穹》漫画原页（全彩，话数与 fandom 一致），并生成缩略总览，用于查找角色的真实漫画形象。
用法:
  python3 mdx.py sheet <outdir> <话数...>      下载(省流版)并为每话生成 <outdir>/sheet_<话>.jpg
  python3 mdx.py full  <outdir> <话数> <页码...> 下载指定页的高清原图 <outdir>/c<话>_<页>.jpg
"""
import sys, os, json, subprocess
MANGA = 'cee2ab81-2ab5-4c91-8715-92848ef5b2d4'
def get(u):
    return json.loads(subprocess.run(['curl', '-s', '-m', '30', '-A', 'Mozilla/5.0', u], capture_output=True, text=True).stdout)
def chapters():
    d = get(f'https://api.mangadex.org/manga/{MANGA}/aggregate'); chs = {}
    for v in d.get('volumes', {}).values():
        for c, x in v['chapters'].items(): chs[c] = x['id']
    return chs
def pages(cid, saver):
    d = get(f'https://api.mangadex.org/at-home/server/{cid}')
    k, q = ('dataSaver', 'data-saver') if saver else ('data', 'data')
    return [f"{d['baseUrl']}/{q}/{d['chapter']['hash']}/{f}" for f in d['chapter'][k]]
def dl(u, p): subprocess.run(['curl', '-s', '-m', '60', '-o', p, u])
if __name__ == '__main__':
    mode, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True); chs = chapters()
    if mode == 'sheet':
        from PIL import Image, ImageDraw
        for c in sys.argv[3:]:
            ps = pages(chs[c], True); ims = []
            for i, u in enumerate(ps):
                p = f'{out}/_t.jpg'; dl(u, p)
                try: im = Image.open(p).convert('RGB')
                except Exception: continue
                im = im.resize((max(1, int(im.width * 300 / im.height)), 300))
                cc = Image.new('RGB', (im.width, 316), 'white'); cc.paste(im, (0, 16)); ImageDraw.Draw(cc).text((3, 2), f'{c}-{i:02d}', fill='red'); ims.append(cc)
            rows, r, w = [], [], 0
            for im in ims:
                if w + im.width > 2400: rows.append(r); r, w = [], 0
                r.append(im); w += im.width + 4
            rows.append(r)
            S = Image.new('RGB', (2400, len(rows) * 320), 'white')
            for y, r in enumerate(rows):
                x = 0
                for im in r: S.paste(im, (x, y * 320)); x += im.width + 4
            S.save(f'{out}/sheet_{c}.jpg', quality=70); print(c, len(ps))
        if os.path.exists(f'{out}/_t.jpg'): os.remove(f'{out}/_t.jpg')
    else:
        c = sys.argv[3]; ps = pages(chs[c], False)
        for i in sys.argv[4:]: dl(ps[int(i)], f'{out}/c{c}_{int(i):02d}.jpg'); print(f'c{c}_{int(i):02d}.jpg')
