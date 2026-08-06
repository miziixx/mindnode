#!/usr/bin/env python3
"""플레이스홀더 자연음/패드/차임 WAV 생성기.

⚠️ 실제 최종 음원이 아니다. 라이선스가 확인된 실제 음원으로 교체해야 한다(ASSET_GUIDE.md).
파일명에 'placeholder'를 명시한다. 자연음/패드는 seamless loop가 되도록 구간을
정수 주기로 맞추고, 차임은 감쇠하는 one-shot으로 만든다.

int16 PCM WAV(48kHz stereo)로 저장하여 용량을 작게 유지한다.
"""
import os
import struct
import math
import random

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BASE = os.path.join(ROOT, "assets", "audio")

random.seed(42)


def write_int16_wav(path, left, right, sr=SR):
    n = min(len(left), len(right))
    frames = bytearray()
    for i in range(n):
        l = max(-1.0, min(1.0, left[i]))
        r = max(-1.0, min(1.0, right[i]))
        frames += struct.pack('<hh', int(l * 32767), int(r * 32767))
    data = bytes(frames)
    byte_rate = sr * 2 * 2
    with open(path, 'wb') as f:
        f.write(b'RIFF'); f.write(struct.pack('<I', 36 + len(data))); f.write(b'WAVE')
        f.write(b'fmt '); f.write(struct.pack('<I', 16))
        f.write(struct.pack('<H', 1)); f.write(struct.pack('<H', 2))
        f.write(struct.pack('<I', sr)); f.write(struct.pack('<I', byte_rate))
        f.write(struct.pack('<H', 4)); f.write(struct.pack('<H', 16))
        f.write(b'data'); f.write(struct.pack('<I', len(data))); f.write(data)


def fade_edges(buf, ms=8):
    """루프 경계 클릭 방지용 짧은 크로스 페이드(경계 매끄럽게)."""
    k = int(SR * ms / 1000)
    n = len(buf)
    for i in range(k):
        g = i / k
        buf[i] *= g
        buf[n - 1 - i] *= g
    return buf


def loop_noise(seconds, lp, amp):
    """저역 통과된 소프트 노이즈(비/바람/바다 계열 placeholder)."""
    n = int(SR * seconds)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        w = random.uniform(-1, 1)
        prev = prev + lp * (w - prev)  # 1-pole LP
        out[i] = prev * amp
    return out


def loop_pad(seconds, base_hz, partials, amp):
    """느린 화음 패드 placeholder(정수 주기 루프)."""
    n = int(SR * seconds)
    l = [0.0] * n
    r = [0.0] * n
    for k, (mult, g) in enumerate(partials):
        f = base_hz * mult
        for i in range(n):
            ph = 2 * math.pi * f * i / SR
            v = math.sin(ph) * g * amp
            l[i] += v * (1.0 if k % 2 == 0 else 0.85)
            r[i] += v * (0.85 if k % 2 == 0 else 1.0)
    return l, r


def chime(seconds, freqs, decay):
    """감쇠하는 종/싱잉볼 placeholder(one-shot)."""
    n = int(SR * seconds)
    l = [0.0] * n
    r = [0.0] * n
    for f, g in freqs:
        for i in range(n):
            env = math.exp(-i / (SR * decay))
            v = math.sin(2 * math.pi * f * i / SR) * g * env
            l[i] += v
            r[i] += v
    return l, r


def main():
    nat = os.path.join(BASE, "nature")
    pad = os.path.join(BASE, "pads")
    chm = os.path.join(BASE, "chimes")
    for d in (nat, pad, chm):
        os.makedirs(d, exist_ok=True)

    # 자연음(placeholder): 저역 노이즈 계열 4초 루프
    nature = {
        "rain_soft": (0.4, 0.18), "forest_morning": (0.15, 0.12),
        "ocean_calm": (0.05, 0.2), "stream_soft": (0.6, 0.15),
        "wind_light": (0.08, 0.14), "fire_soft": (0.5, 0.13),
    }
    for name, (lp, amp) in nature.items():
        l = fade_edges(loop_noise(4, lp, amp))
        r = fade_edges(loop_noise(4, lp, amp))
        write_int16_wav(os.path.join(nat, f"{name}_placeholder.wav"), l, r)

    # 패드(placeholder): 저음량 화음 2초 루프(정수 주기)
    pads = {
        "warm_air": 110.0, "deep_space": 55.0, "soft_light": 165.0,
        "grounding_dark": 82.5, "crystal_air": 220.0,
    }
    partials = [(1.0, 0.5), (2.0, 0.25), (3.0, 0.12), (5.0, 0.06)]
    for name, base in pads.items():
        # 2초에 정수 주기가 되도록 base를 0.5Hz 배수로 근사(루프 매끄럽게)
        base_q = round(base * 2) / 2.0
        l, r = loop_pad(2.0, base_q, partials, 0.12)
        write_int16_wav(os.path.join(pad, f"{name}_placeholder.wav"),
                        fade_edges(l), fade_edges(r))

    # 차임(placeholder): 감쇠 one-shot
    chimes = {
        "bell_soft_01": ([(880, 0.5), (1320, 0.2)], 1.2),
        "bell_soft_02": ([(988, 0.5), (1480, 0.2)], 1.2),
        "bowl_low": ([(196, 0.5), (392, 0.25), (588, 0.1)], 2.5),
        "bowl_high": ([(432, 0.5), (864, 0.2), (1296, 0.1)], 2.2),
        "session_end": ([(528, 0.5), (792, 0.2)], 3.0),
    }
    for name, (freqs, decay) in chimes.items():
        l, r = chime(3.0, freqs, decay)
        write_int16_wav(os.path.join(chm, f"{name}_placeholder.wav"), l, r)

    total = sum(len(os.listdir(d)) for d in (nat, pad, chm))
    print(f"placeholder assets written: {total} files under {BASE}")


if __name__ == "__main__":
    main()
