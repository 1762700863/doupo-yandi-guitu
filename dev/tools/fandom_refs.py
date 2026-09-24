"""从 battle-through-the-heavens.fandom.com 角色页面抓取参考图（身份可靠：图片挂在对应角色页）。
用法: python3 fandom_refs.py <outdir> slug="Page Title" ...
输出 <outdir>/<slug>_<n>_<文件名>.jpg（长边700）。注意：标“Manhua”的图不一定是本人，需目测核实。"""
import sys,json,urllib.request,urllib.parse,os,re,subprocess
from PIL import Image
API="https://battle-through-the-heavens.fandom.com/api.php"
def q(**k):
    k['format']='json'
    for _ in range(4):
        try:
            r=subprocess.run(['curl','-s','-m','30','--retry','3','-A','Mozilla/5.0',API+'?'+urllib.parse.urlencode(k)],capture_output=True,text=True)
            return json.loads(r.stdout)
        except Exception: pass
    return {}
out=sys.argv[1]; os.makedirs(out,exist_ok=True)
for key in sys.argv[2:]:
    slug,page=key.split('=',1)
    d=q(action='query',titles=page,prop='images|pageimages',piprop='original',imlimit=60,redirects=1)
    if not d.get('query'): print(slug,'NOQUERY'); continue
    p=list(d['query']['pages'].values())[0]
    files=[i['title'] for i in p.get('images',[]) if not re.search(r'icon|\.gif|\.mp3|\.ogg|2015060816',i['title'],re.I)]
    main=p.get('original',{}).get('source')
    pick=[f for f in files if re.search('manhua|comic',f,re.I)]
    pick+=[f for f in files if f not in pick][:5]
    urls=[('main',main)] if main else []
    if pick:
        ii=q(action='query',titles='|'.join(pick[:9]),prop='imageinfo',iiprop='url')
        for pg in ii.get('query',{}).get('pages',{}).values():
            if 'imageinfo' in pg: urls.append((pg['title'],pg['imageinfo'][0]['url']))
    print(slug,p.get('title'),[u[0] for u in urls],flush=True)
    for j,(t,u) in enumerate(urls):
        fn=f'{out}/{slug}_{j}_'+re.sub(r'[^A-Za-z0-9]+','_',t)[:40]
        if os.path.exists(fn+'.jpg'): continue
        subprocess.run(['curl','-sL','--retry','4','--retry-all-errors','-m','40','-A','Mozilla/5.0','-o',fn,u])
        try:
            im=Image.open(fn).convert('RGB'); im.thumbnail((700,700)); im.save(fn+'.jpg',quality=85)
        except Exception as e: print(' fail',t,e)
        if os.path.exists(fn): os.remove(fn)
