import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _secureStorageChannel,
          _handleSecureStorageCall,
        );
  });

  setUp(() {
    _mockSecureStorage.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('settings hub exposes account settings entry', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileSettings);

    expect(find.text('账号设置'), findsNothing);
    expect(find.text('资料摘要'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(find.text('账号管理'), findsOneWidget);

    await tester.tap(find.text('账号管理'));
    await tester.pumpAndSettle();

    expect(find.text('账号管理'), findsOneWidget);
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('重置密码'), findsOneWidget);
    expect(find.text('登录管理'), findsOneWidget);
    expect(find.text('寝室管理'), findsOneWidget);
  });

  testWidgets('account management routes to profile detail and edit pages', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountCenter);

    await tester.tap(find.text('个人资料').first);
    await tester.pumpAndSettle();

    expect(find.text('个人资料'), findsWidgets);
    expect(find.text('编辑资料'), findsOneWidget);

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    expect(find.text('编辑个人资料'), findsOneWidget);
  });

  testWidgets('account routes open password login and dorm pages', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountCenter);

    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    expect(find.text('找回密码'), findsWidgets);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('登录管理'));
    await tester.pumpAndSettle();
    expect(find.text('登录管理'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('寝室管理'),
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('寝室管理'));
    await tester.pumpAndSettle();
    expect(find.text('寝室管理'), findsWidgets);
  });

  testWidgets('filled primary button uses welcome accent colors', (
    WidgetTester tester,
  ) async {
    const NightMoodPalette palette = NightMoodPalette(
      mood: NightMood.happy,
      primary: Color(0xFF111111),
      primarySoft: Color(0xFF222222),
      primaryHighlight: Color(0xFF333333),
      primaryDeep: Color(0xFF444444),
      calmBlue: Color(0xFF555555),
      welcomeCardColor: Color(0xFF666666),
      welcomeFaceColor: Color(0xFF777777),
      welcomeAccentColor: Color(0xFFABCDEF),
      welcomeTextOnAccent: Color(0xFF123456),
      welcomeSurfaceColor: Color(0xFF888888),
      heroGradientStart: Color(0xFF999999),
      heroGradientMid: Color(0xFFAAAAAA),
      heroGradientEnd: Color(0xFFBBBBBB),
      moonGradientStart: Color(0xFFCCCCCC),
      moonGradientMid: Color(0xFFDDDDDD),
      moonGradientEnd: Color(0xFFEEEEEE),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[palette]),
        home: const Scaffold(
          body: Center(child: PrimaryButton(label: '保存')),
        ),
      ),
    );

    final FilledButton button = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );

    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      palette.welcomeAccentColor,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      palette.welcomeTextOnAccent,
    );

    final RoundedRectangleBorder shape =
        button.style?.shape?.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, AppRadius.button);
    expect(
      button.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(0, 56),
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  await tester.pumpWidget(SleepDormApp(initialLocation: initialLocation));
  await tester.pumpAndSettle();
}

Future<dynamic> _handleSecureStorageCall(MethodCall call) async {
  final Map<dynamic, dynamic> arguments =
      call.arguments as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{};
  final String key = arguments['key'] as String? ?? '';
  switch (call.method) {
    case 'read':
      return _mockSecureStorage[key];
    case 'write':
      _mockSecureStorage[key] = arguments['value'] as String? ?? '';
      return null;
    case 'delete':
      _mockSecureStorage.remove(key);
      return null;
    case 'containsKey':
      return _mockSecureStorage.containsKey(key);
    case 'readAll':
      return Map<String, String>.from(_mockSecureStorage);
    case 'deleteAll':
      _mockSecureStorage.clear();
      return null;
    default:
      return null;
  }
}

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final Map<String, String> _mockSecureStorage = <String, String>{};
