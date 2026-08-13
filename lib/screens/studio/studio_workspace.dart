import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import '../player/player_screen.dart';
import 'studio_home_screen.dart';
import 'studio_screen.dart';

/// 만들기 탭. 넓은 화면은 3열 워크스페이스, 좁은 화면은 기존 목록 화면.
class StudioTab extends StatelessWidget {
  const StudioTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= 880 ? const StudioWorkspace() : const StudioHomeScreen(),
    );
  }
}

/// 데스크톱 3열: 좌측 라이브러리 · 중앙 편집기 · 우측 세션 인스펙터.
class StudioWorkspace extends StatefulWidget {
  const StudioWorkspace({super.key});

  @override
  State<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends State<StudioWorkspace> {
  final _editorKey = GlobalKey<StudioEditorState>();
  String? _currentId; // 라이브러리에서 선택된 원본 id(없으면 새 사운드)

  void _load(Preset? p) {
    _editorKey.currentState?.loadSource(p);
    setState(() => _currentId = p?.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 284, child: _library(app)),
        const _VDivider(),
        Expanded(
          child: StudioEditor(
            key: _editorKey,
            embedded: true,
            onChanged: () => setState(() {}),
          ),
        ),
        const _VDivider(),
        SizedBox(width: 304, child: _inspector(context)),
      ],
    );
  }

  // ── 좌측 라이브러리 ──
  Widget _library(AppState app) {
    final mine = app.presets.userPresets;
    final builtIns = app.presets.builtIns;
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.surface1.withOpacity(0.5),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, topInset + 22, 16, 120),
        children: [
          const Eyebrow('Library'),
          const SizedBox(height: 14),
          PrimaryButton(
            label: '새 사운드',
            icon: AppIcons.add,
            onPressed: () => _load(null),
          ),
          const SizedBox(height: 22),
          SectionHeader('내 프리셋'),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('저장한 프리셋이 없어요',
                  style: AppTypography.tiny),
            )
          else
            for (final p in mine) _libItem(p),
          const SizedBox(height: 18),
          SectionHeader('기본 프리셋'),
          for (final p in builtIns) _libItem(p),
        ],
      ),
    );
  }

  Widget _libItem(Preset p) {
    final selected = _currentId == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.accent.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _load(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    )),
                const SizedBox(height: 3),
                Text(presetMeta(p),
                    style: AppTypography.tiny
                        .copyWith(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 우측 인스펙터 ──
  Widget _inspector(BuildContext context) {
    final ed = _editorKey.currentState;
    final d = ed?.draft;
    final topInset = MediaQuery.of(context).padding.top;
    if (d == null) {
      return Container(color: AppColors.surface1.withOpacity(0.5));
    }
    final s = d.stages.first;
    final freq = s.displayFrequencyHz;
    final layersOn = [
      s.primaryTone.enabled,
      s.drone.enabled,
      s.secondaryTone.enabled,
      s.binaural.enabled,
      s.pulse.enabled,
      s.natureAssetId != null,
      s.padAssetId != null,
      s.chimeAssetId != null,
    ].where((e) => e).length;

    return Container(
      color: AppColors.surface1.withOpacity(0.5),
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, topInset + 22, 18, 120),
        children: [
          const Eyebrow('Session'),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _renameDialog(context, ed!),
            child: Row(
              children: [
                Expanded(
                  child: Text(d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3),
                ),
                const Icon(Icons.edit_outlined,
                    size: 15, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _infoRow('전체 시간', '${(d.totalDurationSec / 60).round()}분'),
          _infoRow('구성',
              d.stages.length > 1 ? '${d.stages.length}단계' : (freq != null ? '${freq.toStringAsFixed(0)}Hz' : '무음')),
          _infoRow('반복', d.repeatCount == 0 ? '무한' : '${d.repeatCount}회'),
          _infoRow('켜진 레이어', '$layersOn개'),
          const SizedBox(height: 22),
          PrimaryButton(
            label: '미리 듣기',
            icon: AppIcons.play,
            onPressed: () => openPresetInPlayer(context, d),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: '프리셋 저장',
            icon: AppIcons.save,
            onPressed: () => ed!.save(),
          ),
          const SizedBox(height: 16),
          Text('편집 내용은 중앙에서 바로 반영돼요. 저장하면 라이브러리에 남습니다.',
              style: AppTypography.tiny
                  .copyWith(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: AppTypography.tiny),
            Text(v,
                style: AppTypography.label
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _renameDialog(BuildContext context, StudioEditorState ed) async {
    final ctrl = TextEditingController(text: ed.draft.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인')),
        ],
      ),
    );
    if (ok == true) ed.setTitle(ctrl.text);
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: AppColors.divider);
}
