import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_tokens.dart';
import '../core/design/app_typography.dart';
import '../core/state/app_state.dart';
import 'app_icons.dart';

/// 넓은 화면(태블릿 가로·데스크톱)용 좌측 세로 내비게이션.
/// 하단 탭바 대신 사용. 색·아이콘·항목은 기존 하단바와 동일하게 유지한다.
class SideNav extends StatelessWidget {
  const SideNav({super.key});

  static const double width = 236;

  static const _items = [
    (AppIcons.home, '홈'),
    (AppIcons.chakra, '차크라'),
    (AppIcons.create, '만들기'),
    (AppIcons.records, '기록'),
    (AppIcons.settings, '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: width,
      padding: EdgeInsets.only(top: topInset + 20, left: 14, right: 14, bottom: 16),
      decoration: const BoxDecoration(
        color: Color(0xF210141B),
        border: Border(right: BorderSide(color: AppColors.divider, width: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
            child: Row(
              children: [
                Text('MUUN',
                    style: AppTypography.label.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3)),
                Text('SOUND',
                    style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3)),
              ],
            ),
          ),
          for (var i = 0; i < _items.length; i++)
            _SideItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              active: app.navIndex == i,
              onTap: () => app.setNavIndex(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text('개인용 · 오프라인',
                style: AppTypography.tiny
                    .copyWith(fontSize: 10, color: AppColors.textDisabled)),
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textDisabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: active
              ? AppColors.accent.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 14),
                  Text(label,
                      style: AppTypography.label.copyWith(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
