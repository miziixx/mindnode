# AUDIO_TESTING_README.md — 빌드 전 오디오 검증 도구 사용법

마인드사운드의 실시간 오디오 엔진(주파수·드론·바이노럴·펄스·믹서)의 정확성을
**귀가 아니라 디지털 PCM 분석**으로 검증하는 오프라인 도구다. 스피커/이어폰 출력이 필요 없다.

## 무엇을 검증하나

- 지정 주파수의 정확도(FFT + 포물선 보간, Goertzel 교차검증)
- 장시간(60분 상당) 주파수 드리프트 없음
- 오디오 버퍼 경계 위상 연속성(버퍼 크기·불규칙 순서 무관)
- 바이노럴 좌우 채널 분리·차이 주파수·누화·반전
- 진폭 펄스 속도·깊이(해석적 엔벌로프)
- 드론 Sub/Main/Air 구성 + 느린 LFO(프레임 RMS 엔벌로프)
- 다중 레이어 믹싱 클리핑/리미터/헤드룸
- 주파수·게인 변경 시 클릭 노이즈
- NaN / Infinity / DC offset

## 실행

```bash
cd tools/audio_verify
python3 run_tests.py
```

의존성: Python 3.9+, `numpy`. (`pip install numpy`)

## 산출물

| 파일 | 내용 |
|------|------|
| `test_output/audio_test_results.json` | 전 테스트 실측값(진단실 화면용 스키마) |
| `test_output/audio_test_results.csv` | 표 형식 요약 |
| `test_output/audio_test_results.md` | 카테고리별 PASS/FAIL 표 |
| `test_output/audio_reference/*.wav` | 참조 WAV(Float32, 분석에 쓴 PCM과 동일) |
| `test_output/failures/*.wav` | 실패/버그 재현 구간 WAV |
| `PREBUILD_AUDIO_TEST_REPORT.md` | 사람이 읽는 종합 보고서 |

> 참조 WAV는 **분석·청취 확인용**이며 최종 앱 음원이 아니다. 저장된 PCM 값은 분석에 사용한 값과 동일하다(무손실 IEEE float WAV).

## 구조

```
tools/audio_verify/
├── dsp.py        # DSP 코어(엔진과 동일 알고리즘: Sine/Drone/Binaural/Pulse/Mixer/Ramp/Limiter)
├── analyzer.py   # FFT peak, Goertzel, RMS/peak/DC, NaN/Inf, 위상연속성, 클릭, 엔벌로프
├── render.py     # 오프라인 블록 렌더러(가변/불규칙 버퍼, 드리프트 창)
├── wavio.py      # Float32 WAV 입출력
├── run_tests.py  # 전 섹션 실행 + 리포트 생성
└── fixtures/common_fixture.json  # Android/iOS/Python 공통 입력(대조용)
```

## 엔진과의 관계 (중요)

`dsp.py`는 검증을 **실제로 실행**하기 위한 Python 미러이며, 다음과 **동일한 알고리즘·상수**다.

- 정본(Dart): `lib/core/audio/dsp_reference.dart`
- Android(Kotlin), iOS(Swift): 동일 상수로 포팅

정본 상수(v1)는 `PREBUILD_AUDIO_TEST_PLAN.md` 참조. Dart 포팅의 수치 동등성은
CI의 `flutter test`(`test/dsp_reference_test.dart`)에서 별도로 검증한다.

## 네이티브 대조 절차 (실기기/CI)

1. Android/iOS 엔진에 디버그용 "오프라인 렌더" 진입점을 두어 `common_fixture.json`의
   각 케이스를 Float32 WAV로 내보낸다.
2. 내보낸 WAV를 `analyzer.py`로 로드하여 동일 지표를 측정한다.
3. Python 결과와 주파수·RMS·위상 진행·램프·바이노럴·펄스·드론 구성이 일치하는지 대조한다.
4. 플랫폼별 Float 처리 미세 차이는 허용하되, 주파수·진폭·시간 동작은 동일해야 한다.

> 현재까지 Kotlin/Swift는 이 환경에서 **실행하지 못했다**. 공통 DSP 결과를 네이티브 결과로
> 대체 보고하지 않는다.
