import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_tokens.dart';
import '../core/design/app_typography.dart';
import '../core/state/playback_controller.dart';
import '../screens/player/player_screen.dart';
import 'app_icons.dart';

/// 미니 플레이어. 재생 중 다른 화면에서도 유지. 불투명 차콜 표면(유리 효과 X).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final session = playback.session;

    return AnimatedSlide(
      duration: AppAnimation.miniPlayer,
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.4),
      child: AnimatedOpacity(
        duration: AppAnimation.miniPlayer,
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: session == null
              ? const SizedBox(height: AppMetrics.miniPlayerHeight)
              : _MiniContent(playback: playback),
        ),
      ),
    );
  }
}

class _MiniContent extends StatelessWidget {
  const _MiniContent({required this.playback});
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final session = playback.session!;
    final freq = playback.currentFrequency;
    final freqText = freq != null ? '${freq.toStringAsFixed(0)}Hz' : '무음';
    final remain = playback.formatTime(playback.totalRemainingSec);

    return Container(
      height: AppMetrics.miniPlayerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.softDivider),
        boxShadow: AppElevation.floating,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(AppIcons.wave,
                size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => openFullPlayer(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(fontSize: 13)),
                  const SizedBox(height: 3),
                  Text('$freqText · $remain 남음',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.tiny.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: playback.isPlaying ? '일시정지' : '재생',
            child: IconButton(
              onPressed: playback.togglePlayPause,
              icon: Icon(playback.isPlaying ? AppIcons.pause : AppIcons.play),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface3,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(42, 42),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
