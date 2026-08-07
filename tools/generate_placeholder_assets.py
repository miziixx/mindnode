#!/usr/bin/env python3
"""플레이스홀더 자연음/패드/차임 WAV 생성기 (합성, 라이선스 무관).

⚠️ 실제 녹음이 아니라 합성음이다. 하지만 화이트 노이즈가 아니라
브라운/핑크 노이즈 + 느린 진폭 움직임(파도·바람·시냇물)으로 만들어
"자연음답게" 들리도록 하고, FFT 기반 색 노이즈라 **경계가 완벽히 이어져
이음매 없는(seamless) 루프**가 된다(주기적으로 뚝 끊기는 갭 없음).

원한다면 라이선스 확인된 실제 음원으로 교체 가능(ASSET_GUIDE.md).
int16 PCM WAV(48kHz stereo).
"""
import os
import struct
import numpy as np

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASE = os.path.join(ROOT, "assets", "audio")
rng = np.random.default_rng(7)


def write_int16_wav(path, left, right, sr=SR):
    n = min(len(left), len(right))
    l = np.clip(left[:n], -1.0, 1.0)
    r = np.clip(right[:n], -1.0, 1.0)
    inter = np.empty(n * 2, dtype=np.int16)
    inter[0::2] = (l * 32767).astype(np.int16)
    inter[1::2] = (r * 32767).astype(np.int16)
    data = inter.tobytes()
    byte_rate = sr * 2 * 2
    with open(path, "wb") as f:
        f.write(b"RIFF"); f.write(struct.pack("<I", 36 + len(data))); f.write(b"WAVE")
        f.write(b"fmt "); f.write(struct.pack("<I", 16))
        f.write(struct.pack("<H", 1)); f.write(struct.pack("<H", 2))
        f.write(struct.pack("<I", sr)); f.write(struct.pack("<I", byte_rate))
        f.write(struct.pack("<H", 4)); f.write(struct.pack("<H", 16))
        f.write(b"data"); f.write(struct.pack("<I", len(data))); f.write(data)


def colored_noise(n, beta):
    """FFT 기반 색 노이즈. beta=1 핑크(쉬-), beta=2 브라운(부드러운 쏴-).
    DFT는 주기적이므로 결과는 완벽히 루프된다(경계 이음매 없음)."""
    white = rng.standard_normal(n)
    X = np.fft.rfft(white)
    f = np.fft.rfftfreq(n)
    f[0] = f[1]
    X = X / (f ** (beta / 2.0))
    X[0] = 0.0  # DC 제거
    out = np.fft.irfft(X, n)
    m = np.max(np.abs(out))
    return out / m if m > 0 else out


def periodic_lfo(n, cycles, depth):
    """정확히 `cycles`번 반복하는 진폭 LFO(1-depth ~ 1). 루프 경계 연속."""
    t = np.arange(n)
    return (1.0 - depth) + depth * (0.5 + 0.5 * np.cos(2 * np.pi * cycles * t / n))


def lowpass(x, cutoff_norm):
    """간이 1-pole 저역통과(부드럽게). cutoff_norm: 0~1."""
    a = cutoff_norm
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def make_nature(kind, seconds):
    n = int(SR * seconds)
    if kind == "rain":
        l = colored_noise(n, 1.1) * 0.22
        r = colored_noise(n, 1.1) * 0.22
    elif kind == "ocean":
        base_l = colored_noise(n, 2.0)
        base_r = colored_noise(n, 2.0)
        swell = periodic_lfo(n, cycles=max(1, round(0.08 * seconds)), depth=0.6)
        l = base_l * swell * 0.30
        r = base_r * np.roll(swell, n // 7) * 0.30
    elif kind == "wind":
        base_l = colored_noise(n, 2.2)
        base_r = colored_noise(n, 2.2)
        gust = periodic_lfo(n, cycles=max(1, round(0.06 * seconds)), depth=0.7)
        l = base_l * gust * 0.20
        r = base_r * np.roll(gust, n // 5) * 0.20
    elif kind == "stream":
        # 중고역 강조 + 잔잔한 버블 변조
        l = colored_noise(n, 0.8) * 0.16
        r = colored_noise(n, 0.8) * 0.16
        bub = periodic_lfo(n, cycles=max(2, round(3.0 * seconds)), depth=0.25)
        l *= bub; r *= np.roll(bub, 137)
    elif kind == "forest":
        l = colored_noise(n, 1.6) * 0.10
        r = colored_noise(n, 1.6) * 0.10
        l, r = add_birds(l, r)
    elif kind == "fire":
        l = colored_noise(n, 2.0) * 0.12
        r = colored_noise(n, 2.0) * 0.12
        l, r = add_crackle(l, r)
    else:
        l = colored_noise(n, 1.5) * 0.15
        r = colored_noise(n, 1.5) * 0.15
    return l, r


def add_birds(l, r):
    """숲: 몇 개의 부드러운 새 지저귐(경계에서 떨어진 위치, 완전 감쇠)."""
    n = len(l)
    for _ in range(6):
        start = int(rng.uniform(0.1, 0.8) * n)
        dur = int(SR * rng.uniform(0.08, 0.18))
        if start + dur >= n:
            continue
        f0 = rng.uniform(2200, 3600)
        t = np.arange(dur) / SR
        chirp = np.sin(2 * np.pi * (f0 + rng.uniform(-200, 600) * t) * t)
        env = np.sin(np.pi * np.arange(dur) / dur) ** 2
        seg = chirp * env * rng.uniform(0.03, 0.06)
        pan = rng.uniform(0.2, 0.8)
        l[start:start + dur] += seg * (1 - pan)
        r[start:start + dur] += seg * pan
    return l, r


def add_crackle(l, r):
    """모닥불: 무작위 탁탁 튀는 소리."""
    n = len(l)
    for _ in range(40):
        start = int(rng.uniform(0.02, 0.95) * n)
        dur = int(SR * rng.uniform(0.004, 0.02))
        if start + dur >= n:
            continue
        pop = rng.standard_normal(dur) * np.exp(-np.linspace(0, 6, dur))
        amp = rng.uniform(0.05, 0.16)
        pan = rng.uniform(0.3, 0.7)
        l[start:start + dur] += pop * amp * (1 - pan)
        r[start:start + dur] += pop * amp * pan
    return l, r


def make_pad(base_hz, seconds, partials, amp=0.11):
    """느린 앰비언트 패드. 부분음 주파수를 루프 길이에 정수 배수로 맞춰 seamless."""
    n = int(SR * seconds)
    t = np.arange(n)
    l = np.zeros(n); r = np.zeros(n)
    for k, (mult, g) in enumerate(partials):
        f = base_hz * mult
        cycles = max(1, round(f * seconds))  # 정수 사이클 → 경계 연속
        ph = 2 * np.pi * cycles * t / n
        v = np.sin(ph) * g
        # 부분음마다 아주 느린 진폭 움직임(정수 사이클)
        mov = periodic_lfo(n, cycles=max(1, round((0.03 + 0.02 * k) * seconds)), depth=0.25)
        l += v * mov * (1.0 if k % 2 == 0 else 0.8)
        r += v * np.roll(mov, n // 6) * (0.8 if k % 2 == 0 else 1.0)
    peak = max(np.max(np.abs(l)), np.max(np.abs(r)), 1e-9)
    return l / peak * amp, r / peak * amp


def chime(seconds, freqs, decay):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    l = np.zeros(n); r = np.zeros(n)
    for f, g in freqs:
        env = np.exp(-np.arange(n) / (SR * decay))
        v = np.sin(2 * np.pi * f * t) * g * env
        l += v; r += v
    peak = max(np.max(np.abs(l)), np.max(np.abs(r)), 1e-9)
    return l / peak * 0.6, r / peak * 0.6


def main():
    nat = os.path.join(BASE, "nature")
    pad = os.path.join(BASE, "pads")
    chm = os.path.join(BASE, "chimes")
    for d in (nat, pad, chm):
        os.makedirs(d, exist_ok=True)

    nature = {
        "rain_soft": "rain", "forest_morning": "forest", "ocean_calm": "ocean",
        "stream_soft": "stream", "wind_light": "wind", "fire_soft": "fire",
    }
    for name, kind in nature.items():
        l, r = make_nature(kind, 8.0)  # 8초 루프(반복감 감소)
        write_int16_wav(os.path.join(nat, f"{name}_placeholder.wav"), l, r)

    pads = {
        "warm_air": (110.0, [(1, 0.5), (2, 0.28), (3, 0.14), (5, 0.07)]),
        "deep_space": (55.0, [(1, 0.5), (2, 0.22), (4, 0.12), (6, 0.06)]),
        "soft_light": (165.0, [(1, 0.5), (2, 0.26), (3, 0.14), (4, 0.08)]),
        "grounding_dark": (82.5, [(1, 0.5), (1.5, 0.2), (3, 0.12), (4.5, 0.06)]),
        "crystal_air": (220.0, [(1, 0.45), (2, 0.28), (3, 0.16), (5, 0.09)]),
    }
    for name, (base, parts) in pads.items():
        l, r = make_pad(base, 6.0, parts)
        write_int16_wav(os.path.join(pad, f"{name}_placeholder.wav"), l, r)

    chimes = {
        "bell_soft_01": ([(880, 0.5), (1320, 0.2), (2640, 0.06)], 1.3),
        "bell_soft_02": ([(988, 0.5), (1480, 0.2), (2960, 0.06)], 1.3),
        "bowl_low": ([(196, 0.5), (392, 0.25), (588, 0.12)], 2.8),
        "bowl_high": ([(432, 0.5), (864, 0.2), (1296, 0.1)], 2.4),
        "session_end": ([(528, 0.5), (792, 0.2), (1056, 0.08)], 3.2),
    }
    for name, (freqs, decay) in chimes.items():
        l, r = chime(3.2, freqs, decay)
        write_int16_wav(os.path.join(chm, f"{name}_placeholder.wav"), l, r)

    total = sum(len(os.listdir(d)) for d in (nat, pad, chm))
    print(f"placeholder assets written: {total} files under {BASE}")


if __name__ == "__main__":
    main()
