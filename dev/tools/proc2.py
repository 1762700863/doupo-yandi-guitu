# 处理 dev/art_src/<n>.png（纯色背景的全身立绘）→
#   assets/sprites/<n>.png        像素精灵（按 H 表高度，BOX 缩小 + 深色描边）
#   assets/portraits/<n>_full.png 高清立绘（高 420，柔和抗锯齿边缘）
#   assets/portraits/<n>.png      头像（头部 128×128）
# 抠图：按与背景色（边框中位数）的颜色距离 → 柔和 alpha；兼容品红/浅粉/绿幕；去背景混色；残留品红色相淡出
# AI 偶尔一张图画出多个副本：只保留最左边的主体
import numpy as np, glob, os, sys
from PIL import Image
from scipy import ndimage
R = '/var/tmp/w/repo'
SRC = R + '/dev/art_src'; OUT = R + '/assets'
H = {'xiaoyan': 60, 'xuner': 58, 'medusa': 66, 'yunyun': 60, 'xiaoyixian': 58, 'yaolao': 64, 'yandi': 70, 'hun_tiandi': 72,
     'nalan': 60, 'e_wolf': 44, 'b_yunshan': 64}
names = sys.argv[1:] or [os.path.basename(f)[:-4] for f in glob.glob(SRC + '/*.png') if not os.path.basename(f).startswith('poi_')]
for n in names:
    a = np.array(Image.open(f'{SRC}/{n}.png').convert('RGB')).astype(float)
    bg = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)]), axis=0)
    green = bg[1] > bg[0] + 60
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    alpha = np.clip((d - 38) / 55.0, 0, 1)
    mask = ndimage.binary_opening(alpha > 0.5, iterations=1)
    # 多副本检测：按空白列把画面分段，若有 ≥2 段面积相近 → 只保留最左段（附带其左右 60px 内的小碎片）
    col = mask.sum(0) > 2
    segs = []; x = 0; W = mask.shape[1]
    while x < W:
        if col[x]:
            x2 = x
            while x2 < W and col[x2]: x2 += 1
            segs.append([x, x2, int(mask[:, x:x2].sum())]); x = x2
        else:
            x += 1
    bigs = [sg for sg in segs if sg[2] > max(sg2[2] for sg2 in segs) * 0.45]
    if len(bigs) >= 2:
        L, Rr = bigs[0][0], bigs[0][1]
        lim = bigs[1][0]
        for sg in segs:
            if sg[2] < bigs[0][2] * 0.2 and sg[0] < lim and sg[0] - Rr < 60 and sg[1] <= lim:
                L = min(L, sg[0]); Rr = max(Rr, sg[1])
        cut = np.zeros_like(mask); cut[:, L:Rr] = True
        mask = mask & cut; alpha = alpha * cut
    lab, nl = ndimage.label(ndimage.binary_dilation(mask, iterations=25))
    sizes = ndimage.sum(mask, lab, range(1, nl + 1))
    big = [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.5]
    if len(big) > 1:   # 多个副本：取最左
        big.sort(key=lambda k: np.where(lab == k)[1].min())
    k = big[0]
    keep = lab == k
    m = mask & keep
    ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[y0:y1, x0:x1].copy(); mm = m[y0:y1, x0:x1]
    al = alpha[y0:y1, x0:x1] * keep[y0:y1, x0:x1]
    part = (al > 0.02) & (al < 0.999)
    un = (sub - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.02)
    sub = np.where(part[..., None], np.clip(un, 0, 255), sub)
    edge = mm & ~ndimage.binary_erosion(mm, iterations=2)
    if green:
        sub[..., 1] = np.where(edge, np.minimum(sub[..., 1], np.maximum(sub[..., 0], sub[..., 2]) + 10), sub[..., 1])
    else:
        spill = edge & (sub[..., 0] > sub[..., 1] + 40) & (sub[..., 2] > sub[..., 1] + 40) & (np.abs(sub[..., 0] - sub[..., 2]) < 60)
        sub[..., 0] = np.where(spill, np.minimum(sub[..., 0], sub[..., 1] + 40), sub[..., 0])
        sub[..., 2] = np.where(spill, np.minimum(sub[..., 2], sub[..., 1] + 40), sub[..., 2])
        mn = np.minimum(sub[..., 0], sub[..., 2])
        mag = np.clip((mn - sub[..., 1] - 70) / 60.0, 0, 1) * (np.abs(sub[..., 0] - sub[..., 2]) < 90)
        al = al * (1 - mag)
    if n in ('yunyun', 'yaolao'):   # 半透明风环/魂光被品红底污染 → 还原为冷白色
        R, G, B = sub[..., 0], sub[..., 1], sub[..., 2]
        hz = (R > G + 12) & (B > G + 12) & (R >= B * 0.75) & (B >= R * 0.6)
        if n == 'yaolao':
            solid = ndimage.binary_erosion(al > 0.5, iterations=14)
            hz = hz & ~solid
        L = (R * 0.3 + G * 0.5 + B * 0.2)
        L = np.clip(L * 1.05 + 20, 0, 255)
        sub[..., 0] = np.where(hz, L * 0.90, R); sub[..., 1] = np.where(hz, L * 0.96, G); sub[..., 2] = np.where(hz, np.minimum(255, L * 1.02 + 6), B)
    if n == 'xuner':   # 金帝焚天炎：粉色火焰校正回金色
        pink = (sub[..., 0] > 190) & (sub[..., 2] > sub[..., 1] + 15) & (sub[..., 0] > sub[..., 2] + 10)
        sub[..., 2] = np.where(pink, sub[..., 1] * 0.45, sub[..., 2])
        sub[..., 1] = np.where(pink, np.minimum(255, sub[..., 1] * 1.08 + 18), sub[..., 1])
    rgba = np.zeros(sub.shape[:2] + (4,), np.uint8)
    rgba[..., :3] = np.clip(sub, 0, 255); rgba[..., 3] = np.clip(al * 255, 0, 255)
    # 重新裁掉被淡出的空边
    ys2, xs2 = np.where(rgba[..., 3] > 40)
    rgba = rgba[ys2.min():ys2.max() + 1, xs2.min():xs2.max() + 1]
    im = Image.fromarray(rgba, 'RGBA')
    # 高清立绘
    ph = 420; pw = round(im.width * ph / im.height)
    full = im.resize((pw, ph), Image.LANCZOS)
    fa = np.array(full); fa[..., 3] = np.where(fa[..., 3] < 20, 0, fa[..., 3]); full = Image.fromarray(fa)
    pad = Image.new('RGBA', (pw + 8, ph + 8)); pad.paste(full, (4, 4)); pad.save(f'{OUT}/portraits/{n}_full.png')
    # 精灵
    base = n.split('_alt')[0]
    th = H.get(base, 60); w = max(1, round(im.width * th / im.height))
    sm = im.resize((w, th), Image.BOX); s2 = np.array(sm); s2[..., 3] = np.where(s2[..., 3] > 110, 255, 0)
    alm = s2[..., 3] > 0; ring = ndimage.binary_dilation(alm) & ~alm; s2[ring] = [20, 12, 18, 255]
    Image.fromarray(s2, 'RGBA').save(f'{OUT}/sprites/{n}.png')
    # 头像：头部区域（上 28%，按不透明像素中心裁正方形）
    A = np.array(im)[..., 3] > 100
    hh = int(im.height * 0.28); cx = int(np.mean(np.where(A[:hh])[1])) if A[:hh].any() else im.width // 2
    side = hh; left = max(0, min(im.width - side, cx - side // 2))
    p = im.crop((left, 0, left + side, side)).resize((128, 128), Image.LANCZOS)
    q = np.array(p); q[..., 3] = np.where(q[..., 3] < 20, 0, q[..., 3]); Image.fromarray(q).save(f'{OUT}/portraits/{n}.png')
    print(n, im.size, '-> spr', (w, th), 'full', pad.size)
