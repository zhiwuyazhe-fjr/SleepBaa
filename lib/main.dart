import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final AppEnvironment environment = AppEnvironment.fromDefines();
  runApp(SleepDormApp(environment: environment));
}
