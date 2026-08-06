"""오디오 분석기. FFT peak(포물선 보간), Goertzel, RMS/peak/DC, NaN/Inf,
클리핑, 위상 연속성, 클릭 탐지, 해석적 엔벌로프 변조 주파수."""
from __future__ import annotations
import numpy as np


def measure_frequency(x: np.ndarray, sr: int) -> float:
    """Hann 윈도우 rFFT + 로그크기 2차(포물선) 보간으로 주파수 추정."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    if n < 4:
        return 0.0
    w = np.hanning(n)
    xw = x * w
    spec = np.abs(np.fft.rfft(xw))
    if spec.max() <= 0:
        return 0.0
    k = int(np.argmax(spec[1:])) + 1  # DC 제외
    if k <= 0 or k >= len(spec) - 1:
        return k * sr / n
    # 로그 크기 포물선 보간(정점 이동량 delta ∈ [-0.5,0.5])
    a = np.log(spec[k - 1] + 1e-20)
    b = np.log(spec[k] + 1e-20)
    c = np.log(spec[k + 1] + 1e-20)
    denom = (a - 2 * b + c)
    delta = 0.0 if denom == 0 else 0.5 * (a - c) / denom
    return (k + delta) * sr / n


def goertzel_magnitude(x: np.ndarray, sr: int, freq: float) -> float:
    """특정 주파수의 Goertzel 크기(정규화)."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    k = freq / sr
    w = 2.0 * np.pi * k
    coeff = 2.0 * np.cos(w)
    s0 = s1 = s2 = 0.0
    for sample in x:
        s0 = sample + coeff * s1 - s2
        s2 = s1
        s1 = s0
    power = s1 * s1 + s2 * s2 - coeff * s1 * s2
    return float(np.sqrt(max(power, 0.0)) / n * 2.0)


def second_peak_ratio(x: np.ndarray) -> float:
    """최대 peak 대비 두 번째 peak 비율(스펙트럼 순도 지표)."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    w = np.hanning(n)
    spec = np.abs(np.fft.rfft(x * w))
    if spec[1:].max() <= 0:
        return 0.0
    k = int(np.argmax(spec[1:])) + 1
    m = spec.copy()
    lo = max(1, k - 3)
    hi = min(len(m), k + 4)
    m[lo:hi] = 0
    second = m[1:].max()
    return float(second / spec[k])


def rms(x: np.ndarray) -> float:
    x = np.asarray(x, dtype=np.float64)
    return float(np.sqrt(np.mean(x * x))) if len(x) else 0.0


def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x))) if len(x) else 0.0


def dc_offset(x: np.ndarray) -> float:
    return float(np.mean(x)) if len(x) else 0.0


def dc_offset_whole_cycles(x: np.ndarray) -> float:
    """정수 사이클 구간(첫 상승 영교차 ~ 마지막 상승 영교차) 평균으로 DC 측정.
    유한 사인 구간의 부분-사이클 평균(윈도잉 아티팩트)을 제거하여
    엔진이 실제로 부가한 DC 바이어스만 드러낸다. 근거는 리포트에 설명."""
    x = np.asarray(x, dtype=np.float64)
    if len(x) < 4:
        return float(np.mean(x)) if len(x) else 0.0
    s = np.sign(x)
    # 상승(-→+) 영교차 인덱스
    cross = np.where((s[:-1] <= 0) & (s[1:] > 0))[0]
    if len(cross) < 2:
        return float(np.mean(x))
    a, b = cross[0] + 1, cross[-1] + 1
    seg = x[a:b]
    return float(np.mean(seg)) if len(seg) else float(np.mean(x))


def count_nan(x: np.ndarray) -> int:
    return int(np.count_nonzero(np.isnan(x)))


def count_inf(x: np.ndarray) -> int:
    return int(np.count_nonzero(np.isinf(x)))


def count_clipping(x: np.ndarray, ceil: float = 1.0) -> int:
    x = np.asarray(x, dtype=np.float64)
    return int(np.count_nonzero(np.abs(x) > ceil + 1e-6))


def to_dbfs(v: float) -> float:
    return -200.0 if v <= 1e-10 else float(20.0 * np.log10(v))


def phase_continuity_error(a: np.ndarray, b: np.ndarray) -> float:
    """두 렌더 출력의 최대 절대 오차(위상 보존 검증)."""
    m = min(len(a), len(b))
    if m == 0:
        return float('inf')
    return float(np.max(np.abs(np.asarray(a[:m], np.float64) -
                                np.asarray(b[:m], np.float64))))


def detect_clicks(x: np.ndarray, freq: float, sr: int, amp: float,
                  margin: float = 6.0):
    """클릭 탐지: 인접 샘플 변화가 사인 최대 기울기의 margin배를 넘으면 클릭.
    사인 최대 기울기(per sample) = amp * 2π f / sr. 반환: 클릭 샘플 인덱스 목록."""
    x = np.asarray(x, dtype=np.float64)
    if len(x) < 2:
        return []
    diff = np.abs(np.diff(x))
    max_slope = amp * 2.0 * np.pi * max(freq, 1.0) / sr
    thresh = max_slope * margin + 1e-6
    idx = np.where(diff > thresh)[0]
    return idx.tolist()


def envelope_modulation_freq(x: np.ndarray, sr: int) -> float:
    """해석적(Hilbert) 엔벌로프의 지배적 변조 주파수(펄스/드론 LFO 측정)."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    if n < 8:
        return 0.0
    # FFT 기반 Hilbert 변환으로 해석적 신호 생성
    Xf = np.fft.fft(x)
    h = np.zeros(n)
    if n % 2 == 0:
        h[0] = h[n // 2] = 1
        h[1:n // 2] = 2
    else:
        h[0] = 1
        h[1:(n + 1) // 2] = 2
    analytic = np.fft.ifft(Xf * h)
    env = np.abs(analytic)
    env = env - np.mean(env)  # DC 제거
    if np.max(np.abs(env)) < 1e-9:
        return 0.0
    return measure_frequency(env, sr)


def slow_envelope_freq(x: np.ndarray, sr: int, hop: int = 2048) -> float:
    """느린 진폭 변화(드론 LFO, <1Hz) 측정.
    hop 프레임 단위 RMS로 고주파 보이스 간 비팅을 평균 제거한 뒤,
    남은 저속 엔벌로프의 지배 주파수를 측정한다."""
    x = np.asarray(x, dtype=np.float64)
    n = len(x)
    frames = n // hop
    if frames < 8:
        return 0.0
    seg = x[:frames * hop].reshape(frames, hop)
    env = np.sqrt(np.mean(seg * seg, axis=1))  # 프레임 RMS
    env = env - np.mean(env)
    if np.max(np.abs(env)) < 1e-9:
        return 0.0
    frame_sr = sr / hop
    return measure_frequency(env, frame_sr)


def channel_crosstalk(target_ch: np.ndarray, other_freq: float, sr: int,
                      ref_mag: float) -> float:
    """target_ch 에서 other_freq 성분 크기 / ref_mag (누화 비율)."""
    if ref_mag <= 0:
        return 0.0
    return goertzel_magnitude(target_ch, sr, other_freq) / ref_mag
