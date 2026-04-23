import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/settings_page.dart';

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
      find.byKey(const ValueKey<String>('assistant-composer-mic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-current-assistant-message')),
      findsNothing,
    );
  });

  testWidgets(
    'assistant glacier reply stage stays compact and keeps hint hidden',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('assistant-current-assistant-message'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('先别急着逼自己立刻睡着'), findsOneWidget);
      expect(find.text('闹钟已设定 23:00'), findsOneWidget);
      expect(find.text('寝室静音模式已同步'), findsOneWidget);
      expect(find.text('晚安提醒已开启'), findsOneWidget);
    },
  );

  testWidgets(
    'assistant reply requires a second downward pull and collapses from archive bottom',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture revealHintGesture = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await revealHintGesture.moveBy(const Offset(0, 54));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsOneWidget,
      );

      await revealHintGesture.up();
      await _pumpAssistantFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsNothing,
      );

      final TestGesture expandGesture = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await expandGesture.moveBy(const Offset(0, 180));
      await tester.pump();
      await expandGesture.up();
      await _pumpAssistantFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-history-current')),
        findsOneWidget,
      );

      final Finder collapseZone = find.byKey(
        const ValueKey<String>('assistant-history-collapse-zone'),
      );
      await tester.drag(collapseZone, const Offset(0, -170));
      await tester.pump();
      await _pumpAssistantFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('assistant-current-assistant-message'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'assistant archive hint resets after five seconds and needs a new first pull',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture firstGesture = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await firstGesture.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstGesture.up();
      await _pumpAssistantFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 6));

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );

      final TestGesture secondGesture = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await secondGesture.moveBy(const Offset(0, 180));
      await tester.pump();
      await secondGesture.up();
      await _pumpAssistantFrames(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'assistant archive opens at the latest message when history is expanded',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      for (int index = 0; index < 5; index++) {
        await _sendPrompt(tester, '第${index + 1}条：今天脑子一直停不下来，想把这些念头先收好再睡。');
      }

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture firstPull = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await firstPull.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstPull.up();
      await _pumpAssistantFrames(tester);

      final TestGesture secondPull = await tester.startGesture(
        tester.getCenter(viewport),
      );
      await secondPull.moveBy(const Offset(0, 200));
      await tester.pump();
      await secondPull.up();
      await _pumpAssistantFrames(tester);

      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('assistant-history-scroll')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(
        scrollable.position.pixels,
        closeTo(scrollable.position.maxScrollExtent, 1),
      );
    },
  );

  testWidgets('assistant history action opens the thread history page', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);
    await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

    await tester.tap(
      find.byKey(const ValueKey<String>('assistant-header-history')),
    );
    await _pumpAssistantFrames(tester);

    expect(
      find.byKey(const ValueKey<String>('assistant-thread-history-list')),
      findsOneWidget,
    );
    expect(find.text('历史对话'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('assistant-thread-history-add')),
      findsNothing,
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

  testWidgets('assistant empty stage floats as a single text group', (
    WidgetTester tester,
  ) async {
    await _pumpGlacierApp(tester);

    final Finder floatingFinder = find.byKey(
      const ValueKey<String>('assistant-empty-floating-motion'),
    );
    expect(floatingFinder, findsOneWidget);

    final Transform initialTransform = tester.widget<Transform>(floatingFinder);
    final double initialDy = initialTransform.transform.getTranslation().y;

    await tester.pump(const Duration(milliseconds: 900));

    final Transform movedTransform = tester.widget<Transform>(floatingFinder);
    final double movedDy = movedTransform.transform.getTranslation().y;

    expect(movedDy, isNot(initialDy));
    expect(find.text('你好，我是小眠'), findsOneWidget);
    expect(find.text('今晚想聊点什么'), findsOneWidget);
    expect(find.text('可以和小眠聊聊睡不着的原因，也可以把脑海里还没放下的念头交给我。'), findsOneWidget);
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

  testWidgets('assistant reply motion level changes floating amplitude', (
    WidgetTester tester,
  ) async {
    final UserSettings baseSettings = buildDefaultUserSettings();
    final double lowDy = await _replyFloatingDistanceForLevel(
      tester,
      baseSettings.copyWith(
        assistantReplyMotionLevel: AssistantReplyMotionLevel.low,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final double highDy = await _replyFloatingDistanceForLevel(
      tester,
      baseSettings.copyWith(
        assistantReplyMotionLevel: AssistantReplyMotionLevel.high,
      ),
    );

    expect(highDy.abs(), greaterThan(lowDy.abs()));
  });

  testWidgets(
    'assistant motion setting saves from the dedicated settings row',
    (WidgetTester tester) async {
      await _pumpRouteApp(
        tester,
        AppRoutes.profileSettings,
        initialSettings: buildDefaultUserSettings().copyWith(
          assistantReplyMotionLevel: AssistantReplyMotionLevel.low,
        ),
      );

      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('陪伴动效'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('陪伴动效'), findsOneWidget);
      expect(find.text('回复文字浮动'), findsOneWidget);
      expect(find.text('低'), findsOneWidget);

      await tester.tap(find.text('回复文字浮动'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      await tester.tap(find.text('高').last);
      await _pumpAssistantFrames(tester);

      final AppServices services = AppScope.of(
        tester.element(find.byType(SettingsPage)),
      );
      expect(
        services.profileFacade.currentSettings.assistantReplyMotionLevel,
        AssistantReplyMotionLevel.high,
      );
    },
  );
}

Future<void> _pumpGlacierApp(
  WidgetTester tester, {
  UserSettings? initialSettings,
}) async {
  await _pumpRouteApp(
    tester,
    AppRoutes.assistant,
    initialSettings: initialSettings,
  );
}

Future<void> _pumpRouteApp(
  WidgetTester tester,
  String route, {
  UserSettings? initialSettings,
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: route,
      clock: _dayClock,
      initialSettings: initialSettings,
    ),
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
  await tester.pump(const Duration(milliseconds: 520));
  await tester.pump(const Duration(milliseconds: 760));
}

Future<double> _replyFloatingDistanceForLevel(
  WidgetTester tester,
  UserSettings settings,
) async {
  await _pumpGlacierApp(tester, initialSettings: settings);
  await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

  final Finder floatingFinder = find.byKey(
    const ValueKey<String>('assistant-current-floating-motion'),
  );
  await tester.pump(const Duration(milliseconds: 900));

  final Transform movedTransform = tester.widget<Transform>(floatingFinder);
  return movedTransform.transform.getTranslation().y;
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
