# TEST_REPORT.md — 마인드사운드 테스트 종합

정직 원칙: 실제로 실행한 것만 통과로 기록한다. 실행하지 못한 것은 명시한다.

## 1. 오프라인 오디오 DSP 검증 — ✅ 실행 완료 (이 환경)

- 도구: `tools/audio_verify/` (Python + numpy), 실행: `python3 tools/audio_verify/run_tests.py`
- 결과: **132 PASS · 0 FAIL · 0 INFO / 132**
- 상세: `PREBUILD_AUDIO_TEST_REPORT.md`, 원본 `test_output/audio_test_results.{json,csv,md}`
- 항목: 단일 주파수(46), 위상 연속성(7), 60분 드리프트(5), 주파수 램프(30), 게인 페이드(10),
  바이노럴(4), 펄스(12), 드론(11), 믹서/리미터(5), 시퀀스(2)
- 검출력 증명: 위상 리셋 버그 주입 시 테스트가 실패로 검출(`test_output/failures/`).

## 2. Dart 유닛 테스트 — ⏳ CI(`flutter test`)에서 실행

이 환경엔 Flutter SDK가 없어 로컬 실행 불가. GitHub Actions 워크플로에서 실행된다.

| 파일 | 검증 |
|------|------|
| `test/dsp_reference_test.dart` | Dart DSP 레퍼런스: 사인 성분/위상 연속성/리미터/램프/드론 (Python 코어와 동일 알고리즘) |
| `test/session_scheduler_test.dart` | 시퀀스 타이밍·차임 인터벌 (가상 시계) |
| `test/models_test.dart` | 모델 JSON 왕복, 바이노럴/드론 계산 |
| `test/preset_data_test.dart` | 번들 프리셋 14개/23단계 로드·구조 검증 |

## 3. 프리셋/자산 데이터 — ✅ 실행 완료 (이 환경)

- 프리셋 JSON 파싱·구조 검증: `python3` 로 14 프리셋/23 단계 확인 (PASS).
- 플레이스홀더 WAV 16개 생성: `python3 tools/generate_placeholder_assets.py` (PASS, 9.1MB).

## 4. Android 빌드 — ⏳ CI에서 실행 (이 환경 미실행)

- 이 환경엔 Android SDK/Flutter 없음 → 로컬 빌드 불가.
- CI: `flutter create`(스캐폴드) → `tools/apply_native.py`(네이티브 오버레이 + manifest 패치)
  → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --debug` → APK 아티팩트.
- 워크플로: `.github/workflows/build.yml` (jobs: `audio-verify` → `android`).

## 5. iOS 빌드 — ⏳ CI(macOS)에서 실행, 미검증 상태

- macOS/Xcode 부재로 이 환경에서 iOS 코드 실행/빌드 불가.
- iOS 엔진은 완전히 **구현**되었으나(단일 `AppDelegate.swift`), **빌드 성공을 주장하지 않는다.**
- CI: macOS 러너에서 `flutter build ios --no-codesign` 시도(서명 없음, 배포용 아님).

## 6. 네이티브 실기기 검증 — ⏳ 미실행 (필요 항목)

- 실제 출력 샘플레이트, 오디오 포커스/인터럽션, 이어폰/BT/스피커 경로 변경,
  백그라운드·잠금화면 재생, 버퍼 언더런, 미디어 알림 컨트롤.
- 네이티브가 생성한 PCM을 `common_fixture.json` 로 내보내 `analyzer.py` 로 대조(절차 문서화,
  `AUDIO_TESTING_README.md`).

## 완료 기준 대비 현황

| 완료 기준 | 상태 |
|-----------|------|
| 실시간 주파수/드론/바이노럴/펄스 생성 정확성 | ✅ DSP 검증 통과 |
| 재생 중 주파수 변경 클릭 없음 | ✅ 램프 검증 통과 |
| 다중 레이어 믹싱/클리핑 방지 | ✅ 믹서 검증 통과 |
| NaN/Inf/의도치 않은 클리핑 0 | ✅ |
| 기본 프리셋 14개 로딩 | ✅ 데이터 검증 |
| 차크라 순차/레이키 차임 타이머 | ✅ 스케줄러 유닛테스트(가상시계) |
| 자연음/패드/차임 로컬 재생 | ⏳ 네이티브 구현, 실기기 검증 필요(placeholder 음원) |
| 화면잠금/백그라운드 재생 | ⏳ 구현(서비스/세션), 실기기 검증 필요 |
| 사용자 프리셋/기록 로컬 저장, JSON 백업/복원 | ✅ 구현(모델 테스트) |
| Android 빌드 | ⏳ CI에서 수행 |
| iOS 빌드 | ⏳ CI(macOS), 미검증 표기 |
| 자동 테스트 결과 기록 / 미완료 문서화 | ✅ 본 문서 |
