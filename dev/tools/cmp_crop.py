from PIL import Image, ImageDraw, ImageFont
import sys
R='art_src/refs_raw/'
F=ImageFont.truetype('/var/tmp/w/doupo-yandi-guitu/assets/fonts/fusion.ttf',28)
def crop(f,x0,y0,x1,y1):
    im=Image.open(R+f).convert('RGB'); W,H=im.size
    return im.crop((int(x0*W),int(y0*H),int(x1*W),int(y1*H)))
def art(name):
    im=Image.open('art_src/base_cut/'+name+'.png').convert('RGBA')
    bb=im.getbbox(); im=im.crop(bb)
    bg=Image.new('RGBA',im.size,(88,88,96,255)); bg.alpha_composite(im); return bg.convert('RGB')
def make(out,refs,artname,label,H=800):
    tiles=[]
    for r in refs:
        t=crop(*r); s=H/t.height; tiles.append(('漫画 '+r[0].split('_c')[-1].split('.')[0],t.resize((int(t.width*s),H))))
    a=art(artname); s=(H-40)/a.height; a=a.resize((int(a.width*s),H-40))
    pad=Image.new('RGB',(a.width+40,H),(88,88,96)); pad.paste(a,(20,20)); tiles.append(('立绘 '+artname,pad))
    W=sum(t.width for _,t in tiles)+8*(len(tiles)-1)
    c=Image.new('RGB',(W,H+44),'white'); d=ImageDraw.Draw(c); x=0
    for lab,t in tiles:
        c.paste(t,(x,44)); d.text((x+6,6),lab,fill='black',font=F); x+=t.width+8
    c.save(out,quality=88); print(out,c.size)
J={
'魂天帝龟裂':([('r135/hun_tiandi_crack_c465_19.jpg',.58,.03,.92,.96),('r135/hun_tiandi_crack_c465_21.jpg',.10,.67,.91,.95),('r135/hun_tiandi_crack_c465_23.jpg',.10,.03,.63,.95)],'hun_tiandi_crack'),
'陈闲':([('r134/chenxian_c274_17.jpg',.0,.60,1,.78),('r134/chenxian_c274_17.jpg',0,.79,1,1),('r134/xuanming_mask_c274_21.jpg',0,.14,1,.80)],'chenxian'),
'玄冥宗面具长老':([('r134/chenxian_c274_20.jpg',0,.27,1,.80),('r134/chenxian_c274_20.jpg',0,.80,1,1),('r134/xuanming_mask_c274_18.jpg',0,.44,.40,.75)],'xuanming_mask'),
'狮天':([('r134/shitian_c357_15.jpg',0,.08,1,.42),('r134/shitian_c357_15.jpg',0,.65,1,.85),('r134/shitian_c358_15.jpg',.40,.33,1,.98)],'shitian'),
'一辰':([('r134/yichen_c292_11.jpg',0,.1,1,.88),('r134/yichen_c292_22.jpg',0,.1,.82,.9)],'yichen'),
'人蝎子':([('r134/renxiezi_c364_12.jpg',0,.5,1,1),('r134/renxiezi_c364_14.jpg',0,.52,1,.96)],'renxiezi'),
'魂玉':([('r134/hunyu_c374_18.jpg',.03,.5,.97,.96),('r134/hunyu_c374_19.jpg',0,.4,1,.82)],'hunyu'),
}
for k,(refs,a) in J.items(): make('/var/tmp/w/new_'+k+'.jpg',refs,a,k)
