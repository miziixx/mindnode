import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_tokens.dart';
import '../core/state/app_state.dart';
import 'app_icons.dart';

/// 전역 하단 내비게이션. 채움형 표면 + 위쪽 미세 구분선. 재생 중에도 유지.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: AppMetrics.navHeight + bottomInset,
      padding: EdgeInsets.only(top: 8, bottom: 8 + bottomInset, left: 8, right: 8),
      decoration: const BoxDecoration(
        color: Color(0xF210141B),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.6)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                active: app.navIndex == i,
                onTap: () => app.setNavIndex(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    final color = active ? AppColors.textPrimary : AppColors.textDisabled;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withOpacity(0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 22,
                  color: active ? AppColors.accent : AppColors.textDisabled),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
