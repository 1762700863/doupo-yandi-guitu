# 处理 dev/art_src/*.png -> assets/sprites/<n>.png (像素精灵) + portraits/<n>_full.png (高清立绘 ~420px) + portraits/<n>.png (头像)
import numpy as np, glob, os, sys
from PIL import Image
from scipy import ndimage
R='/var/tmp/w/repo'
SRC=R+'/dev/art_src'; OUT=R+'/assets'
H={'xiaoyan':60,'xuner':58,'medusa':66,'yunyun':60,'xiaoyixian':58,'yaolao':64,'yandi':76,'hun_tiandi':72,'nalan':60,'e_wolf':44,'b_yunshan':64}
names=sys.argv[1:] or [os.path.basename(f)[:-4] for f in glob.glob(SRC+'/*.png')]
for n in names:
    a=np.array(Image.open(f'{SRC}/{n}.png').convert('RGB')).astype(int)
    r,g,b=a[...,0],a[...,1],a[...,2]
    bg=np.median(np.concatenate([a[:4].reshape(-1,3),a[-4:].reshape(-1,3),a[:,:4].reshape(-1,3),a[:,-4:].reshape(-1,3)]),axis=0)
    if bg[1]>bg[0]+60:   # green
        key=(g>100)&(g>r+45)&(g>b+45)
        soft=(g>r+20)&(g>b+20)
    else:                # magenta
        key=(r>130)&(b>130)&(g<r-60)&(g<b-60)
        soft=(r>g+30)&(b>g+30)&(abs(r-b)<70)
    mask=~key
    mask=ndimage.binary_opening(mask,iterations=1)
    lab,nl=ndimage.label(ndimage.binary_dilation(mask,iterations=25))
    sizes=ndimage.sum(mask,lab,range(1,nl+1))
    k=int(np.argmax(sizes))+1
    m=mask&(lab==k)
    # 保留与主体相连的所有小碎片（火焰/丝带）：dilation 25 已合并
    ys,xs=np.where(m)
    y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    sub=a[y0:y1,x0:x1].copy(); mm=m[y0:y1,x0:x1]
    # 去溢色：边缘2px内
    edge=mm & ~ndimage.binary_erosion(mm,iterations=2)
    s=soft[y0:y1,x0:x1]&edge
    if bg[1]>bg[0]+60:
        sub[...,1]=np.where(s,np.minimum(sub[...,1],np.maximum(sub[...,0],sub[...,2])),sub[...,1])
    else:
        mx=np.minimum(sub[...,0],sub[...,2]); 
        sub[...,0]=np.where(s,np.minimum(sub[...,0],sub[...,1]+30),sub[...,0]); sub[...,2]=np.where(s,np.minimum(sub[...,2],sub[...,1]+30),sub[...,2])
    rgba=np.zeros(sub.shape[:2]+(4,),np.uint8); rgba[...,:3]=np.clip(sub,0,255); rgba[...,3]=mm*255
    im=Image.fromarray(rgba,'RGBA')
    # 高清立绘：高 420，LANCZOS（清晰），加 2px 余量
    ph=420; pw=round(im.width*ph/im.height)
    full=im.resize((pw,ph),Image.LANCZOS)
    fa=np.array(full); fa[...,3]=np.where(fa[...,3]>100,255,0); full=Image.fromarray(fa)
    pad=Image.new('RGBA',(pw+8,ph+8)); pad.paste(full,(4,4)); pad.save(f'{OUT}/portraits/{n}_full.png')
    # 精灵
    th=H.get(n,60); w=max(1,round(im.width*th/im.height))
    sm=im.resize((w,th),Image.BOX); s2=np.array(sm); s2[...,3]=np.where(s2[...,3]>110,255,0)
    al=s2[...,3]>0; ring=ndimage.binary_dilation(al)&~al; s2[ring]=[20,12,18,255]
    Image.fromarray(s2,'RGBA').save(f'{OUT}/sprites/{n}.png')
    # 头像：取头部区域（上 30%，按主体宽度中心裁正方形）
    hh=int(im.height*0.30); cx=int(np.mean(np.where(mm[:hh])[1])) if mm[:hh].any() else im.width//2
    side=hh; left=max(0,min(im.width-side,cx-side//2))
    p=im.crop((left,0,left+side,side)).resize((128,128),Image.LANCZOS)
    q=np.array(p); q[...,3]=np.where(q[...,3]>100,255,0); Image.fromarray(q).save(f'{OUT}/portraits/{n}.png')
    print(n,im.size,'-> spr',(w,th),'full',pad.size)
