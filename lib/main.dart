import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/user_settings_cache_store.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/evening_welcome_local_store.dart';

const List<DeviceOrientation> _sleepDormPreferredOrientations =
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];

Future<void> configureSleepDormSystemChrome() async {
  await SystemChrome.setPreferredOrientations(
    _sleepDormPreferredOrientations,
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSleepDormSystemChrome();
  GoogleFonts.config.allowRuntimeFetching = false;
  final AppEnvironment environment = AppEnvironment.fromDefines();
  await EveningWelcomeLocalStore.pruneStaleAgainstNow();
  final LocalEveningWelcomeBootState? localEveningWelcome =
      await EveningWelcomeLocalStore.readBootState();
  final UserSettings? cachedSettings = await UserSettingsCacheStore().read();
  runApp(
    SleepDormApp(
      environment: environment,
      initialSettings: cachedSettings,
      initialLocalEveningWelcome: localEveningWelcome,
    ),
  );
}
