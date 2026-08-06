import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/page_scaffold.dart';
import '../player/player_screen.dart';

/// 차크라 화면. 세로형 타임라인 + 전체 순환.
class ChakraScreen extends StatefulWidget {
  const ChakraScreen({super.key});
  @override
  State<ChakraScreen> createState() => _ChakraScreenState();
}

class _ChakraScreenState extends State<ChakraScreen> {
  int _selected = 1; // 1..7
  bool _reverse = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final chakras = app.presets.chakraPresets;
    final cycle = app.presets.byId('chakra_full_cycle');

    return PageScaffold(
      eyebrow: 'Chakra sequence',
      title: '차크라',
      slivers: [
        SurfaceCard(
          color: AppColors.surface2,
          radius: 22,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('하나를 선택하거나\n전체 순환을 시작하세요.',
                  style: AppTypography.h2),
              const SizedBox(height: 8),
              Text('각 차크라의 주파수와 드론, 배경음을 자유롭게 수정할 수 있어요.',
                  style: AppTypography.body),
              const SizedBox(height: 16),
              _segmented(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final p in chakras)
          _ChakraTimelineItem(
            preset: p,
            selected: _selected == p.chakraIndex,
            onSelect: () => setState(() => _selected = p.chakraIndex!),
            onOpen: () => openPresetInPlayer(context, p),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _reverse ? '7 → 1 순환 시작' : '1 → 7 순환 시작',
          icon: Icons.play_arrow_rounded,
          onPressed: cycle == null
              ? null
              : () {
                  final p = _reverse ? _reversedCycle(cycle) : cycle;
                  openPresetInPlayer(context, p);
                },
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: '선택한 차크라 상세 보기',
          onPressed: () {
            final p = chakras.firstWhere((c) => c.chakraIndex == _selected,
                orElse: () => chakras.first);
            _openDetail(context, p);
          },
        ),
      ],
    );
  }

  Widget _segmented() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        _segBtn('1 → 7 순환', !_reverse, () => setState(() => _reverse = false)),
        _segBtn('7 → 1 순환', _reverse, () => setState(() => _reverse = true)),
      ]),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.surface3 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppTypography.label.copyWith(
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textMuted)),
        ),
      ),
    );
  }

  Preset _reversedCycle(Preset cycle) {
    final p = cycle.deepCopy();
    p.id = 'chakra_full_cycle_reverse';
    p.title = '전체 차크라 순환 (7→1)';
    p.stages = p.stages.reversed.toList();
    return p;
  }

  void _openDetail(BuildContext context, Preset p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChakraDetailScreen(preset: p),
    ));
  }
}

class _ChakraTimelineItem extends StatelessWidget {
  const _ChakraTimelineItem({
    required this.preset,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final Preset preset;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final idx = preset.chakraIndex!;
    final color = ChakraColors.byIndex(idx);
    final stage = preset.stages.first;
    final freq = stage.displayFrequencyHz ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onSelect,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Color.alphaBlend(
                        color.withOpacity(0.2), AppColors.surface3)
                    : AppColors.surface2,
                border: Border.all(
                    color: color.withOpacity(selected ? 0.56 : 0.34)),
                boxShadow: selected
                    ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 22)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(idx.toString().padLeft(2, '0'),
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: SurfaceCard(
              color: selected ? AppColors.surface2 : AppColors.surface1,
              onTap: onOpen,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(preset.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Text('${freq.toStringAsFixed(0)}Hz',
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ]),
                        const SizedBox(height: 4),
                        Text(stage.title, style: AppTypography.tiny),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, color: color, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 차크라 상세.
class ChakraDetailScreen extends StatelessWidget {
  const ChakraDetailScreen({super.key, required this.preset});
  final Preset preset;

  @override
  Widget build(BuildContext context) {
    final idx = preset.chakraIndex ?? 1;
    final color = ChakraColors.byIndex(idx);
    final stage = preset.stages.first;
    final app = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(preset.title, style: AppTypography.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            color: AppColors.surface2,
            accent: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(stage.displayFrequencyHz ?? 0).toStringAsFixed(0)} Hz',
                    style: AppTypography.frequencyDisplay
                        .copyWith(fontSize: 44, color: color)),
                const SizedBox(height: 4),
                Text(stage.title, style: AppTypography.body),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _info('중심 주파수', '${(stage.displayFrequencyHz ?? 0).toStringAsFixed(1)}Hz'),
          _info('드론 중심', '${stage.drone.centerHz.toStringAsFixed(1)}Hz'),
          _info('패드', stage.padAssetId ?? '없음'),
          _info('자연음', stage.natureAssetId ?? '없음'),
          _info('시간', '${(preset.totalDurationSec / 60).round()}분'),
          const SizedBox(height: 20),
          PrimaryButton(
            label: '시작',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              Navigator.pop(context);
              openPresetInPlayer(context, preset);
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: '기본값 복원',
            onPressed: () async {
              await app.presets.restoreBuiltIn(preset.id);
              app.refresh();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: AppTypography.label),
            Text(v, style: AppTypography.tiny),
          ],
        ),
      );
}
