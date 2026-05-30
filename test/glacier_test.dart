import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';
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

  testWidgets('profile account details use grouped settings sections', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountProfile);

    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('个性签名'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('寝室'), findsOneWidget);
    expect(find.byType(AppSettingsGroup), findsOneWidget);
  });

  testWidgets('login management metadata uses grouped settings section', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountLogin);

    expect(find.text('登录方式'), findsOneWidget);
    expect(find.text('手机验证'), findsOneWidget);
    expect(find.text('最近绑定'), findsOneWidget);
    expect(find.text('退出当前账号'), findsOneWidget);
    expect(find.byType(AppSettingsGroup), findsOneWidget);
  });

  testWidgets('dorm management removes dorm-space shortcut', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountDorm);

    expect(find.text('查看宿舍空间'), findsNothing);
    expect(find.text('查看宿舍规则'), findsOneWidget);
    expect(find.text('编辑宿舍名称'), findsOneWidget);
  });

  testWidgets('dorm management edit name uses the shared form dialog shell', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountDorm);

    await tester.tap(find.text('编辑宿舍名称'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('app-center-dialog-form')),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets(
    'sleep preference action rows keep shared settings item baseline',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester, initialLocation: AppRoutes.profileSettings);
      await _scrollToSleepPreferences(tester);

      final List<String> sleepItemTitles = <String>[
        '睡前提醒时间',
        '睡前提醒',
        '晨间反馈提醒',
        '寝室动态提醒',
        '智能建议',
      ];
      final List<AppSettingsItem> settingsItems = tester
          .widgetList<AppSettingsItem>(find.byType(AppSettingsItem))
          .toList(growable: false);

      for (final String title in sleepItemTitles) {
        final AppSettingsItem item = settingsItems.firstWhere(
          (AppSettingsItem candidate) => candidate.title == title,
        );
        expect(item.leadingWidth, 28, reason: title);
        expect(item.minHeight, isNull, reason: title);
        expect(item.titleStyle, isNull, reason: title);
        expect(item.padding.horizontal, AppSpacing.md * 2, reason: title);
      }
    },
  );

  testWidgets('sleep preference rows match account and dorm entry heights', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountCenter);
    final double accountEntryHeight = tester
        .getSize(
          find.ancestor(of: find.text('个人资料'), matching: find.byType(InkWell)),
        )
        .height;

    await _pumpApp(tester, initialLocation: AppRoutes.profileAccountDorm);
    final double dormEntryHeight = tester
        .getSize(
          find.ancestor(of: find.text('邀请舍友'), matching: find.byType(InkWell)),
        )
        .height;

    await _pumpApp(tester, initialLocation: AppRoutes.profileSettings);
    await _scrollToSleepPreferences(tester);
    final List<String> sleepItemTitles = <String>[
      '睡前提醒时间',
      '睡前提醒',
      '晨间反馈提醒',
      '寝室动态提醒',
      '智能建议',
    ];

    expect(dormEntryHeight, accountEntryHeight);
    for (final String title in sleepItemTitles) {
      final double sleepRowHeight = tester
          .getSize(
            find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
          )
          .height;
      expect(sleepRowHeight, accountEntryHeight, reason: title);
    }
  });

  testWidgets('sleep preference toggles are wider without stretching rows', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.profileSettings);
    await _scrollToSleepPreferences(tester);

    final List<String> switchItemTitles = <String>[
      '睡前提醒',
      '晨间反馈提醒',
      '寝室动态提醒',
      '智能建议',
    ];

    for (final String title in switchItemTitles) {
      final Size rowSize = tester.getSize(
        find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
      );
      final Size toggleSize = tester.getSize(
        find.byKey(ValueKey<String>('settings-toggle-$title')),
      );
      expect(toggleSize.width, 52, reason: title);
      expect(toggleSize.height, 26, reason: title);
      expect(toggleSize.height, lessThan(rowSize.height), reason: title);
    }
  });

  testWidgets('shared app card tap emits light haptic feedback', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppCard(
              onTap: () {
                taps += 1;
              },
              child: const Text('打开详情'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开详情'));
    await tester.pump();

    expect(taps, 1);
    expect(_platformHapticTypes, contains('HapticFeedbackType.lightImpact'));
  });

  testWidgets('section title action emits navigation haptic feedback', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SectionTitle(
              title: '今晚行动建议',
              actionLabel: '查看全部',
              onAction: () {
                taps += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('查看全部'));
    await tester.pump();

    expect(taps, 1);
    expect(_platformHapticTypes, contains('HapticFeedbackType.lightImpact'));
  });

  testWidgets('settings page exposes assistant reply motion entry', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.profileSettings);

    expect(find.text('AI陪伴'), findsOneWidget);
    await tester.ensureVisible(find.text('睡眠偏好'));
    expect(find.text('睡眠偏好'), findsOneWidget);
    expect(find.text('回复文字浮动'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('AI陪伴')).dy,
      lessThan(tester.getTopLeft(find.text('睡眠偏好')).dy),
    );
  });

  testWidgets('filled primary button uses semantic action colors', (
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

    final AppSemanticColors appColors = AppSemanticColors.light(palette);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[palette, appColors],
        ),
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
      appColors.accent,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      appColors.textOnAccent,
    );

    final RoundedRectangleBorder shape =
        button.style?.shape?.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, AppRadius.button);
    expect(
      button.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(0, 56),
    );
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

  test('assistant strip glow palette gets lighter from core to tail', () {
    for (final NightMood? mood in <NightMood?>[
      null,
      NightMood.happy,
      NightMood.sad,
      NightMood.calm,
    ]) {
      final AssistantSurfacePalette palette = AssistantSurfacePalette.fromMood(
        NightMoodPalette.fromMood(mood),
      );
      final double coreLightness = HSLColor.fromColor(
        palette.bottomGlowCore.withAlpha(0xFF),
      ).lightness;
      final double midLightness = HSLColor.fromColor(
        palette.bottomGlowMid.withAlpha(0xFF),
      ).lightness;
      final double tailLightness = HSLColor.fromColor(
        palette.bottomGlowStart.withAlpha(0xFF),
      ).lightness;

      expect(
        coreLightness,
        lessThan(midLightness),
        reason: 'Glow core for $mood should stay deeper than the mid band.',
      );
      expect(
        midLightness,
        lessThan(tailLightness),
        reason: 'Glow tail for $mood should be the lightest strip layer.',
      );
    }
  });

  testWidgets('assistant background glow keeps strip gradients only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: Colors.black,
          child: AssistantBackgroundGlow(
            palette: AssistantSurfacePalette.fromMood(
              NightMoodPalette.fromMood(null),
            ),
          ),
        ),
      ),
    );

    final Iterable<BoxDecoration> decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox widget) => widget.decoration)
        .whereType<BoxDecoration>();

    final Iterable<Gradient> gradients = decorations
        .map((BoxDecoration decoration) => decoration.gradient)
        .whereType<Gradient>();

    expect(
      gradients.whereType<LinearGradient>().length,
      greaterThanOrEqualTo(2),
    );
    expect(gradients.whereType<RadialGradient>(), isEmpty);
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
    'assistant stage viewport extends beneath the composer for reply scroll',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Rect viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-stage-viewport')),
      );
      final Rect composerRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-composer-field')),
      );

      expect(viewportRect.bottom, greaterThan(composerRect.top));
    },
  );

  testWidgets(
    'assistant reply requires two pulls to open and one pull to exit while return hint is visible',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      await _openConversationFlow(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-history-current')),
        findsOneWidget,
      );
      expect(find.text('上拉返回当前回复'), findsOneWidget);

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
    'assistant entering conversation flow immediately shows the bottom return hint',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      await _openConversationFlow(tester);

      expect(find.text('上拉返回当前回复'), findsOneWidget);
      final Rect hintRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
      );
      final Rect viewportRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-stage-viewport')),
      );
      expect(hintRect.center.dy, greaterThan(viewportRect.center.dy));
    },
  );

  testWidgets(
    'assistant flow hint disappears as soon as the confirmed transition starts',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture firstPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await firstPull.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstPull.up();
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.text('再次下拉查看对话记录'), findsOneWidget);

      final TestGesture secondPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await secondPull.moveBy(const Offset(0, 72));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );

      await secondPull.up();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'assistant flow hint sits above the composer in the lower stage',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture firstPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await firstPull.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstPull.up();
      await tester.pump(const Duration(milliseconds: 220));

      final Rect hintRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
      );
      final Rect composerRect = tester.getRect(
        find.byKey(const ValueKey<String>('assistant-composer-field')),
      );
      final Rect viewportRect = tester.getRect(viewport);

      expect(hintRect.bottom, lessThan(composerRect.top));
      expect(hintRect.center.dy, greaterThan(viewportRect.center.dy));
    },
  );

  testWidgets(
    'assistant conversation flow expansion waits for release before switching layers',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture firstPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await firstPull.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstPull.up();
      await tester.pump(const Duration(milliseconds: 220));

      final TestGesture secondPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await secondPull.moveBy(const Offset(0, 180));
      await tester.pump();

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

      await secondPull.up();
    },
  );

  testWidgets(
    'assistant conversation flow keeps one visible layer through mid-transition',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');

      final Finder viewport = find.byKey(
        const ValueKey<String>('assistant-stage-viewport'),
      );

      final TestGesture revealHintGesture = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await revealHintGesture.moveBy(const Offset(0, 54));
      await tester.pump();
      await revealHintGesture.up();
      await tester.pump(const Duration(milliseconds: 220));

      final TestGesture expandGesture = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
      );
      await expandGesture.moveBy(const Offset(0, 180));
      await tester.pump();
      await expandGesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      final double replyOpacity = _effectiveAncestorOpacity(
        tester,
        find.byKey(
          const ValueKey<String>('assistant-current-assistant-message'),
        ),
      );
      final double historyOpacity = _effectiveAncestorOpacity(
        tester,
        find.byKey(const ValueKey<String>('assistant-history-flow')),
      );

      expect(
        replyOpacity > 0.02 || historyOpacity > 0.02,
        isTrue,
        reason: 'Flow transition should never blank both layers at once.',
      );
    },
  );

  testWidgets(
    'assistant collapse hint disappears as soon as the confirmed return transition starts',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');
      await _openConversationFlow(tester);

      final Finder collapseZone = find.byKey(
        const ValueKey<String>('assistant-history-collapse-zone'),
      );

      final TestGesture returnPull = await tester.startGesture(
        tester.getCenter(collapseZone),
      );
      await returnPull.moveBy(const Offset(0, -112));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );

      await returnPull.up();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'assistant conversation flow collapse waits for release even when the return hint is pre-armed',
    (WidgetTester tester) async {
      await _pumpGlacierApp(tester);
      await _sendPrompt(tester, '我有点累，但脑子还是停不下来。');
      await _openConversationFlow(tester);

      final Finder collapseZone = find.byKey(
        const ValueKey<String>('assistant-history-collapse-zone'),
      );

      final TestGesture returnPull = await tester.startGesture(
        tester.getCenter(collapseZone),
      );
      await returnPull.moveBy(const Offset(0, -170));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('assistant-history-flow')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('assistant-current-assistant-message'),
        ),
        findsNothing,
      );

      await returnPull.up();
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
        _assistantViewportTopPullStart(tester, viewport),
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
      await tester.pump(const Duration(milliseconds: 320));

      expect(
        find.byKey(const ValueKey<String>('assistant-history-hint')),
        findsNothing,
      );

      final TestGesture secondGesture = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
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
        _assistantViewportTopPullStart(tester, viewport),
      );
      await firstPull.moveBy(const Offset(0, 54));
      await tester.pump();
      await firstPull.up();
      await _pumpAssistantFrames(tester);

      final TestGesture secondPull = await tester.startGesture(
        _assistantViewportTopPullStart(tester, viewport),
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
      expect(find.text('AI陪伴'), findsOneWidget);
      expect(find.text('回复文字浮动'), findsOneWidget);
      expect(find.text('低'), findsOneWidget);

      await tester.tap(find.text('回复文字浮动'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      expect(
        find.byKey(const ValueKey<String>('app-bottom-sheet-selection')),
        findsOneWidget,
      );
      expect(find.text('更克制，存在感最低。'), findsNothing);
      expect(find.text('默认档，柔和但能感知到呼吸感。'), findsNothing);
      expect(find.text('上浮更明显，转场戏剧性更强。'), findsNothing);

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

  testWidgets('sleep goal slider expands and collapses from the settings row', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpRouteApp(tester, AppRoutes.profileSettings);
    await _scrollToSleepPreferences(tester);

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('目标睡眠时长'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showFirst,
    );

    await tester.tap(find.text('目标睡眠时长'));
    await tester.pump();

    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showSecond,
    );

    await tester.tap(find.text('目标睡眠时长'));
    await tester.pump();

    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showFirst,
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  await _pumpRouteApp(tester, initialLocation);
}

Future<void> _scrollToSleepPreferences(WidgetTester tester) async {
  await tester.ensureVisible(find.text('睡眠偏好'));
  await tester.pumpAndSettle();
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

Future<void> _openConversationFlow(WidgetTester tester) async {
  final Finder viewport = find.byKey(
    const ValueKey<String>('assistant-stage-viewport'),
  );
  expect(
    find.byKey(const ValueKey<String>('assistant-stage-pull-zone')),
    findsOneWidget,
  );

  final TestGesture revealHintGesture = await tester.startGesture(
    _assistantViewportTopPullStart(tester, viewport),
  );
  await revealHintGesture.moveBy(const Offset(0, 54));
  await tester.pump();
  await revealHintGesture.up();
  await tester.pump(const Duration(milliseconds: 220));
  expect(
    find.byKey(const ValueKey<String>('assistant-history-hint')),
    findsOneWidget,
  );
  await _pumpAssistantFrames(tester);

  final TestGesture expandGesture = await tester.startGesture(
    _assistantViewportTopPullStart(tester, viewport),
  );
  await expandGesture.moveBy(const Offset(0, 180));
  await tester.pump();
  await expandGesture.up();
  await _pumpAssistantFrames(tester);
}

Offset _assistantViewportTopPullStart(WidgetTester tester, Finder viewport) {
  final Finder pullZone = find.byKey(
    const ValueKey<String>('assistant-stage-pull-zone'),
  );
  if (pullZone.evaluate().isNotEmpty) {
    final Rect pullZoneRect = tester.getRect(pullZone);
    return Offset(
      pullZoneRect.center.dx,
      pullZoneRect.top + (pullZoneRect.height * 0.5),
    );
  }
  final Rect rect = tester.getRect(viewport);
  return Offset(rect.center.dx, rect.top + (rect.height * 0.16));
}

Future<void> _pumpAssistantFrames(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 160));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 1000));
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

double _effectiveAncestorOpacity(WidgetTester tester, Finder finder) {
  final List<Opacity> opacities = tester
      .widgetList<Opacity>(
        find.ancestor(of: finder, matching: find.byType(Opacity)),
      )
      .toList(growable: false);
  if (opacities.isEmpty) {
    return 1;
  }
  return opacities.map((Opacity opacity) => opacity.opacity).reduce(math.min);
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

Iterable<String?> get _platformHapticTypes => _platformMethodCalls
    .where((MethodCall call) => call.method == 'HapticFeedback.vibrate')
    .map((MethodCall call) => call.arguments as String?);

DateTime _dayClock() => DateTime(2026, 4, 5, 14);

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const MethodChannel _platformChannel = SystemChannels.platform;
final Map<String, String> _mockSecureStorage = <String, String>{};
final List<MethodCall> _platformMethodCalls = <MethodCall>[];
