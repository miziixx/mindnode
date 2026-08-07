"""프리셋 검증: 각 프리셋이 선언한 주파수를 엔진이 실제로 생성하는지(측정)와,
그 값이 상황별 대중 기준값(솔페지오/차크라/뇌파 대역/슈만)과 맞는지 확인한다.

- dsp.py(검증된 엔진 미러)로 각 레이어를 렌더 → analyzer.py로 측정.
- 프리셋 JSON의 선언값 vs 실제 측정값 vs 대중 기준값을 대조.
- 프리셋별 합성 레이어 믹스를 짧은 WAV로 내보내 청취 확인 가능하게 함.
"""
from __future__ import annotations
import json
import os
import sys
import numpy as np

RENDER_WAV = "--render" in sys.argv  # 청취용 WAV는 옵션(용량 큼). CI에선 생략.

import dsp
import analyzer as A
from wavio import write_wav_float32

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PRESET_FILES = [
    "assets/presets/default_presets.json",
    "assets/presets/chakra_presets.json",
    "assets/presets/wellness_presets.json",
]
OUT = os.path.join(ROOT, "test_output")
RENDER = os.path.join(OUT, "preset_renders")
os.makedirs(RENDER, exist_ok=True)
SR = 48000

# 대중적으로 통용되는 기준값 -------------------------------------------------
SOLFEGGIO = {174, 285, 396, 417, 528, 639, 741, 852, 963}
CHAKRA_HZ = {1: 396, 2: 417, 3: 528, 4: 639, 5: 741, 6: 852, 7: 963}
SCHUMANN = 7.83


def brainwave_band(hz: float) -> str:
    if hz <= 0:
        return "-"
    if hz < 4:
        return "Delta"
    if hz < 8:
        return "Theta"
    if hz < 13:
        return "Alpha"
    if hz < 30:
        return "Beta"
    return "Gamma"


# 웰니스 프리셋이 의도한 대역/기준
EXPECTED = {
    "sleep_delta": ("Delta", "수면"),
    "deep_sleep": ("Delta", "깊은 수면"),
    "calm_alpha": ("Alpha", "불안 완화"),
    "theta_relax": ("Theta", "이완"),
    "focus_beta": ("Beta", "집중"),
    "flow_gamma": ("Gamma", "몰입"),
    "stress_relief": ("Schumann", "스트레스 해소"),
    "meditation_deep": ("Theta", "명상(선택 6Hz)"),
    "reiki_self": ("Schumann", "레이키"),
}

results = []
render_amp = dsp.db_to_lin(-12)  # 측정용 여유 진폭


def measure_tone(freq, gain_db, secs=1.5):
    osc = dsp.SineOscillator(0.0)
    n = int(SR * secs)
    x = osc.render(freq, SR, n) * dsp.db_to_lin(gain_db)
    return A.measure_frequency(x, SR)


def measure_binaural(carrier, beat, invert, secs=4.0):
    g = dsp.BinauralGenerator()
    n = int(SR * secs)
    l, r = g.render(n, SR, carrier, beat, invert=invert, lin_gain=0.2)
    lf = A.measure_frequency(l, SR)
    rf = A.measure_frequency(r, SR)
    return lf, rf, abs(rf - lf)


def measure_pulse_rate(freq, rate, depth, secs=8.0):
    g = dsp.AmplitudePulseGenerator()
    n = int(SR * secs)
    l, _ = g.render(n, SR, freq, rate, depth, lin_gain=0.2)
    return A.envelope_modulation_freq(l, SR)


def measure_drone(center, secs=3.0):
    g = dsp.DroneGenerator()
    n = int(SR * secs)
    l, r = g.render(n, SR, center, lin_gain=0.2)
    mono = (l.astype(np.float64) + r) * 0.5
    return {
        "sub": (center * 0.5, A.goertzel_magnitude(mono, SR, center * 0.5)),
        "main": (center, A.goertzel_magnitude(mono, SR, center)),
        "air": (center * 2, A.goertzel_magnitude(mono, SR, center * 2)),
        "mainMeasured": A.measure_frequency(mono, SR),
    }


def ref_note(hz):
    hz_r = round(hz)
    if hz_r in SOLFEGGIO:
        return f"Solfeggio {hz_r}"
    for k, v in CHAKRA_HZ.items():
        if hz_r == v:
            return f"{k}차크라 {v}"
    if abs(hz - 432) < 0.6:
        return "432 튜닝"
    if abs(hz - 440) < 0.6:
        return "440 표준"
    if abs(hz - 888) < 1:
        return "888 풍요(상징)"
    return "-"


def render_preset_mix(preset, stage, path):
    """합성 주파수 레이어를 믹스해 8초 WAV로 저장(청취 확인용)."""
    n = SR * 8
    layers = []
    pt = stage.get("primaryTone", {})
    if pt.get("enabled"):
        osc = dsp.SineOscillator(0.0)
        x = osc.render(pt["frequencyHz"], SR, n) * dsp.db_to_lin(pt.get("gainDb", -26))
        layers.append((x, x))
    st = stage.get("secondaryTone", {})
    if st.get("enabled"):
        osc = dsp.SineOscillator(0.0)
        x = osc.render(st["frequencyHz"], SR, n) * dsp.db_to_lin(st.get("gainDb", -34))
        layers.append((x, x))
    d = stage.get("drone", {})
    if d.get("enabled"):
        g = dsp.DroneGenerator()
        layers.append(g.render(n, SR, d["centerHz"], lin_gain=dsp.db_to_lin(d.get("gainDb", -24))))
    b = stage.get("binaural", {})
    if b.get("enabled"):
        g = dsp.BinauralGenerator()
        layers.append(g.render(n, SR, b["carrierHz"], b["beatHz"],
                                invert=b.get("invert", False),
                                lin_gain=dsp.db_to_lin(b.get("gainDb", -30))))
    p = stage.get("pulse", {})
    if p.get("enabled"):
        g = dsp.AmplitudePulseGenerator()
        layers.append(g.render(n, SR, p["frequencyHz"], p["rateHz"], p["depth"],
                               lin_gain=dsp.db_to_lin(p.get("gainDb", -30))))
    if not layers:
        return None
    mixer = dsp.LayerMixer()
    lr = mixer.mix(layers, master_gain_lin=dsp.db_to_lin(preset.get("masterGainDb", -12) + 6))
    write_wav_float32(path, lr, SR)
    ceil = dsp.limiter_ceiling_lin()
    clip = A.count_clipping(lr[0], ceil) + A.count_clipping(lr[1], ceil)
    return {"clipped": clip, "peakDbfs": round(A.to_dbfs(max(A.peak(lr[0]), A.peak(lr[1]))), 2)}


def check_preset(preset):
    pid = preset["id"]
    stage = preset["stages"][0]
    row = {"id": pid, "title": preset["title"], "checks": [], "status": "PASS"}

    def add_check(layer, declared, measured, tol, ref=""):
        err = abs(measured - declared)
        ok = err <= tol
        if not ok:
            row["status"] = "FAIL"
        row["checks"].append({
            "layer": layer, "declaredHz": round(declared, 3),
            "measuredHz": round(measured, 3), "errorHz": round(err, 4),
            "ok": ok, "ref": ref,
        })

    pt = stage.get("primaryTone", {})
    if pt.get("enabled"):
        m = measure_tone(pt["frequencyHz"], pt.get("gainDb", -26))
        add_check("primary", pt["frequencyHz"], m,
                  0.05 if pt["frequencyHz"] <= 1000 else pt["frequencyHz"] * 0.0001,
                  ref_note(pt["frequencyHz"]))
    st = stage.get("secondaryTone", {})
    if st.get("enabled"):
        m = measure_tone(st["frequencyHz"], st.get("gainDb", -34))
        add_check("secondary", st["frequencyHz"], m, 0.05, ref_note(st["frequencyHz"]))
    d = stage.get("drone", {})
    if d.get("enabled"):
        dm = measure_drone(d["centerHz"])
        add_check("drone.main", d["centerHz"], dm["mainMeasured"], 0.3,
                  ref_note(d["centerHz"]))
        row["droneVoices"] = {
            "sub": round(dm["sub"][0], 1), "main": round(dm["main"][0], 1),
            "air": round(dm["air"][0], 1),
            "subPresent": dm["sub"][1] > 1e-4, "airPresent": dm["air"][1] > 1e-4,
        }
    b = stage.get("binaural", {})
    if b.get("enabled"):
        lf, rf, beat = measure_binaural(b["carrierHz"], b["beatHz"], b.get("invert", False))
        add_check("binaural.left", b["carrierHz"] + (b["beatHz"] if b.get("invert") else 0), lf, 0.1)
        add_check("binaural.beat", b["beatHz"], beat, 0.05)
        band = brainwave_band(beat)
        row["binauralBand"] = band
        exp = EXPECTED.get(pid)
        if exp:
            want = exp[0]
            band_ok = (want == "Schumann" and abs(beat - SCHUMANN) < 0.3) or (want == band)
            row["bandExpected"] = want
            row["bandOk"] = band_ok
            if not band_ok:
                row["status"] = "FAIL"
    p = stage.get("pulse", {})
    if p.get("enabled"):
        m = measure_pulse_rate(p["frequencyHz"], p["rateHz"], p["depth"])
        add_check("pulse.rate", p["rateHz"], m, 0.03,
                  "Schumann 7.83" if abs(p["rateHz"] - SCHUMANN) < 0.05 else "")

    # 청취용 믹스 렌더(옵션)
    if RENDER_WAV:
        row["render"] = render_preset_mix(preset, stage, os.path.join(RENDER, f"{pid}.wav"))
    return row


def main():
    presets = []
    for f in PRESET_FILES:
        d = json.load(open(os.path.join(ROOT, f)))
        for p in d["presets"]:
            presets.append(p)

    for p in presets:
        row = check_preset(p)
        results.append(row)
        tag = row["status"]
        band = f" band={row.get('binauralBand','-')}" if "binauralBand" in row else ""
        print(f"[{tag:4}] {row['id']:18} {row['title'][:24]:24}{band}")
        for c in row["checks"]:
            mark = "ok " if c["ok"] else "FAIL"
            print(f"        {mark} {c['layer']:14} decl={c['declaredHz']:8} "
                  f"meas={c['measuredHz']:8} err={c['errorHz']:.4f}Hz "
                  f"{('· ' + c['ref']) if c['ref'] and c['ref'] != '-' else ''}")

    npass = sum(1 for r in results if r["status"] == "PASS")
    payload = {"summary": {"pass": npass, "total": len(results)}, "presets": results}
    with open(os.path.join(OUT, "preset_verification.json"), "w") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False, default=float)

    # Markdown 리포트
    lines = ["# 프리셋 주파수 검증 리포트\n",
             f"- 프리셋 {len(results)}개 중 **{npass} PASS**",
             "- 각 프리셋의 선언 주파수를 엔진으로 실제 생성→측정하고, 대중 기준값과 대조.",
             "- 청취용 합성 믹스: `test_output/preset_renders/<id>.wav`\n",
             "| 프리셋 | 상태 | 레이어(선언→측정) | 뇌파대역 | 기준 |",
             "|---|---|---|---|---|"]
    for r in results:
        checks = "; ".join(
            f"{c['layer']} {c['declaredHz']}→{c['measuredHz']}Hz" for c in r["checks"])
        band = r.get("binauralBand", "")
        if "bandExpected" in r:
            band += f" (기대 {r['bandExpected']}, {'OK' if r.get('bandOk') else 'X'})"
        refs = ", ".join(sorted({c["ref"] for c in r["checks"]
                                 if c["ref"] and c["ref"] != "-"}))
        lines.append(f"| {r['title']} | {r['status']} | {checks} | {band} | {refs} |")
    with open(os.path.join(OUT, "preset_verification.md"), "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"\n=== {npass}/{len(results)} PASS ===")
    print(f"리포트: test_output/preset_verification.md, .json")
    print(f"청취 렌더: test_output/preset_renders/")
    return 0 if npass == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
