import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/core/backend/user_settings_cache_store.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('user settings cache preserves dark theme boot settings', () async {
    final UserSettingsCacheStore store = UserSettingsCacheStore();
    final UserSettings settings = buildDefaultUserSettings().copyWith(
      themeMode: AppThemeMode.dark,
      selectedNightMood: NightMood.calm,
    );

    await store.write(settings);

    final UserSettings? restored = await store.read();
    expect(restored?.themeMode, AppThemeMode.dark);
    expect(restored?.selectedNightMood, NightMood.calm);
  });
}
