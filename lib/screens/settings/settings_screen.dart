import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/backup_export.dart';
import '../../core/data/backup_service.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/models/user_settings.dart';
import '../../core/state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/page_scaffold.dart';
import '../tools/self_check_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;

    Future<void> save() => app.updateSettings(s);

    return PageScaffold(
      eyebrow: 'Preferences',
      title: '설정',
      slivers: [
        _group('재생', [
          _valueRow(context, '기본 타이머', '${s.defaultTimerSec ~/ 60}분',
              () => _pickMinutes(context, '기본 타이머', s.defaultTimerSec ~/ 60,
                  (v) { s.defaultTimerSec = v * 60; save(); })),
          _valueRow(context, '시작 페이드', '${s.startFadeSec}초',
              () => _pickSeconds(context, '시작 페이드', s.startFadeSec, 1, 15,
                  (v) { s.startFadeSec = v; save(); })),
          _valueRow(context, '종료 페이드', '${s.endFadeSec}초',
              () => _pickSeconds(context, '종료 페이드', s.endFadeSec, 1, 30,
                  (v) { s.endFadeSec = v; save(); })),
          _switchRow('이어폰 분리 시 일시정지', '스피커로 갑자기 전환되지 않게 함',
              s.pauseOnHeadphoneUnplug,
              (v) { s.pauseOnHeadphoneUnplug = v; save(); }),
          _switchRow('세션 완료 후 자동 정지', null, s.autoStopAfterComplete,
              (v) { s.autoStopAfterComplete = v; save(); }),
          _switchRow('백그라운드 재생', '화면을 끄거나 다른 앱으로 가도 계속 재생 (끄면 자동 일시정지)',
              s.backgroundPlayback,
              (v) { s.backgroundPlayback = v; save(); }),
        ]),
        _group('오디오', [
          _valueRow(context, '최초 시작 음량', '${s.initialMasterVolumePercent}%',
              () => _pickPercent(context, '최초 시작 음량',
                  s.initialMasterVolumePercent,
                  (v) { s.initialMasterVolumePercent = v; save(); })),
          _valueRow(context, '차임 기본 음량', '${s.chimeVolumePercent}%',
              () => _pickPercent(context, '차임 기본 음량', s.chimeVolumePercent,
                  (v) { s.chimeVolumePercent = v; save(); })),
          _switchRow('바이노럴 좌우 반전', '좌우 주파수 배치 전환', s.binauralInvert,
              (v) { s.binauralInvert = v; save(); }),
          _switchRow('출력 장치 변경 시 확인', null, s.confirmOnRouteChange,
              (v) { s.confirmOnRouteChange = v; save(); }),
          _switchRow('고주파 경고', '10kHz 이상 입력 시 확인', s.highFreqWarning,
              (v) { s.highFreqWarning = v; save(); }),
        ]),
        _group('레이키', [
          _valueRow(context, '기본 세션 길이', '${s.reikiDefaultLengthSec ~/ 60}분',
              () => _pickMinutes(context, '레이키 세션 길이',
                  s.reikiDefaultLengthSec ~/ 60,
                  (v) { s.reikiDefaultLengthSec = v * 60; save(); })),
          _valueRow(context, '손 위치 변경 간격',
              '${s.reikiHandChangeIntervalSec ~/ 60}분',
              () => _pickMinutes(context, '손 위치 변경 간격',
                  s.reikiHandChangeIntervalSec ~/ 60,
                  (v) { s.reikiHandChangeIntervalSec = v * 60; save(); })),
          _switchRow('차임', null, s.reikiChime,
              (v) { s.reikiChime = v; save(); }),
          _switchRow('진동', null, s.reikiVibration,
              (v) { s.reikiVibration = v; save(); }),
          _switchRow('화면 자동 어둡게', null, s.reikiAutoDim,
              (v) { s.reikiAutoDim = v; save(); }),
        ]),
        _group('표시', [
          _switchRow('공명 시각화', '재생 파라미터 기반 추상 애니메이션',
              s.showResonanceViz, (v) { s.showResonanceViz = v; save(); }),
          _switchRow('애니메이션 감소', '움직임을 최소화', s.reduceMotion,
              (v) { s.reduceMotion = v; save(); }),
          _switchRow('큰 글씨', null, s.largeText,
              (v) { s.largeText = v; save(); }),
          _switchRow('현재 주파수 소수점 표시', null, s.showFrequencyDecimals,
              (v) { s.showFrequencyDecimals = v; save(); }),
          _switchRow('호흡 가이드', '재생 중 들숨·날숨 리듬 안내', s.breathingGuide,
              (v) { s.breathingGuide = v; save(); }),
          _switchRow('호흡 음성 안내', '들이마시고·멈추고·내쉬라고 음성으로 안내 (기기 음성 사용)',
              s.breathingVoice, (v) { s.breathingVoice = v; save(); }),
        ]),
        _group('도구', [
          _actionRow(context, '주파수 자가 진단', '이 기기에서 생성 주파수 정확도 측정',
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SelfCheckScreen()))),
          _actionRow(context, '온보딩 다시 보기', '앱 첫 소개 화면을 다시 표시',
              () { s.onboardingDone = false; save(); }),
        ]),
        _group('데이터', [
          _actionRow(context, '프리셋 백업', 'JSON 파일로 내보내기',
              () => _exportPresets(context)),
          _actionRow(context, '프리셋 복원', 'JSON 파일에서 가져오기',
              () => _importPresets(context)),
          _actionRow(context, '기록 백업', '세션 기록 내보내기',
              () => _exportRecords(context)),
          _actionRow(context, '기록 삭제', null,
              () => _clearRecords(context), danger: true),
          _actionRow(context, '모든 사용자 설정 초기화', '기본 프리셋은 유지됨',
              () => _resetAll(context), danger: true),
        ]),
        _group('정보', [
          _infoRow('버전', '마인드사운드 1.0.0'),
        ]),
        const SizedBox(height: 8),
        Text(
          '이 앱의 주파수는 개인적 명상과 상징을 위한 초기값이며, 치료 효과나 과학적 효능을 뜻하지 않습니다. '
          '음량은 앱 내부 상대값(dBFS)이며 실제 dB SPL이 아닙니다. '
          '두통·이명·어지럼이 생기면 사용을 멈추세요.',
          style: AppTypography.tiny.copyWith(fontSize: 11, height: 1.6),
        ),
      ],
    );
  }

  // ── 그룹/행 위젯 ──
  Widget _group(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Eyebrow(title),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.softDivider),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1)
                    const Divider(
                        height: 0.5, color: AppColors.divider, thickness: 0.5),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowShell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      );

  Widget _titleDesc(String title, String? desc, {bool danger = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: danger ? AppColors.error : AppColors.textPrimary)),
        if (desc != null) ...[
          const SizedBox(height: 4),
          Text(desc, style: AppTypography.tiny.copyWith(fontSize: 11)),
        ],
      ],
    );
  }

  Widget _switchRow(
      String title, String? desc, bool value, ValueChanged<bool> onChanged) {
    return _rowShell(Row(
      children: [
        Expanded(child: _titleDesc(title, desc)),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    ));
  }

  Widget _valueRow(
      BuildContext context, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: _rowShell(Row(
        children: [
          Expanded(child: _titleDesc(title, null)),
          Text(value, style: AppTypography.tiny),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textDisabled, size: 20),
        ],
      )),
    );
  }

  Widget _actionRow(BuildContext context, String title, String? desc,
      VoidCallback onTap,
      {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      child: _rowShell(Row(
        children: [
          Expanded(child: _titleDesc(title, desc, danger: danger)),
          Icon(Icons.chevron_right_rounded,
              color: danger ? AppColors.error : AppColors.textDisabled,
              size: 20),
        ],
      )),
    );
  }

  Widget _infoRow(String k, String v) => _rowShell(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: AppTypography.label),
          Text(v, style: AppTypography.tiny),
        ],
      ));

  // ── 값 선택 시트 ──
  void _pickMinutes(BuildContext context, String title, int current,
      ValueChanged<int> onPick) {
    _pickFromSlider(context, title, current.toDouble(), 1, 90, '분',
        (v) => onPick(v.round()));
  }

  void _pickSeconds(BuildContext context, String title, int current, int min,
      int max, ValueChanged<int> onPick) {
    _pickFromSlider(context, title, current.toDouble(), min.toDouble(),
        max.toDouble(), '초', (v) => onPick(v.round()));
  }

  void _pickPercent(BuildContext context, String title, int current,
      ValueChanged<int> onPick) {
    _pickFromSlider(context, title, current.toDouble(), 0, 100, '%',
        (v) => onPick(v.round()));
  }

  void _pickFromSlider(BuildContext context, String title, double current,
      double min, double max, String unit, ValueChanged<double> onPick) {
    double v = current.clamp(min, max);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151A22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.h3),
              const SizedBox(height: 8),
              Text('${v.round()}$unit',
                  style: AppTypography.timeDisplay.copyWith(fontSize: 28)),
              Slider(
                value: v,
                min: min,
                max: max,
                onChanged: (nv) => setSt(() => v = nv),
              ),
              PrimaryButton(
                label: '확인',
                onPressed: () {
                  onPick(v);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 백업/복원/삭제 ──
  Future<void> _exportPresets(BuildContext context) async {
    final app = context.read<AppState>();
    try {
      await exportJson('mindsound_presets.json', app.presets.exportData(),
          '마인드사운드 프리셋 백업');
    } catch (e) {
      if (context.mounted) showToast(context, '백업 실패: $e');
    }
  }

  Future<void> _exportRecords(BuildContext context) async {
    final app = context.read<AppState>();
    try {
      await exportJson('mindsound_records.json', app.records.exportData(),
          '마인드사운드 기록 백업');
    } catch (e) {
      if (context.mounted) showToast(context, '백업 실패: $e');
    }
  }

  Future<void> _importPresets(BuildContext context) async {
    final app = context.read<AppState>();
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true, // 웹/모바일 공통: 경로 대신 바이트로 읽는다.
    );
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    final text = utf8.decode(bytes);
    final existing = app.presets.userPresets.map((p) => p.id).toSet();
    final preview = BackupService.inspect(text, existing);
    if (!context.mounted) return;
    if (!preview.valid) {
      showToast(context, '가져오기 실패: ${preview.error}');
      return;
    }
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: const Text('가져오기 미리보기'),
        content: Text(
            '프리셋 ${preview.userPresetCount}개\n중복 ${preview.duplicateIds.length}개\n\n중복 항목을 덮어쓸까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('건너뛰기')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('덮어쓰기')),
        ],
      ),
    );
    final data = BackupService.tryParse(text);
    if (data == null) return;
    final n = await app.presets.importData(data, overwrite: overwrite ?? true);
    app.refresh();
    if (context.mounted) showToast(context, '$n개 프리셋을 가져왔습니다');
  }

  Future<void> _clearRecords(BuildContext context) async {
    final app = context.read<AppState>();
    final ok = await showDangerConfirm(context,
        title: '기록을 모두 삭제할까요?',
        body: '삭제한 기록은 복구할 수 없습니다.',
        confirmLabel: '삭제');
    if (ok) {
      await app.records.clear();
      app.refresh();
      if (context.mounted) showToast(context, '기록을 삭제했습니다');
    }
  }

  Future<void> _resetAll(BuildContext context) async {
    final app = context.read<AppState>();
    final ok = await showDangerConfirm(context,
        title: '모든 사용자 설정을 초기화할까요?',
        body: '설정과 사용자 프리셋, 기본 프리셋 수정본이 초기화됩니다.\n기본 프리셋과 기록은 유지됩니다.',
        confirmLabel: '초기화');
    if (ok) {
      await app.settingsRepo.reset();
      await app.presets.resetUserData();
      app.refresh();
      if (context.mounted) showToast(context, '초기화되었습니다');
    }
  }
}
