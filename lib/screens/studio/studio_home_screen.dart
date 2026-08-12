import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';
import '../player/player_screen.dart';
import 'studio_screen.dart';

/// 만들기 탭의 홈. 저장한 프리셋을 모아 보여주고, 새로 만들거나
/// 기존/기본 프리셋을 에디터로 불러올 수 있다.
class StudioHomeScreen extends StatelessWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final mine = app.presets.userPresets;
    final builtIns = app.presets.builtIns;

    return PageScaffold(
      eyebrow: 'Sound studio',
      title: '만들기',
      slivers: [
        Text('나만의 주파수 세션을 만들고, 저장한 프리셋을 다시 불러와 편집하세요.',
            style: AppTypography.body),
        const SizedBox(height: 18),
        PrimaryButton(
          label: '새 사운드 만들기',
          icon: AppIcons.add,
          onPressed: () => openStudioEditor(context),
        ),
        const SizedBox(height: 28),
        SectionHeader('내 프리셋'),
        if (mine.isEmpty)
          const StatusMessage(
            title: '저장한 프리셋이 없어요',
            message: '새 사운드를 만들어 저장하면 여기에 모여요.',
          )
        else
          for (final p in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MyPresetRow(preset: p),
            ),
        const SizedBox(height: 26),
        SectionHeader('기본 프리셋에서 시작'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('기본 세션을 불러와 편집하고 새 프리셋으로 저장할 수 있어요.',
              style: AppTypography.tiny),
        ),
        for (final p in builtIns)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StartFromRow(preset: p),
          ),
      ],
    );
  }
}

/// 프리셋 요약 메타(주파수·단계·시간).
String presetMeta(Preset p) {
  final s = p.stages.first;
  final freq = s.displayFrequencyHz;
  final min = (p.totalDurationSec / 60).round();
  final parts = <String>[];
  if (p.stages.length > 1) {
    parts.add('${p.stages.length}단계');
  } else if (freq != null) {
    parts.add('${freq.toStringAsFixed(0)}Hz');
  }
  parts.add('$min분');
  return parts.join(' · ');
}

/// 내 프리셋 한 줄. 탭하면 편집, 재생 버튼, 더보기(재생/복제/삭제).
class _MyPresetRow extends StatelessWidget {
  const _MyPresetRow({required this.preset});
  final Preset preset;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.surface2,
      onTap: () => openStudioEditor(context, source: preset),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h3.copyWith(fontSize: 15)),
                const SizedBox(height: 5),
                Text(presetMeta(preset), style: AppTypography.tiny),
              ],
            ),
          ),
          IconChipButton(
            icon: AppIcons.play,
            tooltip: '재생',
            onTap: () => openPresetInPlayer(context, preset),
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more, size: 20),
            color: AppColors.surface3,
            onSelected: (v) => _onSelected(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('편집')),
              PopupMenuItem(value: 'duplicate', child: Text('복제')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onSelected(BuildContext context, String v) async {
    final app = context.read<AppState>();
    switch (v) {
      case 'edit':
        openStudioEditor(context, source: preset);
        break;
      case 'duplicate':
        await app.presets.duplicate(preset);
        app.refresh();
        if (context.mounted) showToast(context, '복제되었습니다');
        break;
      case 'delete':
        final ok = await showDangerConfirm(
          context,
          title: '프리셋 삭제',
          body: '‘${preset.title}’을(를) 삭제할까요? 되돌릴 수 없어요.',
        );
        if (!ok) return;
        await app.presets.deleteUserPreset(preset.id);
        app.refresh();
        if (context.mounted) showToast(context, '삭제되었습니다');
        break;
    }
  }
}

/// 기본 프리셋에서 시작 한 줄. 탭하면 에디터로 불러온다.
class _StartFromRow extends StatelessWidget {
  const _StartFromRow({required this.preset});
  final Preset preset;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => openStudioEditor(context, source: preset),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(presetMeta(preset), style: AppTypography.tiny),
              ],
            ),
          ),
          const Icon(AppIcons.chevron, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}
