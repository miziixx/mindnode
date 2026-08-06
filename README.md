# 마인드사운드 (MindSound)

개인용 오프라인 **주파수·명상 사운드 앱**. 미리 만든 음악 파일을 재생하는 앱이 아니라,
앱이 **실시간으로 생성하는** 주파수 톤·드론·바이노럴·펄스와 **로컬 음원**(자연음·패드·차임)을
하나의 세션으로 실시간 믹싱한다.

- 빌드 이름: **마인드사운드 (MindSound)** · 앱 ID: `com.mindsound.app`
- Flutter(UI/상태/저장) + Android(Kotlin)/iOS(Swift) 네이티브 오디오 엔진
- 서버·로그인·광고·분석·클라우드·구독·소셜·마이크 녹음 **없음**. 모든 데이터는 기기에만 저장.

> ⚠️ 이 앱의 주파수는 개인적 명상·상징을 위한 초기값이며 **치료 효과나 과학적 효능을 뜻하지 않는다.**
> 내부 음량은 dBFS/상대값이며 실제 dB SPL이 아니다. 두통·이명·어지럼이 생기면 사용을 멈추세요.

## 주요 기능

- 실시간 주파수/드론/바이노럴/펄스 생성 + 로컬 자연음/패드/차임 믹싱 (클릭 없는 램프, 소프트 리미터)
- 14개 기본 프리셋(우울·활력·풍요·정화·명상·레이키 + 1~7 차크라 + 전체 순환) 및 사용자 편집/저장
- 단계형 시퀀스 세션, 차크라 순차 재생, 레이키(위치 변경 차임 타이머, 자동 어둡게)
- 전체 플레이어 + 미니 플레이어(화면 이동해도 유지), 레이어별 음량/on-off/상세 설정
- 기록(세션 전/후 상태·편안함·메모, 선택 입력), JSON 백업/복원
- 다크 테마 디자인 시스템, 접근성(라벨·터치 44+·글자 확대·애니메이션 감소)

## 프로젝트 구조

```
lib/
  core/design/   디자인 토큰(색상/타이포/간격/반경/애니메이션) + 다크 테마
  core/models/   Preset·SessionStage·레이어·기록·설정·음원 카탈로그 (+ schemaVersion)
  core/audio/    타입 채널 인터페이스·이벤트·재생 상태 머신·DSP 레퍼런스·시퀀스 스케줄러
  core/data/     로컬 JSON 저장·백업·마이그레이션(프리셋/기록/설정 repository)
  core/state/    AppState · PlaybackController
  screens/       onboarding·home·chakra·studio·records·settings·player·reiki
  widgets/       하단바·미니플레이어·공명 시각화·공용 위젯·다이얼로그·레이어 시트
assets/
  presets/       default_presets.json · chakra_presets.json
  audio/          nature·pads·chimes (플레이스홀더 WAV, ASSET_GUIDE.md 참고)
native/
  android/       SynthDsp·AudioAssets·MindSoundAudioEngine·MainActivity·PlaybackService (Kotlin)
  ios/           AppDelegate.swift (엔진 포함 단일 파일)
tools/
  audio_verify/  오프라인 오디오 검증 시스템(Python) — 실행됨
  apply_native.py           CI 네이티브 오버레이 스크립트
  generate_placeholder_assets.py  플레이스홀더 WAV 생성 — 실행됨
test/            Dart 유닛테스트(DSP·스케줄러·모델·프리셋 데이터)
test_output/     오디오 검증 결과(JSON/CSV/MD) + 참조/실패 WAV
```

## 실행 방법 (로컬 개발 머신)

Flutter SDK(3.19+)와 Android SDK(또는 Xcode)가 설치된 환경에서:

```bash
# 1) 플랫폼 스캐폴드 생성(lib/·pubspec·assets 유지)
flutter create --org com.mindsound --project-name mindsound --platforms=android,ios .

# 2) 네이티브 오디오 엔진 오버레이 + manifest/plist 패치
python3 tools/apply_native.py --platform both

# 3) 의존성 설치 후 실행/빌드
flutter pub get
flutter test
flutter run                 # 기기/에뮬레이터에서 실행
flutter build apk --debug   # Android APK
flutter build ios --no-codesign   # iOS (macOS)
```

> `flutter create` 는 기존 `lib/`, `pubspec.yaml`, `assets/` 를 덮어쓰지 않고 플랫폼 폴더만 생성한다.
> 네이티브 소스는 `native/` 에 보관되며 `apply_native.py` 가 생성된 프로젝트에 주입한다.

## 오디오 검증 실행 (빌드 불필요)

```bash
pip install numpy
python3 tools/audio_verify/run_tests.py   # 132/132 PASS, test_output/ 생성
```

## CI (GitHub Actions)

`.github/workflows/build.yml`:
1. `audio-verify` — 오프라인 DSP 검증(관문)
2. `android` — 스캐폴드 생성 → 네이티브 오버레이 → `flutter test` → `flutter build apk --debug`(APK 아티팩트)
3. `ios` (macOS) — `flutter build ios --no-codesign`

## 문서

- `IMPLEMENTATION_PLAN.md` · `AUDIO_ARCHITECTURE.md` · `ASSET_GUIDE.md` · `PRESET_SCHEMA.md`
- `PREBUILD_AUDIO_TEST_PLAN.md` · `PREBUILD_AUDIO_TEST_REPORT.md` · `AUDIO_TESTING_README.md`
- `TEST_REPORT.md` (실행/미실행 항목 정리)

## 알려진 미완료 / 실기기 검증 필요

- Android/iOS **빌드는 CI에서 수행**하며, iOS는 실행 검증되지 않은 상태로 명시.
- 실제 자연음/패드/차임 음원은 **플레이스홀더**(라이선스 확인 후 교체 — ASSET_GUIDE).
- 네이티브 오디오의 실기기 검증(경로 변경·인터럽션·백그라운드·언더런) 필요.
- 파형은 사인만(사각/톱니/삼각 후속), 세션 오디오 export(WAV/M4A) 후속.
