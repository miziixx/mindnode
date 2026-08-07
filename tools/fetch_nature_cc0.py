#!/usr/bin/env python3
"""Wikimedia Commons에서 라이선스가 명확한(퍼블릭도메인/CC0, 필요시 CC-BY) 실제
자연음 녹음을 찾아 받아, 48kHz 스테레오 seamless 루프 WAV로 가공해 앱 자산으로 넣는다.

- 라이선스는 파일별 extmetadata로 프로그램적으로 확인하고 CREDITS_AUDIO.md에 기록.
- 성공한 카테고리만 실제 녹음으로 교체(_placeholder.wav 덮어씀), 실패 시 합성음 유지.
"""
import json
import os
import subprocess
import sys
import numpy as np
import soundfile as sf

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
NAT = os.path.join(ROOT, "assets", "audio", "nature")
TMP = "/tmp/nature_dl"
os.makedirs(TMP, exist_ok=True)
UA = "MindSoundAssetFetcher/1.0 (personal meditation app; contact: local)"

CATEGORIES = {
    "rain_soft": ["rain ambience", "rainfall", "rain sound", "rain"],
    "forest_morning": ["dawn chorus", "birdsong forest", "forest birds", "bird song"],
    "ocean_calm": ["ocean waves", "sea waves", "ocean surf", "waves beach"],
    "stream_soft": ["stream water", "babbling brook", "creek water", "flowing stream"],
    "wind_light": ["wind ambience", "wind blowing", "wind sound", "breeze"],
    "fire_soft": ["campfire crackling", "fire crackling", "bonfire", "fireplace"],
}

ACCEPT_PD_CC0 = True
ACCEPT_CCBY = True  # 개인 사용: CC-BY/CC-BY-SA도 허용하되 출처 기록


def curl_json(url):
    out = subprocess.run(
        ["curl", "-sS", "--max-time", "40", "-H", f"User-Agent: {UA}", url],
        capture_output=True, text=True)
    try:
        return json.loads(out.stdout)
    except Exception:
        return {}


def search(term, limit=8):
    url = ("https://commons.wikimedia.org/w/api.php?action=query&format=json"
           "&list=search&srnamespace=6&srlimit=%d&srsearch=%s"
           % (limit, quote(term + " filetype:audio")))
    d = curl_json(url)
    return [x["title"] for x in d.get("query", {}).get("search", [])]


def quote(s):
    import urllib.parse
    return urllib.parse.quote(s)


def fileinfo(title):
    url = ("https://commons.wikimedia.org/w/api.php?action=query&format=json"
           "&prop=imageinfo&iiprop=url|size|mime|extmetadata&titles=%s"
           % quote(title))
    d = curl_json(url)
    pages = d.get("query", {}).get("pages", {})
    for _, p in pages.items():
        ii = p.get("imageinfo")
        if not ii:
            continue
        info = ii[0]
        ext = info.get("extmetadata", {})
        def g(k):
            return (ext.get(k, {}) or {}).get("value", "")
        return {
            "title": title,
            "url": info.get("url"),
            "size": info.get("size", 0),
            "mime": info.get("mime", ""),
            "license_short": g("LicenseShortName"),
            "license_code": g("License"),
            "artist": strip_html(g("Artist")),
            "credit": strip_html(g("Credit")),
        }
    return None


def strip_html(s):
    import re
    return re.sub("<[^>]+>", "", s or "").strip()


def license_ok(info):
    code = (info.get("license_code") or "").lower()
    short = (info.get("license_short") or "").lower()
    if ACCEPT_PD_CC0 and ("cc0" in code or "cc0" in short or code == "pd"
                          or "public domain" in short):
        return True, "PD/CC0"
    if ACCEPT_CCBY and ("cc-by" in code or "cc by" in short):
        return True, info.get("license_short") or "CC-BY"
    return False, ""


def download(url, dest):
    r = subprocess.run(
        ["curl", "-sS", "-L", "--max-time", "120", "-H", f"User-Agent: {UA}",
         "-o", dest, url], capture_output=True, text=True)
    return os.path.exists(dest) and os.path.getsize(dest) > 1000


def to_stereo_48k(data, sr):
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    elif data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    else:
        data = data[:, :2]
    if sr != SR:
        n_out = int(data.shape[0] * SR / sr)
        x_old = np.linspace(0, 1, data.shape[0], endpoint=False)
        x_new = np.linspace(0, 1, n_out, endpoint=False)
        data = np.stack([np.interp(x_new, x_old, data[:, 0]),
                         np.interp(x_new, x_old, data[:, 1])], axis=1)
    return data.astype(np.float64)


def seamless_loop(data, loop_sec=20.0, xfade_sec=1.5):
    n_total = data.shape[0]
    xf = int(SR * xfade_sec)
    loop_len = min(int(SR * loop_sec), n_total - xf)
    if loop_len < SR * 4:  # 최소 4초
        loop_len = max(1, n_total - xf)
    body = data[:loop_len + xf].copy()
    out = body[:loop_len].copy()
    tail = body[loop_len:loop_len + xf]
    m = min(xf, len(tail), loop_len)
    w = np.linspace(0, 1, m)[:, None]
    out[:m] = out[:m] * w + tail[:m] * (1 - w)
    return out


def normalize(data, peak=0.6):
    m = np.max(np.abs(data))
    return data * (peak / m) if m > 0 else data


def process(src, out_wav):
    data, sr = sf.read(src, always_2d=True)
    dur = data.shape[0] / sr
    if dur < 6:
        return None, "too short (%.1fs)" % dur
    # 앞 40초까지만 사용(용량/처리)
    data = data[: int(sr * 40)]
    st = to_stereo_48k(data, sr)
    rms = float(np.sqrt(np.mean(st ** 2)))
    if rms < 0.005:
        return None, "too quiet (rms %.4f)" % rms
    looped = normalize(seamless_loop(st))
    sf.write(out_wav, looped.astype(np.float32), SR, subtype="PCM_16")
    seam = abs(float(looped[-1, 0]) - float(looped[0, 0]))
    return {"dur": looped.shape[0] / SR, "rms": rms, "seam": seam}, "ok"


def main():
    credits = []
    results = {}
    for base, terms in CATEGORIES.items():
        print(f"\n=== {base} ===")
        done = False
        seen = set()
        for term in terms:
            if done:
                break
            for title in search(term):
                if title in seen:
                    continue
                seen.add(title)
                info = fileinfo(title)
                if not info or not info.get("url"):
                    continue
                ok, lic = license_ok(info)
                if not ok:
                    continue
                if info["size"] > 40 * 1024 * 1024:
                    continue
                ext = os.path.splitext(info["url"])[1].lower()
                if ext not in (".ogg", ".oga", ".flac", ".wav", ".mp3", ".opus"):
                    continue
                dest = os.path.join(TMP, f"{base}{ext}")
                print(f"  try: {title} [{lic}] {info['size']//1024}KB")
                if not download(info["url"], dest):
                    print("    download failed")
                    continue
                try:
                    stats, msg = process(dest, os.path.join(NAT, f"{base}_placeholder.wav"))
                except Exception as e:
                    print(f"    decode/process error: {e}")
                    continue
                if stats is None:
                    print(f"    rejected: {msg}")
                    continue
                print(f"    OK -> {base}_placeholder.wav "
                      f"dur={stats['dur']:.1f}s rms={stats['rms']:.3f} seam={stats['seam']:.4f}")
                credits.append({
                    "asset": base, "title": title, "license": lic,
                    "artist": info.get("artist", ""),
                    "url": "https://commons.wikimedia.org/wiki/" + quote(title),
                })
                results[base] = lic
                done = True
                break
        if not done:
            print(f"  !! no suitable CC0/PD/CC-BY file found; keeping synth placeholder")
    # CREDITS 기록
    lines = ["# CREDITS_AUDIO.md — 자연음 출처/라이선스\n",
             "아래 자연음은 Wikimedia Commons의 라이선스가 명확한 실제 녹음이다.",
             "나머지(패드/차임, 또는 아래에 없는 자연음)는 합성 플레이스홀더다.\n"]
    for c in credits:
        lines.append(f"- **{c['asset']}** — [{c['title']}]({c['url']}) · "
                     f"{c['license']}" + (f" · {c['artist']}" if c['artist'] else ""))
    with open(os.path.join(ROOT, "CREDITS_AUDIO.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"\n=== summary: {len(results)}/{len(CATEGORIES)} replaced with real recordings ===")
    for k, v in results.items():
        print(f"  {k}: {v}")
    return 0 if results else 1


if __name__ == "__main__":
    sys.exit(main())
