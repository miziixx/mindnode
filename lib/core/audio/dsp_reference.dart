import 'dart:math' as math;

/// 순수 Dart DSP 레퍼런스 구현.
///
/// 네이티브(Kotlin/Swift) 오디오 엔진은 이 알고리즘과 1:1로 동일하게 작성한다.
/// 이 파일은 테스트로 실측 검증되며, 크로스-언어 정확성의 기준이 된다.
///
/// 규칙(지침 4·5·6·7·8·10):
/// - 위상은 double 정밀도로 유지, 버퍼 경계에서 0으로 리셋하지 않음
/// - 위상 2π 초과 시 wrap
/// - 실제 스트림 샘플레이트 기준 계산
/// - 좌/우 독립 위상
/// - 콜백 내 객체 생성/힙 할당 금지(사전 할당 버퍼 재사용)
/// - 파라미터는 샘플 단위 램프로 이동(클릭 방지)

const double twoPi = 2 * math.pi;

double dbToLinear(double db) => math.pow(10.0, db / 20.0).toDouble();

/// 한 샘플 이동하는 1차 파라미터 램프. current→target 을 램프 시간에 맞춰 이동.
class ParamRamp {
  double current;
  double target;
  double _stepPerSample;
  double _rampSamples;

  ParamRamp(this.current)
      : target = current,
        _stepPerSample = 0,
        _rampSamples = 1;

  /// 램프 목표 설정. rampMs 동안 선형 이동.
  void setTarget(double value, double sampleRate, double rampMs) {
    target = value;
    _rampSamples = math.max(1.0, sampleRate * rampMs / 1000.0);
    _stepPerSample = (target - current) / _rampSamples;
  }

  /// 즉시 값 세팅(램프 없음).
  void snap(double value) {
    current = value;
    target = value;
    _stepPerSample = 0;
  }

  /// 한 샘플 진행 후 현재값 반환. 오버슈트 방지.
  double next() {
    if ((_stepPerSample > 0 && current >= target) ||
        (_stepPerSample < 0 && current <= target) ||
        _stepPerSample == 0) {
      current = target;
      _stepPerSample = 0;
      return current;
    }
    current += _stepPerSample;
    return current;
  }
}

/// 위상 누산기(사인 오실레이터 1개). 좌/우 각각 인스턴스화.
class PhaseOsc {
  double phase;
  PhaseOsc([this.phase = 0]);

  /// 한 샘플 진행, sin 값 반환.
  double next(double freqHz, double sampleRate) {
    final inc = twoPi * freqHz / sampleRate;
    final s = math.sin(phase);
    phase += inc;
    if (phase >= twoPi) {
      phase -= twoPi;
    } else if (phase < 0) {
      phase += twoPi;
    }
    return s;
  }
}

/// 비정상 샘플 차단(NaN/Inf → 0), 하드 세이프티.
double sanitize(double x) {
  if (x.isNaN || x.isInfinite) return 0.0;
  return x;
}

/// 소프트 리미터(tanh 기반). ceiling(선형)까지만 부드럽게 눌러줌.
/// -1dBFS ceiling ≈ 0.8913.
class SoftLimiter {
  final double ceiling;
  SoftLimiter({double ceilingDb = -1.0}) : ceiling = dbToLinear(ceilingDb);

  double process(double x) {
    x = sanitize(x);
    // tanh로 부드럽게 압축하고 ceiling로 스케일. |x|가 작으면 거의 선형.
    final y = ceiling * _tanh(x / ceiling);
    // 최종 하드 세이프티(수치 오차 대비)
    if (y > ceiling) return ceiling;
    if (y < -ceiling) return -ceiling;
    return y;
  }

  static double _tanh(double x) {
    if (x > 20) return 1.0;
    if (x < -20) return -1.0;
    final e2 = math.exp(2 * x);
    return (e2 - 1) / (e2 + 1);
  }
}

/// 활성 레이어 수에 따른 헤드룸(간단한 1/sqrt(n) 스케일).
double headroomScale(int activeLayers) {
  if (activeLayers <= 1) return 1.0;
  return 1.0 / math.sqrt(activeLayers.toDouble());
}

/// 드론 보이스 구성(Sub/Main/Air). 각 보이스는 좌우 독립 위상.
class DroneVoiceSet {
  final PhaseOsc subL, subR, mainL, mainR, airL, airR;
  // 매우 느린 진폭 변화(LFO). 무작위 아님(결정적).
  final PhaseOsc lfoL, lfoR;

  DroneVoiceSet()
      : subL = PhaseOsc(0.0),
        subR = PhaseOsc(0.3),
        mainL = PhaseOsc(1.1),
        mainR = PhaseOsc(1.4),
        airL = PhaseOsc(2.2),
        airR = PhaseOsc(2.5),
        lfoL = PhaseOsc(0.0),
        lfoR = PhaseOsc(math.pi / 2);

  /// 스테레오 드론 한 샘플. [outLR] 길이 2 버퍼에 기록(할당 없음).
  void nextInto(
    List<double> outLR, {
    required double centerHz,
    required double sampleRate,
    required double subRatio,
    required double mainRatio,
    required double airRatio,
    required double movementRateHz,
    required double stereoWidth,
    required double linGain,
  }) {
    final nyquist = sampleRate * 0.5;
    final airHz = centerHz * 2.0;
    final airOn = airHz < nyquist * 0.98;

    // 느린 진폭 LFO (0.85~1.0 범위)
    final lfoLv = 0.925 + 0.075 * lfoL.next(movementRateHz, sampleRate);
    final lfoRv = 0.925 + 0.075 * lfoR.next(movementRateHz, sampleRate);

    double l = 0, r = 0;
    l += subRatio * subL.next(centerHz * 0.5, sampleRate);
    r += subRatio * subR.next(centerHz * 0.5, sampleRate);
    l += mainRatio * mainL.next(centerHz, sampleRate);
    r += mainRatio * mainR.next(centerHz, sampleRate);
    if (airOn) {
      l += airRatio * airL.next(airHz, sampleRate);
      r += airRatio * airR.next(airHz, sampleRate);
    }

    l *= lfoLv * linGain;
    r *= lfoRv * linGain;

    // 미세 스테레오 폭
    final mid = 0.5 * (l + r);
    final side = 0.5 * (l - r) * (1.0 + stereoWidth);
    outLR[0] = sanitize(mid + side);
    outLR[1] = sanitize(mid - side);
  }
}
