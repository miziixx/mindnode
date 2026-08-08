#!/usr/bin/env python3
"""아이콘 시안 — '빛나는 파형'을 더 부드럽게 한 변형들.
assets/launcher_icons/wave/*.png (512) + _compare.png
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "wave")
os.makedirs(OUT, exist_ok=True)

SS = 3
STOPS = [(120, 182, 192), (112, 152, 200), (150, 122, 195),
         (186, 124, 178), (120, 182, 192)]
PASTEL = (206, 200, 226)   # 부드럽게 섞을 파스텔 라벤더
WHITE = (245, 244, 240)


def irid(u, soft=0.32):
    u = u % 1.0
    seg = u * (len(STOPS) - 1)
    i = int(seg); f = seg - i
    a = STOPS[i]; b = STOPS[min(i + 1, len(STOPS) - 1)]
    col = [a[k] * (1 - f) + b[k] * f for k in range(3)]
    col = [col[k] * (1 - soft) + PASTEL[k] * soft for k in range(3)]  # 채도 완화
    return tuple(int(round(c)) for c in col)


def dark(S, top=(20, 20, 34), bot=(10, 11, 17)):
    t = np.clip(np.arange(S)[:, None] / S, 0, 1)
    bg = np.array(top)[None, None] * (1 - t)[:, :, None] + \
        np.array(bot)[None, None] * t[:, :, None]
    return np.tile(bg, (1, S, 1)).astype(np.float64)


def base_img(S, **kw):
    return Image.fromarray(np.clip(dark(S, **kw), 0, 255).astype(np.uint8),
                           "RGB").convert("RGBA")


def bloom(base, layer, r, times=3):
    g = layer.filter(ImageFilter.GaussianBlur(r))
    for _ in range(times):
        base.alpha_composite(g)
    base.alpha_composite(layer)


def fin(img, size):
    return img.convert("RGB").resize((size, size), Image.LANCZOS)


# ── V1: 부드러운 방추형 파형(둥근 3로브) ──
def V1_spindle(size):
    S = size * SS
    base = base_img(S)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    seg = 240
    pts_top = []; pts_bot = []
    for i in range(seg + 1):
        u = i / seg
        x = u * S * 0.82 + S * 0.09
        env = math.sin(u * math.pi) ** 0.7
        # 부드러운 3로브(0에 닿지 않게 바닥 0.45 유지)
        osc = 0.45 + 0.55 * (0.5 + 0.5 * math.cos(u * math.pi * 2 * 3))
        amp = S * 0.24 * env * osc
        pts_top.append((x, cy - amp)); pts_bot.append((x, cy + amp))
    for i in range(seg):
        u = i / seg
        col = irid(0.12 + u * 0.72)
        dr.polygon([pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]],
                   fill=col + (235,))
    # 둥근 끝 캡
    for p in (pts_top[0], pts_top[-1]):
        dr.ellipse([p[0] - 2, cy - 2, p[0] + 2, cy + 2], fill=irid(0.4) + (235,))
    bloom(base, layer, S * 0.03, times=3)
    return fin(base, size)


# ── V2: 흐르는 한 줄 파형(부드러운 리본) ──
def V2_line(size):
    S = size * SS
    base = base_img(S, top=(17, 18, 32))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    seg = 300
    th = S * 0.016  # 리본 반두께
    pts_top = []; pts_bot = []
    for i in range(seg + 1):
        u = i / seg
        x = u * S * 0.84 + S * 0.08
        env = math.sin(u * math.pi)
        y = cy - S * 0.16 * env * math.sin(u * math.pi * 2 * 2)
        pts_top.append((x, y - th)); pts_bot.append((x, y + th))
    for i in range(seg):
        u = i / seg
        col = irid(0.1 + u * 0.75)
        dr.polygon([pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]],
                   fill=col + (255,))
    # 둥근 끝
    for p in (0, -1):
        px, py = ((pts_top[p][0] + pts_bot[p][0]) / 2,
                  (pts_top[p][1] + pts_bot[p][1]) / 2)
        dr.ellipse([px - th, py - th, px + th, py + th], fill=irid(0.4) + (255,))
    bloom(base, layer, S * 0.024, times=3)
    return fin(base, size)


# ── V3: 겹치는 부드러운 물결(3겹) ──
def V3_layers(size):
    S = size * SS
    base = base_img(S, top=(18, 18, 33))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    waves = [(-0.075, 0.12, 1.5, 0.2), (0.0, 0.15, 2.0, 0.0), (0.075, 0.12, 1.5, 3.14)]
    seg = 260
    for wy, amp, k, ph in waves:
        pts_top = []; pts_bot = []
        for i in range(seg + 1):
            u = i / seg
            x = u * S * 0.84 + S * 0.08
            env = math.sin(u * math.pi) ** 0.8
            yy = cy + S * wy + S * amp * env * math.sin(u * math.pi * 2 * k + ph)
            th = S * 0.018
            pts_top.append((x, yy - th)); pts_bot.append((x, yy + th))
        for i in range(seg):
            u = i / seg
            col = irid(0.15 + u * 0.6 + (ph * 0.05))
            dr.polygon([pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]],
                       fill=col + (170,))
    bloom(base, layer, S * 0.03, times=3)
    return fin(base, size)


# ── V4: 부드러운 둥근 막대 파형(젠틀 이퀄라이저) ──
def V4_bars(size):
    S = size * SS
    base = base_img(S)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    n = 15
    span = S * 0.72
    x0 = cx - span / 2
    gap = span / n
    bw = gap * 0.5
    for i in range(n):
        u = (i + 0.5) / n
        env = math.sin(u * math.pi) ** 0.7
        h = S * 0.22 * (0.3 + 0.7 * env)
        x = x0 + gap * i + gap * 0.5
        col = irid(0.12 + u * 0.72)
        dr.rounded_rectangle([x - bw / 2, cy - h, x + bw / 2, cy + h],
                             radius=bw / 2, fill=col + (235,))
    bloom(base, layer, S * 0.026, times=3)
    return fin(base, size)


def main():
    items = [("V1_spindle", V1_spindle), ("V2_line", V2_line),
             ("V3_layers", V3_layers), ("V4_bars", V4_bars)]
    for name, fn in items:
        fn(512).save(os.path.join(OUT, f"{name}.png"))
    imgs = [Image.open(os.path.join(OUT, f"{n}.png")) for n, _ in items]
    pad = 24
    W = sum(i.width for i in imgs) + pad * (len(imgs) + 1)
    H = imgs[0].height + pad * 2
    sheet = Image.new("RGB", (W, H), (16, 16, 24))
    x = pad
    for im in imgs:
        sheet.paste(im, (x, pad)); x += im.width + pad
    sheet.save(os.path.join(OUT, "_compare.png"))
    print("done:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
