import 'package:flutter/material.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_typography.dart';

/// 재생 시작 확인(최초 재생/출력장치 변경 후). 낮은 음량으로 시작 안내.
Future<bool> showStartConfirm(BuildContext context, int volumePercent) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _BaseDialog(
      title: '낮은 음량으로 시작합니다',
      body: '현재 마스터 음량 $volumePercent%\n출력 기기마다 실제 소리 크기가 다를 수 있어요.',
      actions: [
        _DialogAction('취소', () => Navigator.pop(ctx, false)),
        _DialogAction('시작', () => Navigator.pop(ctx, true), primary: true),
      ],
    ),
  );
  return ok ?? false;
}

/// 세션 종료 확인. 천천히/즉시/계속.
Future<String?> showStopConfirm(BuildContext context, int fadeSec) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _BaseDialog(
      title: '세션을 종료할까요?',
      body: '$fadeSec초 동안 천천히 소리를 줄인 뒤 종료합니다.',
      actions: [
        _DialogAction('계속 듣기', () => Navigator.pop(ctx, 'cancel')),
        _DialogAction('즉시 종료', () => Navigator.pop(ctx, 'immediate')),
        _DialogAction('천천히 종료', () => Navigator.pop(ctx, 'graceful'),
            primary: true),
      ],
    ),
  );
}

/// 위험 확인(삭제/초기화).
Future<bool> showDangerConfirm(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = '삭제',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => _BaseDialog(
      title: title,
      body: body,
      actions: [
        _DialogAction('취소', () => Navigator.pop(ctx, false)),
        _DialogAction(confirmLabel, () => Navigator.pop(ctx, true),
            danger: true),
      ],
    ),
  );
  return ok ?? false;
}

class _DialogAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  _DialogAction(this.label, this.onTap,
      {this.primary = false, this.danger = false});
}

class _BaseDialog extends StatelessWidget {
  const _BaseDialog(
      {required this.title, required this.body, required this.actions});
  final String title;
  final String body;
  final List<_DialogAction> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.h3),
            const SizedBox(height: 10),
            Text(body, style: AppTypography.body),
            const SizedBox(height: 20),
            for (final a in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: a.onTap,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        a.primary ? AppColors.accent : AppColors.surface3,
                    foregroundColor: a.danger
                        ? AppColors.error
                        : (a.primary
                            ? Colors.white
                            : AppColors.textPrimary),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(a.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(message, style: AppTypography.label),
    backgroundColor: const Color(0xFF252C37),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 2),
  ));
}
