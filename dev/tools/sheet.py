"""参考图接触表。用法: python3 sheet.py <out.jpg> <refs_dir> <slug前缀...>"""
import sys, glob, os
from PIL import Image, ImageDraw
out, d = sys.argv[1], sys.argv[2]
pre = sys.argv[3:]
fs = [f for p in pre for f in sorted(glob.glob(f'{d}/{p}_*.jpg'))]
cols, W, H = 6, 270, 290
rows = (len(fs) + cols - 1) // cols
S = Image.new('RGB', (cols * W, max(1, rows) * H), 'white')
dr = ImageDraw.Draw(S)
for i, f in enumerate(fs):
    im = Image.open(f); im.thumbnail((260, 260))
    x, y = (i % cols) * W, (i // cols) * H
    S.paste(im, (x + 5, y + 22)); dr.text((x + 5, y + 4), os.path.basename(f)[:34], fill='black')
S.save(out, quality=85); print(len(fs))
