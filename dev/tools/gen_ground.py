# 生成无缝地面纹理：每个地形 4 种 256×256 变体（周期噪声 → 天然无缝），像素风量化 + 有序抖动
# 输出 assets/tiles/<biome>.png（1024×256）
import numpy as np
from PIL import Image
S = 256
rng = np.random.default_rng(7)
B4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47
BAYER = np.tile(B4, (S // 4, S // 4))

def pnoise(scale, seed):
    """周期噪声：对白噪声做频域低通（天然可平铺）"""
    r = np.random.default_rng(seed)
    w = r.standard_normal((S, S))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(S)[:, None]; kx = np.fft.fftfreq(S)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    filt = np.exp(-(k * scale) ** 2)
    n = np.real(np.fft.ifft2(f * filt))
    n -= n.min(); n /= n.max() + 1e-9
    return n

def fbm(seed, base=40.0):
    return (pnoise(base, seed) * 0.55 + pnoise(base / 2.5, seed + 1) * 0.3 + pnoise(base / 7, seed + 2) * 0.15)

def quant(v, pal, dither=0.9):
    """v∈[0,1] → 调色板索引（抖动）"""
    n = len(pal)
    idx = np.clip(np.floor(v * n + BAYER * dither), 0, n - 1).astype(int)
    return np.array(pal, dtype=np.float32)[idx]

def put(img, x, y, col, a=1.0):
    x %= S; y %= S
    img[y, x] = img[y, x] * (1 - a) + np.array(col, np.float32) * a

def blades(img, n, cols, seed, hmin=2, hmax=4):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.integers(0, S, 2); h = r.integers(hmin, hmax + 1); c = cols[r.integers(len(cols))]
        lean = r.choice([-1, 0, 0, 1])
        for k in range(h):
            put(img, x + (lean if k == h - 1 else 0), y - k, c, 0.85)

def speckle(img, n, cols, seed, size=1):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.integers(0, S, 2); c = cols[r.integers(len(cols))]
        for dx in range(size):
            for dy in range(size):
                put(img, x + dx, y + dy, c, 0.9)

def flowers(img, n, seed, petals):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.integers(0, S, 2); c = petals[r.integers(len(petals))]
        for dx, dy in [(0, -1), (-1, 0), (1, 0), (0, 1)]:
            put(img, x + dx, y + dy, c)
        put(img, x, y, (250, 230, 120))

def pebbles(img, n, seed, base, hi, sh):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.integers(0, S, 2); w = r.integers(2, 5); h = r.integers(2, 4)
        for dx in range(w):
            for dy in range(h):
                put(img, x + dx, y + dy, base)
        for dx in range(w): put(img, x + dx, y + h, sh, 0.7)
        put(img, x, y, hi)

def grass(seed, pal, blade_cols, variant, flower_cols):
    n = fbm(seed, 34)
    img = quant(n * 0.85 + 0.08, pal)
    blades(img, 900, blade_cols, seed + 10)
    if variant == 1:     # 深色草丛
        m = fbm(seed + 50, 22)
        img = np.where((m > 0.62)[..., None], quant(np.clip(n * 0.6, 0, 1), pal[:3]), img)
        blades(img, 700, blade_cols[:2], seed + 11, 3, 5)
    if variant == 2:     # 野花
        flowers(img, 26, seed + 12, flower_cols)
    if variant == 3:     # 泥土斑块
        m = fbm(seed + 60, 26)
        dirt = quant(np.clip(fbm(seed + 61, 12), 0, 1), [(96, 78, 52), (112, 92, 60), (128, 106, 70), (140, 118, 80)])
        mask = m > 0.63
        img = np.where(mask[..., None], dirt, img)
        pebbles(img, 18, seed + 13, (150, 140, 125), (190, 182, 168), (70, 60, 45))
    return img

def sand(seed, variant):
    pal = [(176, 136, 80), (192, 152, 92), (206, 166, 104), (218, 180, 118), (228, 194, 134)]
    n = fbm(seed, 40)
    yy, xx = np.mgrid[0:S, 0:S]
    warp = pnoise(30, seed + 3) * 6
    rip = 0.5 + 0.5 * np.sin((xx * 2 + yy * 5) * 2 * np.pi / S * 4 + warp)  # 周期整数频率 → 无缝
    v = n * 0.7 + rip * (0.22 if variant != 2 else 0.35)
    img = quant(np.clip(v, 0, 1), pal)
    speckle(img, 500, [(160, 120, 72), (236, 206, 150)], seed + 5)
    if variant == 1:
        pebbles(img, 30, seed + 6, (150, 118, 84), (196, 160, 118), (110, 80, 50))
    if variant == 3:
        m = fbm(seed + 70, 24) > 0.64
        img = np.where(m[..., None], quant(np.clip(n, 0, 1), [(184, 144, 86), (196, 156, 96), (208, 168, 106)]), img)
    return img

def rock(seed, pal, variant, crack=None):
    n = fbm(seed, 30)
    img = quant(n * 0.9 + 0.05, pal)
    speckle(img, 600, [tuple(np.array(pal[0]) * 0.8), tuple(np.minimum(255, np.array(pal[-1]) * 1.1))], seed + 3)
    if crack is not None and variant in (2, 3):
        r = np.random.default_rng(seed + 9)
        for _ in range(3 if variant == 2 else 5):
            x, y = r.integers(0, S, 2).astype(float); a = r.uniform(0, 6.28)
            for k in range(r.integers(30, 70)):
                a += r.uniform(-0.5, 0.5); x += np.cos(a); y += np.sin(a)
                put(img, int(x), int(y), crack[0]); put(img, int(x) + 1, int(y), crack[1], 0.5)
                if r.random() < 0.08:
                    put(img, int(x), int(y) - 1, crack[1], 0.4)
    if variant == 1:
        pebbles(img, 24, seed + 4, tuple(np.array(pal[2])), tuple(np.array(pal[-1])), tuple(np.array(pal[0]) * 0.7))
    return img

def flags(seed, pal, grout, variant):
    """石板：64 网格，每块明暗不同，带倒角"""
    img = quant(fbm(seed, 18) * 0.8 + 0.1, pal)
    r = np.random.default_rng(seed)
    for by in range(0, S, 64):
        for bx in range(0, S, 64):
            off = 32 if (by // 64) % 2 else 0
            tone = r.uniform(0.92, 1.06)
            for y in range(by, by + 64):
                for x in range(bx + off, bx + off + 64):
                    img[y % S, x % S] *= tone
            for k in range(64):
                put(img, bx + off + k, by, grout); put(img, bx + off, by + k, grout)
                put(img, bx + off + k, by + 1, tuple(np.minimum(255, np.array(pal[-1]) * 1.08)), 0.6)
                put(img, bx + off + 1, by + k, tuple(np.minimum(255, np.array(pal[-1]) * 1.05)), 0.5)
                put(img, bx + off + k, by + 63, tuple(np.array(pal[0]) * 0.85), 0.5)
    if variant >= 2:   # 裂纹与苔藓
        rock_cr = np.random.default_rng(seed + 5)
        for _ in range(4):
            x, y = rock_cr.integers(0, S, 2).astype(float); a = rock_cr.uniform(0, 6.28)
            for k in range(rock_cr.integers(10, 26)):
                a += rock_cr.uniform(-0.6, 0.6); x += np.cos(a); y += np.sin(a)
                put(img, int(x), int(y), grout, 0.8)
        if variant == 3:
            speckle(img, 120, [(96, 120, 80), (110, 138, 90)], seed + 6)
    return img

G_FOREST = [(34, 72, 38), (40, 84, 42), (48, 98, 48), (58, 112, 54), (70, 126, 60)]
G_TOWN = [(78, 124, 52), (92, 142, 58), (106, 158, 64), (120, 172, 72), (136, 186, 82)]
biomes = {
    "forest": lambda v: grass(100 + v * 17, G_FOREST, [(28, 62, 32), (78, 136, 66), (90, 150, 72)], v, [(230, 230, 240), (200, 160, 230)]),
    "wutan": lambda v: grass(200 + v * 17, G_TOWN, [(70, 112, 46), (146, 196, 90), (160, 206, 100)], v, [(250, 250, 250), (250, 200, 80), (240, 120, 140)]),
    "desert": lambda v: sand(300 + v * 17, v),
    "lava": lambda v: rock(400 + v * 17, [(40, 30, 30), (52, 38, 36), (64, 46, 42), (78, 56, 50), (92, 66, 58)], v, crack=((255, 110, 30), (255, 190, 80))),
    "void": lambda v: rock(500 + v * 17, [(28, 22, 42), (38, 30, 56), (48, 38, 70), (60, 48, 86), (74, 60, 104)], v, crack=((170, 110, 255), (220, 180, 255))),
    "yunlan": lambda v: flags(600 + v * 17, [(150, 156, 168), (164, 170, 182), (178, 184, 196), (192, 198, 208), (206, 212, 220)], (112, 116, 128), v),
    "hub": lambda v: flags(700 + v * 17, [(120, 110, 96), (134, 124, 108), (148, 138, 120), (162, 152, 134), (176, 166, 148)], (86, 78, 66), v),
}
for name, fn in biomes.items():
    strip = np.zeros((S, S * 4, 3), np.float32)
    for v in range(4):
        strip[:, v * S:(v + 1) * S] = fn(v)
    Image.fromarray(np.clip(strip, 0, 255).astype(np.uint8)).save(f"assets/tiles/{name}.png")
    print(name)

# ---------------- 道路纹理（单张 256 无缝）
def dirt_road(seed, pal, pebble):
    n = fbm(seed, 26)
    img = quant(n * 0.85 + 0.08, pal)
    yy, xx = np.mgrid[0:S, 0:S]
    ruts = 0.5 + 0.5 * np.sin(xx * 2 * np.pi / S * 9 + pnoise(20, seed + 2) * 5)
    img *= (0.95 + 0.07 * ruts)[..., None]
    speckle(img, 700, [tuple(np.array(pal[0]) * 0.85), tuple(np.minimum(255, np.array(pal[-1]) * 1.08))], seed + 3)
    pebbles(img, 40, seed + 4, pebble[0], pebble[1], pebble[2])
    return img

def cobble(seed, pal, grout, cells=12, jit=0.32):
    """石块路：抖动网格 Voronoi（周期），石块大小均匀"""
    r = np.random.default_rng(seed)
    cs = S / cells
    pts = np.array([[(i + 0.5 + r.uniform(-jit, jit) + (0.5 if j % 2 else 0)) * cs % S, (j + 0.5 + r.uniform(-jit, jit)) * cs] for j in range(cells) for i in range(cells)])
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d1 = np.full((S, S), 1e9, np.float32); d2 = np.full((S, S), 1e9, np.float32); idx = np.zeros((S, S), int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px); dx = np.minimum(dx, S - dx)
        dy = np.abs(yy - py); dy = np.minimum(dy, S - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d)); idx = np.where(closer, i, idx); d1 = np.where(closer, d, d1)
    tone = r.uniform(0.3, 0.8, len(pts))[idx]
    edge = d2 - d1
    shade = np.clip(edge / 6.0, 0, 1)
    v = tone * 0.7 + fbm(seed + 1, 10) * 0.3
    v = v * (0.6 + 0.4 * shade) + np.where(yy % 1 == 0, 0, 0)
    img = quant(np.clip(v, 0, 1), pal, 0.6)
    img = np.where((edge < 1.6)[..., None], np.array(grout, np.float32), img)
    # 高光（石块上沿）
    hi = (edge > 1.6) & (edge < 3.0) & (np.roll(edge, 2, axis=0) < 1.6)
    img = np.where(hi[..., None], np.minimum(255, img * 1.15), img)
    return img

roads = {
    "road_dirt": lambda: dirt_road(900, [(104, 84, 58), (118, 96, 66), (132, 108, 74), (146, 120, 84), (160, 134, 94)], ((150, 140, 122), (188, 180, 164), (80, 66, 48))),
    "road_sand": lambda: dirt_road(910, [(160, 124, 78), (172, 136, 86), (184, 148, 96), (196, 160, 106), (208, 172, 118)], ((140, 110, 80), (190, 160, 120), (110, 82, 54))),
    "road_ash": lambda: dirt_road(920, [(58, 46, 44), (70, 56, 52), (82, 66, 60), (94, 76, 68), (106, 86, 76)], ((110, 90, 80), (140, 120, 108), (40, 30, 28))),
    "road_cobble": lambda: cobble(930, [(118, 110, 100), (134, 126, 114), (150, 142, 128), (166, 158, 144), (182, 174, 160)], (78, 72, 62)),
    "road_marble": lambda: cobble(940, [(176, 180, 190), (190, 194, 202), (202, 206, 214), (214, 218, 224), (226, 228, 234)], (130, 134, 146), 8, 0.18),
}
for name, fn in roads.items():
    Image.fromarray(np.clip(fn(), 0, 255).astype(np.uint8)).save(f"assets/tiles/{name}.png")
    print(name)
