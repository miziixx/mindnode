import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../core/state/playback_controller.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';

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
    draft.stages.first.chimeIntervalSec = _intervalMin * 60;
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
    final area = widget.positions[_positionIndex.clamp(0, widget.positions.length - 1)];
    final posLeft = widget.intervalSec - _positionElapsed;

    return GestureDetector(
      onTap: _wake,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        color: _dim ? Colors.black : AppColors.deep,
        child: SafeArea(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: _dim ? 0.35 : 1.0,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(widget.title.toUpperCase(),
                    style: AppTypography.smallCaps
                        .copyWith(letterSpacing: 2.5, color: AppColors.textMuted)),
                const Spacer(),
                Text('현재 위치', style: AppTypography.tiny),
                const SizedBox(height: 12),
                Text(
                    '${(_positionIndex + 1).toString().padLeft(2, '0')} / ${widget.positions.length.toString().padLeft(2, '0')}',
                    style: AppTypography.frequencyDisplay.copyWith(fontSize: 40)),
                const SizedBox(height: 6),
                Text(area, style: AppTypography.h2),
                const SizedBox(height: 28),
                Text(pb.formatTime(posLeft < 0 ? 0 : posLeft),
                    style: AppTypography.timeDisplay
                        .copyWith(color: AppColors.textSecondary)),
                Text('이 위치 남은 시간 · 전체 ${pb.formatTime(pb.totalRemainingSec)}',
                    style: AppTypography.tiny),
                const Spacer(),
                if (!_dim)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SecondaryButton(
                          label: pb.isPlaying ? '일시정지' : '재개',
                          expand: false,
                          onPressed: pb.togglePlayPause,
                        ),
                        const SizedBox(width: 12),
                        SecondaryButton(
                          label: '종료',
                          expand: false,
                          danger: true,
                          onPressed: () async {
                            await pb.stopGraceful();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
