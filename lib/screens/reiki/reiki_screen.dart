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
import '../../widgets/common.dart';
import '../../widgets/resonance_visualizer.dart';

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

/// 셀프 레이키 손 위치(예시). 사용자 수정 가능 범위는 추후 확장.
const _selfPositions = ['정수리', '눈·이마', '목·가슴', '가슴', '명치', '아랫배', '등·허리'];

void openReiki(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReikiSetupScreen()));
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

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _lengthMin = s.reikiDefaultLengthSec ~/ 60;
    _intervalMin = s.reikiHandChangeIntervalSec ~/ 60;
    _chime = s.reikiChime;
    _vibration = s.reikiVibration;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deep,
      appBar: AppBar(
        backgroundColor: AppColors.deep,
        title: const Text('레이키'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow('세션 종류'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in ReikiKind.values)
                ChoiceChip(
                  label: Text(_reikiKindLabels[k]!),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                  selectedColor: AppColors.accent.withOpacity(0.3),
                  backgroundColor: AppColors.surface2,
                  labelStyle: AppTypography.label,
                ),
            ],
          ),
          const SizedBox(height: 24),
          _sliderCard('세션 길이', '$_lengthMin분', _lengthMin.toDouble(), 10, 90,
              (v) => setState(() => _lengthMin = v.round())),
          _sliderCard('손 위치 변경', '$_intervalMin분마다', _intervalMin.toDouble(),
              1, 10, (v) => setState(() => _intervalMin = v.round())),
          SurfaceCard(
            child: Column(children: [
              Row(children: [
                Expanded(child: Text('차임', style: AppTypography.label)),
                AppSwitch(value: _chime, onChanged: (v) => setState(() => _chime = v)),
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: '시작',
            icon: AppIcons.play,
            onPressed: _start,
          ),
        ],
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
              Text(value, style: AppTypography.tiny),
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
    final draft = preset.deepCopy();
    draft.stages.first.durationSec = _lengthMin * 60;
    // 차임은 레이키 화면의 위치 변경 타이머가 담당 → 세션 인터벌 차임은 끔(중복 방지).
    draft.stages.first.chimeIntervalSec = 0;
    await pb.prepareSession(draft);
    await pb.start();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ReikiPlayScreen(
        positions: _kind == ReikiKind.self ? _selfPositions : const ['위치'],
        intervalSec: _intervalMin * 60,
        chime: _chime,
        vibration: _vibration,
        title: _reikiKindLabels[_kind]!,
      ),
    ));
  }
}

/// 레이키 재생 모드. 더 어둡고 단순. 미접촉 시 자동 밝기 저하.
class ReikiPlayScreen extends StatefulWidget {
  const ReikiPlayScreen({
    super.key,
    required this.positions,
    required this.intervalSec,
    required this.chime,
    required this.vibration,
    required this.title,
  });
  final List<String> positions;
  final int intervalSec;
  final bool chime;
  final bool vibration;
  final String title;

  @override
  State<ReikiPlayScreen> createState() => _ReikiPlayScreenState();
}

class _ReikiPlayScreenState extends State<ReikiPlayScreen> {
  int _positionIndex = 0;
  int _positionElapsed = 0;
  Timer? _ticker;
  Timer? _dimTimer;
  bool _dim = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _scheduleDim();
  }

  void _tick() {
    final pb = context.read<PlaybackController>();
    if (!pb.isPlaying) return;
    setState(() {
      _positionElapsed++;
      if (_positionElapsed >= widget.intervalSec &&
          _positionIndex < widget.positions.length - 1) {
        _positionIndex++;
        _positionElapsed = 0;
        _onPositionChange();
      }
    });
  }

  void _onPositionChange() {
    final app = context.read<AppState>();
    final pb = context.read<PlaybackController>();
    if (widget.chime) pb.triggerChimeNow('bowl_low');
    if (widget.vibration && app.settings.reikiVibration) {
      HapticFeedback.mediumImpact();
    }
    // 화면이 갑자기 밝아지지 않도록 dim 유지(사용자 조작 시에만 복귀).
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
    const accent = ChakraColors.heart; // 레이키: 차분한 세이지 그린 포인트
    final width = MediaQuery.of(context).size.width.clamp(0.0, 520.0);
    final ringSize = (width * 0.66).clamp(200.0, 320.0);

    // Material 로 감싸 DefaultTextStyle 을 제공(없으면 노란 밑줄 기본 스타일이 뜸).
    return Material(
      color: _dim ? Colors.black : AppColors.deep,
      child: GestureDetector(
        onTap: _wake,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.0,
              colors: [
                accent.withOpacity(_dim ? 0.0 : 0.10),
                AppColors.deep,
              ],
              stops: const [0.0, 0.6],
            ),
            color: _dim ? Colors.black : null,
          ),
          child: SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _dim ? 0.45 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Text(widget.title.toUpperCase(),
                        style: AppTypography.smallCaps.copyWith(
                            letterSpacing: 2.5, color: accent)),
                    const Spacer(),
                    // 중앙 공명 링 + 현재 위치
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (app.settings.showResonanceViz)
                            ResonanceVisualizer(
                              accent: accent,
                              active: pb.isPlaying,
                              reduceMotion: app.settings.reduceMotion,
                              size: ringSize,
                            ),
                          CustomPaint(
                            size: Size.square(ringSize),
                            painter: _PositionRing(
                                fraction: posFraction, accent: accent),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('현재 위치', style: AppTypography.tiny),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                      (idx + 1).toString().padLeft(2, '0'),
                                      style: AppTypography.frequencyDisplay
                                          .copyWith(fontSize: 56)),
                                  Text(' / ${count.toString().padLeft(2, '0')}',
                                      style: AppTypography.h3.copyWith(
                                          color: AppColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(area,
                                  style: AppTypography.h2
                                      .copyWith(color: accent)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 위치 진행 점
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
                                  ? accent.withOpacity(0.5)
                                  : (i == idx
                                      ? accent
                                      : AppColors.surface4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 시간 칩 두 개
                    Row(
                      children: [
                        _timeChip('이 위치', pb.formatTime(posLeft), accent),
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
                          : Row(
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
                    fontSize: 24,
                    color: accent ?? AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// 현재 위치 진행 링(위치 경과 비율을 호로 표시).
class _PositionRing extends CustomPainter {
  _PositionRing({required this.fraction, required this.accent});
  final double fraction;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.surface3;
    canvas.drawCircle(center, radius, bg);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = accent.withOpacity(0.9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _PositionRing old) =>
      old.fraction != fraction || old.accent != accent;
}
