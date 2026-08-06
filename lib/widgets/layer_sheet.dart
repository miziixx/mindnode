import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design/app_colors.dart';
import '../core/design/app_typography.dart';
import '../core/models/audio_asset.dart';
import '../core/models/layers.dart';
import '../core/state/playback_controller.dart';
import 'common.dart';

/// 레이어 상세 바텀시트. 화면 높이 70~90%까지 확장. 상단에 레이어 포인트색 얇게.
Future<void> showLayerSheet(BuildContext context, String layerId,
    {Color accent = AppColors.accent}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF151A22),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _LayerSheet(layerId: layerId, accent: accent),
  );
}

class _LayerSheet extends StatelessWidget {
  const _LayerSheet({required this.layerId, required this.accent});
  final String layerId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackController>();
    final stage = playback.currentStage;
    final maxH = MediaQuery.of(context).size.height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: accent.withOpacity(0.4), width: 2)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface4,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Eyebrow('Layer settings'),
              const SizedBox(height: 6),
              Text(_titleFor(layerId), style: AppTypography.h2),
              const SizedBox(height: 6),
              Text('현재 세션에 즉시 반영되며, 저장 전에는 원본 프리셋을 덮어쓰지 않습니다.',
                  style: AppTypography.tiny),
              const SizedBox(height: 18),
              if (stage == null)
                const StatusMessage(title: '활성 세션이 없습니다')
              else
                ..._buildControls(context, playback, stage),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(String id) {
    switch (id) {
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

  List<Widget> _buildControls(
      BuildContext context, PlaybackController pb, dynamic stage) {
    switch (layerId) {
      case 'primary':
        return _toneControls(context, pb, stage.primaryTone, primary: true);
      case 'secondary':
        return _toneControls(context, pb, stage.secondaryTone, primary: false);
      case 'drone':
        return _droneControls(context, pb, stage.drone);
      case 'binaural':
        return _binauralControls(context, pb, stage.binaural);
      case 'pulse':
        return _pulseControls(context, pb, stage.pulse);
      case 'nature':
        return _assetControls(context, pb, AssetKind.nature,
            stage.natureAssetId, (id) => pb.setNatureAsset(id));
      case 'pad':
        return _assetControls(context, pb, AssetKind.pad, stage.padAssetId,
            (id) => pb.setPadAsset(id));
      case 'chime':
        return _chimeControls(context, pb, stage);
      default:
        return const [];
    }
  }

  // --- 톤 ---
  List<Widget> _toneControls(
      BuildContext context, PlaybackController pb, ToneLayer tone,
      {required bool primary}) {
    void setHz(double v) {
      final hz = v.clamp(FreqLimits.min, FreqLimits.maxAbsolute);
      if (primary) {
        pb.setPrimaryFrequency(hz);
      } else {
        pb.setSecondaryFrequency(hz);
      }
    }

    return [
      _FrequencyBlock(hz: tone.frequencyHz, onDelta: (d) => setHz(tone.frequencyHz + d)),
      _sliderRow('레이어 음량', '${tone.gainDb.toStringAsFixed(0)}dB',
          (tone.gainDb + 60) / 60, (v) {
        pb.setLayerGainDb(primary ? 'primary' : 'secondary', v * 60 - 60);
      }),
      _sliderRow('좌우 위치', _panLabel(tone.pan), (tone.pan + 1) / 2, (v) {
        tone.pan = v * 2 - 1;
        pb.updateDrone(); // notify + engine layer update handled generically
      }),
    ];
  }

  // --- 드론 ---
  List<Widget> _droneControls(
      BuildContext context, PlaybackController pb, DroneLayer d) {
    return [
      _FrequencyBlock(
          hz: d.centerHz,
          label: '중심 주파수',
          onDelta: (delta) {
            d.centerHz =
                (d.centerHz + delta).clamp(FreqLimits.min, FreqLimits.maxAbsolute);
            pb.updateDrone();
          }),
      Text('Sub ${d.subHz.toStringAsFixed(1)} · Main ${d.mainHz.toStringAsFixed(1)} · Air ${d.airHz.toStringAsFixed(1)} Hz',
          style: AppTypography.tiny),
      _sliderRow('Sub Voice', '${(d.subVoiceRatio * 100).round()}%',
          d.subVoiceRatio, (v) {
        d.subVoiceRatio = v;
        pb.updateDrone();
      }),
      _sliderRow('Main Voice', '${(d.mainVoiceRatio * 100).round()}%',
          d.mainVoiceRatio, (v) {
        d.mainVoiceRatio = v;
        pb.updateDrone();
      }),
      _sliderRow('Air Voice', '${(d.airVoiceRatio * 100).round()}%',
          d.airVoiceRatio, (v) {
        d.airVoiceRatio = v;
        pb.updateDrone();
      }),
      _sliderRow('움직임 속도', '${d.movementRateHz.toStringAsFixed(2)}Hz',
          (d.movementRateHz - 0.02) / 0.18, (v) {
        d.movementRateHz = 0.02 + v * 0.18;
        pb.updateDrone();
      }),
      _sliderRow('스테레오 폭', '${(d.stereoWidth * 100).round()}%', d.stereoWidth,
          (v) {
        d.stereoWidth = v;
        pb.updateDrone();
      }),
    ];
  }

  // --- 바이노럴 ---
  List<Widget> _binauralControls(
      BuildContext context, PlaybackController pb, BinauralLayer b) {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.headphones_outlined,
              color: AppColors.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text('이어폰 사용을 권장합니다. 모노 환경에서는 효과가 달라질 수 있어요.',
                  style: AppTypography.tiny)),
        ]),
      ),
      const SizedBox(height: 8),
      _sliderRow('기준 주파수', '${b.carrierHz.toStringAsFixed(0)}Hz',
          (b.carrierHz - 50) / 450, (v) {
        b.carrierHz = 50 + v * 450;
        pb.updateBinaural();
      }),
      _sliderRow('비트 주파수', '${b.beatHz.toStringAsFixed(2)}Hz', b.beatHz / 40,
          (v) {
        b.beatHz = (v * 40).clamp(0.5, 40);
        pb.updateBinaural();
      }),
      Semantics(
        label: '왼쪽 ${b.leftHz.toStringAsFixed(1)}헤르츠, 오른쪽 ${b.rightHz.toStringAsFixed(1)}헤르츠',
        child: Text(
            'L ${b.leftHz.toStringAsFixed(1)}Hz · R ${b.rightHz.toStringAsFixed(1)}Hz',
            style: AppTypography.label),
      ),
      _toggleRow('좌우 반전', b.invert, (v) {
        b.invert = v;
        pb.updateBinaural();
      }),
    ];
  }

  // --- 펄스 ---
  List<Widget> _pulseControls(
      BuildContext context, PlaybackController pb, PulseLayer p) {
    return [
      _sliderRow('중심 주파수', '${p.frequencyHz.toStringAsFixed(1)}Hz',
          (p.frequencyHz - 50) / 950, (v) {
        p.frequencyHz = 50 + v * 950;
        pb.updatePulse();
      }),
      _sliderRow('펄스 속도', '${p.rateHz.toStringAsFixed(2)}Hz', p.rateHz / 20,
          (v) {
        p.rateHz = (v * 20).clamp(0.1, 20);
        pb.updatePulse();
      }),
      _sliderRow('펄스 깊이', '${(p.depth * 100).round()}%', p.depth, (v) {
        p.depth = v;
        pb.updatePulse();
      }),
      _toggleRow('좌우 교차(alternate)', p.stereoMode == PulseStereoMode.alternate,
          (v) {
        p.stereoMode =
            v ? PulseStereoMode.alternate : PulseStereoMode.center;
        pb.updatePulse();
      }),
    ];
  }

  // --- 자연음/패드 ---
  List<Widget> _assetControls(BuildContext context, PlaybackController pb,
      AssetKind kind, String? currentId, void Function(String?) onSelect) {
    final items = AssetCatalog.byKind(kind);
    return [
      for (final a in items)
        RadioListTile<String?>(
          value: a.id,
          groupValue: currentId,
          onChanged: (v) => onSelect(v),
          activeColor: accent,
          contentPadding: EdgeInsets.zero,
          title: Text(a.displayName, style: AppTypography.label),
          subtitle: Text(a.loop ? 'seamless loop' : 'one-shot',
              style: AppTypography.tiny),
        ),
      RadioListTile<String?>(
        value: null,
        groupValue: currentId,
        onChanged: (v) => onSelect(null),
        activeColor: accent,
        contentPadding: EdgeInsets.zero,
        title: Text('없음', style: AppTypography.label),
      ),
    ];
  }

  // --- 차임 ---
  List<Widget> _chimeControls(
      BuildContext context, PlaybackController pb, dynamic stage) {
    final items = AssetCatalog.byKind(AssetKind.chime);
    return [
      for (final a in items)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            stage.chimeAssetId == a.id
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: stage.chimeAssetId == a.id ? accent : AppColors.textMuted,
          ),
          title: Text(a.displayName, style: AppTypography.label),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            onPressed: () => pb.triggerChimeNow(a.id),
            tooltip: '미리 듣기',
          ),
          onTap: () {
            stage.chimeAssetId = a.id;
            pb.updateDrone();
          },
        ),
      _sliderRow('차임 간격', stage.chimeIntervalSec == 0
          ? '반복 없음'
          : '${(stage.chimeIntervalSec / 60).toStringAsFixed(0)}분',
          (stage.chimeIntervalSec / 600).clamp(0.0, 1.0), (v) {
        stage.chimeIntervalSec = (v * 600).round();
        pb.updateDrone();
      }),
    ];
  }

  String _panLabel(double pan) {
    if (pan.abs() < 0.05) return '중앙';
    return pan < 0
        ? 'L ${(pan.abs() * 100).round()}%'
        : 'R ${(pan * 100).round()}%';
  }
}

Widget _sliderRow(
    String label, String value, double v, ValueChanged<double> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: AppTypography.label)),
          Text(value, style: AppTypography.tiny),
        ]),
        Slider(value: v.clamp(0.0, 1.0), onChanged: onChanged),
      ],
    ),
  );
}

Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(children: [
      Expanded(child: Text(label, style: AppTypography.label)),
      AppSwitch(value: value, onChanged: onChanged),
    ]),
  );
}

class _FrequencyBlock extends StatelessWidget {
  const _FrequencyBlock(
      {required this.hz, required this.onDelta, this.label = 'CURRENT VALUE'});
  final double hz;
  final void Function(double delta) onDelta;
  final String label;

  @override
  Widget build(BuildContext context) {
    const steps = [-10.0, -1.0, -0.1, 0.1, 1.0, 10.0];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Text(label.toUpperCase(),
            style: AppTypography.eyebrow, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${hz.toStringAsFixed(1)} Hz',
            style: AppTypography.frequencyDisplay.copyWith(fontSize: 36)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final s in steps)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    onPressed: () => onDelta(s),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: AppColors.surface3,
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.softDivider),
                    ),
                    child: Text(
                        s > 0 ? '+${_fmt(s)}' : _fmt(s),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }

  String _fmt(double s) =>
      s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toStringAsFixed(1);
}
