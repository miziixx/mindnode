#!/usr/bin/env python3
"""아이콘 시안 — 신비롭고 아름다운(비종교) 방향. 우주/오로라/성운 계열.
assets/launcher_icons/mystic/*.png (512px 미리보기) + _compare.png
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "mystic")
os.makedirs(OUT, exist_ok=True)

SS = 3
ACCENT = (118, 152, 190)   # 블루
VIOLET = (150, 120, 185)   # 바이올렛
MAGENTA = (176, 118, 172)  # 딥 로즈바이올렛
CYAN = (120, 180, 192)     # 청록 포인트
WHITE = (244, 243, 240)


def lerp(a, b, t):
    return tuple(int(round(a[i] * (1 - t) + b[i] * t)) for i in range(3))


def dark_bg(S, top=(20, 20, 38), bot=(9, 10, 16)):
    yy = (np.arange(S)[:, None] / S)
    t = np.clip(yy, 0, 1)
    c0 = np.array(top); c1 = np.array(bot)
    bg = c0[None, None] * (1 - t)[:, :, None] + c1[None, None] * t[:, :, None]
    bg = np.repeat(bg, S, axis=1) if bg.shape[1] == 1 else bg
    return np.clip(bg, 0, 255).astype(np.float64)


def smooth_noise(S, scale, seed):
    rng = np.random.default_rng(seed)
    low = rng.random((scale, scale))
    img = Image.fromarray((low * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
    a = np.asarray(img).astype(np.float64) / 255.0
    return a


def add_blob(bg, S, cxr, cyr, rr, col, op):
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    d = np.sqrt((xx - S * cxr) ** 2 + (yy - S * cyr) ** 2) / (S * rr)
    a = (np.clip(1 - d, 0, 1) ** 2)[:, :, None] * op
    for k in range(3):
        bg[:, :, k] = bg[:, :, k] * (1 - a[:, :, 0]) + col[k] * a[:, :, 0]


def stars(draw, S, n, seed, rmax):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x = rng.random() * S; y = rng.random() * S
        r = rng.random() * rmax + rmax * 0.3
        b = int(180 + rng.random() * 75)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(b, b, min(255, b + 8), 255))


def finalize(arr, size):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    return img.resize((size, size), Image.LANCZOS)


# ── M1: 이클립스 — 어두운 구체 + 빛나는 초승 링 + 성운 헤이즈 ──
def M1_eclipse(size):
    S = size * SS
    bg = dark_bg(S)
    # 성운 헤이즈
    add_blob(bg, S, 0.34, 0.36, 0.55, VIOLET, 0.42)
    add_blob(bg, S, 0.70, 0.60, 0.5, ACCENT, 0.36)
    add_blob(bg, S, 0.6, 0.3, 0.4, MAGENTA, 0.25)
    neb = smooth_noise(S, 9, 7)
    for k in range(3):
        bg[:, :, k] *= (0.72 + 0.28 * neb)
    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    img = img.filter(ImageFilter.GaussianBlur(S * 0.006))

    cx = cy = S / 2
    R = S * 0.26
    # 빛나는 링(뒤) — 살짝 위로 오프셋 → 아래로 초승 노출
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    rim = R * 1.06
    gd.ellipse([cx - rim, cy - rim, cx + rim, cy + rim],
               fill=lerp(CYAN, WHITE, 0.35) + (255,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.02))
    img.alpha_composite(glow)
    gd2 = ImageDraw.Draw(img)
    gd2.ellipse([cx - rim, cy - rim, cx + rim, cy + rim],
                outline=lerp(CYAN, WHITE, 0.5) + (255,), width=int(S * 0.012))
    # 어두운 구체(앞, 위로 오프셋) — 매끈한 방사 그라데이션(가장자리 살짝 푸른 빛)
    off = S * 0.035
    ocx, ocy = cx, cy - off
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    dd = np.sqrt((xx - ocx) ** 2 + (yy - ocy) ** 2)
    inside = dd <= R
    orb_arr = np.zeros((S, S, 4), np.float64)
    trad = np.clip(dd / R, 0, 1)
    # 중심 near-black → 가장자리 아주 옅은 남보라
    edge = np.array((34, 36, 58)); cen = np.array((12, 13, 21))
    for k in range(3):
        orb_arr[:, :, k] = cen[k] * (1 - trad) + edge[k] * trad
    # 윗부분(터미네이터) 은은한 하이라이트
    top = np.clip(1 - np.sqrt((xx - ocx) ** 2 + (yy - (ocy - R * 0.55)) ** 2) / (R * 0.7), 0, 1) ** 2
    for k in range(3):
        orb_arr[:, :, k] += top * np.array((40, 46, 70))[k]
    orb_arr[:, :, 3] = 255
    orb_arr[~inside] = 0
    orb = Image.fromarray(np.clip(orb_arr, 0, 255).astype(np.uint8), "RGBA")
    img.alpha_composite(orb)
    sd = ImageDraw.Draw(img)
    stars(sd, S, 40, 3, S * 0.0024)
    return finalize(np.asarray(img.convert("RGB")).astype(np.float64), size)


# ── M2: 오로라 베일 — 흐르는 빛 리본 + 별 ──
def M2_aurora(size):
    S = size * SS
    bg = dark_bg(S, top=(14, 15, 30), bot=(8, 9, 15))
    img_arr = bg.copy()
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    def ribbon(cy_r, amp_r, thick_r, col, op, k):
        cyc = S * cy_r
        wave = cyc + S * amp_r * np.sin(xx / S * math.pi * k + cy_r * 6)
        d = np.abs(yy - wave) / (S * thick_r)
        a = np.clip(1 - d, 0, 1) ** 2 * op
        for c in range(3):
            img_arr[:, :, c] = img_arr[:, :, c] * (1 - a) + col[c] * a
    ribbon(0.42, 0.10, 0.11, VIOLET, 0.75, 2.0)
    ribbon(0.52, 0.12, 0.09, ACCENT, 0.7, 1.6)
    ribbon(0.60, 0.08, 0.06, CYAN, 0.6, 2.4)
    img = Image.fromarray(np.clip(img_arr, 0, 255).astype(np.uint8), "RGB")
    img = img.filter(ImageFilter.GaussianBlur(S * 0.012)).convert("RGBA")
    sd = ImageDraw.Draw(img)
    stars(sd, S, 55, 11, S * 0.0026)
    return finalize(np.asarray(img.convert("RGB")).astype(np.float64), size)


# ── M3: 성운 오브 — 빛나는 코어를 감싸는 소용돌이 연기 + 별빛 ──
def M3_nebula(size):
    S = size * SS
    bg = dark_bg(S, top=(18, 18, 34), bot=(9, 9, 15))
    add_blob(bg, S, 0.5, 0.5, 0.62, VIOLET, 0.5)
    add_blob(bg, S, 0.40, 0.44, 0.34, MAGENTA, 0.4)
    add_blob(bg, S, 0.62, 0.58, 0.32, ACCENT, 0.45)
    add_blob(bg, S, 0.55, 0.40, 0.2, CYAN, 0.3)
    # 소용돌이 느낌: 각도 기반 연기 변조
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    ang = np.arctan2(yy - S / 2, xx - S / 2)
    rad = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / (S * 0.5)
    swirl = 0.5 + 0.5 * np.sin(ang * 3 + rad * 6)
    neb = smooth_noise(S, 8, 21)
    mod = (0.62 + 0.38 * (0.5 * swirl + 0.5 * neb))
    for k in range(3):
        bg[:, :, k] *= mod
    # 중심 어둡게 눌러 코어 대비
    core_d = np.exp(-(rad / 0.5) ** 2)
    img = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB")
    img = img.filter(ImageFilter.GaussianBlur(S * 0.02)).convert("RGBA")
    # 빛나는 코어
    cx = cy = S / 2
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - S * 0.17, cy - S * 0.17, cx + S * 0.17, cy + S * 0.17],
               fill=lerp(ACCENT, WHITE, 0.4) + (255,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.05))
    img.alpha_composite(glow)
    sharp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sdd = ImageDraw.Draw(sharp)
    for k in range(46):
        t = k / 46
        rr = S * 0.075 * (1 - t)
        col = lerp(WHITE, lerp(ACCENT, WHITE, 0.55), t)
        sdd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                    fill=tuple(int(c) for c in col) + (255,))
    img.alpha_composite(sharp)
    sd = ImageDraw.Draw(img)
    stars(sd, S, 60, 5, S * 0.0022)
    return finalize(np.asarray(img.convert("RGB")).astype(np.float64), size)


def main():
    items = [("M1_eclipse", M1_eclipse), ("M2_aurora", M2_aurora),
             ("M3_nebula", M3_nebula)]
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
