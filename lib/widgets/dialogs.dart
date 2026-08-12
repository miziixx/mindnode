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

/// 숫자 직접 입력 다이얼로그. 확인 시 [min]~[max]로 클램프한 값을 반환하고,
/// 취소하거나 빈 값이면 null을 반환한다. 주파수 등 직접 입력에 사용.
Future<double?> showNumberInputDialog(
  BuildContext context, {
  required String title,
  required double initial,
  required double min,
  required double max,
  String unit = 'Hz',
  int decimals = 2,
}) {
  return showDialog<double>(
    context: context,
    builder: (ctx) => _NumberInputDialog(
      title: title,
      initial: initial,
      min: min,
      max: max,
      unit: unit,
      decimals: decimals,
    ),
  );
}

String _fmtNum(double v, int decimals) {
  if (decimals <= 0) return v.round().toString();
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

class _NumberInputDialog extends StatefulWidget {
  const _NumberInputDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.unit,
    required this.decimals,
  });
  final String title;
  final double initial;
  final double min;
  final double max;
  final String unit;
  final int decimals;

  @override
  State<_NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<_NumberInputDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: _fmtNum(widget.initial, widget.decimals));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null) {
      setState(() => _error = '숫자를 입력하세요');
      return;
    }
    Navigator.pop(context, v.clamp(widget.min, widget.max).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final range =
        '${_fmtNum(widget.min, widget.decimals)}~${_fmtNum(widget.max, widget.decimals)} ${widget.unit}';
    return Dialog(
      backgroundColor: AppColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTypography.h3),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.h2,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                suffixText: widget.unit,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            Text('가능 범위 $range',
                style: AppTypography.tiny, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surface3,
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: _submit,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ]),
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
