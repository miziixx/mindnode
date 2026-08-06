import 'package:flutter/material.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_tokens.dart';
import '../core/design/app_typography.dart';

/// 채움형(아웃라인 아님) 표면 카드. 표면 밝기 차이로 깊이를 만든다.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.medium,
    this.color = AppColors.surface1,
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final Color? accent; // 좌측 얇은 포인트 광

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.softDivider),
      ),
      child: child,
    );
    Widget content = card;
    if (accent != null) {
      content = Stack(children: [
        card,
        Positioned(
          left: 0,
          top: 14,
          bottom: 14,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent!.withOpacity(0.86),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
          ),
        ),
      ]);
    }
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTypography.eyebrow);
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppTypography.h2)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: AppTypography.label),
            ),
        ],
      ),
    );
  }
}

/// 큰 주요 버튼(높이 ≥52).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: AppTouchTarget.primaryButtonHeight,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: AppIconSize.md)
            : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium + 1)),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
    this.danger = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      height: AppTouchTarget.primaryButtonHeight,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: AppIconSize.md)
            : const SizedBox.shrink(),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface3,
          foregroundColor:
              danger ? AppColors.error : AppColors.textPrimary,
          side: BorderSide(color: AppColors.softDivider),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium + 1)),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// 작은 원형 아이콘 버튼(터치 영역 ≥44).
class IconChipButton extends StatelessWidget {
  const IconChipButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        width: AppTouchTarget.min,
        height: AppTouchTarget.min,
        child: Material(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: onTap,
            child: Icon(icon,
                size: AppIconSize.md, color: color ?? AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// 커스텀 토글 스위치(디자인 토큰 색).
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 27,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? AppColors.accent.withOpacity(0.32)
                : AppColors.surface4,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.softDivider),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? AppColors.textPrimary : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// 빈/오류 상태 안내.
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.info_outline_rounded,
  });
  final String title;
  final String? message;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 34),
          const SizedBox(height: 12),
          Text(title,
              style: AppTypography.h3, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                style: AppTypography.tiny, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
