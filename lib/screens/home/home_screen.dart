import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_tokens.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../core/state/playback_controller.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/responsive_grid.dart';
import '../player/player_screen.dart';
import '../reiki/reiki_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // 홈 빠른 상태 카드: (presetId, 포인트색)
  static const _quick = [
    ('uplift_mind', AppColors.info),
    ('energize_wake', ChakraColors.solar),
    ('abundance_ritual', ChakraColors.sacral),
    ('cleanse_negative', ChakraColors.heart),
    ('meditation_deep', ChakraColors.thirdEye),
    ('reiki_self', ChakraColors.crown),
  ];

  // 목적별 추천(뇌파 기반, 이어폰 권장): (presetId, 포인트색)
  static const _recommended = [
    ('sleep_delta', ChakraColors.thirdEye),
    ('deep_sleep', ChakraColors.crown),
    ('calm_alpha', ChakraColors.heart),
    ('stress_relief', ChakraColors.sacral),
    ('theta_relax', ChakraColors.throat),
    ('focus_beta', AppColors.info),
    ('flow_gamma', ChakraColors.solar),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recents = app.records.records.take(3).toList();
    final favorites = app.presets.favorites;

    return PageScaffold(
      eyebrow: "Today's session",
      title: '지금 어떤 상태가\n필요해?',
      slivers: [
        Text('주파수와 드론, 자연음을 조합해 나만의 세션을 시작하세요.',
            style: AppTypography.body),
        const SizedBox(height: 24),
        ResponsiveGrid(children: [
          for (final q in _quick)
            if (app.presets.byId(q.$1) != null)
              _StatusCard(
                preset: app.presets.byId(q.$1)!,
                accent: q.$2,
                // 레이키는 전용 셋업/재생 화면으로 이동.
                onOpenOverride:
                    q.$1 == 'reiki_self' ? () => openReiki(context) : null,
              ),
        ]),
        const SizedBox(height: 24),
        SectionHeader('목적별 추천'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('수면·집중·이완 등 목적별 세션이에요. 이어폰을 끼면 바이노럴 효과가 또렷해집니다.',
              style: AppTypography.tiny),
        ),
        ResponsiveGrid(children: [
          for (final r in _recommended)
            if (app.presets.byId(r.$1) != null)
              _StatusCard(preset: app.presets.byId(r.$1)!, accent: r.$2),
        ]),
        const SizedBox(height: 20),
        SectionHeader('빠른 10분 세션'),
        _QuickTenCard(),
        const SizedBox(height: 28),
        SectionHeader('최근 사용'),
        if (recents.isEmpty)
          const StatusMessage(
            title: '아직 기록이 없어요',
            message: '세션을 완료하면 여기에 표시됩니다.',
          )
        else
          ResponsiveGrid(minItemWidth: 340, children: [
            for (final r in recents)
              _RecentRow(
                title: r.presetTitle,
                meta:
                    '${_relative(r.startedAt)} · ${(r.playedSeconds / 60).round()}분',
                onRestart: () {
                  final p = app.presets.byId(r.presetId);
                  if (p != null) openPresetInPlayer(context, p);
                },
              ),
          ]),
        const SizedBox(height: 28),
        SectionHeader('즐겨찾기'),
        if (favorites.isEmpty)
          const StatusMessage(
            title: '즐겨찾기가 없어요',
            message: '자주 사용하는 세션을 저장해두세요.',
          )
        else
          ResponsiveGrid(minItemWidth: 340, children: [
            for (final p in favorites)
              _RecentRow(
                title: p.title,
                meta: '${(p.totalDurationSec / 60).round()}분',
                onRestart: () => openPresetInPlayer(context, p),
              ),
          ]),
      ],
    );
  }

  static String _relative(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.month}월 ${d.day}일';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.preset, required this.accent, this.onOpenOverride});
  final Preset preset;
  final Color accent;
  final VoidCallback? onOpenOverride;

  String get _meta {
    final s = preset.stages.first;
    final freq = s.displayFrequencyHz;
    final min = (preset.totalDurationSec / 60).round();
    final parts = <String>[];
    if (preset.stages.length > 1) {
      parts.add('${preset.stages.length}단계');
    } else if (freq != null) {
      parts.add('${freq.toStringAsFixed(0)}Hz');
    }
    if (s.binaural.enabled) {
      final b = s.binaural.beatHz;
      parts.add('${b == b.roundToDouble() ? b.toStringAsFixed(0) : b.toStringAsFixed(2)}Hz 바이노럴');
    } else if (s.pulse.enabled) {
      parts.add('${s.pulse.rateHz.toStringAsFixed(2)}Hz 펄스');
    } else if (s.drone.enabled) {
      parts.add('드론');
    }
    parts.add('$min분');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: AppColors.surface2,
      accent: accent,
      onTap: onOpenOverride ?? () => openPresetInPlayer(context, preset),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.title, style: AppTypography.h3),
                const SizedBox(height: 7),
                Text(_meta, style: AppTypography.tiny),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PlayPill(
            accent: accent,
            onTap: onOpenOverride ?? () => _quickStart(context, preset),
          ),
        ],
      ),
    );
  }

  Future<void> _quickStart(BuildContext context, Preset preset) async {
    final app = context.read<AppState>();
    final pb = context.read<PlaybackController>();
    // 최초 재생 확인(낮은 음량 안내).
    final ok = await showStartConfirm(
        context, app.settings.initialMasterVolumePercent);
    if (!ok || !context.mounted) return;
    await pb.prepareSession(preset);
    await pb.start();
    if (context.mounted) openFullPlayer(context);
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.accent, required this.onTap});
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '재생',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: accent.withOpacity(0.22),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Icon(AppIcons.play, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(
      {required this.title, required this.meta, required this.onRestart});
  final String title;
  final String meta;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onRestart,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(meta, style: AppTypography.tiny),
              ],
            ),
          ),
          const Icon(AppIcons.chevron, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}

class _QuickTenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SurfaceCard(
      color: AppColors.surface2,
      accent: AppColors.success,
      onTap: () {
        final p = app.presets.byId('meditation_deep');
        if (p == null) return;
        // 10분 세션: 세션 복제 후 시간 축소.
        final quick = p.deepCopy();
        quick.stages.first.durationSec = 600;
        openPresetInPlayer(context, quick);
      },
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('빠른 10분 명상', style: AppTypography.h3),
                SizedBox(height: 7),
                Text('432Hz · 드론 · 10분', style: AppTypography.tiny),
              ],
            ),
          ),
          Icon(AppIcons.chevron, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}
