"""单图抠图：纯色底 → 透明 PNG（保留所有主体部件），输出到 outdir/<同名>.png
用法: python3 key_one.py <outdir> img1.png img2.png ..."""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
for src in sys.argv[2:]:
    a = np.array(Image.open(src).convert('RGB')).astype(np.float32)
    bd = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]); bg = np.median(bd, 0)
    green = bg[1] > bg[0] + 80
    d = np.sqrt(((a - bg) ** 2).sum(-1)); alpha = np.clip((d - 38) / 55.0, 0, 1)
    mask = ndimage.binary_opening(alpha > 0.5, iterations=1)
    lab, nl = ndimage.label(ndimage.binary_dilation(mask, iterations=20))
    sizes = ndimage.sum(mask, lab, range(1, nl + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.01])
    m = mask & keep; ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    sub = a[y0:y1, x0:x1].copy(); al = alpha[y0:y1, x0:x1] * keep[y0:y1, x0:x1]; mm = m[y0:y1, x0:x1]
    part = (al > 0.02) & (al < 0.999)
    un = (sub - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.02)
    sub = np.where(part[..., None], np.clip(un, 0, 255), sub)
    edge = mm & ~ndimage.binary_erosion(mm, iterations=3)
    if green:
        sub[..., 1] = np.where(edge | part, np.minimum(sub[..., 1], np.maximum(sub[..., 0], sub[..., 2]) + 10), sub[..., 1])
    else:
        sp = edge & (sub[..., 0] > sub[..., 1] + 25) & (sub[..., 2] > sub[..., 1] + 25) & (np.abs(sub[..., 0] - sub[..., 2]) < 70)
        g = sub[..., 1]
        sub[..., 0] = np.where(sp, np.minimum(sub[..., 0], g + 12), sub[..., 0]); sub[..., 2] = np.where(sp, np.minimum(sub[..., 2], g + 12), sub[..., 2])
    rgba = np.dstack([np.clip(sub, 0, 255), al * 255]).astype(np.uint8)
    rgba[..., 3] = np.where(rgba[..., 3] < 16, 0, rgba[..., 3])
    pad = 8; o = np.zeros((rgba.shape[0] + 2 * pad, rgba.shape[1] + 2 * pad, 4), np.uint8); o[pad:-pad, pad:-pad] = rgba
    Image.fromarray(o, 'RGBA').save(f'{out}/{os.path.basename(src)}'); print(os.path.basename(src), o.shape[1], 'x', o.shape[0])
