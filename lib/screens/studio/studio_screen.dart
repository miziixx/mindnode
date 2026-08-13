import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/audio_asset.dart';
import '../../core/models/layers.dart';
import '../../core/models/preset.dart';
import '../../core/state/app_state.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';
import '../player/player_screen.dart';
import 'studio_layer_editor.dart';

/// 스튜디오 에디터를 라우트로 연다(없으면 새 사운드부터 시작). 모바일 경로.
Future<void> openStudioEditor(BuildContext context, {Preset? source}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => StudioEditor(source: source)),
  );
}

/// 사운드 스튜디오 편집기. 드래프트 프리셋을 편집한다.
///
/// - [embedded]=false(기본): 뒤로가기·저장 헤더가 있는 전체 화면(모바일 라우트).
/// - [embedded]=true: 헤더 없이 편집 컬럼만 렌더(데스크톱 3열 워크스페이스 중앙).
///   변경 시 [onChanged]로 외부(오른쪽 인스펙터 등)에 알린다.
class StudioEditor extends StatefulWidget {
  const StudioEditor({
    super.key,
    this.source,
    this.embedded = false,
    this.onChanged,
  });

  final Preset? source;
  final bool embedded;
  final VoidCallback? onChanged;

  @override
  State<StudioEditor> createState() => StudioEditorState();
}

class StudioEditorState extends State<StudioEditor> {
  late Preset draft;
  Preset? _source;
  int stageIndex = 0;
  bool sequenceTab = false;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    draft = widget.source?.deepCopy() ?? _newDraft();
    // 첫 프레임 후 인스펙터가 초기 값을 읽을 수 있도록 알림.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged?.call();
    });
  }

  SessionStage get stage => draft.stages[stageIndex];

  /// 내부 변경 + 외부 통지.
  void _mut(VoidCallback f) {
    setState(f);
    widget.onChanged?.call();
  }

  Preset _newDraft() {
    return Preset(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: '새 사운드',
      category: PresetCategory.custom,
      stages: [
        SessionStage(
          id: 'main',
          title: '메인',
          durationSec: 600,
          primaryTone: ToneLayer(enabled: true, frequencyHz: 528.0),
          drone: DroneLayer(enabled: true, centerHz: 528.0),
        ),
      ],
    );
  }

  // ── 외부(워크스페이스 라이브러리/인스펙터)에서 호출하는 공개 API ──
  void loadSource(Preset? p) {
    _mut(() {
      _source = p;
      draft = p?.deepCopy() ?? _newDraft();
      stageIndex = 0;
      sequenceTab = false;
    });
  }

  void setTitle(String t) {
    _mut(() => draft.title = t.trim().isEmpty ? '무제' : t.trim());
  }

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      Text(_source == null ? '저장되지 않음' : '${_source!.title} 기반',
          style: AppTypography.tiny),
      const SizedBox(height: 16),
      _frequencyEditor(),
      const SizedBox(height: 12),
      _repeatRow(),
      const SizedBox(height: 16),
      _tabs(),
      const SizedBox(height: 12),
      if (sequenceTab) ..._sequenceView() else ..._layersView(),
      if (!widget.embedded) ...[
        const SizedBox(height: 20),
        PrimaryButton(
          label: '현재 구성 미리 듣기',
          icon: AppIcons.play,
          onPressed: () => openPresetInPlayer(context, draft),
        ),
        const SizedBox(height: 10),
        SecondaryButton(label: '프리셋 저장', icon: AppIcons.save, onPressed: save),
      ],
    ];

    if (widget.embedded) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 120),
        children: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageScaffold(
        leading: IconChipButton(
          icon: AppIcons.back,
          tooltip: '뒤로',
          onTap: () => Navigator.of(context).maybePop(),
        ),
        eyebrow: 'Sound studio',
        title: draft.title,
        trailing: IconChipButton(
          icon: AppIcons.save,
          tooltip: '저장',
          onTap: save,
        ),
        slivers: content,
      ),
    );
  }

  // ── 큰 주파수 입력 ──
  Widget _frequencyEditor() {
    final tone = stage.primaryTone;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.softDivider),
      ),
      child: Column(
        children: [
          const Eyebrow('Primary frequency'),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _inputPrimaryFrequency(tone),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(tone.frequencyHz.toStringAsFixed(2),
                      style:
                          AppTypography.frequencyDisplay.copyWith(fontSize: 46)),
                  const SizedBox(width: 8),
                  Text('Hz', style: AppTypography.body),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          Text('숫자를 탭해 직접 입력',
              style: AppTypography.tiny
                  .copyWith(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in const [-10.0, -1.0, -0.1, 0.1, 1.0, 10.0])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: () => _mut(() {
                        tone.frequencyHz = (tone.frequencyHz + d)
                            .clamp(FreqLimits.min, FreqLimits.maxAbsolute);
                        if (stage.drone.enabled) {
                          stage.drone.centerHz = tone.frequencyHz;
                        }
                      }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor: AppColors.surface3,
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(color: AppColors.softDivider),
                      ),
                      child: Text(d > 0 ? '+${_fmtStep(d)}' : _fmtStep(d),
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
            ],
          ),
          if (tone.frequencyHz >= 10000) ...[
            const SizedBox(height: 10),
            Text('10kHz 이상은 큰 음량으로 시작하지 마세요.',
                style: AppTypography.tiny.copyWith(color: AppColors.warning)),
          ],
        ],
      ),
    );
  }

  Future<void> _inputPrimaryFrequency(ToneLayer tone) async {
    final v = await showNumberInputDialog(
      context,
      title: '주파수 직접 입력',
      initial: tone.frequencyHz,
      min: FreqLimits.min,
      max: FreqLimits.maxAbsolute,
      unit: 'Hz',
    );
    if (v == null) return;
    _mut(() {
      tone.frequencyHz = v.clamp(FreqLimits.min, FreqLimits.maxAbsolute);
      if (stage.drone.enabled) stage.drone.centerHz = tone.frequencyHz;
    });
  }

  String _fmtStep(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);

  // ── 반복 횟수 ──
  Widget _repeatRow() {
    const options = [1, 2, 3, 5, 10];
    final rc = draft.repeatCount; // 0 = 무한
    Widget chip(String label, bool selected, VoidCallback onTap) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withOpacity(0.22)
                  : AppColors.surface3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected
                      ? AppColors.accent.withOpacity(0.6)
                      : AppColors.softDivider),
            ),
            child: Text(label,
                style: AppTypography.tiny.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.repeat_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            const Expanded(child: Eyebrow('반복 횟수')),
            Text(rc == 0 ? '무한' : '$rc회',
                style: AppTypography.tiny.copyWith(color: AppColors.accent)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in options)
                chip(n == 1 ? '반복 없음' : '$n회', rc == n,
                    () => _mut(() => draft.repeatCount = n)),
              chip('무한', rc == 0, () => _mut(() => draft.repeatCount = 0)),
              chip('직접 입력', rc > 1 && !options.contains(rc), () async {
                final v = await showNumberInputDialog(context,
                    title: '반복 횟수 직접 입력',
                    initial: (rc == 0 ? 2 : rc).toDouble(),
                    min: 1,
                    max: 99,
                    unit: '회',
                    decimals: 0);
                if (v != null) _mut(() => draft.repeatCount = v.round());
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: active ? AppColors.surface3 : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(label,
                  style: AppTypography.label.copyWith(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textMuted)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        tab('레이어', !sequenceTab, () => _mut(() => sequenceTab = false)),
        tab('시퀀스', sequenceTab, () => _mut(() => sequenceTab = true)),
      ]),
    );
  }

  // ── 레이어 뷰 ──
  List<Widget> _layersView() {
    final s = stage;
    return [
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.softDivider),
        ),
        child: Column(children: [
          _layerRow('PRIMARY TONE', '${s.primaryTone.frequencyHz.toStringAsFixed(2)}Hz',
              AppIcons.wave, s.primaryTone.enabled,
              (v) => _mut(() => s.primaryTone.enabled = v),
              () => _editLayer('primary')),
          _layerRow('DRONE',
              '${s.drone.subHz.toStringAsFixed(0)} / ${s.drone.mainHz.toStringAsFixed(0)} / ${s.drone.airHz.toStringAsFixed(0)}Hz',
              AppIcons.drone, s.drone.enabled,
              (v) => _mut(() => s.drone.enabled = v),
              () => _editLayer('drone')),
          _layerRow('SECONDARY', '${s.secondaryTone.frequencyHz.toStringAsFixed(2)}Hz',
              AppIcons.wave, s.secondaryTone.enabled,
              (v) => _mut(() => s.secondaryTone.enabled = v),
              () => _editLayer('secondary')),
          _layerRow('BINAURAL', '${s.binaural.beatHz.toStringAsFixed(1)}Hz beat',
              AppIcons.binaural, s.binaural.enabled,
              (v) => _mut(() => s.binaural.enabled = v),
              () => _editLayer('binaural')),
          _layerRow('PULSE',
              '${s.pulse.rateHz.toStringAsFixed(1)}Hz · ${(s.pulse.depth * 100).round()}%',
              AppIcons.pulse, s.pulse.enabled,
              (v) => _mut(() => s.pulse.enabled = v),
              () => _editLayer('pulse')),
          _layerRow('NATURE', AssetCatalog.displayNameOf(s.natureAssetId),
              AppIcons.nature, s.natureAssetId != null, (v) {
            _mut(() =>
                s.natureAssetId = v ? AssetCatalog.nature.first.id : null);
          }, () => _editLayer('nature')),
          _layerRow('PAD', AssetCatalog.displayNameOf(s.padAssetId),
              AppIcons.pad, s.padAssetId != null, (v) {
            _mut(() => s.padAssetId = v ? AssetCatalog.pads.first.id : null);
          }, () => _editLayer('pad')),
          _layerRow('CHIME', AssetCatalog.displayNameOf(s.chimeAssetId),
              AppIcons.chime, s.chimeAssetId != null, (v) {
            _mut(() => s.chimeAssetId = v ? AssetCatalog.chimes.first.id : null);
          }, () => _editLayer('chime')),
        ]),
      ),
    ];
  }

  Widget _layerRow(String label, String value, IconData icon, bool enabled,
      ValueChanged<bool> onToggle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 20,
                color: enabled ? AppColors.accent : AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.smallCaps
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          AppSwitch(value: enabled, onChanged: onToggle),
        ]),
      ),
    );
  }

  void _editLayer(String id) {
    showStudioLayerEditor(context, stage, id, () => _mut(() {}));
  }

  // ── 시퀀스 뷰 ──
  List<Widget> _sequenceView() {
    return [
      for (var i = 0; i < draft.stages.length; i++)
        _stepCard(i, draft.stages[i]),
      const SizedBox(height: 12),
      SecondaryButton(
        label: '＋ 단계 추가',
        onPressed: () => _mut(() {
          draft.stages.add(SessionStage(
            id: 'stage_${DateTime.now().millisecondsSinceEpoch}',
            title: '새 단계',
            durationSec: 180,
            primaryTone: ToneLayer(enabled: true, frequencyHz: 528.0),
          ));
        }),
      ),
      const SizedBox(height: 8),
      Text('전체 예상 시간 ${(draft.totalDurationSec / 60).round()}분',
          style: AppTypography.tiny),
    ];
  }

  Widget _stepCard(int i, SessionStage stg) {
    final freq = stg.displayFrequencyHz;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        radius: 15,
        onTap: () {
          setState(() => stageIndex = i);
          _editLayer('primary');
        },
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text((i + 1).toString().padLeft(2, '0'),
                style: AppTypography.tiny.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    freq != null
                        ? '${freq.toStringAsFixed(0)}Hz · ${stg.title}'
                        : '무음 · ${stg.title}',
                    style: AppTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${(stg.durationSec / 60).toStringAsFixed(stg.durationSec % 60 == 0 ? 0 : 1)}분',
                    style: AppTypography.tiny),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            onPressed: i > 0 ? () => _mut(() => _swap(i, i - 1)) : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: i < draft.stages.length - 1
                ? () => _mut(() => _swap(i, i + 1))
                : null,
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more, size: 20),
            color: AppColors.surface3,
            onSelected: (v) => _mut(() {
              if (v == 'dup') {
                draft.stages.insert(i + 1, stg.copy()
                  ..id = 'stage_${DateTime.now().millisecondsSinceEpoch}');
              } else if (v == 'del' && draft.stages.length > 1) {
                draft.stages.removeAt(i);
                stageIndex = stageIndex.clamp(0, draft.stages.length - 1);
              } else if (v == 'time') {
                _editDuration(i, stg);
              }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'time', child: Text('시간 수정')),
              PopupMenuItem(value: 'dup', child: Text('복제')),
              PopupMenuItem(value: 'del', child: Text('삭제')),
            ],
          ),
        ]),
      ),
    );
  }

  void _swap(int a, int b) {
    final tmp = draft.stages[a];
    draft.stages[a] = draft.stages[b];
    draft.stages[b] = tmp;
  }

  void _editDuration(int i, SessionStage stg) {
    double minutes = (stg.durationSec / 60).clamp(1, 60).toDouble();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151A22),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('단계 시간 ${minutes.round()}분', style: AppTypography.h3),
            Slider(
              value: minutes.clamp(1, 60),
              min: 1,
              max: 60,
              onChanged: (v) => setSt(() => minutes = v),
            ),
            SecondaryButton(
              label: '숫자로 직접 입력',
              icon: Icons.edit_outlined,
              onPressed: () async {
                final v = await showNumberInputDialog(context,
                    title: '단계 시간 직접 입력',
                    initial: minutes,
                    min: 1,
                    max: 180,
                    unit: '분',
                    decimals: 0);
                if (v != null) setSt(() => minutes = v);
              },
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: '확인',
              onPressed: () {
                _mut(() => stg.durationSec = (minutes * 60).round());
                Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ── 저장 ──
  Future<void> save() async {
    final app = context.read<AppState>();
    final nameCtrl = TextEditingController(text: draft.title);

    if (_source != null && _source!.isBuiltIn) {
      // 기본 프리셋 편집: 3가지 선택
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF151A22),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('저장 방식 선택', style: AppTypography.h3),
            const SizedBox(height: 16),
            PrimaryButton(
                label: '새 프리셋으로 저장',
                onPressed: () => Navigator.pop(ctx, 'new')),
            const SizedBox(height: 8),
            SecondaryButton(
                label: '기본 프리셋 수정',
                onPressed: () => Navigator.pop(ctx, 'override')),
            const SizedBox(height: 8),
            SecondaryButton(
                label: '현재 세션에만 적용',
                onPressed: () => Navigator.pop(ctx, 'session')),
          ]),
        ),
      );
      if (choice == 'override') {
        draft.id = _source!.id;
        draft.isBuiltIn = true;
        await app.presets.saveBuiltInOverride(draft);
        app.refresh();
        if (mounted) showToast(context, '기본 프리셋을 수정했습니다');
        return;
      } else if (choice == 'session') {
        if (mounted) openPresetInPlayer(context, draft);
        return;
      } else if (choice == 'new') {
        // 기본 프리셋을 시작점으로 새로 저장할 때 id 충돌 방지.
        draft.id = 'user_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        return;
      }
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('프리셋 저장'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: '이름'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok == true) {
      draft.title = nameCtrl.text.trim().isEmpty ? '무제' : nameCtrl.text.trim();
      draft.isBuiltIn = false;
      await app.presets.saveUserPreset(draft);
      app.refresh();
      if (mounted) {
        showToast(context, '저장되었습니다');
        _mut(() {});
      }
    }
  }
}
