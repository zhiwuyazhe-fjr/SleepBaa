import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';

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

  testWidgets('assistant page renders the new current stage shell', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-page-default-avatar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-page-current-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-history-hint')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('assistant page keeps the seeded reply inside the stage', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-current-assistant-message')),
      findsOneWidget,
    );
    expect(
      find.text('一个轻柔的 15 分钟呼吸练习，也许能帮你慢慢切换到入睡状态。要不要我现在带你开始？'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpGlacierApp(WidgetTester tester) async {
  await tester.pumpWidget(
    SleepDormApp(initialLocation: AppRoutes.assistant, clock: _dayClock),
  );
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

DateTime _dayClock() => DateTime(2026, 4, 5, 14);

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
final Map<String, String> _mockSecureStorage = <String, String>{};
