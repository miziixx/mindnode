"""마인드사운드 DSP 코어 (오프라인 검증용 Python 미러).

이 코드는 lib/core/audio/dsp_reference.dart 및 네이티브(Kotlin/Swift) 엔진과
**동일한 알고리즘·상수**를 사용한다. 렌더링은 속도를 위해 numpy 블록으로
구현하되, 위상 누산은 per-sample 누적(cumsum)과 수학적으로 동일하며 float32로
출력하여 네이티브 Float32 출력과 정합한다.

정본 상수(v1)는 PREBUILD_AUDIO_TEST_PLAN.md 참조.
"""
from __future__ import annotations
import numpy as np

TWO_PI = 2.0 * np.pi
LIMITER_CEILING_DB = -1.0


def db_to_lin(db: float) -> float:
    return float(10.0 ** (db / 20.0))


def limiter_ceiling_lin() -> float:
    return db_to_lin(LIMITER_CEILING_DB)


def wrap_phase(p: float) -> float:
    p = p % TWO_PI
    if p < 0:
        p += TWO_PI
    return p


class SineOscillator:
    """위상을 보존하는 사인 오실레이터. 좌/우 각각 인스턴스화."""

    def __init__(self, phase: float = 0.0):
        self.phase = float(phase)

    def render(self, freq, sr: int, n: int) -> np.ndarray:
        """freq: scalar 또는 길이 n 배열(주파수 램프). float32 반환.
        per-sample 위상 누적을 cumsum으로 정확히 재현하고 블록 끝에서 wrap."""
        if np.isscalar(freq):
            inc = TWO_PI * float(freq) / sr
            # phase at sample k = phase + inc*(k+1)  (advance THEN output? )
            # 네이티브: sample=sin(phase); phase+=inc  → 출력은 누적 전 위상.
            idx = np.arange(n, dtype=np.float64)
            ph = self.phase + inc * idx
            out = np.sin(ph).astype(np.float32)
            self.phase = wrap_phase(self.phase + inc * n)
        else:
            f = np.asarray(freq, dtype=np.float64)
            inc = TWO_PI * f / sr
            # 출력 위상 = 누적 이전 값: phase, phase+inc[0], phase+inc[0]+inc[1], ...
            cum = np.concatenate(([0.0], np.cumsum(inc)[:-1]))
            ph = self.phase + cum
            out = np.sin(ph).astype(np.float32)
            self.phase = wrap_phase(self.phase + float(np.sum(inc)))
        return out


class Ramp:
    """선형 파라미터 램프(게인/주파수 공용). per-sample 목표 이동."""

    def __init__(self, value: float):
        self.current = float(value)
        self.target = float(value)
        self._step = 0.0

    def set_target(self, value: float, sr: int, ms: float):
        self.target = float(value)
        ramp_samples = max(1.0, sr * ms / 1000.0)
        self._step = (self.target - self.current) / ramp_samples

    def snap(self, value: float):
        self.current = float(value)
        self.target = float(value)
        self._step = 0.0

    def render(self, n: int) -> np.ndarray:
        """길이 n 램프 배열 반환(오버슈트 클램프)."""
        out = np.empty(n, dtype=np.float64)
        c = self.current
        s = self._step
        t = self.target
        for i in range(n):
            if s == 0.0:
                out[i] = c
                continue
            c += s
            if (s > 0 and c >= t) or (s < 0 and c <= t):
                c = t
                s = 0.0
            out[i] = c
        self.current = c
        self._step = s
        return out


class DroneGenerator:
    """중심 주파수 기반 다중 사인 드론. Sub/Main/Air + 느린 진폭 LFO + 스테레오 폭."""

    def __init__(self):
        # 각 보이스 좌/우 독립 위상(서로 다른 초기 위상)
        self.sub_l = SineOscillator(0.0)
        self.sub_r = SineOscillator(0.3)
        self.main_l = SineOscillator(1.1)
        self.main_r = SineOscillator(1.4)
        self.air_l = SineOscillator(2.2)
        self.air_r = SineOscillator(2.5)
        self.lfo_l = SineOscillator(0.0)
        self.lfo_r = SineOscillator(np.pi / 2)

    def render(self, n, sr, center_hz, sub_ratio=0.35, main_ratio=0.55,
               air_ratio=0.10, movement_hz=0.05, stereo_width=0.25,
               lin_gain=1.0):
        nyq = sr * 0.5
        air_hz = center_hz * 2.0
        air_on = air_hz < nyq * 0.98

        lfo_l = 0.925 + 0.075 * self.lfo_l.render(movement_hz, sr, n)
        lfo_r = 0.925 + 0.075 * self.lfo_r.render(movement_hz, sr, n)

        l = sub_ratio * self.sub_l.render(center_hz * 0.5, sr, n)
        r = sub_ratio * self.sub_r.render(center_hz * 0.5, sr, n)
        l = l + main_ratio * self.main_l.render(center_hz, sr, n)
        r = r + main_ratio * self.main_r.render(center_hz, sr, n)
        if air_on:
            l = l + air_ratio * self.air_l.render(air_hz, sr, n)
            r = r + air_ratio * self.air_r.render(air_hz, sr, n)

        l = l * lfo_l * lin_gain
        r = r * lfo_r * lin_gain

        mid = 0.5 * (l + r)
        side = 0.5 * (l - r) * (1.0 + stereo_width)
        out_l = (mid + side).astype(np.float32)
        out_r = (mid - side).astype(np.float32)
        return out_l, out_r


class BinauralGenerator:
    """좌우 다른 주파수. 독립 위상, 모노 합산 없음."""

    def __init__(self):
        self.left = SineOscillator(0.0)
        self.right = SineOscillator(0.0)

    def render(self, n, sr, carrier_hz, beat_hz, invert=False, lin_gain=1.0):
        lhz = carrier_hz + beat_hz if invert else carrier_hz
        rhz = carrier_hz if invert else carrier_hz + beat_hz
        l = (self.left.render(lhz, sr, n) * lin_gain).astype(np.float32)
        r = (self.right.render(rhz, sr, n) * lin_gain).astype(np.float32)
        return l, r


class AmplitudePulseGenerator:
    """진폭 펄스. 주파수 변경 없이 사인형 진폭 변조."""

    def __init__(self):
        self.carrier = SineOscillator(0.0)
        self.mod_phase = 0.0  # 변조 위상(연속 보존)

    def render(self, n, sr, carrier_hz, rate_hz, depth, stereo='center',
               lin_gain=1.0):
        idx = np.arange(n, dtype=np.float64)
        mod_inc = TWO_PI * rate_hz / sr
        mph = self.mod_phase + mod_inc * idx
        env_l = (1.0 - depth) + depth * (0.5 + 0.5 * np.cos(mph))
        if stereo == 'alternate':
            env_r = (1.0 - depth) + depth * (0.5 + 0.5 * np.cos(mph + np.pi))
        else:
            env_r = env_l
        self.mod_phase = wrap_phase(self.mod_phase + mod_inc * n)

        c = self.carrier.render(carrier_hz, sr, n).astype(np.float64)
        l = (c * env_l * lin_gain).astype(np.float32)
        r = (c * env_r * lin_gain).astype(np.float32)
        return l, r


class SoftLimiter:
    """tanh 기반 소프트 리미터. NaN/Inf 세이프티 포함."""

    def __init__(self, ceiling_db=LIMITER_CEILING_DB):
        self.ceil = db_to_lin(ceiling_db)

    def process(self, x: np.ndarray) -> np.ndarray:
        x = np.nan_to_num(x, nan=0.0, posinf=0.0, neginf=0.0)
        y = self.ceil * np.tanh(x / self.ceil)
        return np.clip(y, -self.ceil, self.ceil).astype(np.float32)


def headroom_scale(active_layers: int) -> float:
    if active_layers <= 1:
        return 1.0
    return 1.0 / np.sqrt(active_layers)


class LayerMixer:
    """레이어 합산 → 헤드룸 → 마스터 게인 → 소프트 리미터."""

    def __init__(self, ceiling_db=LIMITER_CEILING_DB):
        self.limiter = SoftLimiter(ceiling_db)
        self.limiter_active_count = 0

    def mix(self, layers_lr, master_gain_lin=1.0, apply_headroom=True):
        """layers_lr: list of (l, r) float arrays. 반환 (l, r) float32."""
        if not layers_lr:
            n = 0
            return np.zeros(0, np.float32), np.zeros(0, np.float32)
        n = len(layers_lr[0][0])
        sum_l = np.zeros(n, np.float64)
        sum_r = np.zeros(n, np.float64)
        for (l, r) in layers_lr:
            sum_l += l
            sum_r += r
        scale = headroom_scale(len(layers_lr)) if apply_headroom else 1.0
        sum_l *= scale * master_gain_lin
        sum_r *= scale * master_gain_lin
        # 리미터 작동(입력이 ceiling 초과) 횟수 카운트
        self.limiter_active_count += int(np.count_nonzero(
            np.abs(sum_l) > self.limiter.ceil)) + int(np.count_nonzero(
            np.abs(sum_r) > self.limiter.ceil))
        out_l = self.limiter.process(sum_l)
        out_r = self.limiter.process(sum_r)
        return out_l, out_r
