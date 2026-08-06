# ASSET_GUIDE.md — 자연음·패드·차임 음원 교체 가이드

## 현재 상태: 플레이스홀더

`assets/audio/**` 의 모든 파일은 **플레이스홀더**(파일명에 `_placeholder` 명시)이며,
`tools/generate_placeholder_assets.py` 로 생성된 합성음이다. **실제 최종 음원이 아니다.**

```
assets/audio/
├── nature/   rain_soft · forest_morning · ocean_calm · stream_soft · wind_light · fire_soft
├── pads/     warm_air · deep_space · soft_light · grounding_dark · crystal_air
└── chimes/   bell_soft_01 · bell_soft_02 · bowl_low · bowl_high · session_end
```

## 실제 음원으로 교체하는 방법

1. **라이선스 확인**: 개인 사용/재배포가 허용된 음원만 사용한다. 출처 불명 음원을
   임의로 다운로드/포함하지 않는다. (앱은 자동 음원 다운로드 기능이 없다.)
2. **포맷 권장**: PCM WAV, 48kHz, Stereo. 자연음/패드는 **루프 시작과 끝이 자연스럽게
   연결**되도록 편집(제로 크로싱/짧은 크로스페이드). 차임은 감쇠 one-shot.
3. **파일 교체**: 같은 폴더에 넣고 파일명을 카탈로그와 맞춘다. 파일명을 바꾸려면
   `lib/core/models/audio_asset.dart` 의 `assetPath` 를 함께 수정한다.
   - 예: `assets/audio/pads/warm_air.wav` 로 교체 후 카탈로그의 경로를
     `..._placeholder.wav` → `warm_air.wav` 로 변경.
4. `pubspec.yaml` 의 `assets:` 는 폴더 단위로 등록되어 있어 새 파일은 자동 포함된다.
5. **검증**: 실제 음원 교체 후 루프 경계 불연속/클릭과 크로스페이드를 재검증한다.
   `tools/audio_verify/` 의 분석기(`analyzer.py`)로 마지막/첫 샘플 차이·기울기를 점검할 수 있다.

## 코드에서의 참조

- 카탈로그: `lib/core/models/audio_asset.dart` (`AssetCatalog`)
- 로드(Android): `native/android/AudioAssets.kt` — `flutter_assets/<assetPath>` 를 PCM Float 로 디코딩
- 로드(iOS): `native/ios/AppDelegate.swift` — `FlutterDartProject.lookupKey(forAsset:)` → `AVAudioFile`

## 주의

- 오디오 원본 파일은 JSON 백업(프리셋/기록)에 **포함되지 않는다**. 백업은 설정·프리셋·기록만.
- 자연음/패드는 seamless loop, 차임은 one-shot(+ 스테이지 인터벌)로 재생된다.
- 플레이스홀더 상태에서는 "실제 음원 품질"을 검증했다고 주장하지 않는다.
