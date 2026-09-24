# 处理地图物件：抠掉品红/绿色背景 → 裁切 → 缩放到目标高度 → assets/obj/<name>.png
# 用法: python3 dev/tools/proc_obj.py name:height [name:height ...]
import sys, numpy as np
from PIL import Image
from scipy import ndimage
for arg in sys.argv[1:]:
    name, h = arg.split(':'); h = int(h)
    im = Image.open(f'dev/art_src/{name}.png').convert('RGBA')
    a = np.array(im).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    corner = a[2, 2, :3]
    if corner[1] > corner[0] + 60:   # 绿幕
        key = (g > 150) & (g > r + 60) & (g > b + 60)
        soft = (g > r + 25) & (g > b + 25)
    else:                            # 品红
        key = (r > 150) & (b > 150) & (g < r - 70) & (g < b - 70)
        soft = (r > g + 40) & (b > g + 40) & (np.abs(r - b) < 90)
    alpha = np.where(key, 0, 255)
    # 边缘去品红溢色
    edge = soft & ~key
    a[..., 1] = np.where(edge, np.maximum(g, (r + b) // 2 - 30), g)
    a[..., 0] = np.where(edge, np.minimum(r, g + 40), r)
    a[..., 2] = np.where(edge, np.minimum(b, g + 40), b)
    alpha = np.where(edge, 140, alpha)
    # 只保留最大连通块及其附近（去掉杂散/多个副本）
    lab, n = ndimage.label(alpha > 0)
    if n > 1:
        sizes = ndimage.sum(alpha > 0, lab, range(1, n + 1))
        big = np.argmax(sizes) + 1
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.04])
        alpha = np.where(keep, alpha, 0)
    a[..., 3] = alpha
    out = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    out = out.crop(out.getbbox())
    w = round(out.width * h / out.height)
    out = out.resize((w, h), Image.LANCZOS)
    # 清理半透明噪点
    arr = np.array(out); arr[..., 3] = np.where(arr[..., 3] < 60, 0, np.where(arr[..., 3] > 200, 255, arr[..., 3])); out = Image.fromarray(arr)
    out.save(f'assets/obj/{name}.png')
    print(name, out.size)
