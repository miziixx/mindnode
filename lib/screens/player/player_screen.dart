import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_tokens.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/audio_asset.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../core/state/playback_controller.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/breathing_guide.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/dreamy_background.dart';
import '../../widgets/layer_sheet.dart';
import '../../widgets/player_visualizer.dart';

/// 프리셋을 세션으로 준비하고 플레이어를 연다(바로 재생하지 않음).
Future<void> openPresetInPlayer(BuildContext context, Preset preset) async {
  final pb = context.read<PlaybackController>();
  await pb.prepareSession(preset);
  if (context.mounted) openFullPlayer(context);
}

/// 전체 플레이어 화면을 라우트로 연다.
void openFullPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: AppAnimation.bottomSheet,
      pageBuilder: (_, __, ___) => const PlayerScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
    ),
  );
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  Color _accent(PlaybackController pb) {
    final idx = pb.sourcePreset?.chakraIndex;
    if (idx != null) return ChakraColors.byIndex(idx);
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.watch<PlaybackController>();
    final app = context.watch<AppState>();
    final session = pb.session;
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (session == null) {
      // 세션이 종료됨 → 닫기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final accent = _accent(pb);
    final freq = pb.currentFrequency;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 몽환적 배경(바람에 흐르는 별빛 · 연기 같은 성운).
          if (app.settings.showResonanceViz)
            Positioned.fill(
              child: DreamyBackground(
                accent: accent,
                reduceMotion: app.settings.reduceMotion,
              ),
            ),
          Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, topInset + 12, 20, bottomInset + 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context, pb, session),
                if (pb.hearingNudgeActive) ...[
                  const SizedBox(height: 12),
                  _hearingBanner(context, pb),
                ],
                const SizedBox(height: 20),
                _resonance(context, app, pb, accent, freq, session),
                if (app.settings.breathingGuide) ...[
                  const SizedBox(height: 16),
                  BreathingGuide(
                    accent: accent,
                    active: pb.isPlaying,
                    reduceMotion: app.settings.reduceMotion,
                  ),
                ],
                const SizedBox(height: 24),
                _timeBlock(pb),
                const SizedBox(height: 16),
                ThinProgressBar(
                    fraction: pb.progressFraction, color: accent),
                const SizedBox(height: 24),
                _transport(pb, accent),
                const SizedBox(height: 24),
                _masterVolume(pb),
                const SizedBox(height: 12),
                _sleepTimer(context, pb, accent),
                const SizedBox(height: 12),
                _breathingToggle(context, app),
                const SizedBox(height: 14),
                SectionHeader('현재 사운드',
                    action: '편집', onAction: () {}),
                _mixer(context, pb, accent),
                const SizedBox(height: 20),
                SecondaryButton(
                  label: '세션 천천히 종료',
                  onPressed: () => _onStop(context, pb, app),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _topBar(
      BuildContext context, PlaybackController pb, Preset session) {
    final app = context.watch<AppState>();
    final favId = pb.sourcePreset?.id;
    final isFav = favId != null && app.presets.isFavorite(favId);
    return Row(
      children: [
        IconChipButton(
            icon: AppIcons.back,
            tooltip: '뒤로',
            onTap: () => Navigator.pop(context)),
        Expanded(
          child: Column(
            children: [
              Text(session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h3.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(pb.isPlaying ? '현재 재생 중' : '준비됨',
                  style: AppTypography.tiny.copyWith(fontSize: 11)),
            ],
          ),
        ),
        if (favId != null)
          IconChipButton(
            icon: isFav ? AppIcons.favoriteFilled : AppIcons.favorite,
            tooltip: isFav ? '즐겨찾기 해제' : '즐겨찾기',
            color: isFav ? AppColors.accent : null,
            onTap: () async {
              await app.presets.toggleFavorite(favId);
              app.refresh();
              if (context.mounted) {
                showToast(context, isFav ? '즐겨찾기에서 제거했어요' : '즐겨찾기에 추가했어요');
              }
            },
          ),
        const SizedBox(width: 8),
        _MoreMenu(pb: pb),
      ],
    );
  }

  Widget _resonance(BuildContext context, AppState app, PlaybackController pb,
      Color accent, double? freq, Preset session) {
    final stage = pb.currentStage!;
    final width = MediaQuery.of(context).size.width.clamp(0.0, 520.0);
    final size = width * 0.62;
    final showViz = app.settings.showResonanceViz;
    return Column(
      children: [
        SizedBox(
          height: size + 8,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (showViz)
                PlayerVisualizer(
                  accent: accent,
                  active: pb.isPlaying,
                  reduceMotion: app.settings.reduceMotion,
                  pulseActive: stage.pulse.enabled,
                  pulseRateHz: stage.pulse.rateHz,
                  binauralActive: stage.binaural.enabled,
                  size: size,
                  seed: session.id.hashCode.abs(),
                  onStyleChanged: (s) => showToast(
                      context, kVizStyleNames[s.index]),
                ),
              // 텍스트는 탭을 통과시켜(IgnorePointer) 시각화 스타일 순환을 방해하지 않음.
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      freq == null
                          ? '무음'
                          : freq.toStringAsFixed(
                              app.settings.showFrequencyDecimals ? 1 : 0),
                      style: AppTypography.frequencyDisplay,
                    ),
                    if (freq != null)
                      Text('HZ',
                          style: AppTypography.smallCaps
                              .copyWith(letterSpacing: 2)),
                    const SizedBox(height: 10),
                    Text(stage.title.isEmpty ? session.title : stage.title,
                        style: AppTypography.h3.copyWith(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showViz && pb.isPlaying && !app.settings.reduceMotion) ...[
          const SizedBox(height: 6),
          Text('화면을 탭해 애니메이션 바꾸기',
              style: AppTypography.tiny.copyWith(fontSize: 10)),
        ],
      ],
    );
  }

  Widget _timeBlock(PlaybackController pb) {
    final stageInfo = pb.isSequence
        ? '남음 · ${pb.currentStageIndex + 1} / ${pb.stageCount} 단계'
        : '남음';
    return Column(
      children: [
        Text(pb.formatTime(pb.totalRemainingSec),
            style: AppTypography.timeDisplay),
        const SizedBox(height: 4),
        Text(stageInfo, style: AppTypography.tiny.copyWith(fontSize: 11)),
      ],
    );
  }

  Widget _transport(PlaybackController pb, Color accent) {
    final showSkips = pb.isSequence;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 52,
          child: showSkips
              ? IconButton(
                  onPressed: pb.currentStageIndex > 0
                      ? pb.previousStage
                      : null,
                  icon: const Icon(AppIcons.prev, size: 28),
                  color: AppColors.textSecondary,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 20),
        Semantics(
          button: true,
          label: pb.isPlaying ? '일시정지' : '재생',
          child: GestureDetector(
            onTap: pb.togglePlayPause,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: Icon(pb.isPlaying ? AppIcons.pause : AppIcons.play,
                  color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 52,
          child: showSkips
              ? IconButton(
                  onPressed: pb.currentStageIndex < pb.stageCount - 1
                      ? pb.nextStage
                      : null,
                  icon: const Icon(AppIcons.next, size: 28),
                  color: AppColors.textSecondary,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _hearingBanner(BuildContext context, PlaybackController pb) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_up_outlined,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('한 시간 넘게 듣고 있어요. 잠깐 쉬거나 음량을 낮춰보세요.',
                style: AppTypography.tiny),
          ),
          TextButton(
            onPressed: pb.dismissHearingNudge,
            child: Text('확인', style: AppTypography.label),
          ),
        ],
      ),
    );
  }

  Widget _sleepTimer(BuildContext context, PlaybackController pb, Color accent) {
    const options = [0, 15, 30, 45, 60];
    final active = pb.sleepRemainingSec > 0;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.timer, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(child: Eyebrow('SLEEP TIMER')),
              Text(
                active ? pb.formatTime(pb.sleepRemainingSec) : '꺼짐',
                style: AppTypography.tiny
                    .copyWith(color: active ? accent : AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final m in options)
                _sleepChip(
                  label: m == 0 ? '꺼짐' : '$m분',
                  selected: m == 0 ? !active : pb.sleepTimerSetMinutes == m,
                  accent: accent,
                  onTap: () {
                    pb.setSleepTimerMinutes(m);
                    showToast(context,
                        m == 0 ? '수면 타이머를 껐어요' : '$m분 뒤 부드럽게 종료돼요');
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('설정한 시간이 지나면 소리가 서서히 사라지며 종료됩니다 · 틀어놓고 잠들 때 좋아요',
              style: AppTypography.tiny.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _sleepChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.22) : AppColors.surface3,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected ? accent.withOpacity(0.6) : AppColors.softDivider),
        ),
        child: Text(label,
            style: AppTypography.tiny.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
      ),
    );
  }

  Widget _breathingToggle(BuildContext context, AppState app) {
    final on = app.settings.breathingGuide;
    return GestureDetector(
      onTap: () {
        final s = app.settings;
        s.breathingGuide = !s.breathingGuide;
        app.updateSettings(s);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(on ? Icons.air_rounded : Icons.air_outlined,
              size: 16,
              color: on ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 8),
          Text(on ? '호흡 가이드 켜짐 · 끄기' : '호흡 가이드 켜기',
              style: AppTypography.tiny.copyWith(
                  color: on ? AppColors.accent : AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _masterVolume(PlaybackController pb) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Eyebrow('MASTER')),
              Text('${(pb.masterVolume01 * 100).round()}%',
                  style: AppTypography.tiny),
            ],
          ),
          Slider(
            value: pb.masterVolume01,
            onChanged: pb.setMasterVolume,
          ),
          Text('낮출수록 편안하게 오래 듣기 좋아요 · 처음엔 낮게 시작하세요 (앱 내부 상대 음량)',
              style: AppTypography.tiny.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _mixer(BuildContext context, PlaybackController pb, Color accent) {
    final stage = pb.currentStage!;
    final rows = <Widget>[];
    void add(String id, IconData icon, String name, String hint, String value,
        bool enabled) {
      rows.add(_MixerRow(
        icon: icon,
        name: name,
        hint: hint,
        value: value,
        enabled: enabled,
        accent: accent,
        onToggle: (v) => pb.setLayerEnabled(id, v),
        onTap: () => showLayerSheet(context, id, accent: accent),
      ));
    }

    add('primary', AppIcons.wave, 'PRIMARY TONE', '중심 주파수 · 세션의 기준음',
        '${stage.primaryTone.frequencyHz.toStringAsFixed(1)}Hz · ${stage.primaryTone.gainDb.toStringAsFixed(0)}dB',
        stage.primaryTone.enabled);
    add('drone', AppIcons.drone, 'DRONE', '중심음을 감싸는 깊고 부드러운 배경음',
        '${stage.drone.subHz.toStringAsFixed(0)} / ${stage.drone.mainHz.toStringAsFixed(0)} / ${stage.drone.airHz.toStringAsFixed(0)}Hz',
        stage.drone.enabled);
    if (stage.secondaryTone.enabled || stage.secondaryTone.frequencyHz > 0) {
      add('secondary', AppIcons.wave, 'SECONDARY', '살짝 더해지는 보조 주파수',
          '${stage.secondaryTone.frequencyHz.toStringAsFixed(1)}Hz',
          stage.secondaryTone.enabled);
    }
    if (stage.binaural.enabled) {
      add('binaural', AppIcons.binaural, 'BINAURAL', '좌우 다른 주파수 · 이어폰 권장',
          '${stage.binaural.beatHz.toStringAsFixed(1)}Hz beat',
          stage.binaural.enabled);
    }
    if (stage.pulse.enabled) {
      add('pulse', AppIcons.pulse, 'PULSE', '음량이 부드럽게 커졌다 작아지는 맥동',
          '${stage.pulse.rateHz.toStringAsFixed(1)}Hz · ${(stage.pulse.depth * 100).round()}%',
          stage.pulse.enabled);
    }
    add('nature', AppIcons.nature, 'NATURE', '빗소리·숲 등 자연 배경음',
        AssetCatalog.displayNameOf(stage.natureAssetId),
        stage.natureAssetId != null);
    add('pad', AppIcons.pad, 'PAD', '은은하게 깔리는 앰비언트 패드',
        AssetCatalog.displayNameOf(stage.padAssetId),
        stage.padAssetId != null);
    add('chime', AppIcons.chime, 'CHIME', '종·싱잉볼 소리 (일정 간격)',
        AssetCatalog.displayNameOf(stage.chimeAssetId),
        stage.chimeAssetId != null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.softDivider),
      ),
      child: Column(children: rows),
    );
  }

  Future<void> _onStop(
      BuildContext context, PlaybackController pb, AppState app) async {
    final choice = await showStopConfirm(context, app.settings.endFadeSec);
    if (choice == 'graceful') {
      await pb.stopGraceful();
      if (context.mounted) Navigator.pop(context);
    } else if (choice == 'immediate') {
      await pb.stopImmediate();
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _MixerRow extends StatelessWidget {
  const _MixerRow({
    required this.icon,
    required this.name,
    required this.hint,
    required this.value,
    required this.enabled,
    required this.accent,
    required this.onToggle,
    required this.onTap,
  });
  final IconData icon;
  final String name;
  final String hint;
  final String value;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 18, color: enabled ? accent : AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.smallCaps.copyWith(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tiny
                          .copyWith(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 3),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tiny.copyWith(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: onToggle,
              activeColor: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.pb});
  final PlaybackController pb;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(AppIcons.more, color: AppColors.textPrimary),
      color: AppColors.surface3,
      onSelected: (v) async {
        final app = context.read<AppState>();
        switch (v) {
          case 'duplicate':
            if (pb.sourcePreset != null) {
              await app.presets.duplicate(pb.sourcePreset!);
              app.refresh();
              if (context.mounted) showToast(context, '복제되었습니다');
            }
            break;
          case 'saveNew':
            await pb.saveAsNewPreset(
                '${pb.session?.title ?? '세션'} (내 프리셋)',
                pb.session?.category ?? PresetCategory.custom);
            app.refresh();
            if (context.mounted) showToast(context, '새 프리셋으로 저장했습니다');
            break;
          case 'saveOverride':
            await pb.saveAsBuiltInOverride();
            app.refresh();
            if (context.mounted) showToast(context, '기본 프리셋을 수정했습니다');
            break;
          case 'restore':
            if (pb.sourcePreset != null) {
              await app.presets.restoreBuiltIn(pb.sourcePreset!.id);
              app.refresh();
              if (context.mounted) showToast(context, '기본값으로 복원했습니다');
            }
            break;
        }
      },
      itemBuilder: (_) {
        final isBuiltIn = pb.sourcePreset?.isBuiltIn ?? false;
        return [
          const PopupMenuItem(value: 'duplicate', child: Text('현재 설정으로 복제')),
          const PopupMenuItem(value: 'saveNew', child: Text('새 프리셋으로 저장')),
          if (isBuiltIn)
            const PopupMenuItem(
                value: 'saveOverride', child: Text('기본 프리셋 수정')),
          if (isBuiltIn)
            const PopupMenuItem(value: 'restore', child: Text('기본값 복원')),
        ];
      },
    );
  }
}

/// 얇은 진행 막대(플레이어용, 단계형은 두 줄로 구분 가능).
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({super.key, required this.fraction, this.color});
  final double fraction;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 3,
        backgroundColor: AppColors.surface3,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.accent),
      ),
    );
  }
}
