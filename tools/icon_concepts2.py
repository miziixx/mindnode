#!/usr/bin/env python3
"""앱 아이콘 시안 2차(완전히 다른 방향). assets/launcher_icons/concepts/*.png"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "concepts")
os.makedirs(OUT, exist_ok=True)
SS = 4
ACCENT = (120, 150, 185)
VIOLET = (150, 120, 175)
TEAL = (110, 170, 165)
CREAM = (228, 226, 216)


def lin_grad(S, c0, c1, angle=0.0):
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64) / S
    t = xx * math.cos(angle) + yy * math.sin(angle)
    t = (t - t.min()) / (t.max() - t.min())
    return np.array(c0)[None, None] * (1 - t)[:, :, None] + np.array(c1)[None, None] * t[:, :, None]


def base_img(S, c0, c1, ang=math.pi / 3):
    return Image.fromarray(np.clip(lin_grad(S, c0, c1, ang), 0, 255).astype(np.uint8)).convert("RGBA")


def glow_compose(base, layer, r, times=1):
    g = layer.filter(ImageFilter.GaussianBlur(r))
    for _ in range(times):
        base.alpha_composite(g)
    base.alpha_composite(layer)


def E5_radial_eq(size):
    S = size * SS
    base = base_img(S, (20, 20, 40), (10, 11, 18))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    n = 40
    inner = S * 0.13
    for i in range(n):
        ang = i / n * 2 * math.pi
        h = 0.5 + 0.5 * math.sin(i / n * 2 * math.pi * 3)  # 물결
        outer = inner + S * (0.06 + 0.16 * h)
        f = i / n
        col = (int(ACCENT[0] * (1 - f) + VIOLET[0] * f),
               int(ACCENT[1] * (1 - f) + VIOLET[1] * f),
               int(ACCENT[2] * (1 - f) + VIOLET[2] * f))
        x0 = cx + inner * math.cos(ang); y0 = cy + inner * math.sin(ang)
        x1 = cx + outer * math.cos(ang); y1 = cy + outer * math.sin(ang)
        dr.line([(x0, y0), (x1, y1)], fill=col + (255,), width=int(S * 0.016))
    glow_compose(base, layer, S * 0.02)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def E6_lotus(size):
    S = size * SS
    base = base_img(S, (34, 28, 58), (12, 12, 22))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx, cy = S / 2, S * 0.56
    petals = 5
    for i in range(petals):
        ang = -math.pi / 2 + (i - (petals - 1) / 2) * 0.5
        pl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        pd = ImageDraw.Draw(pl)
        pw, ph = S * 0.11, S * 0.32
        pd.ellipse([cx - pw, cy - ph, cx + pw, cy + ph],
                   fill=(ACCENT[0], ACCENT[1], ACCENT[2], 220))
        pl = pl.rotate(math.degrees(ang) + 90, center=(cx, cy), resample=Image.BICUBIC)
        layer.alpha_composite(pl)
    # 중심 작은 광
    dr.ellipse([cx - S * 0.04, cy - S * 0.04, cx + S * 0.04, cy + S * 0.04],
               fill=CREAM + (255,))
    glow_compose(base, layer, S * 0.02)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def E7_aurora(size):
    S = size * SS
    bg = lin_grad(S, (14, 14, 24), (9, 10, 16), math.pi / 2)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    def blob(cxr, cyr, rr, col, op):
        d = np.sqrt((xx - S * cxr) ** 2 + (yy - S * cyr) ** 2) / (S * rr)
        a = np.clip(1 - d, 0, 1) ** 2 * op
        for k in range(3):
            bg[:, :, k] = bg[:, :, k] * (1 - a) + col[k] * a
    blob(0.35, 0.35, 0.42, VIOLET, 0.55)
    blob(0.68, 0.45, 0.40, ACCENT, 0.5)
    blob(0.5, 0.72, 0.38, TEAL, 0.4)
    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGB")
    return img.filter(ImageFilter.GaussianBlur(SS * 1.2)).resize((size, size), Image.LANCZOS)


def E8_fork(size):
    S = size * SS
    base = base_img(S, (18, 22, 32), (10, 12, 18), math.pi / 2)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = S / 2
    lw = int(S * 0.05)
    top = S * 0.24; midjoin = S * 0.52; bot = S * 0.80
    dx = S * 0.12
    col = ACCENT + (255,)
    dr.line([(cx - dx, top), (cx - dx, midjoin)], fill=col, width=lw)
    dr.line([(cx + dx, top), (cx + dx, midjoin)], fill=col, width=lw)
    dr.arc([cx - dx, midjoin - dx, cx + dx, midjoin + dx], 0, 180, fill=col, width=lw)
    dr.line([(cx, midjoin + dx - lw / 2), (cx, bot)], fill=col, width=lw)
    for (x, y) in [(cx - dx, top), (cx + dx, top)]:
        dr.ellipse([x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2], fill=col)
    glow_compose(base, layer, S * 0.022, times=2)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def E9_ripple(size):
    S = size * SS
    base = base_img(S, (16, 18, 30), (9, 10, 16), math.pi / 2.5)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx, cy = S / 2, S / 2
    for i, rr in enumerate([0.12, 0.22, 0.32, 0.42]):
        r = S * rr
        alpha = int(255 * (1 - i * 0.22))
        f = i / 4
        col = (int(ACCENT[0] * (1 - f) + VIOLET[0] * f),
               int(ACCENT[1] * (1 - f) + VIOLET[1] * f),
               int(ACCENT[2] * (1 - f) + VIOLET[2] * f))
        dr.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col + (alpha,),
                   width=int(S * 0.016))
    dr.ellipse([cx - S * 0.045, cy - S * 0.045, cx + S * 0.045, cy + S * 0.045],
               fill=CREAM + (255,))
    glow_compose(base, layer, S * 0.025, times=2)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def main():
    for name, fn in [("5_radial", E5_radial_eq), ("6_lotus", E6_lotus),
                     ("7_aurora", E7_aurora), ("8_fork", E8_fork),
                     ("9_ripple", E9_ripple)]:
        fn(512).save(os.path.join(OUT, f"concept_{name}.png"))
    print("done:", [f for f in sorted(os.listdir(OUT)) if f.startswith("concept_") and any(c in f for c in "56789")])


if __name__ == "__main__":
    main()
