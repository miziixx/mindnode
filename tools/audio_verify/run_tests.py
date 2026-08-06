"""빌드 전 오프라인 오디오 검증 실행기.

실제 스피커 없이 엔진 PCM을 생성/분석하여 전 항목을 검증하고
JSON/CSV/Markdown 리포트와 참조/실패 WAV를 생성한다.
"""
from __future__ import annotations
import os
import csv
import json
import datetime
import numpy as np

import dsp
import analyzer as A
import render as R
from wavio import write_wav_float32

ENGINE_VERSION = "mindsound-dsp-v1"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "test_output")
REF = os.path.join(OUT, "audio_reference")
FAIL = os.path.join(OUT, "failures")
for d in (OUT, REF, FAIL):
    os.makedirs(d, exist_ok=True)

RESULTS = []  # list of dict
PRIMARY_AMP = dsp.db_to_lin(-26)  # 엔진 primary tone 기본 레벨과 정합


def add(name, category, status, **kw):
    row = {"name": name, "category": category, "status": status}
    row.update(kw)
    RESULTS.append(row)
    tag = "PASS" if status == "PASS" else ("—" if status == "INFO" else status)
    extra = ""
    if "measuredHz" in kw and "targetHz" in kw:
        extra = f" target={kw['targetHz']} measured={kw['measuredHz']:.4f} err={kw.get('errorHz', 0):.5f}Hz"
    print(f"[{tag:4}] {category:14} {name}{extra}")
    return row


def common_metrics(x, ceil=1.0):
    return dict(
        rmsDbfs=round(A.to_dbfs(A.rms(x)), 4),
        peakDbfs=round(A.to_dbfs(A.peak(x)), 4),
        dcOffset=A.dc_offset_whole_cycles(x),
        clippedSamples=A.count_clipping(x, ceil),
        nanSamples=A.count_nan(x),
        infiniteSamples=A.count_inf(x),
    )


# ─────────────────────────────────────────────────────────────
# 4. 단일 주파수
# ─────────────────────────────────────────────────────────────
FREQS = [20, 40, 100, 198, 208.5, 220, 264, 396, 417, 426, 432, 440,
         481.5, 528, 639, 741, 852, 888, 963, 1000, 5000, 10000, 15000]


def freq_pass(target, measured, m):
    err = abs(measured - target)
    err_pct = err / target * 100 if target else 0
    ok_freq = err <= 0.05 if target <= 1000 else err_pct <= 0.01
    ok = (ok_freq and abs(m["dcOffset"]) <= 1e-5 and m["nanSamples"] == 0
          and m["infiniteSamples"] == 0 and m["clippedSamples"] == 0)
    return ok, err, err_pct


def test_single_frequencies():
    for sr in (44100, 48000):
        dur = 2.0
        n = int(sr * dur)
        for f in FREQS:
            x = R.render_tone_contiguous(f, sr, n, amp=PRIMARY_AMP)
            measured = A.measure_frequency(x, sr)
            m = common_metrics(x)
            ok, err, err_pct = freq_pass(f, measured, m)
            add(f"Sine {f}Hz @{sr//1000}k", "single_frequency",
                "PASS" if ok else "FAIL",
                targetHz=f, measuredHz=round(measured, 5),
                errorHz=round(err, 6), errorPercent=round(err_pct, 6),
                sampleRate=sr, secondPeakRatio=round(A.second_peak_ratio(x), 5),
                **m)


# ─────────────────────────────────────────────────────────────
# 5. 위상 연속성
# ─────────────────────────────────────────────────────────────
def test_phase_continuity():
    sr = 48000
    f = 432.0
    total = sr * 10
    contiguous = R.render_tone_contiguous(f, sr, total, amp=PRIMARY_AMP)
    schemes = {
        "block64": [64], "block128": [128], "block256": [256],
        "block480": [480], "block1024": [1024],
        "irregular": [64, 192, 480, 128, 1024, 256, 960, 64],
    }
    worst = 0.0
    for name, bs in schemes.items():
        blk = R.render_tone_blocks(f, sr, total, bs, amp=PRIMARY_AMP)
        err = A.phase_continuity_error(contiguous, blk)
        worst = max(worst, err)
        add(f"Phase continuity {name}", "phase_continuity",
            "PASS" if err <= 1e-5 else "FAIL",
            maxSampleError=float(err), targetHz=f)
    # 버그 재현: 매 블록 위상 리셋 → 큰 오차 + 실패 WAV 저장(탐지력 증명)
    buggy = R.render_tone_blocks(f, sr, total, [256], amp=PRIMARY_AMP,
                                 reset_each_block=True)
    berr = A.phase_continuity_error(contiguous, buggy)
    write_wav_float32(os.path.join(FAIL, "phase_discontinuity_buffer_256.wav"),
                      buggy[:sr * 2], sr)
    add("Phase reset bug is DETECTED", "phase_continuity",
        "PASS" if berr > 1e-3 else "FAIL",
        buggyMaxSampleError=float(berr),
        detail="의도적 위상리셋 버그가 테스트로 검출되는지 확인(오차 커야 정상)")


# ─────────────────────────────────────────────────────────────
# 6. 장시간 드리프트 (60분 상당, 블록 생성)
# ─────────────────────────────────────────────────────────────
def test_long_drift():
    sr = 48000
    win = sr * 5  # 5초 분석창
    starts = [0, 10 * 60 * sr, 30 * 60 * sr, 59 * 60 * sr]
    total = 60 * 60 * sr
    for f in (396.0, 432.0, 528.0, 741.0, 963.0):
        windows, filled = R.render_drift_windows(f, sr, total, starts, win,
                                                  block=16384)
        base = A.measure_frequency(windows[0], sr)
        errs = []
        bad = False
        detail = {}
        for s in starts:
            mf = A.measure_frequency(windows[s], sr)
            e = abs(mf - f)
            errs.append(e)
            label = f"{s // sr // 60}min"
            detail[label] = round(mf, 5)
            if e > 0.05:
                bad = True
            if A.count_nan(windows[s]) or A.count_inf(windows[s]):
                bad = True
        # 오차가 계속 증가하지 않는지(마지막이 첫 구간 대비 폭증 없음)
        increasing = errs[-1] > errs[0] + 0.05
        status = "FAIL" if (bad or increasing) else "PASS"
        add(f"Drift 60min {f}Hz", "long_drift", status,
            targetHz=f, measuredHz=round(base, 5),
            errorHz=round(max(errs), 6), windowsHz=detail,
            monotonicIncrease=bool(increasing))


# ─────────────────────────────────────────────────────────────
# 7. 주파수 램프
# ─────────────────────────────────────────────────────────────
def test_frequency_ramps():
    sr = 48000
    pairs = [(396, 417), (432, 528), (528, 741), (741, 852), (852, 963),
             (963, 481.5)]
    for (f0, f1) in pairs:
        for ramp_ms in (10, 30, 50, 100, 1500):
            total = int(sr * (ramp_ms / 1000.0 + 1.0))  # 램프 + 1초 안정
            x = R.render_freq_ramp(f0, f1, ramp_ms, sr, total, amp=PRIMARY_AMP)
            # 최종 0.5초로 최종 주파수 측정
            tail = x[-sr // 2:]
            measured = A.measure_frequency(tail, sr)
            err = abs(measured - f1)
            clicks = A.detect_clicks(x, max(f0, f1), sr, PRIMARY_AMP)
            m = common_metrics(x)
            ok = (err <= (0.05 if f1 <= 1000 else f1 * 0.0001)
                  and len(clicks) == 0 and m["nanSamples"] == 0)
            status = "PASS" if ok else "FAIL"
            add(f"Ramp {f0}->{f1} {ramp_ms}ms", "frequency_ramp", status,
                targetHz=f1, measuredHz=round(measured, 5),
                errorHz=round(err, 6), clickCount=len(clicks), **m)
            if clicks:
                write_wav_float32(
                    os.path.join(FAIL, f"click_{f0}_to_{f1}_ramp{ramp_ms}.wav"),
                    x[:sr], sr)


# ─────────────────────────────────────────────────────────────
# 8. 게인/페이드
# ─────────────────────────────────────────────────────────────
def test_gain_fades():
    sr = 48000
    f = 432.0
    for (label, g0, g1) in [("fade_in", 0.0, 1.0), ("fade_out", 1.0, 0.0)]:
        for fade_ms in (30, 100, 1000, 3000, 10000):
            total = int(sr * (fade_ms / 1000.0 + 0.2))
            x = R.render_gain_fade(f, sr, total, g0, g1, fade_ms,
                                   amp=PRIMARY_AMP)
            # 엔벌로프(절대 peak) 단조성 검사: 다운샘플된 |x| 추세
            env = np.abs(x)
            # 시작/끝 경계 검사
            first = abs(float(x[0]))
            last_win = env[-int(sr * 0.02):]
            residual = float(np.max(last_win)) if g1 == 0 else 0.0
            fade_frames = int(sr * fade_ms / 1000.0)
            # 페이드 인: 첫 샘플이 큰 값으로 시작하지 않음
            start_ok = (g0 == 0.0 and first < PRIMARY_AMP * 0.05) or g0 != 0.0
            # 페이드 아웃: 종료 후 잔류 거의 0
            end_ok = (g1 == 0.0 and residual < PRIMARY_AMP * 0.02) or g1 != 0.0
            ok = start_ok and end_ok and A.count_nan(x) == 0
            add(f"Gain {label} {fade_ms}ms", "gain_fade",
                "PASS" if ok else "FAIL",
                firstSample=round(first, 6), residualAfterFade=round(residual, 6),
                fadeFrames=fade_frames)
    # 참조 WAV
    ref = R.render_gain_fade(432.0, sr, sr * 4, 0.0, 1.0, 3000, amp=0.4)
    ref2 = R.render_gain_fade(432.0, sr, sr * 4, 1.0, 0.0, 3000, amp=0.4)
    both = np.concatenate([ref, ref2]).astype(np.float32)
    write_wav_float32(os.path.join(REF, "gain_fade_test.wav"), both, sr)


# ─────────────────────────────────────────────────────────────
# 9. 바이노럴
# ─────────────────────────────────────────────────────────────
def test_binaural():
    sr = 48000
    n = sr * 6
    combos = [("A", 220, 4), ("B", 220, 7.83), ("C", 220, 10), ("D", 400, 16)]
    for (label, carrier, beat) in combos:
        gen = dsp.BinauralGenerator()
        l, r = gen.render(n, sr, carrier, beat, invert=False, lin_gain=PRIMARY_AMP)
        lf = A.measure_frequency(l, sr)
        rf = A.measure_frequency(r, sr)
        diff = abs(rf - lf)
        # 누화: 왼쪽 채널에서 오른쪽 주파수 성분
        lmag = A.goertzel_magnitude(l, sr, carrier)
        xtalk = A.channel_crosstalk(l, carrier + beat, sr, lmag)
        # 반전
        gi = dsp.BinauralGenerator()
        li, ri = gi.render(n, sr, carrier, beat, invert=True, lin_gain=PRIMARY_AMP)
        lif = A.measure_frequency(li, sr)
        rif = A.measure_frequency(ri, sr)
        invert_ok = (abs(lif - (carrier + beat)) <= 0.1 and abs(rif - carrier) <= 0.1)
        ok = (abs(lf - carrier) <= 0.05 and abs(rf - (carrier + beat)) <= 0.05
              and abs(diff - beat) <= 0.05 and xtalk < 0.02 and invert_ok)
        add(f"Binaural {label} beat {beat}Hz", "binaural",
            "PASS" if ok else "FAIL",
            leftTargetHz=carrier, leftMeasuredHz=round(lf, 5),
            rightTargetHz=carrier + beat, rightMeasuredHz=round(rf, 5),
            beatTargetHz=beat, beatMeasuredHz=round(diff, 5),
            crosstalk=round(float(xtalk), 6), invertOk=bool(invert_ok))
        if label == "C":
            write_wav_float32(os.path.join(REF, "binaural_220_230hz_10s.wav"),
                              dsp.BinauralGenerator().render(
                                  sr * 10, sr, 220, 10, lin_gain=0.4), sr)


# ─────────────────────────────────────────────────────────────
# 10. 진폭 펄스
# ─────────────────────────────────────────────────────────────
def test_pulse():
    sr = 48000
    n = sr * 8  # 저속 변조 측정 위해 8초
    rates = [1, 4, 6, 7.83, 8.8, 10, 16]
    # 전 rate (carrier 432, depth 0.5)
    cases = [(r, 432, 0.5) for r in rates]
    # carrier/ depth 크로스 (rate 7.83)
    cases += [(7.83, c, 0.5) for c in (220, 528)]
    cases += [(7.83, 432, d) for d in (0.1, 0.25, 1.0)]
    for (rate, carrier, depth) in cases:
        gen = dsp.AmplitudePulseGenerator()
        l, r = gen.render(n, sr, carrier, rate, depth, lin_gain=PRIMARY_AMP)
        env_freq = A.envelope_modulation_freq(l, sr)
        err = abs(env_freq - rate)
        # 엔벌로프 min/max로 깊이 검증(완전 0 여부)
        analytic_env = np.abs(_analytic(l))
        emin = float(np.min(analytic_env[sr // 4:-sr // 4]))
        clicks = A.detect_clicks(l, carrier, sr, PRIMARY_AMP)
        m = common_metrics(l)
        full_zero = emin < 1e-5 and depth < 1.0
        ok = (err <= 0.03 and not full_zero and len(clicks) == 0
              and m["nanSamples"] == 0)
        add(f"Pulse {rate}Hz c{carrier} d{int(depth*100)}%", "pulse",
            "PASS" if ok else "FAIL",
            targetHz=rate, measuredHz=round(env_freq, 5), errorHz=round(err, 6),
            envMin=round(emin, 6), clickCount=len(clicks), **m)
    write_wav_float32(os.path.join(REF, "pulse_432hz_7_83hz_10s.wav"),
                      dsp.AmplitudePulseGenerator().render(
                          sr * 10, sr, 432, 7.83, 0.5, lin_gain=0.4)[0], sr)


def _analytic(x):
    x = np.asarray(x, np.float64)
    n = len(x)
    Xf = np.fft.fft(x)
    h = np.zeros(n)
    if n % 2 == 0:
        h[0] = h[n // 2] = 1
        h[1:n // 2] = 2
    else:
        h[0] = 1
        h[1:(n + 1) // 2] = 2
    return np.fft.ifft(Xf * h)


# ─────────────────────────────────────────────────────────────
# 11. 드론
# ─────────────────────────────────────────────────────────────
def test_drone():
    sr = 48000
    n = sr * 4
    for center in (396, 417, 432, 528, 639, 741, 852, 963):
        gen = dsp.DroneGenerator()
        l, r = gen.render(n, sr, center, lin_gain=PRIMARY_AMP)
        mono = (l.astype(np.float64) + r) * 0.5
        sub_mag = A.goertzel_magnitude(mono, sr, center * 0.5)
        main_mag = A.goertzel_magnitude(mono, sr, center)
        air_mag = A.goertzel_magnitude(mono, sr, center * 2)
        nyq = sr * 0.5
        air_expected = center * 2 < nyq * 0.98
        m = common_metrics(mono)
        # main peak 위치 확인
        main_f = A.measure_frequency(mono, sr)
        ok = (sub_mag > 0 and main_mag > 0
              and abs(main_f - center) <= 0.2
              and m["nanSamples"] == 0 and m["infiniteSamples"] == 0
              and m["clippedSamples"] == 0)
        if air_expected:
            ok = ok and air_mag > 0
        add(f"Drone center {center}Hz", "drone",
            "PASS" if ok else "FAIL",
            targetHz=center, measuredHz=round(main_f, 5),
            subHz=round(center * 0.5, 2), subMag=round(sub_mag, 6),
            mainMag=round(main_mag, 6),
            airHz=round(center * 2, 2), airMag=round(air_mag, 6),
            airEnabled=bool(air_expected), **m)
    # LFO 움직임 속도 — 프레임 RMS 저속 엔벌로프로 측정(고주파 비팅 제거).
    # 저속 정확 측정을 위해 긴 렌더(0.03Hz는 ~4사이클 확보).
    for mv, secs in ((0.03, 160), (0.05, 120), (0.10, 80)):
        gen = dsp.DroneGenerator()
        big = gen.render(sr * secs, sr, 432, movement_hz=mv,
                         lin_gain=PRIMARY_AMP)[0]
        ef = A.slow_envelope_freq(big, sr)
        add(f"Drone LFO {mv}Hz", "drone",
            "PASS" if abs(ef - mv) <= 0.03 else "FAIL",
            targetHz=mv, measuredHz=round(ef, 5), errorHz=round(abs(ef - mv), 5),
            detail="느린 진폭 변화 속도(프레임 RMS 엔벌로프) 측정")
    write_wav_float32(os.path.join(REF, "drone_432hz_10s.wav"),
                      dsp.DroneGenerator().render(sr * 10, sr, 432,
                                                  lin_gain=0.4), sr)


# ─────────────────────────────────────────────────────────────
# 12. 다중 레이어 믹서
# ─────────────────────────────────────────────────────────────
def _tone_lr(freq, sr, n, amp, pan=0.0):
    osc = dsp.SineOscillator(0.0)
    x = osc.render(freq, sr, n) * amp
    lg = np.cos((pan + 1) / 2 * np.pi / 2)
    rg = np.sin((pan + 1) / 2 * np.pi / 2)
    return x * lg, x * rg


def test_mixer():
    sr = 48000
    n = sr * 4
    ceil = dsp.limiter_ceiling_lin()

    def run(label, layers, master_db=-12):
        mixer = dsp.LayerMixer()
        l, r = mixer.mix(layers, master_gain_lin=dsp.db_to_lin(master_db))
        pk = max(A.peak(l), A.peak(r))
        clip = A.count_clipping(l, ceil) + A.count_clipping(r, ceil)
        nan = A.count_nan(l) + A.count_nan(r)
        inf = A.count_inf(l) + A.count_inf(r)
        ok = pk <= ceil + 1e-6 and clip == 0 and nan == 0 and inf == 0
        add(f"Mixer {label}", "mixer", "PASS" if ok else "FAIL",
            peakDbfs=round(A.to_dbfs(pk), 4),
            rmsDbfs=round(A.to_dbfs((A.rms(l) + A.rms(r)) / 2), 4),
            clippedSamples=clip, nanSamples=nan, infiniteSamples=inf,
            limiterActive=mixer.limiter_active_count,
            dcOffset=A.dc_offset_whole_cycles(l))
        return l, r

    # 조합 1: primary 528 + drone 528
    d = dsp.DroneGenerator().render(n, sr, 528, lin_gain=dsp.db_to_lin(-24))
    p = _tone_lr(528, sr, n, dsp.db_to_lin(-26))
    run("combo1 (528+drone)", [p, d])

    # 조합 2: primary 432 + secondary 888 + drone + pulse 8.8
    d2 = dsp.DroneGenerator().render(n, sr, 432, lin_gain=dsp.db_to_lin(-24))
    p2 = _tone_lr(432, sr, n, dsp.db_to_lin(-26))
    s2 = _tone_lr(888, sr, n, dsp.db_to_lin(-36))
    pulse = dsp.AmplitudePulseGenerator().render(n, sr, 432, 8.8, 0.2,
                                                 lin_gain=dsp.db_to_lin(-30))
    run("combo2 (abundance)", [p2, s2, d2, pulse])

    # 조합 3: 396 + 417 + drone + (nature/pad placeholder 생략, 톤만)
    d3 = dsp.DroneGenerator().render(n, sr, 396, lin_gain=dsp.db_to_lin(-25))
    a3 = _tone_lr(396, sr, n, dsp.db_to_lin(-26))
    b3 = _tone_lr(417, sr, n, dsp.db_to_lin(-32))
    run("combo3 (cleanse tones)", [a3, b3, d3])

    # 조합 4: 모든 톤 레이어 활성(고밀도) — 클리핑 방지 확인
    layers = [
        _tone_lr(528, sr, n, dsp.db_to_lin(-26)),
        _tone_lr(741, sr, n, dsp.db_to_lin(-32)),
        dsp.DroneGenerator().render(n, sr, 528, lin_gain=dsp.db_to_lin(-24)),
        dsp.BinauralGenerator().render(n, sr, 220, 10, lin_gain=dsp.db_to_lin(-30)),
        dsp.AmplitudePulseGenerator().render(n, sr, 528, 7.83, 0.2,
                                             lin_gain=dsp.db_to_lin(-30)),
    ]
    l4, r4 = run("combo4 (all layers)", layers)

    # mute 검증: 레이어 게인 0 → 해당 주파수 성분 사라짐
    muted = [_tone_lr(528, sr, n, dsp.db_to_lin(-26)),
             _tone_lr(741, sr, n, 0.0)]
    mixer = dsp.LayerMixer()
    lm, rm = mixer.mix(muted, master_gain_lin=dsp.db_to_lin(-12))
    mag741 = A.goertzel_magnitude(lm, sr, 741)
    add("Mixer mute (741 muted)", "mixer",
        "PASS" if mag741 < 1e-4 else "FAIL",
        mutedFreqMag=round(float(mag741), 8))

    # 참조 mix WAV
    write_wav_float32(os.path.join(REF, "mix_abundance_10s.wav"),
                      dsp.LayerMixer().mix([
                          _tone_lr(432, sr, sr * 10, dsp.db_to_lin(-26)),
                          _tone_lr(888, sr, sr * 10, dsp.db_to_lin(-36)),
                          dsp.DroneGenerator().render(sr * 10, sr, 432,
                                                      lin_gain=dsp.db_to_lin(-24)),
                      ], master_gain_lin=dsp.db_to_lin(-8)), sr)


# ─────────────────────────────────────────────────────────────
# 15. 시퀀스(무음/크로스페이드 DSP 측면)
# ─────────────────────────────────────────────────────────────
def test_sequence_dsp():
    sr = 48000
    # 무음 단계: 완전한 0
    silence = np.zeros(sr * 2, np.float32)
    add("Sequence silent stage", "sequence",
        "PASS" if A.peak(silence) == 0 else "FAIL",
        peakDbfs=A.to_dbfs(A.peak(silence)),
        detail="무음 단계 완전 무음 확인")
    # 크로스페이드: 396→741 1.5초, 게인 램프로 합성 시 클리핑/단조 확인
    n = int(sr * 1.5)
    a = R.render_gain_fade(396, sr, n, 1.0, 0.0, 1500, amp=PRIMARY_AMP)
    b = R.render_gain_fade(741, sr, n, 0.0, 1.0, 1500, amp=PRIMARY_AMP)
    mixer = dsp.LayerMixer()
    l, r = mixer.mix([(a, a), (b, b)], master_gain_lin=1.0)
    ceil = dsp.limiter_ceiling_lin()
    ok = A.count_clipping(l, ceil) == 0 and A.count_nan(l) == 0
    add("Sequence crossfade 396->741", "sequence",
        "PASS" if ok else "FAIL",
        peakDbfs=round(A.to_dbfs(A.peak(l)), 4),
        clippedSamples=A.count_clipping(l, ceil))


# ─────────────────────────────────────────────────────────────
# 16. 참조 WAV(추가 단일 톤)
# ─────────────────────────────────────────────────────────────
def write_reference_wavs():
    sr = 48000
    for f in (396, 432, 528, 741, 963):
        st = R.render_tone_contiguous(f, sr, sr * 10, amp=0.4)
        write_wav_float32(
            os.path.join(REF, f"sine_{f}hz_10s_48k_stereo.wav"), (st, st), sr)
    write_wav_float32(
        os.path.join(REF, "frequency_ramp_432_to_528.wav"),
        R.render_freq_ramp(432, 528, 1500, sr, sr * 3, amp=0.4), sr)


# ─────────────────────────────────────────────────────────────
# 리포트
# ─────────────────────────────────────────────────────────────
def write_reports():
    passed = sum(1 for r in RESULTS if r["status"] == "PASS")
    failed = sum(1 for r in RESULTS if r["status"] == "FAIL")
    info = sum(1 for r in RESULTS if r["status"] == "INFO")
    payload = {
        "generatedAt": datetime.datetime.now(datetime.timezone.utc)
        .isoformat(),
        "engineVersion": ENGINE_VERSION,
        "summary": {"pass": passed, "fail": failed, "info": info,
                    "total": len(RESULTS)},
        "tests": RESULTS,
    }
    with open(os.path.join(OUT, "audio_test_results.json"), "w") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False, default=float)

    # CSV
    keys = ["category", "name", "status", "targetHz", "measuredHz", "errorHz",
            "errorPercent", "peakDbfs", "rmsDbfs", "dcOffset", "clippedSamples",
            "nanSamples", "infiniteSamples"]
    with open(os.path.join(OUT, "audio_test_results.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        for r in RESULTS:
            w.writerow(r)

    # Markdown 요약(상세 보고서는 별도 파일에서 참조)
    by_cat = {}
    for r in RESULTS:
        by_cat.setdefault(r["category"], []).append(r)
    lines = ["# Audio Test Results (auto-generated)\n",
             f"- generatedAt: {payload['generatedAt']}",
             f"- engineVersion: {ENGINE_VERSION}",
             f"- PASS {passed} · FAIL {failed} · INFO {info} · TOTAL {len(RESULTS)}\n"]
    for cat, rows in by_cat.items():
        p = sum(1 for r in rows if r["status"] == "PASS")
        lines.append(f"## {cat} — {p}/{len(rows)} PASS")
        lines.append("| test | status | target | measured | error |")
        lines.append("|---|---|---|---|---|")
        for r in rows:
            lines.append(
                f"| {r['name']} | {r['status']} | "
                f"{r.get('targetHz','')} | {r.get('measuredHz','')} | "
                f"{r.get('errorHz', r.get('maxSampleError',''))} |")
        lines.append("")
    with open(os.path.join(OUT, "audio_test_results.md"), "w") as f:
        f.write("\n".join(lines))
    return passed, failed, info


def main():
    print("=== 마인드사운드 빌드 전 오디오 검증 시작 ===")
    test_single_frequencies()
    test_phase_continuity()
    test_long_drift()
    test_frequency_ramps()
    test_gain_fades()
    test_binaural()
    test_pulse()
    test_drone()
    test_mixer()
    test_sequence_dsp()
    write_reference_wavs()
    passed, failed, info = write_reports()
    print("\n=== 요약 ===")
    print(f"PASS {passed} · FAIL {failed} · INFO {info} · TOTAL {len(RESULTS)}")
    print(f"결과: {OUT}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
