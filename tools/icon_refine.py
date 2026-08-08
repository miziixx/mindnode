#!/usr/bin/env python3
"""아이콘 리파인 시안(같은 블루→바이올렛 계열, 완성도 위주).
assets/launcher_icons/refine/*.png 로 512px 미리보기 생성.
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "refine")
os.makedirs(OUT, exist_ok=True)

SS = 4
ACCENT = (120, 150, 185)   # 블루
VIOLET = (150, 122, 178)   # 바이올렛
CYAN = (128, 178, 190)     # 살짝 청록(포인트)
WHITE = (243, 242, 238)


def radial_bg(S, inner=(30, 30, 54), outer=(10, 11, 17), glow_col=ACCENT,
              glow=0.22, glow_r=0.34):
    cx = cy = S / 2
    d = np.sqrt((np.arange(S)[None, :] - cx) ** 2 +
                (np.arange(S)[:, None] - cy) ** 2) / (S * 0.72)
    d = np.clip(d, 0, 1)[:, :, None]
    c0 = np.array(inner); c1 = np.array(outer)
    bg = c0[None, None] * (1 - d) + c1[None, None] * d
    dd = np.sqrt((np.arange(S)[None, :] - cx) ** 2 +
                 (np.arange(S)[:, None] - cy) ** 2)
    g = np.exp(-(dd / (S * glow_r)) ** 2)[:, :, None] * glow
    bg = bg * (1 - g) + np.array(glow_col)[None, None] * g
    return Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def lerp(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def core(dr, cx, cy, r, S):
    # 광원 코어: 여러 겹 그라데이션 원
    for k, (rr, a) in enumerate([(2.8, 0.10), (1.9, 0.18), (1.25, 0.55), (1.0, 1.0)]):
        col = lerp(ACCENT, WHITE, min(1.0, 0.4 + k * 0.2))
        dr.ellipse([cx - r * rr, cy - r * rr, cx + r * rr, cy + r * rr],
                   fill=col + (int(255 * a),))


def core_glow(base, cx, cy, r, S):
    """별도 레이어에 부드러운 광원 코어(블러 헤일로 + 선명한 중심)."""
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse([cx - r * 3.2, cy - r * 3.2, cx + r * 3.2, cy + r * 3.2],
               fill=lerp(ACCENT, WHITE, 0.35) + (150,))
    halo = halo.filter(ImageFilter.GaussianBlur(r * 1.1))
    base.alpha_composite(halo)
    sharp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sharp)
    steps = 40
    for k in range(steps, 0, -1):
        t = k / steps
        col = lerp(WHITE, lerp(ACCENT, WHITE, 0.5), t)
        rr = r * t
        sd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (255,))
    base.alpha_composite(sharp)


def glow_compose(base, layer, r, times=2):
    g = layer.filter(ImageFilter.GaussianBlur(r))
    for _ in range(times):
        base.alpha_composite(g)
    base.alpha_composite(layer)


# ── R1: 폴리시드 만다라 — 완전 대칭 코로나 + 이중 링 + 광원 코어 ──
def R1_mandala(size):
    S = size * SS
    base = radial_bg(S)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2

    # 바깥 코로나 — N겹 대칭(k-fold). 각 막대는 완전히 동일하게 반복.
    petals = 12
    n = 96  # petals 의 배수 → 완벽 대칭
    inner = S * 0.205
    for i in range(n):
        ang = i / n * 2 * math.pi - math.pi / 2
        # petals-겹 대칭 물결(같은 배수 하모닉만 사용 → 대칭 유지)
        h = (0.55
             + 0.30 * (0.5 + 0.5 * math.cos(petals * (i / n * 2 * math.pi)))
             + 0.15 * (0.5 + 0.5 * math.cos(petals * 2 * (i / n * 2 * math.pi))))
        h /= 1.0
        hn = max(0.0, min(1.0, (h - 0.55) / 0.45))  # 0..1 막대 길이 비율
        outer = inner + S * (0.055 + 0.155 * hn)
        # 색: 짧으면 블루, 길수록 밝은 바이올렛(끝이 빛남)
        col = lerp(lerp(ACCENT, VIOLET, 0.4), lerp(VIOLET, WHITE, 0.35), hn)
        x0 = cx + inner * math.cos(ang); y0 = cy + inner * math.sin(ang)
        x1 = cx + outer * math.cos(ang); y1 = cy + outer * math.sin(ang)
        dr.line([(x0, y0), (x1, y1)], fill=col + (255,), width=int(S * 0.0135))

    # 얇은 이중 경계 링(정돈감)
    for rr, a, wr in [(0.185, 70, 0.0035), (0.44, 45, 0.003)]:
        dr.ellipse([cx - S * rr, cy - S * rr, cx + S * rr, cy + S * rr],
                   outline=lerp(ACCENT, WHITE, 0.35) + (a,), width=max(1, int(S * wr)))

    glow_compose(base, layer, S * 0.012, times=2)
    core_glow(base, cx, cy, S * 0.062, S)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


# ── R2: 오라 오브 — 빛나는 구체 + 확산되는 소리 링 ──
def R2_orb(size):
    S = size * SS
    base = radial_bg(S, inner=(26, 26, 50), glow=0.16)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx = cy = S / 2

    # 확산 링(굵기·투명도 그라데이션)
    for i, rr in enumerate([0.20, 0.29, 0.38, 0.47]):
        f = i / 3
        col = lerp(ACCENT, VIOLET, f)
        a = int(220 * (1 - f * 0.7))
        dr.ellipse([cx - S * rr, cy - S * rr, cx + S * rr, cy + S * rr],
                   outline=col + (a,), width=int(S * (0.010 - 0.0016 * i)))

    # 중앙 오브(방사 그라데이션)
    orb = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(orb)
    R = S * 0.155
    steps = 60
    for k in range(steps, 0, -1):
        t = k / steps
        col = lerp(WHITE, ACCENT, t)
        rr = R * t
        od.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col + (255,))
    layer.alpha_composite(orb)
    glow_compose(base, layer, S * 0.016, times=2)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


# ── R3: 로터스 블룸 — 부드러운 꽃잎 8장, 대칭·그라데이션 ──
def R3_lotus(size):
    S = size * SS
    base = radial_bg(S, inner=(32, 26, 56), glow=0.18)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S / 2

    def petal_layer(petals, radius, width_r, col, alpha, rot=0.0):
        pl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        pd = ImageDraw.Draw(pl)
        for i in range(petals):
            one = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            od = ImageDraw.Draw(one)
            pw = S * width_r
            od.ellipse([cx - pw, cy - radius, cx + pw, cy + radius * 0.1],
                       fill=col + (alpha,))
            ang = math.degrees(rot) + i * (360 / petals)
            one = one.rotate(ang, center=(cx, cy), resample=Image.BICUBIC)
            pl.alpha_composite(one)
        return pl

    # 뒤 꽃잎(바이올렛, 큼) + 앞 꽃잎(블루, 작음, 45도 회전)
    back = petal_layer(8, S * 0.34, 0.075, VIOLET, 150)
    front = petal_layer(8, S * 0.26, 0.055, ACCENT, 190, rot=math.pi / 8)
    layer.alpha_composite(back)
    layer.alpha_composite(front)
    glow_compose(base, layer, S * 0.016, times=2)
    core_glow(base, cx, cy, S * 0.048, S)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def main():
    for name, fn in [("R1_mandala", R1_mandala), ("R2_orb", R2_orb),
                     ("R3_lotus", R3_lotus)]:
        fn(512).save(os.path.join(OUT, f"{name}.png"))
    # 나란히 비교용 콘택트 시트
    imgs = [Image.open(os.path.join(OUT, f"{n}.png")) for n in
            ("R1_mandala", "R2_orb", "R3_lotus")]
    pad = 24
    W = sum(i.width for i in imgs) + pad * (len(imgs) + 1)
    H = imgs[0].height + pad * 2
    sheet = Image.new("RGB", (W, H), (18, 18, 26))
    x = pad
    for im in imgs:
        sheet.paste(im, (x, pad)); x += im.width + pad
    sheet.save(os.path.join(OUT, "_compare.png"))
    print("done:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
