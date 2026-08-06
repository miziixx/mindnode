# AUDIO_ARCHITECTURE.md — 마인드사운드 오디오 아키텍처

## 개요

```
Flutter (UI · 상태 · 저장)                      Native 실시간 DSP
──────────────────────────                     ─────────────────────────────
PlaybackController (ChangeNotifier)             Android(Kotlin)          iOS(Swift)
  ├─ 재생 상태 머신                              MindSoundAudioEngine     MindSoundEngine
  ├─ 세션(프리셋 깊은 복제)                       ├─ AudioTrack            ├─ AVAudioEngine
  └─ AudioEngineInterface                        │   MODE_STREAM          ├─ AVAudioSourceNode
        │  MethodChannel  ──────────────►        │   PCM Float, Stereo    ├─ AVAudioPlayerNode×3
        │  (명령: 타입 명확)                       ├─ SynthDsp(공용 상수)    └─ AVAudioMixerNode
        │                                         ├─ WavDecoder/ClipPlayer
        ◄──────────────  EventChannel             └─ PlaybackService
           (이벤트: engineReady, progress, …)         (Foreground + 알림)
```

**Flutter는 오디오 샘플을 생성/전달하지 않는다.** 명령과 목표 파라미터만 전달하고,
샘플 단위 램프·합성·믹싱·리미팅은 네이티브가 수행한다.

## 레이어 구조

```
MasterMixer
├── PrimaryToneLayer      실시간 사인
├── DroneLayer            Sub(0.5c)/Main(c)/Air(2c) + 느린 LFO + 스테레오 폭
├── SecondaryToneLayer    실시간 사인
├── BinauralOrPulseLayer  좌우 독립(바이노럴) / 진폭 변조(펄스)
├── NatureLayer           로컬 WAV seamless loop
├── PadLayer              로컬 WAV seamless loop
└── ChimeLayer            로컬 WAV one-shot(+ 인터벌)
```

## 정본 DSP 상수 (v1) — 3개 구현이 동일

| 항목 | 값/식 |
|------|-------|
| 사인 | `phase += 2π·f/sr`, `sin(phase)`, `[0,2π)` wrap, phase는 Double |
| 램프 | 선형, `step=(target−current)/max(1, sr·ms/1000)`, 오버슈트 클램프 |
| 램프 시간 | 주파수/게인 30ms · 레이어 on/off 100ms · 프리셋 크로스페이드 1500ms · 시작 페이드 3000ms · 종료 10000ms |
| 소프트 리미터 | `y = ceil·tanh(x/ceil)`, `ceil=10^(−1/20)` (−1 dBFS) |
| 헤드룸 | `1/√(활성레이어수)` |
| 드론 비율 | Sub 35% · Main 55% · Air 10%, Air off if `2c ≥ 0.98·Nyquist` |
| 드론 LFO | `0.925 + 0.075·sin(2π·movement·t)`, movement 0.03~0.10Hz, L/R 위상차 π/2 |
| 바이노럴 | L=carrier, R=carrier+beat (반전 시 교환), 좌우 독립 위상, 모노 합산 없음 |
| 펄스 | `env=(1−depth)+depth·(0.5+0.5·cos(2π·rate·t))`, center/alternate(π 위상차) |
| 주파수 안전범위 | `[20Hz, min(20000, sr·0.45)]` |

정본 소스: `lib/core/audio/dsp_reference.dart`.
검증 미러: `tools/audio_verify/dsp.py`. 포팅: `native/android/SynthDsp.kt`, `native/ios/AppDelegate.swift`.

## 실시간 안전(오디오 콜백/렌더 블록 내부 금지 사항)

파일 읽기·디코딩·네트워크·힙 할당·무거운 로그·UI 호출·DB·장시간 lock.
- 파라미터는 lock-free 스냅샷으로 전달(Android: `AtomicReference<Stage>`, iOS: `NSLock.try()` 복사).
- 로컬 음원은 백그라운드 스레드에서 PCM 버퍼로 사전 로드 후 커서로만 읽음.

## 명령 / 이벤트 (타입 채널)

- 명령: initialize, loadPreset, start, pause, resume, stop(graceful), seekToStage,
  nextStage, previousStage, setMasterGain, setLayerGain, setLayerEnabled, setFrequency,
  setSecondaryFrequency, setDroneParameters, setBinauralParameters, setPulseParameters,
  setNatureAsset, setPadAsset, triggerChime, setTimer, dispose.
- 이벤트: engineReady, playbackStateChanged, currentStageChanged, progressChanged,
  remainingTimeChanged, routeChanged, interruptionChanged, underrunDetected,
  errorOccurred, sessionCompleted, chimeTriggered.

채널 이름: `com.mindsound.app/audio`(Method), `com.mindsound.app/audio_events`(Event).

## 재생 상태 머신

`idle → preparing → ready → playing ⇄ paused → fadingOut → completed / error`

방지: 중복 엔진 생성, 준비 중 정지 후 지연 재생, 타이머 종료 후 잔류음, 프리셋 교체 중
이전 음원 지속, 백그라운드/UI 상태 불일치, 이어폰 분리 후 스피커 재생, 앱 재실행 자동 재생.
**앱 실행 직후 자동 재생하지 않는다.**

## 믹싱·음량 안전

레이어 개별 게인 → 헤드룸 확보 → 마스터 게인 → 소프트 리미터 → 출력.
초기 내부 게인(dBFS): Primary −26 · Drone −24 · Secondary −32~−36 · Binaural/Pulse −30 ·
Nature −20 · Pad −24 · Chime −24 · Master 시작 낮게(기본 15%) · Limiter ceiling −1.
NaN/Inf 차단, 출력 [−ceil, +ceil] 보호. 내부 레벨은 dBFS/상대값이며 실제 dB SPL 아님.

## 백그라운드 재생

- Android: `PlaybackService`(Foreground, `mediaPlayback` 타입) + 알림. 엔진은 액티비티와
  분리된 싱글턴(`MindSoundAudio.engine`)이라 Activity 종료 후에도 재생 유지.
  (초기 버전은 프레임워크 알림 기반. Media3 `MediaSessionService` 어댑터는 후속 확장 항목.)
- iOS: `AVAudioSession(.playback)` + `UIBackgroundModes: audio`(Info.plist), 잠금화면 재생.

## 알려진 한계 / 후속

- Android MediaSession 잠금화면 트랜스포트 컨트롤(재생/정지 버튼)은 알림 액션 확장 필요.
- 파형은 사인만(사각/톱니/삼각은 앨리어싱 방지와 함께 후속).
- 세션 오디오 렌더링(WAV/M4A export)은 미구현이나 엔진/데이터 모델은 재사용 가능 구조.
