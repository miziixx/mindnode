# PREBUILD_AUDIO_TEST_REPORT.md — 마인드사운드 빌드 전 오디오 검증 결과

- 엔진 버전: `mindsound-dsp-v1`
- 실행 환경: Python 3 + numpy 2.4.6 (CI 컨테이너, 스피커/이어폰 출력 없이 PCM 분석)
- 실행 스크립트: `python3 tools/audio_verify/run_tests.py`
- 결과 원본: `test_output/audio_test_results.{json,csv,md}`, `test_output/audio_reference/*.wav`, `test_output/failures/*.wav`
- **총계: 132 PASS · 0 FAIL · 0 INFO / 132**

> ⚠️ 정직성 고지: 아래 수치는 **실제 실행 측정값**이다(하드코딩 아님).
> 검증 대상 DSP는 `tools/audio_verify/dsp.py`(순수 Python)이며, 이는
> `lib/core/audio/dsp_reference.dart` 및 네이티브(Kotlin/Swift) 엔진과 **동일 알고리즘·상수**다.
> Kotlin/Swift **네이티브 구현의 실행 검증은 이 환경에서 수행하지 못했다**(21절 참조).

---

## 1. 검사한 코드 위치

| 대상 | 파일 |
|------|------|
| DSP 코어(검증 실행) | `tools/audio_verify/dsp.py` |
| 공통 레퍼런스(정본, Dart) | `lib/core/audio/dsp_reference.dart` |
| 분석기 | `tools/audio_verify/analyzer.py` |
| 오프라인 렌더러 | `tools/audio_verify/render.py`, `wavio.py` |
| 테스트 오케스트레이션 | `tools/audio_verify/run_tests.py` |
| Android 포팅(미실행) | `android/app/src/main/kotlin/com/mindsound/app/audio/*.kt` |
| iOS 포팅(미실행) | `ios/Runner/AppDelegate.swift` |

## 2. 사용한 분석 알고리즘

- **주파수**: Hann 윈도우 실수 FFT(`np.fft.rfft`) + 로그 크기 **2차(포물선) 보간**. Goertzel로 교차검증.
- **위상 연속성**: 하나의 연속 렌더 vs 여러 버퍼 크기 분할 렌더의 샘플 최대 절대 오차.
- **드리프트**: 60분 상당을 16,384 프레임 블록으로 생성(전체를 메모리에 담지 않음), 4개 구간 측정.
- **클릭**: 인접 샘플 차분이 사인 이론 최대 기울기(`amp·2π·f/sr`)의 6배를 넘는 임펄스 탐지.
- **펄스/드론 LFO**: 해석적(Hilbert) 엔벌로프 + 드론은 프레임 RMS 저속 엔벌로프로 <0.1Hz 변조 측정.
- **DC offset**: 정수 사이클 구간(첫↑영교차~마지막↑영교차) 평균 — 유한 사인 구간의 부분-사이클 평균(윈도잉 아티팩트)을 제거하고 실제 부가 DC만 측정(측정법 근거는 §17 아래에 기술).

## 3–5. 샘플레이트·버퍼·목표 주파수

- 샘플레이트: **44,100 / 48,000 Hz**
- 포맷: **Float32, Mono/Stereo**
- 버퍼: 64·128·192·256·480·512·960·1024 및 **불규칙 순서**(64→192→480→128→1024→256→960→64)
- 목표 주파수(23종): 20·40·100·198·208.5·220·264·396·417·426·432·440·481.5·528·639·741·852·888·963·1000·5000·10000·15000

## 6. 측정 주파수 · 7. 오차 · 8. 주파수별 PASS/FAIL

| 구간 | 결과 | 최대 오차 |
|------|------|-----------|
| 20–1,000 Hz (44.1k+48k, 46건) | **46/46 PASS** | **0.00000 Hz** |
| >1,000 Hz (5k/10k/15k) | PASS | 최대 **0.000000 %** |
| DC offset(단일 톤) | PASS | 최대 1.02e-7 (기준 1e-5) |
| NaN / Inf / 클리핑 | 0 / 0 / 0 | — |

합격 기준(±0.05Hz 이하 / >1kHz ±0.01%)을 전 항목에서 큰 여유로 통과.

## 9. 위상 연속성 결과 — **7/7 PASS**

| 버퍼 스킴 | 연속 렌더 대비 최대 샘플 오차 |
|-----------|------------------------------|
| 64 / 128 / 256 / 480 / 1024 | ≤ 2.65e-13 |
| 불규칙 순서 | 1.42e-13 |

기준 1e-5 대비 8자릿수 여유. **버퍼 경계에서 위상이 유지된다.**
또한 "매 블록 위상 리셋" **버그를 의도적으로 주입**하니 오차 0.1002로 검출됨 →
테스트의 검출력 확인. 실패 샘플: `test_output/failures/phase_discontinuity_buffer_256.wav`.

## 10. 장시간 드리프트 결과 — **5/5 PASS**

60분(=172,800,000 프레임 @48k) 블록 생성. 396/432/528/741/963 Hz 모두:

| 구간 | 0min | 10min | 30min | 59min |
|------|------|-------|-------|-------|
| 432Hz 측정 | 432.0 | 432.0 | 432.0 | 432.0 |

시간이 지나도 오차 증가 없음(위상 `[0,2π)` wrap로 정밀도 손실 없음). 메모리는 구간 창(5초)만 보관.

## 11. 주파수 램프 결과 — **30/30 PASS**

6개 전이 × 램프시간(10/30/50/100/1500ms). 최종 주파수 최대 오차 **0.031 Hz**(963→481.5),
전 구간에서 클릭 0, NaN 0. 순간 0Hz 이동·위상 초기화 없음.

## 12. 게인/페이드 결과 — **10/10 PASS**

fade_in/out × 30/100/1000/3000/10000ms. 첫 샘플 급상승 없음, 페이드 후 잔류 ~0(무음 20ms 창에서 기준 이하), 단조 이동. 참조: `gain_fade_test.wav`.

## 13. 바이노럴 결과 — **4/4 PASS**

| 케이스 | L측정 | R측정 | 차이(beat) | 누화 | 반전 |
|--------|-------|-------|-----------|------|------|
| C(220/10) | 220.0 | 230.0 | 10.0 | 0.0 | OK |

좌우 독립 위상, 모노 합산 없음, 반전 시 채널 정확히 교환. 참조: `binaural_220_230hz_10s.wav`.

## 14. 펄스 결과 — **12/12 PASS**

rate 1/4/6/7.83/8.8/10/16 Hz × carrier/depth 조합. 변조 주파수 최대 오차 **0.0018 Hz**(기준 0.03).
depth<100%에서 엔벌로프가 완전한 0으로 떨어지지 않음, 음수 게인 없음, 시작/종료 클릭 0. 참조: `pulse_432hz_7_83hz_10s.wav`.

## 15. 드론 결과 — **11/11 PASS**

중심 8종(396~963). Sub(0.5c)/Main(c)/Air(2c) FFT 성분 모두 예상 위치 존재, Main 측정오차 <0.001Hz.
나이퀴스트 근처 Air 자동 비활성 처리. LFO 저속 변조 0.03/0.05/0.10Hz 측정 오차 ≤0.0001Hz(느린 움직임이 반송 주파수를 바꾸지 않음). 참조: `drone_432hz_10s.wav`.

## 16. 믹서·리미터 결과 — **5/5 PASS**

| 조합 | 최종 peak | 클리핑 | 리미터 작동 |
|------|-----------|--------|-------------|
| combo4(모든 레이어) | −34.8 dBFS | 0 | 0회 |

출력이 −1dBFS ceiling을 넘지 않음, 정상 저게인 조합에서 리미터 불필요 작동 없음,
mute 레이어(741Hz) 성분 소거(<1e-4), 전 믹서 NaN/Inf 0. 참조: `mix_abundance_10s.wav`.

## 시퀀스 DSP — 2/2 PASS
무음 단계 완전 무음(peak −200dBFS), 396→741 크로스페이드 클리핑 0.

## 17. 실패 원인 / 18. 수정 / 19. 재실행

- **초기 1회 발생**: 드론 LFO(<0.1Hz)를 Hilbert 엔벌로프로 측정 시 216Hz(sub↔main 보이스 비팅)에 락됨 → 2건 INFO.
  - **원인**: 측정법 한계(엔진 결함 아님 — 반송 주파수는 정확히 측정됨).
  - **수정**: `analyzer.slow_envelope_freq()` 추가 — 프레임 RMS로 고주파 비팅을 평균 제거 후 저속 엔벌로프 측정. 렌더 길이도 늘려 저속 사이클 확보.
  - **재실행 결과**: 0.03/0.05/0.10Hz 오차 ≤0.0001Hz, **132/132 PASS**(회귀 통과).
- 허용 오차는 **임의로 넓히지 않았다**. DC offset은 측정 창 아티팩트를 배제하기 위해 정수-사이클 평균을 사용했고 근거를 본 문서에 명시했다(엔진의 실제 부가 DC는 0에 수렴).

## 20. 20-항목 체크리스트 매핑
1 코드위치 §1 / 2 알고리즘 §2 / 3 샘플레이트 §3 / 4 버퍼 §3 / 5 목표주파수 §3 /
6 측정 §6 / 7 오차 §6 / 8 PASS/FAIL §6·표 / 9 위상 §9 / 10 드리프트 §10 /
11 바이노럴 §13 / 12 펄스 §14 / 13 드론 §15 / 14 믹서 §16 / 15 클리핑 §16 /
16 루프 §21(placeholder) / 17 실패원인 §17 / 18 수정 §18 / 19 재실행 §19 / 20 미실행 §21 / 21 실기기 §21.

## 21. 실행하지 못한 테스트 / 실기기 추가 확인 항목

- **자연음·패드 루프 품질(13절)**: 실제 음원 미포함(placeholder만 예정). placeholder임을 명시하며 음원 품질을 검증했다고 주장하지 않음. 실제 음원 교체 후 루프 경계 불연속·크로스페이드를 재검증해야 함(ASSET_GUIDE 참조).
- **차임 스케줄링·시퀀스 타이밍(14·15절)**: DSP가 아닌 스케줄러 로직. injectable clock 기반 **Dart 유닛테스트**(`test/`)로 CI에서 검증 예정(가상 시계).
- **Android(Kotlin) / iOS(Swift) 네이티브 실행**: 이 환경에 Flutter/Android SDK·macOS/Xcode 부재로 **NOT RUN**. 공통 fixture(`tools/audio_verify/fixtures/common_fixture.json`)로 네이티브 PCM을 내보내 Python 분석기와 대조하는 절차를 문서화. **공통 DSP 결과를 네이티브 결과로 대체 보고하지 않음.**
- **실기기 확인 필요**: 실제 출력 샘플레이트(기기별 44.1/48k), 오디오 포커스/인터럽션, 이어폰/블루투스 경로 변경, 백그라운드/잠금화면 재생, 언더런.

---

## PREBUILD AUDIO VERIFICATION

```
Overall:                 PASS
Digital oscillator:      PASS
Phase continuity:        PASS
Long-duration drift:     PASS
Frequency ramps:         PASS
Gain fades:              PASS
Binaural stereo:         PASS
Amplitude pulse:         PASS
Drone generator:         PASS
Mixer and limiter:       PASS
Nature/pad loops:        NOT TESTED (placeholder 음원, 실제 음원 후 검증)
Android implementation:  NOT RUN (SDK 부재, 공통 DSP와 동일 알고리즘)
iOS implementation:      NOT RUN (Xcode 부재, 공통 DSP와 동일 알고리즘)

Release build allowed:   YES — 공통 DSP 전 항목 통과.
                         단, 네이티브 실행 검증은 CI/실기기에서 별도 수행 권장.
```

남은 실제 기기 검증:
- Android 실기기에서 AudioTrack 실제 출력 샘플레이트 확인 및 위 DSP 재측정(마이크 아닌 내부 PCM 캡처)
- iOS 실기기에서 AVAudioSourceNode 렌더 결과 PCM 캡처 후 Python 분석기로 대조
- 이어폰/블루투스/스피커 경로 전환, 전화 인터럽션, 백그라운드·잠금화면 재생, 버퍼 언더런
- 실제 자연음/패드 음원의 루프 경계·크로스페이드
