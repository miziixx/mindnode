import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/session_record.dart';
import '../../core/state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/page_scaffold.dart';
import '../player/player_screen.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final records = app.records.records;
    final sum = app.records.monthSummary(DateTime.now());

    return PageScaffold(
      eyebrow: 'Session archive',
      title: '기록',
      slivers: [
        SurfaceCard(
          color: AppColors.surface2,
          radius: 22,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _metric('${sum.count}회', '이번 달 세션'),
              const SizedBox(width: 16),
              _metric(_fmtDuration(sum.totalSeconds), '누적 청취 시간'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionHeader('최근 세션'),
        if (records.isEmpty)
          const StatusMessage(
            title: '아직 기록이 없어요',
            message: '세션을 시작하면 여기에 자동으로 기록됩니다.\n(효과 측정이나 진단이 아닌 개인 기록입니다.)',
          )
        else
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordCard(record: r),
            ),
      ],
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTypography.timeDisplay.copyWith(fontSize: 26)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.tiny),
        ],
      ),
    );
  }

  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});
  final SessionRecord record;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final d = record.startedAt;
    final date =
        '${d.month}월 ${d.day}일 · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final freqs = record.frequencies.map((f) => '${f.toStringAsFixed(0)}Hz').join(' · ');

    return SurfaceCard(
      radius: 16,
      onTap: () => _showDetail(context, app),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: AppTypography.tiny),
              if (record.comfortScore != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${record.comfortScore} / 10',
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(record.presetTitle, style: AppTypography.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 5),
          Text(
            '$freqs · ${(record.playedSeconds / 60).round()}분'
            '${record.completed ? '' : ' · 중단'}',
            style: AppTypography.tiny,
          ),
          if (record.note != null && record.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(record.note!, style: AppTypography.tiny),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, AppState app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151A22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.presetTitle, style: AppTypography.h2),
            const SizedBox(height: 6),
            Text('실제 재생 ${(record.playedSeconds / 60).round()}분 / 계획 ${(record.plannedSeconds / 60).round()}분',
                style: AppTypography.body),
            const SizedBox(height: 4),
            Text('완료: ${record.completed ? '예' : '아니오'}${record.modified ? ' · 수정됨' : ''}',
                style: AppTypography.tiny),
            const SizedBox(height: 20),
            PrimaryButton(
              label: '동일 설정으로 다시 시작',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                final p = app.presets.byId(record.presetId);
                Navigator.pop(context);
                if (p != null) openPresetInPlayer(context, p);
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: '이 기록 삭제',
              danger: true,
              onPressed: () async {
                await app.records.delete(record.id);
                app.refresh();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
