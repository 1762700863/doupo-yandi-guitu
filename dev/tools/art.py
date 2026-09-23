import numpy as np, glob, os
from PIL import Image
from scipy import ndimage
A='/home/user/game/assets'
rng=np.random.default_rng(3)
BAYER=np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]])/16.0
def hexc(h): h=h.lstrip('#'); return np.array([int(h[i:i+2],16) for i in (0,2,4)])
def vnoise(w,h,scale,seed,octs=3):
    r=np.random.default_rng(seed); out=np.zeros((h,w)); amp=1; tot=0
    for o in range(octs):
        s=max(1,int(scale/(2**o)))
        gw,gh=w//s+2,h//s+2
        g=r.random((gh,gw))
        # tileable: wrap
        g[:,-1]=g[:,0]; g[-1,:]=g[0,:]
        z=ndimage.zoom(g,(s,s),order=3,mode='grid-wrap')[:h,:w]
        out+=z*amp; tot+=amp; amp*=0.5
    out/=tot; out=(out-out.min())/(out.max()-out.min()+1e-9); return out
def quant(v,pal,dither=0.18):
    n=len(pal); h,w=v.shape
    th=np.tile(BAYER,(h//4+1,w//4+1))[:h,:w]
    idx=np.clip((v*n+(th-0.5)*dither*n).astype(int),0,n-1)
    return np.array(pal)[idx].astype(np.uint8)
def save(a,p,alpha=None):
    if alpha is None: Image.fromarray(a,'RGB').save(p)
    else:
        b=np.dstack([a,alpha]).astype(np.uint8); Image.fromarray(b,'RGBA').save(p)
BIOMES={
 'wutan':['#4a6b2f','#5b7f36','#6d9340','#86a84f','#a2c160'],
 'forest':['#1f3a24','#28492b','#335a33','#3f6b3b','#557f47'],
 'desert':['#b0803f','#c4944c','#d4a75b','#e0b96d','#ecd08a'],
 'lava':['#231a1c','#2f2224','#3c2b2b','#4a3431','#5b4038'],
 'yunlan':['#8d93a0','#a0a6b2','#b3b9c3','#c5cad2','#d9dde3'],
 'void':['#140f22','#1c1530','#251c3d','#30244c','#3d2e5c'],
 'hub':['#6b5a3e','#7b6947','#8c7952','#9d8a5e','#b09d6e'],
}
for name,pal in BIOMES.items():
    pal=[hexc(c) for c in pal]
    tiles=[]
    for v in range(4):
        n=vnoise(64,64,16,seed=hash(name)%1000+v,octs=3)*0.7+vnoise(64,64,4,seed=v+50,octs=1)*0.3
        t=quant(n,pal)
        if name=='yunlan' or name=='hub':
            # stone slabs grid
            t=t.copy(); dark=np.array(pal[0]); 
            t[0,:]=dark; t[:,0]=dark; t[32,:]=dark; t[:,32 if v%2==0 else 16]=dark
            t[1,:]=np.minimum(255,t[1,:].astype(int)+20)
        if name=='lava' and v>=2:
            m=vnoise(64,64,24,seed=v+9,octs=2)
            crack=(abs(m-0.5)<0.02)
            t=t.copy(); t[crack]=hexc('#ff7a2a'); t[ndimage.binary_dilation(crack)&~crack]=hexc('#8a2e14')
        if name=='void':
            t=t.copy(); st=rng.random((64,64))<0.004; t[st]=hexc('#b9a4ff')
        tiles.append(t)
    sheet=np.concatenate(tiles,1)
    save(sheet,f'{A}/tiles/{name}.png')
# ---------- objects ----------
def outline(rgba,col=(18,12,16)):
    al=rgba[...,3]>0; ring=ndimage.binary_dilation(al)&~al
    rgba[ring]=list(col)+[255]; return rgba
def shade_blob(w,h,pal,seed,shape='ellipse'):
    yy,xx=np.mgrid[0:h,0:w]; cx,cy=w/2,h/2
    if shape=='ellipse':
        n=vnoise(w,h,max(4,w//4),seed,2)
        d=((xx-cx)/(w/2-1))**2+((yy-cy)/(h/2-1))**2 + (n-0.5)*0.5
        m=d<1
    light=1-(((xx-cx*0.7)/(w))**2+((yy-cy*0.6)/(h))**2)*3
    light=np.clip(light+vnoise(w,h,6,seed+1,2)*0.3-0.1,0,1)
    col=quant(light,pal,0.25)
    rgba=np.zeros((h,w,4),np.uint8); rgba[...,:3]=col; rgba[...,3]=m*255
    return outline(rgba)
OBJ={
 'rock':(['#3a3a44','#4f505c','#676a76','#858a95','#a7adb6'],44,34),
 'rock_desert':(['#6b4a2a','#86603a','#a0784a','#ba915c','#d3ab74'],46,34),
 'rock_lava':(['#1c1416','#2c2022','#3d2c2c','#533b36','#6b4b42'],46,36),
 'crystal_void':(['#2a1a4a','#43297a','#6641b0','#8d66e0','#c2a8ff'],30,46),
 'bush':(['#1d3a1f','#2a5229','#3a6d35','#528a45','#72a85c'],40,30),
}
for k,(pal,w,h) in OBJ.items():
    pal=[hexc(c) for c in pal]
    if k=='crystal_void':
        rgba=np.zeros((h,w,4),np.uint8)
        for (x0,hh,ww) in [(w//2,h-2,10),(w//2-8,h-14,7),(w//2+8,h-18,7)]:
            for y in range(h-hh,h):
                frac=(y-(h-hh))/hh; half=int(ww/2*min(1,frac*3))
                for x in range(x0-half,x0+half+1):
                    if 0<=x<w:
                        li=0.35+0.6*(1-(x-(x0-half))/(2*half+1))-frac*0.2
                        rgba[y,x,:3]=pal[int(np.clip(li*5,0,4))]; rgba[y,x,3]=255
        rgba=outline(rgba)
    else:
        rgba=shade_blob(w,h,pal,seed=len(k))
    Image.fromarray(rgba,'RGBA').save(f'{A}/obj/{k}.png')
# tree: trunk + layered canopy
def tree(pal_leaf,pal_trunk,w=64,h=84,seed=1):
    rgba=np.zeros((h,w,4),np.uint8)
    tw=10; 
    for y in range(h-28,h):
        for x in range(w//2-tw//2,w//2+tw//2):
            li=1-(x-(w//2-tw//2))/tw; rgba[y,x,:3]=pal_trunk[int(np.clip(li*3.9,0,3))]; rgba[y,x,3]=255
    r=np.random.default_rng(seed)
    blobs=[(w/2,26,26),(w/2-14,38,18),(w/2+14,38,18),(w/2,44,20),(w/2-8,18,16),(w/2+9,20,15)]
    yy,xx=np.mgrid[0:h,0:w]
    n=vnoise(w,h,6,seed,2)
    for bx,by,br in blobs:
        d=np.sqrt((xx-bx)**2+(yy-by)**2)+(n-0.5)*6
        m=d<br
        li=np.clip(1-((xx-(bx-br*0.4))**2+(yy-(by-br*0.5))**2)/(br*1.6)**2 +(n-0.5)*0.4,0,1)
        col=quant(li,pal_leaf,0.3)
        rgba[m,:3]=col[m]; rgba[m,3]=255
    return outline(rgba)
Image.fromarray(tree([hexc(c) for c in ['#14301a','#1f4524','#2d5e2e','#3f783a','#5b964c']],[hexc(c) for c in ['#2b1c14','#3e2a1c','#573b26','#6e4d31']]),'RGBA').save(f'{A}/obj/tree.png')
Image.fromarray(tree([hexc(c) for c in ['#2c1b0c','#4a2f14','#6b441c','#8d5c28','#b07a3a']],[hexc(c) for c in ['#1c120c','#2e1e14','#45301f','#5b402a']],seed=4),'RGBA').save(f'{A}/obj/tree_dead.png')
# pillar
def pillar(w=26,h=70):
    pal=[hexc(c) for c in ['#6f7582','#8a909c','#a7adb8','#c5cad3','#e2e6ec']]
    rgba=np.zeros((h,w,4),np.uint8)
    for y in range(h):
        for x in range(w):
            inner = 3<=x<w-3 or y<8 or y>h-8
            if not inner: continue
            li=0.9-abs(x-w*0.38)/w*1.6
            if y<8 or y>h-8: li+=0.1
            if (x-3)%5==0 and 8<y<h-8: li-=0.25
            rgba[y,x,:3]=pal[int(np.clip(li*5,0,4))]; rgba[y,x,3]=255
    return outline(rgba)
Image.fromarray(pillar(),'RGBA').save(f'{A}/obj/pillar.png')
# lantern post (hub/yunlan decor) & cactus
def cactus(w=30,h=48):
    pal=[hexc(c) for c in ['#1e3d1e','#2d5a2a','#3f7a37','#5a9a48']]
    rgba=np.zeros((h,w,4),np.uint8)
    def rect(x0,y0,x1,y1):
        for y in range(y0,y1):
            for x in range(x0,x1):
                li=1-(x-x0)/(x1-x0); rgba[y,x,:3]=pal[int(np.clip(li*3.9,0,3))]; rgba[y,x,3]=255
    rect(11,4,19,h); rect(3,16,9,30); rect(3,26,11,32); rect(21,10,27,24); rect(19,20,27,26)
    return outline(rgba)
Image.fromarray(cactus(),'RGBA').save(f'{A}/obj/cactus.png')
# ---------- white silhouettes for hit flash ----------
for f in glob.glob(f'{A}/sprites/*.png'):
    if f.endswith('_w.png'): continue
    im=np.array(Image.open(f).convert('RGBA'))
    w=np.zeros_like(im); w[...,:3]=255; w[...,3]=im[...,3]
    Image.fromarray(w,'RGBA').save(f[:-4]+'_w.png')
for f in glob.glob(f'{A}/obj/*.png'):
    pass
# ---------- portraits (busts) ----------
for f in glob.glob(f'{A}/portraits/*_hi.png'):
    n=os.path.basename(f)[:-7]
    im=Image.open(f).convert('RGBA')
    a=np.array(im); ys,xs=np.where(a[...,3]>0)
    # bust: top part centered on head (use top 48% of height), crop width around median x of top rows
    top=int(im.height*0.5)
    rows=a[:int(im.height*0.18),:,3]>0
    cx=int(np.median(np.where(rows)[1])) if rows.any() else im.width//2
    half=int(im.height*0.32)
    x0=max(0,cx-half); x1=min(im.width,cx+half)
    b=im.crop((x0,0,x1,top))
    th=150; tw=round(b.width*th/b.height)
    b=b.resize((tw,th),Image.BOX); q=np.array(b); q[...,3]=np.where(q[...,3]>110,255,0)
    q=outline(q,(10,6,10))
    Image.fromarray(q,'RGBA').save(f'{A}/portraits/{n}.png')
    # full body medium (for select screen / CG) height 200
    fb=im.resize((round(im.width*200/im.height),200),Image.BOX); q=np.array(fb); q[...,3]=np.where(q[...,3]>110,255,0)
    Image.fromarray(outline(q,(10,6,10)),'RGBA').save(f'{A}/portraits/{n}_full.png')
print('objs & portraits ok')
