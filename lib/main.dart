import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/state/evening_welcome_local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  GoogleFonts.config.allowRuntimeFetching = false;
  final AppEnvironment environment = AppEnvironment.fromDefines();
  final String? localHandledEveningPeriod =
      await EveningWelcomeLocalStore.readHandledPeriodKey();
  runApp(
    SleepDormApp(
      environment: environment,
      initialLocalHandledEveningPeriodKey: localHandledEveningPeriod,
    ),
  );
}
