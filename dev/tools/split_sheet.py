"""图集切分：纯色底上多个独立物件 → 各自抠图输出透明 PNG（按从左到右顺序命名）
用法: python3 split_sheet.py <sheet.png> <outdir> name1 name2 ..."""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
src, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(out, exist_ok=True)
a = np.array(Image.open(src).convert('RGB')).astype(np.float32)
bd = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]); bg = np.median(bd, 0)
d = np.sqrt(((a - bg) ** 2).sum(-1))
alpha = np.clip((d - 38) / 55.0, 0, 1)
green = bg[1] > bg[0] + 80
mask = ndimage.binary_opening(alpha > 0.5, iterations=1)
lab, nl = ndimage.label(ndimage.binary_dilation(mask, iterations=12))
sizes = ndimage.sum(mask, lab, range(1, nl + 1))
keep = [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.05]
keep.sort(key=lambda k: np.where(lab == k)[1].min())
print('found', len(keep), 'objects')
for n, k in zip(names, keep):
    reg = lab == k
    ys, xs = np.where(reg & mask); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[y0:y1, x0:x1].copy(); al = alpha[y0:y1, x0:x1] * reg[y0:y1, x0:x1]
    part = (al > 0.02) & (al < 0.999)
    un = (sub - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.02)
    sub = np.where(part[..., None], np.clip(un, 0, 255), sub)
    if green:
        sub[..., 1] = np.where(part, np.minimum(sub[..., 1], np.maximum(sub[..., 0], sub[..., 2]) + 10), sub[..., 1])
    else:
        mm = (reg & mask)[y0:y1, x0:x1]; edge = mm & ~ndimage.binary_erosion(mm, iterations=3)
        sp = edge & (sub[..., 0] > sub[..., 1] + 25) & (sub[..., 2] > sub[..., 1] + 25) & (np.abs(sub[..., 0] - sub[..., 2]) < 70)
        g = sub[..., 1]; sub[..., 0] = np.where(sp, np.minimum(sub[..., 0], g + 12), sub[..., 0]); sub[..., 2] = np.where(sp, np.minimum(sub[..., 2], g + 12), sub[..., 2])
        mn = np.minimum(sub[..., 0], sub[..., 2]); mag = np.clip((mn - sub[..., 1] - 70) / 60.0, 0, 1) * (np.abs(sub[..., 0] - sub[..., 2]) < 90)
        al = al * (1 - mag * part)
    rgba = np.dstack([np.clip(sub, 0, 255), al * 255]).astype(np.uint8)
    rgba[..., 3] = np.where(rgba[..., 3] < 16, 0, rgba[..., 3])
    Image.fromarray(rgba, 'RGBA').save(f'{out}/{n}.png'); print(n, rgba.shape[1], 'x', rgba.shape[0])
