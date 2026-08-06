import 'package:flutter/foundation.dart';

import '../data/preset_repository.dart';
import '../data/record_repository.dart';
import '../data/settings_repository.dart';
import '../models/user_settings.dart';

/// 앱 전역 상태: 저장소, 설정, 하단 탭 인덱스.
class AppState extends ChangeNotifier {
  final PresetRepository presets = PresetRepository();
  final RecordRepository records = RecordRepository();
  final SettingsRepository settingsRepo = SettingsRepository();

  int navIndex = 0;
  bool _loaded = false;
  bool get loaded => _loaded;

  UserSettings get settings => settingsRepo.settings;

  Future<void> load() async {
    await Future.wait([
      presets.load(),
      records.load(),
      settingsRepo.load(),
    ]);
    _loaded = true;
    notifyListeners();
  }

  void setNavIndex(int i) {
    if (i == navIndex) return;
    navIndex = i;
    notifyListeners();
  }

  Future<void> updateSettings(UserSettings s) async {
    await settingsRepo.save(s);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final s = settings;
    s.onboardingDone = true;
    await settingsRepo.save(s);
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
