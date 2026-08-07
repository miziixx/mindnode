#!/usr/bin/env python3
"""앱 아이콘 시안 여러 개 생성(고르기용). assets/launcher_icons/concepts/*.png"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons", "concepts")
os.makedirs(OUT, exist_ok=True)
SS = 4


def lin_grad(S, c0, c1, angle=0.0):
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64) / S
    t = xx * math.cos(angle) + yy * math.sin(angle)
    t = (t - t.min()) / (t.max() - t.min())
    c0 = np.array(c0); c1 = np.array(c1)
    img = c0[None, None, :] * (1 - t)[:, :, None] + c1[None, None, :] * t[:, :, None]
    return img


def A_orb(size):
    S = size * SS
    bg = lin_grad(S, (44, 38, 74), (14, 16, 30), angle=math.pi / 4)
    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")
    cx = cy = S / 2
    # 구체(방사형)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (S * 0.34)
    inner = np.array((150, 185, 225)); outer = np.array((58, 70, 120))
    sphere = np.clip(1 - d, 0, 1)[:, :, None]
    orb_rgb = inner[None, None, :] * sphere + outer[None, None, :] * (1 - sphere)
    mask = (d <= 1.0)
    # 하이라이트(좌상단)
    hd = np.sqrt((xx - cx + S * 0.10) ** 2 + (yy - cy + S * 0.12) ** 2) / (S * 0.13)
    hl = np.clip(1 - hd, 0, 1)[:, :, None] * 0.5
    orb_rgb = orb_rgb + np.array((255, 255, 255))[None, None, :] * hl
    orb = np.zeros((S, S, 4), np.uint8)
    orb[:, :, :3] = np.clip(orb_rgb, 0, 255).astype(np.uint8)
    orb[:, :, 3] = (mask * 255).astype(np.uint8)
    orb_img = Image.fromarray(orb)
    glow = orb_img.filter(ImageFilter.GaussianBlur(S * 0.03))
    base.alpha_composite(glow); base.alpha_composite(orb_img)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def B_wave(size):
    S = size * SS
    bg = lin_grad(S, (18, 22, 30), (10, 12, 17), angle=math.pi / 2)
    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    heights = [0.16, 0.30, 0.52, 0.72, 0.9, 0.72, 0.52, 0.30, 0.16]
    n = len(heights)
    bw = S * 0.052
    gap = S * 0.028
    total = n * bw + (n - 1) * gap
    x = (S - total) / 2
    cy = S / 2
    for i, h in enumerate(heights):
        bh = S * 0.40 * h
        col = (int(120 + 20 * (i / n)), 150, int(185 - 30 * (i / n)))
        dr.rounded_rectangle([x, cy - bh, x + bw, cy + bh], radius=bw / 2,
                             fill=col + (255,))
        x += bw + gap
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.02))
    base.alpha_composite(glow); base.alpha_composite(layer)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def C_moon(size):
    S = size * SS
    bg = lin_grad(S, (26, 28, 48), (10, 12, 20), angle=math.pi / 3)
    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cx, cy = S * 0.54, S * 0.5
    r = S * 0.26
    cream = (226, 224, 214)
    dr.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cream + (255,))
    # 초승달: 겹치는 원으로 잘라내기
    ox, oy, orr = cx + S * 0.14, cy - S * 0.06, r * 1.02
    dr.ellipse([ox - orr, oy - orr, ox + orr, oy + orr], fill=(0, 0, 0, 0))
    # 별
    sx, sy = S * 0.30, S * 0.34
    for a in range(4):
        ang = a * math.pi / 2
        dr.polygon([
            (sx + math.cos(ang) * S * 0.05, sy + math.sin(ang) * S * 0.05),
            (sx + math.cos(ang + 0.4) * S * 0.014, sy + math.sin(ang + 0.4) * S * 0.014),
            (sx + math.cos(ang + math.pi / 2) * S * 0.05, sy + math.sin(ang + math.pi / 2) * S * 0.05),
            (sx + math.cos(ang + 0.4) * S * 0.014, sy + math.sin(ang + 0.4) * S * 0.014),
        ], fill=(226, 224, 214, 255))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.015))
    base.alpha_composite(glow); base.alpha_composite(layer)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def D_pulse(size):
    S = size * SS
    bg = lin_grad(S, (16, 20, 30), (9, 11, 16), angle=math.pi / 2)
    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    cy = S / 2
    lw = int(S * 0.03)
    accent = (120, 150, 185, 255)
    pts = []
    for i in range(0, S + 1, 4):
        t = i / S
        y = cy
        if 0.34 < t < 0.66:
            y = cy - math.sin((t - 0.34) / 0.32 * math.pi) * S * 0.22 * (1 if t < 0.5 else -1) * 0 \
                - (math.exp(-((t - 0.5) / 0.06) ** 2)) * S * 0.24
        pts.append((i, y))
    dr.line(pts, fill=accent, width=lw, joint="curve")
    dot_t = 0.5
    dr.ellipse([S * dot_t - lw, cy - S * 0.24 - lw, S * dot_t + lw, cy - S * 0.24 + lw],
               fill=(200, 215, 235, 255))
    glow = layer.filter(ImageFilter.GaussianBlur(S * 0.02))
    base.alpha_composite(glow); base.alpha_composite(glow); base.alpha_composite(layer)
    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def main():
    for name, fn in [("1_orb", A_orb), ("2_wave", B_wave),
                     ("3_moon", C_moon), ("4_pulse", D_pulse)]:
        img = fn(512)
        img.save(os.path.join(OUT, f"concept_{name}.png"))
    print("concepts:", os.listdir(OUT))


if __name__ == "__main__":
    main()
