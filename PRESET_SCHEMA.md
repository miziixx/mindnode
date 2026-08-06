# PRESET_SCHEMA.md — 프리셋 데이터 스키마

- 현재 `schemaVersion`: **1**
- 데이터는 UI/오디오 코드에 하드코딩하지 않고 이 모델을 통해서만 다룬다.
- 마이그레이션: `lib/core/data/migrations.dart` (`migratePresetCollection`).

## 엔티티

`Preset` · `SessionStage` · `ToneLayer` · `DroneLayer` · `BinauralLayer` · `PulseLayer` ·
`AssetLayer` · `PlaybackSession`(런타임) · `SessionRecord` · `UserSettings` · `AudioAssetMetadata`.
소스: `lib/core/models/*.dart`.

## Preset

| 필드 | 타입 | 설명 |
|------|------|------|
| schemaVersion | int | 스키마 버전(현재 1) |
| id | string | 고유 id |
| title | string | 표시 이름 |
| category | string | uplift·energize·abundance·cleanse·meditation·reiki·chakra·custom |
| symbolicUse | bool | 상징적 초기값 표기(치료 효과 아님) |
| fadeInSec / fadeOutSec | int | 시작/종료 페이드 |
| masterGainDb | number | 마스터 기준 레벨(dBFS) |
| isBuiltIn | bool | 기본 프리셋 여부 |
| favorite | bool | 즐겨찾기 |
| chakraIndex | int? | 차크라 프리셋이면 1~7 |
| stages | SessionStage[] | 단계 목록 |

## SessionStage

| 필드 | 타입 | 설명 |
|------|------|------|
| id, title | string | |
| durationSec | int | 단계 길이 |
| primaryTone / secondaryTone | ToneLayer | `{enabled, frequencyHz, gainDb, pan}` |
| drone | DroneLayer | `{enabled, centerHz, gainDb, movementRateHz, stereoWidth, subVoiceRatio, mainVoiceRatio, airVoiceRatio}` |
| binaural | BinauralLayer | `{enabled, carrierHz, beatHz, invert, gainDb}` |
| pulse | PulseLayer | `{enabled, frequencyHz, rateHz, depth, stereoMode(center/alternate), gainDb}` |
| natureAssetId / padAssetId / chimeAssetId | string? | 음원 id(`AssetCatalog`) |
| chimeIntervalSec | int | 0이면 반복 없음 |
| transitionDurationSec | number | 단계 전환 크로스페이드(기본 1.5초 이상) |

## 예시

```json
{
  "schemaVersion": 1,
  "id": "abundance_ritual",
  "title": "풍요 · 돈 들어오는 의식",
  "category": "abundance",
  "symbolicUse": true,
  "fadeInSec": 5, "fadeOutSec": 20, "masterGainDb": -12,
  "isBuiltIn": true,
  "stages": [{
    "id": "main", "title": "풍요 의식", "durationSec": 1200,
    "primaryTone": { "enabled": false, "frequencyHz": 432.0, "gainDb": -30, "pan": 0 },
    "drone": { "enabled": true, "centerHz": 432.0, "gainDb": -24, "movementRateHz": 0.05, "stereoWidth": 0.25 },
    "secondaryTone": { "enabled": true, "frequencyHz": 888.0, "gainDb": -36, "pan": 0 },
    "pulse": { "enabled": true, "frequencyHz": 432.0, "rateHz": 8.8, "depth": 0.2, "stereoMode": "center", "gainDb": -30 },
    "natureAssetId": null, "padAssetId": "warm_air", "chimeAssetId": "bowl_high",
    "chimeIntervalSec": 0, "transitionDurationSec": 1.5
  }]
}
```

## 기본 프리셋 데이터 파일 위치

- `assets/presets/default_presets.json` — A 마음 끌어올리기 / B 활력 깨우기 / C 풍요 의식 /
  D 부정적 에너지 정화(4단계) / M 깊은 명상 / N 레이키 셀프 (6개)
- `assets/presets/chakra_presets.json` — 1~7 차크라(E~K) + 전체 차크라 순환(L) (8개)
- 합계 **14개 프리셋 / 23단계** (JSON 검증 통과, `test/preset_data_test.dart`).

## 저장/백업

- 로컬 전용. 사용자 프리셋: `user_presets.json` · 기본 수정본: `builtin_overrides.json` ·
  기록: `records.json` · 설정: `settings.json` (앱 문서 디렉터리).
- 백업: JSON 내보내기/가져오기, 버전 검사, 유효성 검증, 가져오기 전 미리보기, 중복 처리,
  덮어쓰기 확인 (`lib/core/data/backup_service.dart`). 오디오 원본은 백업에 미포함.
