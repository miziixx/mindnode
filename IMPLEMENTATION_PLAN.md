# IMPLEMENTATION_PLAN.md — 마인드사운드 (MindSound)

개인용 오프라인 주파수·명상 사운드 앱. 미리 만든 음악 파일을 재생하는 앱이 아니라,
**실시간으로 생성하는 주파수/드론/바이노럴/펄스 레이어**와 **로컬 자연음/패드/차임 음원**을
하나의 세션으로 실시간 믹싱한다.

- 빌드 이름: **마인드사운드 (MindSound)**
- 앱 ID: `com.mindsound.app`
- Flutter 프로젝트명(pubspec): `mindsound`

## 0. 저장소 사전 조사 결과

| 항목 | 결과 |
|------|------|
| 기존 프로젝트 구조 | 없음. `README.md`만 존재하는 빈 저장소 |
| Android / iOS 지원 | 없음 (신규 생성) |
| 기존 프레임워크 | 없음 |
| 상태 관리 | 없음 |
| 로컬 저장 구조 | 없음 |
| 백그라운드 재생 | 없음 |
| 기존 오디오 코드 | 없음 |
| 충돌 라이브러리 | 없음 |
| 빌드 설정 | 없음 |
| 테스트 환경 | 없음 |

→ **신규 프로젝트**로 진행. 지침에 명시된 기본 구조(Flutter + Kotlin/Swift 네이티브 오디오)를 채택.

## 1. 빌드 환경 사전 조사 결과 (중요 · 정직 기록)

이 작업은 CI 컨테이너에서 수행되었으며 다음이 **설치되어 있지 않다.**

- ❌ Flutter SDK / Dart SDK
- ❌ Android SDK / NDK / `adb`
- ❌ macOS / Xcode (iOS 빌드는 애초에 이 환경에서 불가)

설치되어 있는 것: `java 21`, `gradle`, `node 22`, `python3`.

**결론:** 이 환경에서는 `flutter build` / `flutter test` / Gradle Android 빌드를 **실행할 수 없다.**
따라서 다음 원칙으로 진행한다.

1. 전체 소스 코드(Flutter Dart + Android Kotlin + iOS Swift)를 **완전히 구현**한다.
2. 실제로 **실행 가능한 검증**은 언어 독립적으로 수행한다:
   - 핵심 DSP 알고리즘(사인 생성, 위상 연속성, 드론, 바이노럴, 펄스, 소프트 리미터)을
     **Python 레퍼런스 구현**으로 재현하여 FFT 피크·드리프트·클릭·클리핑을 **실측**한다.
     (Dart/Kotlin/Swift 코드는 이 검증된 알고리즘과 1:1로 동일하게 작성한다.)
   - 프리셋 JSON을 Python으로 **파싱·스키마 검증**한다.
   - 플레이스홀더 WAV 자산을 Python으로 **실제 생성**한다.
3. `flutter build`/`flutter test`/Android/iOS 빌드는 **미검증(UNVERIFIED)** 으로 명확히 표기하고,
   실행 방법을 문서화한다. 성공했다고 주장하지 않는다.

## 2. 아키텍처 개요

```
Flutter (UI · 상태 · 저장)           Native (실시간 오디오 DSP)
────────────────────────            ─────────────────────────
screens/  widgets/                   Android: Kotlin
core/state/  (ChangeNotifier)          AudioTrack MODE_STREAM PCM Float
core/models/ (JSON + schemaVersion)    MediaSessionService (백그라운드)
core/data/   (로컬 JSON 저장/백업)     SynthEngine / Mixer / Ramp / Limiter
core/design/ (디자인 토큰)          iOS: Swift
core/audio/  (타입 채널 인터페이스)     AVAudioEngine + AVAudioSourceNode
        │                               AVAudioPlayerNode + MixerNode
        │  MethodChannel(commands)
        └──────────────► EventChannel(events)
```

- Flutter는 **오디오 샘플을 생성하지 않는다.** 명령/파라미터만 네이티브로 전달.
- 파라미터는 네이티브 렌더 스레드에서 **lock-free 스냅샷**으로 읽는다.
- 모든 실시간 파라미터는 **샘플 단위 램프**로 부드럽게 이동(클릭 방지).

## 3. 레이어 모델

`MasterMixer` → PrimaryTone / Drone / SecondaryTone / BinauralOrPulse / Nature / Pad / Chime.
공통 필드: `id, enabled, mute, gainDb, pan, fadeInMs, fadeOutMs`.
주파수 레이어 추가 필드: `frequencyHz, targetFrequencyHz, waveform(sine only v1), phase, mode, pulseRateHz, pulseDepth, leftFrequencyHz, rightFrequencyHz`.

## 4. 작업 순서 (실제 수행 순서)

1. ✅ 저장소·환경 조사, 디렉터리 스캐폴딩
2. ✅ 디자인 시스템 토큰 (`core/design`)
3. ✅ 데이터 모델 + schemaVersion (`core/models`)
4. ✅ 기본 프리셋 JSON (`assets/presets`) + 로더
5. ✅ 타입 채널 인터페이스 (`core/audio`) + 재생 상태 머신
6. ✅ 로컬 저장/백업 (`core/data`)
7. ✅ 상태 관리 (`core/state`)
8. ✅ 화면: 온보딩/홈/차크라/스튜디오/기록/설정/플레이어/미니플레이어/레이키 + 바텀시트/모달
9. ✅ Android Kotlin 오디오 엔진 + MediaSessionService + 채널 브리지
10. ✅ iOS Swift 오디오 엔진 + 채널 브리지 (미검증 표기)
11. ✅ 플레이스홀더 WAV 생성 스크립트 (Python, 실제 실행)
12. ✅ 테스트: Dart 유닛테스트 + Python DSP 검증(실행) + 프리셋 검증(실행)
13. ✅ 문서: AUDIO_ARCHITECTURE / ASSET_GUIDE / PRESET_SCHEMA / TEST_REPORT

## 5. 안전 원칙 (앱 전반)

- 앱 실행 직후 **자동 재생 금지**, 최초 마스터 음량 15%.
- 시작 페이드 ≥ 3초, 종료 페이드 기본 10초.
- 이어폰 분리 시 기본 일시정지, 출력 장치 변경 시 자동 음량 상승 금지.
- 프리셋 전환 크로스페이드 1.5초, NaN/Inf 차단, 소프트 리미터 ceiling −1dBFS.
- 주파수는 개인적 상징 초기값이며 치료·과학적 효능으로 표현하지 않는다.
- 내부 음량은 dBFS/상대값으로만 표기(실제 dB SPL 아님).

## 6. 미구현/후속 (초기 버전 제외)

사각/톱니/삼각 파형, AI 작곡, 온라인, 마이크, 세션 오디오 렌더링(WAV/M4A export).
단, 데이터 모델·엔진은 export 재사용이 가능하도록 설계.
