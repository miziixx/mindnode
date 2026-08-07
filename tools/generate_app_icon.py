#!/usr/bin/env python3
"""마인드사운드 앱 아이콘 생성.
어두운 차콜 배경 + 은은한 공명 링(글로우) + 별빛 점. 앱 분위기와 통일.

미리보기(assets/launcher_icons/app_icon_preview.png)와 안드로이드 mipmap,
iOS AppIcon.appiconset(완전한 Contents.json 포함)을 만든다.
apply_native.py가 생성된 프로젝트에 복사한다.
"""
import json
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "launcher_icons")
os.makedirs(OUT, exist_ok=True)

# 팔레트(앱 토큰과 동일)
BG_TOP = (18, 22, 30)      # #12161E
BG_BOT = (11, 13, 18)      # #0B0D12
ACCENT = (120, 150, 185)   # #7896B9
VIOLET = (138, 115, 157)   # crown 뮤트 바이올렛
WHITE = (241, 240, 235)

SS = 4  # 슈퍼샘플


def render_master(size=1024):
    S = size * SS
    cx = cy = S / 2

    # 배경: 세로 그라데이션 + 중앙 위쪽 은은한 방사형 글로우
    yy = np.linspace(0, 1, S)[:, None]
    top = np.array(BG_TOP); bot = np.array(BG_BOT)
    grad = (top * (1 - yy) + bot * yy)  # (S,3) 세로 그라데이션
    bg = np.broadcast_to(grad[:, None, :], (S, S, 3)).astype(np.float64).copy()

    gx = np.arange(S)[None, :] - cx
    gy = np.arange(S)[:, None] - (S * 0.42)
    d = np.sqrt(gx ** 2 + gy ** 2)
    glow = np.exp(-(d / (S * 0.34)) ** 2) * 0.22
    for i in range(3):
        bg[:, :, i] = bg[:, :, i] * (1 - glow) + ACCENT[i] * glow

    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # 링 + 코어를 그릴 레이어(글로우용)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    rings = [(0.17, ACCENT, 235), (0.29, ACCENT, 150), (0.41, VIOLET, 95)]
    lw = int(S * 0.013)
    for rr, col, alpha in rings:
        r = S * rr
        dr.ellipse([cx - r, cy - r, cx + r, cy + r],
                   outline=col + (alpha,), width=lw)
    # 중심 코어(부드러운 원)
    core_r = S * 0.055
    dr.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r],
               fill=ACCENT + (255,))

    # 글로우: 레이어를 블러해서 먼저 합성
    glow_layer = layer.filter(ImageFilter.GaussianBlur(radius=S * 0.02))
    base.alpha_composite(glow_layer)
    base.alpha_composite(glow_layer)  # 한 번 더 → 은은하게 빛남
    base.alpha_composite(layer)       # 선명한 링

    # 별빛 점
    stars = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ds = ImageDraw.Draw(stars)
    rng = np.random.default_rng(5)
    for _ in range(14):
        ang = rng.uniform(0, 2 * math.pi)
        rad = rng.uniform(0.12, 0.46) * S
        x = cx + rad * math.cos(ang)
        y = cy + rad * math.sin(ang)
        sr = rng.uniform(1.5, 4.0) * SS
        a = int(rng.uniform(90, 200))
        ds.ellipse([x - sr, y - sr, x + sr, y + sr], fill=WHITE + (a,))
    stars = stars.filter(ImageFilter.GaussianBlur(radius=SS * 0.6))
    base.alpha_composite(stars)

    return base.resize((size, size), Image.LANCZOS).convert("RGB")


def main():
    master = render_master(1024)
    master.save(os.path.join(OUT, "app_icon_preview.png"))
    master.save(os.path.join(OUT, "app_icon_1024.png"))

    # Android mipmap
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dpi, px in android.items():
        d = os.path.join(OUT, "android", f"mipmap-{dpi}")
        os.makedirs(d, exist_ok=True)
        img = master.resize((px, px), Image.LANCZOS)
        img.save(os.path.join(d, "ic_launcher.png"))
        img.save(os.path.join(d, "ic_launcher_round.png"))

    # iOS AppIcon.appiconset (완전 교체)
    ios = os.path.join(OUT, "ios", "AppIcon.appiconset")
    os.makedirs(ios, exist_ok=True)
    specs = [
        ("20", "2x", 40), ("20", "3x", 60), ("29", "2x", 58), ("29", "3x", 87),
        ("40", "2x", 80), ("40", "3x", 120), ("60", "2x", 120), ("60", "3x", 180),
        ("20", "1x", 20), ("29", "1x", 29), ("40", "1x", 40),
        ("76", "1x", 76), ("76", "2x", 152), ("83.5", "2x", 167),
        ("1024", "1x", 1024),
    ]
    images = []
    seen = {}
    for base_pt, scale, px in specs:
        fn = f"Icon-App-{base_pt}x{base_pt}@{scale}.png"
        if fn not in seen:
            master.resize((px, px), Image.LANCZOS).save(os.path.join(ios, fn))
            seen[fn] = True
        idiom = "ios-marketing" if base_pt == "1024" else (
            "ipad" if base_pt in ("76", "83.5") else "iphone")
        entry = {"size": f"{base_pt}x{base_pt}", "idiom": idiom,
                 "filename": fn, "scale": scale}
        images.append(entry)
    # iPhone/iPad 공용 20/29/40 도 idiom별로 필요 → iPad 항목 보강
    for base_pt, scale, px in [("20", "1x", 20), ("20", "2x", 40),
                               ("29", "1x", 29), ("29", "2x", 58),
                               ("40", "1x", 40), ("40", "2x", 80)]:
        fn = f"Icon-App-{base_pt}x{base_pt}@{scale}.png"
        images.append({"size": f"{base_pt}x{base_pt}", "idiom": "ipad",
                       "filename": fn, "scale": scale})
    with open(os.path.join(ios, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"version": 1, "author": "xcode"}},
                  f, indent=2)

    print("app icon generated:")
    print("  preview:", os.path.relpath(os.path.join(OUT, "app_icon_preview.png"), ROOT))
    print("  android mipmaps + ios appiconset under", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
