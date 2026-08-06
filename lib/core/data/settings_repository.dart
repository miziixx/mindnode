import '../models/user_settings.dart';
import 'local_store.dart';

/// 사용자 설정 저장소.
class SettingsRepository {
  static const _file = 'settings.json';
  UserSettings _settings = UserSettings();

  UserSettings get settings => _settings;

  Future<void> load() async {
    final raw = await LocalStore.readJson(_file);
    if (raw.isNotEmpty) {
      _settings = UserSettings.fromJson(raw);
    }
  }

  Future<void> save(UserSettings s) async {
    _settings = s;
    await LocalStore.writeJson(_file, s.toJson());
  }

  Future<void> reset() async {
    final keepOnboarding = _settings.onboardingDone;
    _settings = UserSettings()..onboardingDone = keepOnboarding;
    await LocalStore.writeJson(_file, _settings.toJson());
  }
}
