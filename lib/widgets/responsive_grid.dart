import 'package:flutter/widgets.dart';

/// 넓은 화면에서 카드를 여러 열 그리드로 펼치고, 좁은 화면에선 한 열로 쌓는다.
/// 폰에서는 기존과 동일(1열), 태블릿·데스크톱에서는 자동으로 2~4열.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.gap = 12,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // 좁은 폭(폰)은 무조건 1열 — 기존 레이아웃 유지.
        int cols = w < 560
            ? 1
            : (w / (minItemWidth + gap)).floor().clamp(1, maxColumns);
        if (cols <= 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        final itemW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: itemW, child: child),
          ],
        );
      },
    );
  }
}
