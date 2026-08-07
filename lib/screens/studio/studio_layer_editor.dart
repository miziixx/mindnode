import 'package:flutter/material.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/audio_asset.dart';
import '../../core/models/layers.dart';
import '../../core/models/preset.dart';
import '../../widgets/layer_hints.dart';

/// 스튜디오 드래프트 레이어 편집 시트(재생 세션과 무관하게 드래프트를 직접 수정).
Future<void> showStudioLayerEditor(
    BuildContext context, SessionStage stage, String layerId,
    VoidCallback onChanged) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151A22),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => _Editor(stage: stage, layerId: layerId, onChanged: onChanged),
  );
}

class _Editor extends StatefulWidget {
  const _Editor(
      {required this.stage, required this.layerId, required this.onChanged});
  final SessionStage stage;
  final String layerId;
  final VoidCallback onChanged;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  void _apply(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.surface4,
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Text(_title(), style: AppTypography.h2),
              const SizedBox(height: 12),
              ..._controls(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _title() {
    switch (widget.layerId) {
      case 'primary':
        return '주파수';
      case 'secondary':
        return '보조 주파수';
      case 'drone':
        return '드론';
      case 'binaural':
        return '바이노럴';
      case 'pulse':
        return '펄스';
      case 'nature':
        return '자연음';
      case 'pad':
        return '패드';
      case 'chime':
        return '차임';
      default:
        return '레이어';
    }
  }

  List<Widget> _controls() {
    final s = widget.stage;
    switch (widget.layerId) {
      case 'primary':
        return _tone(s.primaryTone);
      case 'secondary':
        return _tone(s.secondaryTone);
      case 'drone':
        return _drone(s.drone);
      case 'binaural':
        return _binaural(s.binaural);
      case 'pulse':
        return _pulse(s.pulse);
      case 'nature':
        return _asset(AssetKind.nature, s.natureAssetId,
            (id) => _apply(() => s.natureAssetId = id));
      case 'pad':
        return _asset(AssetKind.pad, s.padAssetId,
            (id) => _apply(() => s.padAssetId = id));
      case 'chime':
        return _chime(s);
      default:
        return const [];
    }
  }

  List<Widget> _tone(ToneLayer t) => [
        _slider('주파수', '${t.frequencyHz.toStringAsFixed(1)}Hz',
            (t.frequencyHz - 20) / (2000 - 20),
            (v) => _apply(() => t.frequencyHz = 20 + v * (2000 - 20))),
        _slider('음량', '${t.gainDb.toStringAsFixed(0)}dB', (t.gainDb + 60) / 60,
            (v) => _apply(() => t.gainDb = v * 60 - 60)),
      ];

  List<Widget> _drone(DroneLayer d) => [
        _slider('중심 주파수', '${d.centerHz.toStringAsFixed(1)}Hz',
            (d.centerHz - 20) / (2000 - 20),
            (v) => _apply(() => d.centerHz = 20 + v * (2000 - 20))),
        Text('Sub ${d.subHz.toStringAsFixed(0)} · Main ${d.mainHz.toStringAsFixed(0)} · Air ${d.airHz.toStringAsFixed(0)} Hz',
            style: AppTypography.tiny),
        _slider('Sub', '${(d.subVoiceRatio * 100).round()}%', d.subVoiceRatio,
            (v) => _apply(() => d.subVoiceRatio = v)),
        _slider('Main', '${(d.mainVoiceRatio * 100).round()}%', d.mainVoiceRatio,
            (v) => _apply(() => d.mainVoiceRatio = v)),
        _slider('Air', '${(d.airVoiceRatio * 100).round()}%', d.airVoiceRatio,
            (v) => _apply(() => d.airVoiceRatio = v)),
        _slider('움직임 속도', '${d.movementRateHz.toStringAsFixed(2)}Hz',
            (d.movementRateHz - 0.02) / 0.18,
            (v) => _apply(() => d.movementRateHz = 0.02 + v * 0.18)),
        _slider('스테레오 폭', '${(d.stereoWidth * 100).round()}%', d.stereoWidth,
            (v) => _apply(() => d.stereoWidth = v)),
      ];

  List<Widget> _binaural(BinauralLayer b) => [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Text('이어폰 사용 권장. 모노 환경에서는 효과가 달라질 수 있어요.',
              style: AppTypography.tiny),
        ),
        _slider('기준 주파수', '${b.carrierHz.toStringAsFixed(0)}Hz',
            (b.carrierHz - 50) / 450,
            (v) => _apply(() => b.carrierHz = 50 + v * 450)),
        _slider('비트 주파수', '${b.beatHz.toStringAsFixed(2)}Hz', b.beatHz / 40,
            (v) => _apply(() => b.beatHz = (v * 40).clamp(0.5, 40))),
        Text('L ${b.leftHz.toStringAsFixed(1)}Hz · R ${b.rightHz.toStringAsFixed(1)}Hz',
            style: AppTypography.label),
        _switchRow('좌우 반전', b.invert, (v) => _apply(() => b.invert = v)),
      ];

  List<Widget> _pulse(PulseLayer p) => [
        _slider('중심 주파수', '${p.frequencyHz.toStringAsFixed(1)}Hz',
            (p.frequencyHz - 50) / 950,
            (v) => _apply(() => p.frequencyHz = 50 + v * 950)),
        _slider('펄스 속도', '${p.rateHz.toStringAsFixed(2)}Hz', p.rateHz / 20,
            (v) => _apply(() => p.rateHz = (v * 20).clamp(0.1, 20))),
        _slider('펄스 깊이', '${(p.depth * 100).round()}%', p.depth,
            (v) => _apply(() => p.depth = v)),
        _switchRow('좌우 교차', p.stereoMode == PulseStereoMode.alternate,
            (v) => _apply(() => p.stereoMode =
                v ? PulseStereoMode.alternate : PulseStereoMode.center)),
      ];

  List<Widget> _asset(
      AssetKind kind, String? current, ValueChanged<String?> onSelect) {
    return [
      for (final a in AssetCatalog.byKind(kind))
        RadioListTile<String?>(
          value: a.id,
          groupValue: current,
          onChanged: onSelect,
          activeColor: AppColors.accent,
          contentPadding: EdgeInsets.zero,
          title: Text(a.displayName, style: AppTypography.label),
          subtitle: Text(a.loop ? 'seamless loop' : 'one-shot',
              style: AppTypography.tiny),
        ),
      RadioListTile<String?>(
        value: null,
        groupValue: current,
        onChanged: onSelect,
        activeColor: AppColors.accent,
        contentPadding: EdgeInsets.zero,
        title: Text('없음', style: AppTypography.label),
      ),
    ];
  }

  List<Widget> _chime(SessionStage s) {
    return [
      ..._asset(AssetKind.chime, s.chimeAssetId,
          (id) => _apply(() => s.chimeAssetId = id)),
      _slider(
          '차임 간격',
          s.chimeIntervalSec == 0
              ? '반복 없음'
              : '${(s.chimeIntervalSec / 60).toStringAsFixed(0)}분',
          (s.chimeIntervalSec / 600).clamp(0.0, 1.0),
          (v) => _apply(() => s.chimeIntervalSec = (v * 600).round())),
    ];
  }

  Widget _slider(String label, String value, double v,
      ValueChanged<double> onChanged) {
    final hint = layerHint(label);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: AppTypography.label)),
            Text(value, style: AppTypography.tiny),
          ]),
          Slider(value: v.clamp(0.0, 1.0), onChanged: onChanged),
          if (hint.isNotEmpty)
            Text(hint,
                style: AppTypography.tiny
                    .copyWith(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    final hint = layerHint(label);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: AppTypography.label)),
            Switch.adaptive(
                value: value, onChanged: onChanged, activeColor: AppColors.accent),
          ]),
          if (hint.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint,
                  style: AppTypography.tiny
                      .copyWith(fontSize: 11, color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}
