import numpy as np, glob, os
from PIL import Image
from scipy import ndimage
OUT='/home/user/game/assets'
H={'xiaoyan':60,'xuner':58,'medusa':66,'yunyun':60,'xiaoyixian':58,'yaolao':64,'yandi':72,'hun_tiandi':80,'nalan':58,'e_wolf':44}
for f in glob.glob('/home/user/art_src/*.png'):
    n=os.path.basename(f)[:-4]
    a=np.array(Image.open(f).convert('RGB')).astype(int)
    bg=a[5,5]
    r,g,b=a[...,0],a[...,1],a[...,2]
    if bg[1]>200 and bg[0]<100: # green
        key=(g>150)&(g>r+60)&(g>b+60)
    else:
        key=(r>150)&(b>150)&(g<120)&(abs(r-b)<90)
    mask=~key
    mask=ndimage.binary_opening(mask,iterations=1)
    lab,nl=ndimage.label(ndimage.binary_dilation(mask,iterations=12))
    sizes=ndimage.sum(mask,lab,range(1,nl+1))
    # choose largest component; for multi-copy images this picks one
    k=int(np.argmax(sizes))+1
    m=mask&(lab==k)
    ys,xs=np.where(m)
    y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    rgba=np.zeros((y1-y0,x1-x0,4),np.uint8)
    rgba[...,:3]=a[y0:y1,x0:x1]
    rgba[...,3]=m[y0:y1,x0:x1]*255
    # despill
    sub=rgba[...,:3].astype(int)
    if bg[1]>200 and bg[0]<100: sub[...,1]=np.minimum(sub[...,1],np.maximum(sub[...,0],sub[...,2])+40)
    else:
        mx=np.maximum(sub[...,0],sub[...,2]); 
        spill=(sub[...,0]>sub[...,1]+80)&(sub[...,2]>sub[...,1]+80)&(abs(sub[...,0]-sub[...,2])<40)
        sub[spill]=sub[spill]//2
    rgba[...,:3]=np.clip(sub,0,255)
    im=Image.fromarray(rgba,'RGBA')
    im.save(f'{OUT}/portraits/{n}_hi.png')
    th=H.get(n,60); w=max(1,round(im.width*th/im.height))
    # downsample: box then alpha threshold -> crisp pixels
    sm=im.resize((w,th),Image.BOX)
    s=np.array(sm); s[...,3]=np.where(s[...,3]>110,255,0)
    # outline 1px dark
    al=s[...,3]>0
    ring=ndimage.binary_dilation(al)&~al
    s[ring]=[20,12,18,255]
    Image.fromarray(s,'RGBA').save(f'{OUT}/sprites/{n}.png')
    # portrait: top 45% of hi image, pixelated to 96 wide
    ph=int(im.height*0.42); p=im.crop((0,0,im.width,ph))
    pw=96; p=p.resize((pw,max(1,round(ph*pw/im.width))),Image.BOX)
    q=np.array(p); q[...,3]=np.where(q[...,3]>110,255,0); Image.fromarray(q).save(f'{OUT}/portraits/{n}.png')
    print(n,im.size,'->',(w,th))
