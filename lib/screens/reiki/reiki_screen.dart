import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_tokens.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../core/state/playback_controller.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/breathing_guide.dart';
import '../../widgets/common.dart';
import '../../widgets/dreamy_background.dart';

/// 레이키 세션 종류.
enum ReikiKind { self, other, pet, space, chakra, custom }

const _reikiKindLabels = {
  ReikiKind.self: '셀프 레이키',
  ReikiKind.other: '타인 레이키',
  ReikiKind.pet: '반려동물 레이키',
  ReikiKind.space: '공간 정화',
  ReikiKind.chakra: '차크라 순차 레이키',
  ReikiKind.custom: '사용자 정의',
};

/// 세션 종류별 손 위치 풀(사용자가 켜고 끌 수 있음).
const _reikiPositionPools = {
  ReikiKind.self: ['정수리', '눈·이마', '목·가슴', '가슴', '명치', '아랫배', '등·허리'],
  ReikiKind.other: ['머리', '눈·이마', '목', '가슴', '명치', '복부', '등 위', '등 아래', '무릎', '발'],
  ReikiKind.pet: ['머리', '목·어깨', '등', '배', '엉덩이·다리'],
  ReikiKind.space: ['공간 중심', '동쪽', '남쪽', '서쪽', '북쪽'],
  ReikiKind.chakra: ['뿌리', '천골', '태양신경총', '심장', '목', '제3의 눈', '정수리'],
  ReikiKind.custom: ['위치 1', '위치 2', '위치 3', '위치 4', '위치 5', '위치 6'],
};

void openReiki(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ReikiSetupScreen()));
}

class ReikiSetupScreen extends StatefulWidget {
  const ReikiSetupScreen({super.key});
  @override
  State<ReikiSetupScreen> createState() => _ReikiSetupScreenState();
}

class _ReikiSetupScreenState extends State<ReikiSetupScreen> {
  ReikiKind _kind = ReikiKind.self;
  int _lengthMin = 45;
  int _intervalMin = 5;
  bool _chime = true;
  bool _vibration = true;
  bool _meditationOn = true; // 시작 명상
  int _meditationMin = 3;
  late Set<String> _enabled; // 선택된 부위

  static const _accent = ChakraColors.heart;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _lengthMin = s.reikiDefaultLengthSec ~/ 60;
    _intervalMin = s.reikiHandChangeIntervalSec ~/ 60;
    _chime = s.reikiChime;
    _vibration = s.reikiVibration;
    _enabled = {..._reikiPositionPools[_kind]!};
  }

  void _selectKind(ReikiKind k) {
    setState(() {
      _kind = k;
      _enabled = {..._reikiPositionPools[k]!};
    });
  }

  List<String> get _positionsInOrder =>
      _reikiPositionPools[_kind]!.where(_enabled.contains).toList();

  @override
  Widget build(BuildContext context) {
    final pool = _reikiPositionPools[_kind]!;
    return Scaffold(
      backgroundColor: AppColors.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('레이키'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.7),
            radius: 1.1,
            colors: [_accent.withOpacity(0.10), AppColors.deep],
            stops: const [0.0, 0.55],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DreamyBackground(
                accent: _accent,
                reduceMotion:
                    context.watch<AppState>().settings.reduceMotion,
                particleCount: 24,
              ),
            ),
            ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Eyebrow('세션 종류'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in ReikiKind.values)
                  _SelectPill(
                    label: _reikiKindLabels[k]!,
                    selected: _kind == k,
                    accent: _accent,
                    onTap: () => _selectKind(k),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            // 부위 선택
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('부위 선택',
                            style: AppTypography.label
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text('${_enabled.length} / ${pool.length}',
                          style: AppTypography.tiny),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('원하는 부위만 켜세요 · 켠 순서대로 진행됩니다',
                      style: AppTypography.tiny.copyWith(fontSize: 10)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in pool)
                        _SelectPill(
                          label: p,
                          selected: _enabled.contains(p),
                          accent: _accent,
                          dense: true,
                          onTap: () => setState(() {
                            if (_enabled.contains(p)) {
                              if (_enabled.length > 1) _enabled.remove(p);
                            } else {
                              _enabled.add(p);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sliderCard('세션 길이', '$_lengthMin분', _lengthMin.toDouble(), 10, 90,
                (v) => setState(() => _lengthMin = v.round())),
            _sliderCard('부위 변경 간격', '$_intervalMin분마다', _intervalMin.toDouble(),
                1, 10, (v) => setState(() => _intervalMin = v.round())),
            // 시작 명상(호흡 고르기) — 켜고 끌 수 있고 시간 조절 가능.
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('시작 명상', style: AppTypography.label),
                          const SizedBox(height: 2),
                          Text('부위 진행 전에 호흡을 고르는 시간',
                              style: AppTypography.tiny.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                    AppSwitch(
                        value: _meditationOn,
                        onChanged: (v) => setState(() => _meditationOn = v)),
                  ]),
                  if (_meditationOn) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: Text('명상 시간', style: AppTypography.label)),
                      Text('$_meditationMin분',
                          style: AppTypography.tiny.copyWith(color: _accent)),
                    ]),
                    Slider(
                      value: _meditationMin.toDouble(),
                      min: 1,
                      max: 15,
                      onChanged: (v) =>
                          setState(() => _meditationMin = v.round()),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('차임', style: AppTypography.label)),
                  AppSwitch(
                      value: _chime,
                      onChanged: (v) => setState(() => _chime = v)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('진동', style: AppTypography.label)),
                  AppSwitch(
                      value: _vibration,
                      onChanged: (v) => setState(() => _vibration = v)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
                '${_meditationOn ? "명상 $_meditationMin분 · " : ""}부위 ${_positionsInOrder.length}곳 · 약 ${_lengthMin + (_meditationOn ? _meditationMin : 0)}분',
                textAlign: TextAlign.center,
                style: AppTypography.tiny),
            const SizedBox(height: 10),
            PrimaryButton(label: '시작', icon: AppIcons.play, onPressed: _start),
          ],
        ),
          ],
        ),
      ),
    );
  }

  Widget _sliderCard(String label, String value, double v, double min,
      double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: AppTypography.label)),
              Text(value, style: AppTypography.tiny.copyWith(color: _accent)),
            ]),
            Slider(value: v, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    final app = context.read<AppState>();
    final pb = context.read<PlaybackController>();
    final preset = app.presets.byId('reiki_self') ??
        app.presets.all.firstWhere((p) => p.category == PresetCategory.reiki);
    final medSec = _meditationOn ? _meditationMin * 60 : 0;
    final draft = preset.deepCopy();
    // 시작 명상 시간을 세션 길이에 더해 오디오가 전체 동안 유지되도록.
    draft.stages.first.durationSec = _lengthMin * 60 + medSec;
    draft.stages.first.chimeIntervalSec = 0; // 위치 타이머가 차임 담당
    await pb.prepareSession(draft);
    await pb.start();
    if (!mounted) return;
    final positions = _positionsInOrder;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReikiPlayScreen(
        positions: positions.isEmpty ? const ['위치'] : positions,
        intervalSec: _intervalMin * 60,
        meditationSec: medSec,
        chime: _chime,
        vibration: _vibration,
        title: _reikiKindLabels[_kind]!,
      ),
    ));
  }
}

/// 선택형 알약 버튼(그라데이션 강조).
class _SelectPill extends StatelessWidget {
  const _SelectPill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.dense = false,
  });
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: dense ? 13 : 16, vertical: dense ? 8 : 11),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
                  accent.withOpacity(0.34),
                  accent.withOpacity(0.18),
                ])
              : null,
          color: selected ? null : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? accent.withOpacity(0.7) : AppColors.softDivider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(AppIcons.check, size: 14, color: accent),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: AppTypography.label.copyWith(
                    fontSize: dense ? 12 : 13,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 레이키 재생 모드. 더 어둡고 단순. 미접촉 시 자동 밝기 저하.
class ReikiPlayScreen extends StatefulWidget {
  const ReikiPlayScreen({
    super.key,
    required this.positions,
    required this.intervalSec,
    required this.meditationSec,
    required this.chime,
    required this.vibration,
    required this.title,
  });
  final List<String> positions;
  final int intervalSec;
  final int meditationSec;
  final bool chime;
  final bool vibration;
  final String title;

  @override
  State<ReikiPlayScreen> createState() => _ReikiPlayScreenState();
}

class _ReikiPlayScreenState extends State<ReikiPlayScreen>
    with SingleTickerProviderStateMixin {
  int _positionIndex = 0;
  int _positionElapsed = 0;
  Timer? _ticker;
  Timer? _dimTimer;
  bool _dim = false;
  late bool _meditation; // 시작 명상 단계 여부
  late int _meditationLeft;
  late final AnimationController _anim;

  static const _accent = ChakraColors.heart;

  @override
  void initState() {
    super.initState();
    _meditation = widget.meditationSec > 0;
    _meditationLeft = widget.meditationSec;
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _scheduleDim();
  }

  void _tick() {
    final pb = context.read<PlaybackController>();
    if (!pb.isPlaying) return;
    setState(() {
      if (_meditation) {
        _meditationLeft--;
        if (_meditationLeft <= 0) _endMeditation();
        return;
      }
      _positionElapsed++;
      if (_positionElapsed >= widget.intervalSec &&
          _positionIndex < widget.positions.length - 1) {
        _positionIndex++;
        _positionElapsed = 0;
        _onPositionChange();
      }
    });
  }

  /// 명상 종료 → 첫 부위로 전환(차임/진동으로 알림).
  void _endMeditation() {
    _meditation = false;
    _meditationLeft = 0;
    _positionIndex = 0;
    _positionElapsed = 0;
    _onPositionChange();
  }

  void _skipMeditation() {
    setState(_endMeditation);
  }

  void _onPositionChange() {
    final app = context.read<AppState>();
    final pb = context.read<PlaybackController>();
    if (widget.chime) pb.triggerChimeNow('bowl_low');
    if (widget.vibration && app.settings.reikiVibration) {
      HapticFeedback.mediumImpact();
    }
  }

  void _scheduleDim() {
    _dimTimer?.cancel();
    if (!context.read<AppState>().settings.reikiAutoDim) return;
    _dimTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _dim = true);
    });
  }

  void _wake() {
    setState(() => _dim = false);
    _scheduleDim();
  }

  @override
  void dispose() {
    _anim.dispose();
    _ticker?.cancel();
    _dimTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.watch<PlaybackController>();
    final app = context.watch<AppState>();
    final count = widget.positions.length;
    final idx = _positionIndex.clamp(0, count - 1);
    final area = widget.positions[idx];
    final posLeft = (widget.intervalSec - _positionElapsed)
        .clamp(0, widget.intervalSec)
        .toInt();
    final posFraction =
        widget.intervalSec > 0 ? _positionElapsed / widget.intervalSec : 0.0;
    final auraFraction = _meditation
        ? (widget.meditationSec > 0
            ? 1.0 - _meditationLeft / widget.meditationSec
            : 0.0)
        : posFraction;
    final width = MediaQuery.of(context).size.width.clamp(0.0, 520.0);
    final ringSize = (width * 0.72).clamp(220.0, 340.0);
    final animate = !app.settings.reduceMotion && pb.isPlaying && !_dim;

    return Material(
      color: _dim ? Colors.black : AppColors.deep,
      child: GestureDetector(
        onTap: _wake,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.1,
              colors: [
                _accent.withOpacity(_dim ? 0.0 : 0.13),
                AppColors.deep,
              ],
              stops: const [0.0, 0.62],
            ),
            color: _dim ? Colors.black : null,
          ),
          child: SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _dim ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Text(widget.title.toUpperCase(),
                        style: AppTypography.smallCaps
                            .copyWith(letterSpacing: 2.5, color: _accent)),
                    const Spacer(),
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _anim,
                            builder: (context, _) => CustomPaint(
                              size: Size.square(ringSize),
                              painter: _ReikiAura(
                                t: _anim.value,
                                fraction: auraFraction,
                                accent: _accent,
                                active: animate,
                              ),
                            ),
                          ),
                          if (_meditation)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('시작 명상',
                                    style: AppTypography.smallCaps.copyWith(
                                        letterSpacing: 2, color: _accent)),
                                const SizedBox(height: 14),
                                BreathingGuide(
                                  accent: _accent,
                                  active: animate,
                                  reduceMotion: app.settings.reduceMotion,
                                ),
                                const SizedBox(height: 14),
                                Text(pb.formatTime(_meditationLeft),
                                    style: AppTypography.timeDisplay
                                        .copyWith(fontSize: 30)),
                              ],
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('현재 부위', style: AppTypography.tiny),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text((idx + 1).toString().padLeft(2, '0'),
                                        style: AppTypography.frequencyDisplay
                                            .copyWith(fontSize: 56)),
                                    Text(
                                        ' / ${count.toString().padLeft(2, '0')}',
                                        style: AppTypography.h3.copyWith(
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(area,
                                    style: AppTypography.h2
                                        .copyWith(color: _accent)),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_meditation)
                      Text('호흡을 고르고 준비되면 시작하세요',
                          style: AppTypography.tiny)
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: i == idx ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i < idx
                                    ? _accent.withOpacity(0.5)
                                    : (i == idx
                                        ? _accent
                                        : AppColors.surface4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _timeChip(
                            _meditation ? '명상 남은 시간' : '이 부위',
                            pb.formatTime(_meditation ? _meditationLeft : posLeft),
                            _accent),
                        const SizedBox(width: 12),
                        _timeChip('전체 남은 시간',
                            pb.formatTime(pb.totalRemainingSec), null),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _dim
                          ? Text('화면을 탭하면 밝아집니다',
                              style: AppTypography.tiny)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_meditation) ...[
                                  PrimaryButton(
                                    label: '부위 바로 시작',
                                    icon: AppIcons.play,
                                    onPressed: _skipMeditation,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: SecondaryButton(
                                        label: pb.isPlaying ? '일시정지' : '재개',
                                        icon: pb.isPlaying
                                            ? AppIcons.pause
                                            : AppIcons.play,
                                        onPressed: pb.togglePlayPause,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SecondaryButton(
                                        label: '종료',
                                        danger: true,
                                        onPressed: () async {
                                          await pb.stopGraceful();
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeChip(String label, String value, Color? accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.softDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.tiny.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Text(value,
                style: AppTypography.timeDisplay.copyWith(
                    fontSize: 24, color: accent ?? AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// 레이키 중앙 시각화: 부드럽게 호흡하는 그라데이션 링 + 부위 진행 호 + 글로우 코어.
class _ReikiAura extends CustomPainter {
  _ReikiAura({
    required this.t,
    required this.fraction,
    required this.accent,
    required this.active,
  });
  final double t;
  final double fraction;
  final Color accent;
  final bool active;

  Color _lig(double x) => Color.lerp(accent, Colors.white, x)!;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 배경 글로우
    canvas.drawCircle(
        center,
        maxR,
        Paint()
          ..shader = RadialGradient(colors: [
            accent.withOpacity(0.14),
            accent.withOpacity(0.03),
            Colors.transparent,
          ], stops: const [
            0.0,
            0.5,
            0.85
          ]).createShader(Rect.fromCircle(center: center, radius: maxR)));

    // 호흡하는 동심원(그라데이션 스트로크 + 소프트 글로우)
    final specs = [0.42, 0.6, 0.78, 0.94];
    for (var i = 0; i < specs.length; i++) {
      final breath =
          active ? 1.0 + 0.03 * math.sin((t + i * 0.2) * 2 * math.pi) : 1.0;
      final r = maxR * specs[i] * breath;
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = maxR * 0.03
            ..color = _lig(0.1).withOpacity(0.05)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxR * 0.02));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = _lig(0.2).withOpacity([0.35, 0.25, 0.16, 0.09][i]));
    }

    // 부위 진행 호(글로우 + 선명)
    final ringR = maxR * 0.6;
    final rect = Rect.fromCircle(center: center, radius: ringR);
    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [accent.withOpacity(0.2), _lig(0.5)],
    ).createShader(rect);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = maxR * 0.03
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxR * 0.015)
          ..shader = shader);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = maxR * 0.012
          ..shader = shader);

    // 글로우 코어
    canvas.drawCircle(
        center,
        maxR * 0.12,
        Paint()
          ..shader = RadialGradient(colors: [
            _lig(0.4).withOpacity(0.18),
            Colors.transparent,
          ]).createShader(
              Rect.fromCircle(center: center, radius: maxR * 0.12)));
  }

  @override
  bool shouldRepaint(covariant _ReikiAura old) =>
      old.t != t ||
      old.fraction != fraction ||
      old.accent != accent ||
      old.active != active;
}
