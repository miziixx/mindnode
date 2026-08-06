"""오프라인 블록 렌더러. 실제 기기 출력 없이 PCM 생성.
버퍼 크기가 바뀌어도 위상이 유지되는지 검증하기 위한 헬퍼 포함."""
from __future__ import annotations
import numpy as np
from dsp import SineOscillator, Ramp


def block_iter(total: int, block_sizes):
    """total 프레임을 block_sizes(순환)로 분할하는 크기 시퀀스 생성."""
    i = 0
    remaining = total
    while remaining > 0:
        b = block_sizes[i % len(block_sizes)]
        b = min(b, remaining)
        yield b
        remaining -= b
        i += 1


def render_tone_blocks(freq, sr, total, block_sizes, amp=1.0,
                       phase0=0.0, reset_each_block=False):
    """단일 톤을 블록 단위로 렌더. reset_each_block=True면 위상 초기화 버그 재현."""
    osc = SineOscillator(phase0)
    out = np.empty(total, dtype=np.float32)
    pos = 0
    for b in block_iter(total, block_sizes):
        if reset_each_block:
            osc.phase = phase0  # 버그: 매 블록 위상 리셋
        out[pos:pos + b] = osc.render(freq, sr, b) * amp
        pos += b
    return out[:pos]


def render_tone_contiguous(freq, sr, total, amp=1.0, phase0=0.0):
    osc = SineOscillator(phase0)
    return (osc.render(freq, sr, total) * amp).astype(np.float32)


def render_freq_ramp(f0, f1, ramp_ms, sr, total, amp=1.0, block=256):
    """주파수 램프 톤. FrequencyRamp로 per-sample 주파수 생성 후 osc 적용."""
    osc = SineOscillator(0.0)
    framp = Ramp(f0)
    framp.set_target(f1, sr, ramp_ms)
    out = np.empty(total, dtype=np.float32)
    pos = 0
    for b in block_iter(total, [block]):
        farr = framp.render(b)
        out[pos:pos + b] = osc.render(farr, sr, b) * amp
        pos += b
    return out[:pos]


def render_gain_fade(freq, sr, total, g0, g1, fade_ms, amp=1.0, block=256):
    """게인 페이드 톤. GainRamp 적용."""
    osc = SineOscillator(0.0)
    gramp = Ramp(g0)
    gramp.set_target(g1, sr, fade_ms)
    out = np.empty(total, dtype=np.float32)
    pos = 0
    for b in block_iter(total, [block]):
        garr = gramp.render(b)
        out[pos:pos + b] = osc.render(freq, sr, b) * amp * garr
        pos += b
    return out[:pos]


def render_drift_windows(freq, sr, total_frames, window_starts, window_len,
                         block=8192):
    """60분 상당 신호를 블록 단위로 생성하되 지정 구간만 보관(메모리 절약).
    window_starts: 프레임 시작 위치 목록. 반환: {start: array}."""
    osc = SineOscillator(0.0)
    windows = {s: np.empty(window_len, dtype=np.float32) for s in window_starts}
    filled = {s: 0 for s in window_starts}
    pos = 0
    while pos < total_frames:
        b = min(block, total_frames - pos)
        chunk = osc.render(freq, sr, b)
        for s in window_starts:
            wstart, wend = s, s + window_len
            a = max(pos, wstart)
            bb = min(pos + b, wend)
            if a < bb:
                dst0 = a - wstart
                src0 = a - pos
                length = bb - a
                windows[s][dst0:dst0 + length] = chunk[src0:src0 + length]
                filled[s] += length
        pos += b
    return windows, filled
