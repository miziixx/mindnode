/// 사용자 설정. 로컬에만 저장.
class UserSettings {
  int schemaVersion;
  // 재생
  int defaultTimerSec;
  int startFadeSec;
  int endFadeSec;
  bool pauseOnHeadphoneUnplug;
  bool autoStopAfterComplete;
  // 오디오
  int initialMasterVolumePercent; // 최초 시작 음량(낮게)
  int chimeVolumePercent;
  bool binauralInvert;
  bool confirmOnRouteChange;
  bool highFreqWarning; // 10kHz 이상 경고
  // 레이키
  int reikiDefaultLengthSec;
  int reikiHandChangeIntervalSec;
  bool reikiChime;
  bool reikiVibration;
  bool reikiAutoDim;
  // 표시
  bool darkTheme;
  bool reduceMotion;
  bool showResonanceViz;
  bool largeText;
  bool showFrequencyDecimals;
  bool breathingGuide; // 재생 중 호흡 가이드 표시
  // 온보딩
  bool onboardingDone;

  UserSettings({
    this.schemaVersion = 1,
    this.defaultTimerSec = 1200,
    this.startFadeSec = 5,
    this.endFadeSec = 10,
    this.pauseOnHeadphoneUnplug = true,
    this.autoStopAfterComplete = true,
    this.initialMasterVolumePercent = 15,
    this.chimeVolumePercent = 70,
    this.binauralInvert = false,
    this.confirmOnRouteChange = true,
    this.highFreqWarning = true,
    this.reikiDefaultLengthSec = 2700,
    this.reikiHandChangeIntervalSec = 300,
    this.reikiChime = true,
    this.reikiVibration = true,
    this.reikiAutoDim = true,
    this.darkTheme = true,
    this.reduceMotion = false,
    this.showResonanceViz = true,
    this.largeText = false,
    this.showFrequencyDecimals = true,
    this.breathingGuide = false,
    this.onboardingDone = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
        schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
        defaultTimerSec: (j['defaultTimerSec'] as num?)?.toInt() ?? 1200,
        startFadeSec: (j['startFadeSec'] as num?)?.toInt() ?? 5,
        endFadeSec: (j['endFadeSec'] as num?)?.toInt() ?? 10,
        pauseOnHeadphoneUnplug:
            j['pauseOnHeadphoneUnplug'] as bool? ?? true,
        autoStopAfterComplete: j['autoStopAfterComplete'] as bool? ?? true,
        initialMasterVolumePercent:
            (j['initialMasterVolumePercent'] as num?)?.toInt() ?? 15,
        chimeVolumePercent: (j['chimeVolumePercent'] as num?)?.toInt() ?? 70,
        binauralInvert: j['binauralInvert'] as bool? ?? false,
        confirmOnRouteChange: j['confirmOnRouteChange'] as bool? ?? true,
        highFreqWarning: j['highFreqWarning'] as bool? ?? true,
        reikiDefaultLengthSec:
            (j['reikiDefaultLengthSec'] as num?)?.toInt() ?? 2700,
        reikiHandChangeIntervalSec:
            (j['reikiHandChangeIntervalSec'] as num?)?.toInt() ?? 300,
        reikiChime: j['reikiChime'] as bool? ?? true,
        reikiVibration: j['reikiVibration'] as bool? ?? true,
        reikiAutoDim: j['reikiAutoDim'] as bool? ?? true,
        darkTheme: j['darkTheme'] as bool? ?? true,
        reduceMotion: j['reduceMotion'] as bool? ?? false,
        showResonanceViz: j['showResonanceViz'] as bool? ?? true,
        largeText: j['largeText'] as bool? ?? false,
        showFrequencyDecimals: j['showFrequencyDecimals'] as bool? ?? true,
        breathingGuide: j['breathingGuide'] as bool? ?? false,
        onboardingDone: j['onboardingDone'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'defaultTimerSec': defaultTimerSec,
        'startFadeSec': startFadeSec,
        'endFadeSec': endFadeSec,
        'pauseOnHeadphoneUnplug': pauseOnHeadphoneUnplug,
        'autoStopAfterComplete': autoStopAfterComplete,
        'initialMasterVolumePercent': initialMasterVolumePercent,
        'chimeVolumePercent': chimeVolumePercent,
        'binauralInvert': binauralInvert,
        'confirmOnRouteChange': confirmOnRouteChange,
        'highFreqWarning': highFreqWarning,
        'reikiDefaultLengthSec': reikiDefaultLengthSec,
        'reikiHandChangeIntervalSec': reikiHandChangeIntervalSec,
        'reikiChime': reikiChime,
        'reikiVibration': reikiVibration,
        'reikiAutoDim': reikiAutoDim,
        'darkTheme': darkTheme,
        'reduceMotion': reduceMotion,
        'showResonanceViz': showResonanceViz,
        'largeText': largeText,
        'showFrequencyDecimals': showFrequencyDecimals,
        'breathingGuide': breathingGuide,
        'onboardingDone': onboardingDone,
      };
}
