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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platformChannel, _handlePlatformCall);
  });

  setUp(() {
    _mockSecureStorage.clear();
    _platformMethodCalls.clear();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_platformChannel, null);
  });

  testWidgets('assistant glacier empty stage matches the pencil shell', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-header-add')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-header-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-empty-stage')),
      findsOneWidget,
    );
    expect(find.text('你好，我是小眠'), findsOneWidget);
    expect(find.text('今晚想聊点什么'), findsOneWidget);
    expect(find.text('可以和小眠聊聊睡不着的原因，也可以把脑海里还没放下的念头交给我。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('assistant-current-assistant-message')),
      findsNothing,
    );
  });

  testWidgets('assistant glacier reply stage shows pencil tool status rows', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('assistant-composer-field')),
      '我有点累，但脑子还是停不下来。',
    );
    await tester.pump();

    final Finder submitButtonFinder = find.descendant(
      of: find.byKey(const ValueKey<String>('assistant-composer-submit')),
      matching: find.byType(IconButton),
    );
    final IconButton submitButton = tester.widget<IconButton>(
      submitButtonFinder,
    );
    expect(submitButton.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-composer-submit')),
    );
    await tester.pump();
    await _pumpAssistantFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-history-hint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-current-assistant-message')),
      findsOneWidget,
    );
    expect(find.textContaining('先别急着逼自己立刻睡着'), findsOneWidget);
    expect(find.text('闹钟已设定 23:00'), findsOneWidget);
    expect(find.text('寝室静音模式已同步'), findsOneWidget);
    expect(find.text('晚安提醒已开启'), findsOneWidget);
  });

  testWidgets('assistant glacier history page keeps the stored archive flow', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');
    await _sendPrompt(tester, '寝室有点吵，我还是睡不着。');

    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-header-history')),
    );
    await _pumpAssistantFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-history-flow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-history-earlier')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-history-current')),
      findsOneWidget,
    );
    expect(
      find.text('一个轻柔的 15 分钟呼吸练习，也许能帮你慢慢切换到入睡状态。要不要我现在带你开始？'),
      findsOneWidget,
    );
    expect(find.text('我有点累，但脑子还是停不下来。'), findsOneWidget);
    expect(find.text('寝室有点吵，我还是睡不着。'), findsOneWidget);
    expect(find.textContaining('现在宿舍环境大约'), findsOneWidget);
  });

  testWidgets('assistant history action opens the history route', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);
    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-header-history')),
    );
    await _pumpAssistantFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-history-flow')),
      findsOneWidget,
    );
  });

  testWidgets('assistant add action starts a new empty conversation stage', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);
    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-header-add')),
    );
    await _pumpAssistantFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-empty-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-current-assistant-message')),
      findsNothing,
    );
  });

  testWidgets('assistant reply text has subtle floating motion', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);
    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

    final Finder floatingFinder = find.byKey(
      const ValueKey<String>('assistant-current-floating-motion'),
    );
    expect(floatingFinder, findsOneWidget);

    final Transform initialTransform = tester.widget<Transform>(floatingFinder);
    final double initialDy = initialTransform.transform.getTranslation().y;

    await tester.pump(const Duration(milliseconds: 900));

    final Transform movedTransform = tester.widget<Transform>(floatingFinder);
    final double movedDy = movedTransform.transform.getTranslation().y;

    expect(movedDy, isNot(initialDy));
  });

  testWidgets('assistant reply reveal triggers gentle haptics', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);
    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

    final Iterable<MethodCall> hapticCalls = _platformMethodCalls.where(
      (MethodCall call) => call.method == 'HapticFeedback.vibrate',
    );
    expect(hapticCalls, isNotEmpty);
  });
}

Future<void> _pumpGlacierApp(WidgetTester tester) async {
  await tester.pumpWidget(
    SleepDormApp(initialLocation: AppRoutes.assistant, clock: _dayClock),
  );
  await _pumpAssistantFrames(tester);
}

Future<void> _sendPrompt(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('assistant-composer-field')),
    text,
  );
  await tester.pump();
  await tester.tap(
    find.byKey(const ValueKey<String>('assistant-composer-submit')),
  );
  await tester.pump();
  await _pumpAssistantFrames(tester);
}

Future<void> _pumpAssistantFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump(const Duration(milliseconds: 320));
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

Future<dynamic> _handlePlatformCall(MethodCall call) async {
  _platformMethodCalls.add(call);
  return null;
}

DateTime _dayClock() => DateTime(2026, 4, 5, 14);

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const MethodChannel _platformChannel = SystemChannels.platform;
final Map<String, String> _mockSecureStorage = <String, String>{};
final List<MethodCall> _platformMethodCalls = <MethodCall>[];
