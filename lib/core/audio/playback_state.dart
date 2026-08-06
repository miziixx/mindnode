/// 재생 상태 머신. 중복 엔진 생성, 유령 재생 등을 방지한다.
enum PlaybackState {
  idle,
  preparing,
  ready,
  playing,
  paused,
  fadingOut,
  completed,
  error,
}

extension PlaybackStateX on PlaybackState {
  bool get isActive =>
      this == PlaybackState.playing ||
      this == PlaybackState.paused ||
      this == PlaybackState.fadingOut ||
      this == PlaybackState.preparing ||
      this == PlaybackState.ready;

  bool get isPlaying => this == PlaybackState.playing;

  static PlaybackState fromString(String s) {
    return PlaybackState.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlaybackState.idle,
    );
  }
}
