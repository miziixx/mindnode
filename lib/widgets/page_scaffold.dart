import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_tokens.dart';
import '../core/design/app_typography.dart';
import '../core/state/playback_controller.dart';

/// 탭 페이지 공통 스캐폴드. 상단 안전영역 + 하단바/미니플레이어 만큼 하단 여백.
/// 스크롤 콘텐츠가 하단바 뒤로 숨지 않게 처리한다.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.slivers,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final List<Widget> slivers;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final playback = context.watch<PlaybackController>();
    final miniSpace = (playback.isActive && playback.session != null)
        ? AppMetrics.miniPlayerHeight + 8
        : 0.0;
    final bottomPad =
        AppMetrics.navHeight + bottomInset + miniSpace + 24;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, topInset + 18, AppSpacing.screenH, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow.toUpperCase(),
                          style: AppTypography.eyebrow),
                      const SizedBox(height: 5),
                      Text(title, style: AppTypography.h1),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, 20, AppSpacing.screenH, bottomPad),
          sliver: SliverList(delegate: SliverChildListDelegate(slivers)),
        ),
      ],
    );
  }
}

/// 얇은 진행 링/막대 등에 쓰는 얇은 진행선.
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.fraction, this.color});
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
        valueColor:
            AlwaysStoppedAnimation(color ?? AppColors.accent),
      ),
    );
  }
}
