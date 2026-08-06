# PREBUILD_AUDIO_TEST_PLAN.md — 빌드 전 오프라인 오디오 검증

릴리스 빌드(APK/AAB/IPA) **이전에** 오디오 엔진의 DSP 정확성을 귀가 아니라
**디지털 PCM 분석**으로 검증한다. 실제 스피커/이어폰 출력 없이 실행 가능하다.

## 검증 대상 DSP (엔진과 1:1 미러)

`tools/audio_verify/dsp.py` 의 순수 Python DSP 코어는 다음 3개 구현과 **동일한 알고리즘**이다.

| 구현 | 파일 | 상태 |
|------|------|------|
| 공통 레퍼런스(Dart) | `lib/core/audio/dsp_reference.dart` | 테스트 대상(정본) |
| 검증 실행용(Python) | `tools/audio_verify/dsp.py` | **이 환경에서 실제 실행** |
| Android(Kotlin) | `android/app/.../audio/*.kt` | 1:1 포팅, 이 환경에서 미실행 |
| iOS(Swift) | `ios/Runner/AppDelegate.swift` | 1:1 포팅, 이 환경에서 미실행 |

> Python 코어는 검증을 **실제로 실행**하기 위한 도구이며, 세 언어 포팅이 동일 알고리즘·상수임을
> `PRESET_SCHEMA.md`/`AUDIO_ARCHITECTURE.md`에 명시한다. Dart 포팅은 CI `flutter test`에서
> 별도로 수치 검증한다. Kotlin/Swift 실행 검증은 실기기/CI에서 수행할 항목으로 남긴다.

## 정본 DSP 상수(v1)

- Sine: `phase += 2π·f/sr`; `sin(phase)`; `[0,2π)` wrap
- Gain/Freq 램프: 선형, `step=(target-current)/max(1, sr·ms/1000)`, 오버슈트 클램프
- Soft limiter: `y = ceil·tanh(x/ceil)`, `ceil=10^(-1/20)≈0.8913` (−1 dBFS)
- Headroom: `1/sqrt(activeLayers)` (n>1)
- Drone: sub=0.5c, main=c, air=2c; 비율 0.35/0.55/0.10; air off if `2c ≥ 0.98·nyquist`;
  진폭 LFO `0.925+0.075·sin`, L/R 위상차 π/2; mid/side 스테레오 폭
- Binaural: L=carrier, R=carrier+beat(반전 시 교환), 좌우 독립 위상, 모노 합산 없음
- Pulse: `env=(1−depth)+depth·(0.5+0.5·cos(2π·rate·t))`, center/alternate(π 위상차)

## 테스트 매트릭스

- 샘플레이트: 44,100 / 48,000
- 포맷: Float32, Mono / Stereo
- 버퍼: 64,128,192,256,480,512,960,1024 및 불규칙 순서(64→192→480→128→1024→256→960→64)

## 합격 기준

| 항목 | 기준 |
|------|------|
| 20–1000Hz 주파수 오차 | ±0.05 Hz |
| >1000Hz 주파수 오차 | ±0.01 % |
| DC offset | \|dc\| ≤ 1e-5 |
| NaN / Inf | 0 / 0 |
| 의도치 않은 클리핑 | 0 |
| 버퍼 경계 위상 불연속 | float32 절대오차 ≤ 1e-5 |
| 바이노럴 차이 주파수 | ±0.05 Hz |
| 펄스 속도 | ±0.03 Hz |
| 믹서 출력 범위 | [−ceil, +ceil], ceil=−1 dBFS |

## 분석 알고리즘

- 주파수: Hann 윈도우 rFFT + 로그 크기 **2차(포물선) 보간**, Goertzel 교차검증
- 위상 연속성: 연속 렌더 vs 블록 분할 렌더 샘플 일치(1e-5)
- 드리프트: 60분 상당 블록 생성, 구간(0s/10m/30m/59m) 측정
- 램프/클릭: 인접 샘플 기울기 분석, 사인 기울기로 설명 불가한 임펄스 탐지
- 펄스/드론 LFO: 해석적(Hilbert) 엔벌로프의 변조 주파수 측정
- 스테레오: 채널별 독립 측정 + 누화

## 산출물

`PREBUILD_AUDIO_TEST_REPORT.md`, `test_output/audio_test_results.{json,csv}`,
`test_output/audio_reference/*.wav`, `test_output/failures/*.wav`, `AUDIO_TESTING_README.md`.
