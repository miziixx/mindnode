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

# 팔레트 — 이리데센트(오로라) 색 스톱 + 파스텔 완화
STOPS = [(120, 182, 192), (112, 152, 200), (150, 122, 195),
         (186, 124, 178), (120, 182, 192)]
PASTEL = (206, 200, 226)   # 채도 완화용 라벤더
WHITE = (245, 244, 240)

SS = 4  # 슈퍼샘플


def _irid(u, soft=0.32):
    """u in [0,1] → 이리데센트 색(파스텔로 부드럽게)."""
    u = u % 1.0
    seg = u * (len(STOPS) - 1)
    i = int(seg); f = seg - i
    a = STOPS[i]; b = STOPS[min(i + 1, len(STOPS) - 1)]
    col = [a[k] * (1 - f) + b[k] * f for k in range(3)]
    col = [col[k] * (1 - soft) + PASTEL[k] * soft for k in range(3)]
    return tuple(int(round(c)) for c in col)


def render_master(size=1024):
    """빛나는 파형 — 둥근 막대 이퀄라이저(부드러운 벨 포락선)."""
    S = size * SS
    cx = cy = S / 2

    # 배경: 세로 그라데이션(딥 인디고 → 차콜)
    t = np.clip(np.arange(S)[:, None] / S, 0, 1)
    bg = (np.array((20, 20, 34))[None, None] * (1 - t)[:, :, None] +
          np.array((10, 11, 17))[None, None] * t[:, :, None])
    bg = np.tile(bg, (1, S, 1))
    base = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # 둥근 막대 파형
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    n = 15
    span = S * 0.72
    x0 = cx - span / 2
    gap = span / n
    bw = gap * 0.5
    for i in range(n):
        u = (i + 0.5) / n
        env = math.sin(u * math.pi) ** 0.7           # 가운데가 큰 벨 포락선
        h = S * 0.22 * (0.3 + 0.7 * env)
        x = x0 + gap * i + gap * 0.5
        col = _irid(0.12 + u * 0.72)
        dr.rounded_rectangle([x - bw / 2, cy - h, x + bw / 2, cy + h],
                             radius=bw / 2, fill=col + (235,))

    # 부드러운 글로우(블룸)
    g = layer.filter(ImageFilter.GaussianBlur(radius=S * 0.026))
    for _ in range(3):
        base.alpha_composite(g)
    base.alpha_composite(layer)
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
