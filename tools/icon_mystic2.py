#!/usr/bin/env python3
"""아이콘 시안 2차 — 추상·세련된 신비로움(비종교). 흐르는 빛/오팔/헤일로/파형.
assets/launcher_icons/mystic2/*.png (512) + _compare.png
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "mystic2")
os.makedirs(OUT, exist_ok=True)

SS = 3
# 이리데센트(오로라) 색 스톱
STOPS = [(120, 182, 192), (110, 150, 200), (150, 120, 195),
         (188, 120, 176), (120, 182, 192)]
WHITE = (245, 244, 240)


def irid(u):
    """u in [0,1] → 이리데센트 색 보간."""
    u = u % 1.0
    seg = u * (len(STOPS) - 1)
    i = int(seg); f = seg - i
    a = STOPS[i]; b = STOPS[min(i + 1, len(STOPS) - 1)]
    return tuple(int(round(a[k] * (1 - f) + b[k] * f)) for k in range(3))


def dark(S, top=(19, 19, 34), bot=(9, 9, 15)):
    t = np.clip(np.arange(S)[:, None] / S, 0, 1)
    bg = np.array(top)[None, None] * (1 - t)[:, :, None] + \
        np.array(bot)[None, None] * t[:, :, None]
    return np.tile(bg, (1, S, 1)).astype(np.float64)


def stars(draw, S, n, seed, rmax):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x = rng.random() * S; y = rng.random() * S
        r = rng.random() * rmax + rmax * 0.3
        b = int(170 + rng.random() * 85)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(b, b, min(255, b + 8), 255))


def fin(img, size):
    return img.convert("RGB").resize((size, size), Image.LANCZOS)


# ── N1: 흐르는 빛 리본(리퀴드 실크) ──
def N1_silk(size):
    S = size * SS
    base = Image.fromarray(np.clip(dark(S), 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    ribbons = [(0.50, 0.16, 0.9, 0.0), (0.46, 0.12, 1.2, 1.3), (0.55, 0.10, 1.5, 2.6)]
    for cyr, amp, k, ph in ribbons:
        pts_top = []; pts_bot = []
        seg = 160
        for i in range(seg + 1):
            x = i / seg * S * 0.9 + S * 0.05
            u = i / seg
            yy = S * cyr + S * amp * math.sin(u * math.pi * 2 * k + ph)
            th = S * (0.02 + 0.02 * (0.5 + 0.5 * math.sin(u * math.pi * 3 + ph)))
            pts_top.append((x, yy - th)); pts_bot.append((x, yy + th))
        poly = pts_top + pts_bot[::-1]
        # 색: 리본 중앙 u=0.5 기준
        # 조각별 그라데이션 위해 얇은 사다리꼴로 나눠 칠함
        for i in range(seg):
            u = i / seg
            col = irid(u + ph * 0.1)
            quad = [pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]]
            dr.polygon(quad, fill=col + (210,))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.02))
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    base.alpha_composite(layer)
    return fin(base, size)


# ── N2: 오팔 구체(이리데센트 스월) ──
def N2_opal(size):
    S = size * SS
    bg = dark(S, top=(16, 16, 28))
    cx = cy = S / 2
    R = S * 0.30
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    ang = np.arctan2(yy - cy, xx - cx)
    rad = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    inside = rad <= R
    u = (ang / (2 * math.pi) + 0.5 + 0.35 * np.sin(rad / R * 3)) % 1.0
    # 이리데센트 매핑(벡터화)
    stops = np.array(STOPS, dtype=np.float64)
    seg = u * (len(STOPS) - 1)
    idx = np.clip(seg.astype(int), 0, len(STOPS) - 2)
    f = seg - idx
    orb = np.zeros((S, S, 3))
    for k in range(3):
        a = stops[idx, k]; b = stops[idx + 1, k]
        orb[:, :, k] = a * (1 - f) + b * f
    # 구체 음영(중심 밝고 가장자리 어둡게) + 좌상단 하이라이트
    shade = np.clip(1 - (rad / R), 0, 1) ** 0.6
    hl = np.clip(1 - np.sqrt((xx - (cx - R * 0.32)) ** 2 +
                             (yy - (cy - R * 0.32)) ** 2) / (R * 0.5), 0, 1) ** 2
    for k in range(3):
        orb[:, :, k] = orb[:, :, k] * (0.45 + 0.55 * shade) + WHITE[k] * hl * 0.6
    out = bg.copy()
    for k in range(3):
        out[:, :, k] = np.where(inside, orb[:, :, k], out[:, :, k])
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    # 외곽 글로우
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([cx - R, cy - R, cx + R, cy + R],
                                 outline=(150, 150, 200, 160), width=int(S * 0.02))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(S * 0.03)))
    return fin(img, size)


# ── N3: 빛의 고리(헤일로/토러스) ──
def N3_halo(size):
    S = size * SS
    base = Image.fromarray(np.clip(dark(S), 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    sd = ImageDraw.Draw(base)
    stars(sd, S, 45, 9, S * 0.0022)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    Rx = S * 0.30; Ry = S * 0.30
    seg = 240
    lw = int(S * 0.028)
    for i in range(seg):
        u0 = i / seg
        a0 = u0 * 2 * math.pi
        col = irid(u0)
        x = cx + Rx * math.cos(a0); y = cy + Ry * math.sin(a0)
        dr.ellipse([x - lw / 2, y - lw / 2, x + lw / 2, y + lw / 2], fill=col + (255,))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.02))
    base.alpha_composite(glow); base.alpha_composite(glow); base.alpha_composite(layer)
    # 중심 작은 광점
    core = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(core).ellipse([cx - S * 0.03, cy - S * 0.03, cx + S * 0.03, cy + S * 0.03],
                                 fill=WHITE + (255,))
    base.alpha_composite(core.filter(ImageFilter.GaussianBlur(S * 0.02)))
    base.alpha_composite(core)
    return fin(base, size)


# ── N4: 빛나는 파형(사운드 웨이브) ──
def N4_wave(size):
    S = size * SS
    base = Image.fromarray(np.clip(dark(S, top=(16, 17, 30)), 0, 255).astype(np.uint8),
                           "RGB").convert("RGBA")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2
    seg = 220
    pts_top = []; pts_bot = []
    for i in range(seg + 1):
        u = i / seg
        x = u * S * 0.86 + S * 0.07
        env = math.sin(u * math.pi) ** 0.8  # 가운데가 큰 포락선
        osc = math.sin(u * math.pi * 2 * 5)  # 5주기 파형
        amp = S * 0.26 * env * (0.35 + 0.65 * abs(osc))
        pts_top.append((x, cy - amp)); pts_bot.append((x, cy + amp))
    for i in range(seg):
        u = i / seg
        col = irid(0.15 + u * 0.7)
        quad = [pts_top[i], pts_top[i + 1], pts_bot[i + 1], pts_bot[i]]
        dr.polygon(quad, fill=col + (230,))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.02))
    base.alpha_composite(glow); base.alpha_composite(glow); base.alpha_composite(layer)
    # 중앙 라인 하이라이트
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).line([(S * 0.07, cy), (S * 0.93, cy)], fill=WHITE + (90,),
                            width=int(S * 0.004))
    base.alpha_composite(hl.filter(ImageFilter.GaussianBlur(S * 0.004)))
    return fin(base, size)


def main():
    items = [("N1_silk", N1_silk), ("N2_opal", N2_opal),
             ("N3_halo", N3_halo), ("N4_wave", N4_wave)]
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
