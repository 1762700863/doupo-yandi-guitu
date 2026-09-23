import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
A='/home/user/game/assets/obj/'
def outline(img,col=(16,10,14,255)):
    a=np.array(img); al=a[...,3]>0; ring=ndimage.binary_dilation(al)&~al; a[ring]=col; return Image.fromarray(a)
def roof(d,x0,x1,y,h,c1,c2,c3,over=12,curl=6):
    # upturned eaves roof
    pts=[(x0-over,y+h),(x0-over-curl,y+h-curl),(x0+8,y),(x1-8,y),(x1+over+curl,y+h-curl),(x1+over,y+h)]
    d.polygon(pts,fill=c2)
    d.polygon([(x0-over,y+h),(x1+over,y+h),(x1+over-2,y+h+3),(x0-over+2,y+h+3)],fill=c1)
    for i,xx in enumerate(range(x0+4,x1-2,5)):
        d.line([(xx,y+2),(xx-((xx-(x0+x1)/2)*0.25),y+h-1)],fill=c1)
    d.line([(x0+8,y),(x1-8,y)],fill=c3,width=2)
    d.line([(x0-over-curl,y+h-curl),(x0+8,y)],fill=c3)
    d.line([(x1+over+curl,y+h-curl),(x1-8,y)],fill=c3)
def pavilion(name,roofc,wallc=(196,170,128),pillar=(150,38,32),w=120,h=110,plaque=True):
    img=Image.new('RGBA',(w+40,h),(0,0,0,0)); d=ImageDraw.Draw(img)
    ox=20; bx0,bx1=ox+10,ox+w-10
    d.rectangle([ox,h-12,ox+w,h-1],fill=(110,110,118,255)); d.rectangle([ox,h-12,ox+w,h-10],fill=(150,150,160,255))
    d.line([(ox,h-6),(ox+w,h-6)],fill=(90,90,98,255))
    d.rectangle([bx0,h-58,bx1,h-12],fill=wallc+(255,))
    d.rectangle([bx0,h-58,bx1,h-54],fill=tuple(int(c*0.7) for c in wallc)+(255,))
    for px in [bx0,bx0+ (bx1-bx0)//3, bx0+2*(bx1-bx0)//3, bx1-6]:
        d.rectangle([px,h-58,px+6,h-12],fill=pillar+(255,)); d.line([(px+1,h-58),(px+1,h-12)],fill=tuple(min(255,int(c*1.4)) for c in pillar)+(255,))
    mx=(bx0+bx1)//2
    d.rectangle([mx-12,h-40,mx+12,h-12],fill=(60,34,24,255)); d.line([(mx,h-40),(mx,h-12)],fill=(40,20,14,255))
    for wx in [bx0+14,bx1-30]:
        d.rectangle([wx,h-48,wx+16,h-30],fill=(70,44,30,255))
        for k in range(3): d.line([(wx+4+k*4,h-48),(wx+4+k*4,h-30)],fill=(200,170,110,255))
    c1=tuple(int(c*0.55) for c in roofc)+(255,); c2=roofc+(255,); c3=tuple(min(255,int(c*1.5)+20) for c in roofc)+(255,)
    roof(d,bx0,bx1,h-86,28,c1,c2,c3)
    if plaque:
        d.rectangle([mx-16,h-66,mx+16,h-56],fill=(40,24,16,255)); d.rectangle([mx-14,h-65,mx+14,h-57],fill=(214,170,60,255))
    img=outline(img); img.save(A+name+'.png')
pavilion('b_alchemy',(58,92,80))
pavilion('b_library',(40,54,90))
pavilion('b_train',(110,40,36))
pavilion('b_forge',(70,62,58),wallc=(150,130,110))
pavilion('b_inn',(96,60,40))
pavilion('b_codex',(80,50,100))
pavilion('b_challenge',(40,40,48),wallc=(120,110,120),pillar=(60,60,70))
# pagoda 天火塔
w,h=110,190; img=Image.new('RGBA',(w+40,h),(0,0,0,0)); d=ImageDraw.Draw(img); ox=20
d.rectangle([ox+5,h-10,ox+w-5,h-1],fill=(100,100,110,255))
tiers=[(ox+18,ox+w-18,h-10,40),(ox+26,ox+w-26,h-62,34),(ox+34,ox+w-34,h-108,30),(ox+40,ox+w-40,h-148,24)]
for i,(a,b,base,th) in enumerate(tiers):
    d.rectangle([a,base-th,b,base],fill=(170,60,40,255)); d.rectangle([a,base-th,a+3,base],fill=(210,90,60,255))
    m=(a+b)//2; d.rectangle([m-6,base-th+8,m+6,base-2],fill=(255,170,60,255)); d.rectangle([m-4,base-th+10,m+4,base-2],fill=(255,230,140,255))
    roof(d,a,b,base-th-14,14,(40,24,20,255),(70,40,30,255),(200,150,60,255),over=8,curl=5)
d.line([(ox+w//2,h-190),(ox+w//2,h-162)],fill=(220,180,70,255),width=3)
img=outline(img); img.save(A+'b_tower.png')
# gate 出征
w,h=150,120; img=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(img)
for px in [18,w-30]:
    d.rectangle([px,30,px+12,h-2],fill=(150,36,30,255)); d.rectangle([px,30,px+3,h-2],fill=(200,70,55,255))
    d.rectangle([px-3,h-10,px+15,h-2],fill=(90,90,100,255))
d.rectangle([10,40,w-10,48],fill=(120,28,24,255))
roof(d,20,w-20,8,20,(30,20,16,255),(56,36,28,255),(210,160,60,255),over=10,curl=6)
d.rectangle([w//2-20,30,w//2+20,44],fill=(40,24,16,255)); d.rectangle([w//2-18,31,w//2+18,43],fill=(214,170,60,255))
img=outline(img); img.save(A+'b_gate.png')
# cauldron 丹炉
w,h=48,50; img=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(img)
d.polygon([(10,h-2),(14,h-12),(34,h-12),(38,h-2)],fill=(60,50,40,255))
d.ellipse([4,12,44,44],fill=(120,90,50,255)); d.ellipse([8,14,32,34],fill=(160,125,70,255)); d.ellipse([12,16,22,24],fill=(200,170,110,255))
d.rectangle([10,8,38,14],fill=(90,66,40,255)); d.rectangle([2,20,6,28],fill=(90,66,40,255)); d.rectangle([42,20,46,28],fill=(90,66,40,255))
d.rectangle([20,2,28,8],fill=(90,66,40,255))
img=outline(img); img.save(A+'cauldron.png')
# lantern
w,h=16,40; img=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(img)
d.rectangle([7,14,9,h-1],fill=(60,40,30,255)); d.ellipse([2,2,14,18],fill=(220,60,40,255)); d.ellipse([4,4,10,12],fill=(255,150,90,255)); d.rectangle([5,0,11,2],fill=(50,30,20,255))
img=outline(img); img.save(A+'lantern.png')
print('ok')
