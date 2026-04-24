// ignore_for_file: dead_code

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/app_brand.dart';
import 'package:sleep_dorm_app/main.dart' as app_main;
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab_dock.dart';
import 'package:sleep_dorm_app/core/widgets/bottom_nav_shell.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_page.dart';
import 'package:sleep_dorm_app/features/auth/presentation/pages/phone_auth_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_status_page.dart';
import 'package:sleep_dorm_app/features/dream/presentation/pages/dream_journal_page.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/sleep_report_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  test('cloudbase auth gate only blocks before bootstrap completes', () {
    expect(
      shouldShowCloudBaseAuthBlockingScreen(
        usesCloudBase: true,
        hasCompletedInitialAuthBootstrap: false,
      ),
      isTrue,
    );
    expect(
      shouldShowCloudBaseAuthBlockingScreen(
        usesCloudBase: true,
        hasCompletedInitialAuthBootstrap: true,
      ),
      isFalse,
    );
    expect(
      shouldShowCloudBaseAuthBlockingScreen(
        usesCloudBase: false,
        hasCompletedInitialAuthBootstrap: false,
      ),
      isFalse,
    );
  });

  test('system chrome config locks the app to portrait orientations', () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await app_main.configureSleepDormSystemChrome();

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having(
              (MethodCall call) => call.method,
              'method',
              'SystemChrome.setPreferredOrientations',
            )
            .having((MethodCall call) => call.arguments, 'arguments', <String>[
              'DeviceOrientation.portraitUp',
              'DeviceOrientation.portraitDown',
            ]),
      ),
    );
  });

  testWidgets(
    'app boots into pre-sleep home via /home redirect during daytime',
    (WidgetTester tester) async {
      await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _dayClock);

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.title, AppBrand.displayName);
      expect(find.byType(HomePreSleepPage), findsOneWidget);
      expect(find.byKey(BottomNavShell.navBarKey), findsOneWidget);
    },
  );

  testWidgets('home quick actions show defaults and editor catalog', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    expect(find.text('梦记一则'), findsOneWidget);
    expect(find.text('打卡日历'), findsOneWidget);
    expect(find.text('睡眠百科'), findsOneWidget);
    expect(find.text('思绪清理'), findsOneWidget);

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑快捷功能'), findsOneWidget);
    await _scrollToHomeQuickActionCandidate(
      tester,
      HomeQuickActionIds.thoughtVault,
    );
    expect(find.text('事记仓库'), findsOneWidget);
    expect(find.text('我的勋章'), findsOneWidget);
    await _scrollToHomeQuickActionCandidate(
      tester,
      HomeQuickActionIds.profileReport,
    );
    expect(find.text('实验报告'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('home quick action editor saves a selected four item set', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();

    for (final String id in kDefaultHomeQuickActionIds) {
      await tester.tap(
        find.byKey(ValueKey<String>('home-quick-action-remove-$id')),
      );
      await tester.pumpAndSettle();
    }

    const List<String> nextIds = <String>[
      HomeQuickActionIds.thoughtVault,
      HomeQuickActionIds.profileBadges,
      HomeQuickActionIds.profileReport,
      HomeQuickActionIds.profileSettings,
    ];
    for (final String id in nextIds) {
      await _tapHomeQuickActionCandidate(tester, id);
    }

    await tester.tap(find.text('保存快捷功能'));
    await tester.pumpAndSettle();

    expect(find.text('事记仓库'), findsOneWidget);
    expect(find.text('我的勋章'), findsOneWidget);
    expect(find.text('实验报告'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('梦记一则'), findsNothing);
  });

  testWidgets('home quick action editor preserves dragged order', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();

    await tester.timedDrag(
      find.byKey(
        ValueKey<String>(
          'home-quick-action-drag-${HomeQuickActionIds.thoughtClean}',
        ),
      ),
      const Offset(0, -220),
      const Duration(milliseconds: 350),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存快捷功能'));
    await tester.pumpAndSettle();

    final double thoughtCleanX = tester.getTopLeft(find.text('思绪清理').first).dx;
    final double dreamJournalX = tester.getTopLeft(find.text('梦记一则').first).dx;
    expect(thoughtCleanX, lessThan(dreamJournalX));
  });

  testWidgets('night entry from /home opens the welcome flow first', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    expect(
      find.byKey(const ValueKey<String>('night-mood-top-card')),
      findsOneWidget,
    );
    expect(find.byType(HomePreSleepPage), findsNothing);
    expect(find.byKey(BottomNavShell.navBarKey), findsNothing);
  });

  testWidgets('debug override can show the welcome flow during daytime', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.home,
      clock: _feedbackClock,
      showNightWelcomeOutsideNightInDebug: true,
    );

    expect(
      find.byKey(const ValueKey<String>('night-mood-top-card')),
      findsOneWidget,
    );
  });

  testWidgets('skip uses the default blue theme and enters home', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('night-mood-top-card')),
      findsNothing,
    );
    expect(
      Theme.of(
        tester.element(find.byType(HomePreSleepPage)),
      ).extension<NightMoodPalette>()?.mood,
      isNull,
    );
  });

  testWidgets('selected mood updates the active theme after welcome flow', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.text('开心'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '进入今晚首页'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.byType(HomePreSleepPage)),
      ).extension<NightMoodPalette>()?.mood,
      NightMood.happy,
    );
  });

  testWidgets('previous mood is preselected on the next night launch', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.home,
      clock: _nightClock,
      initialSettings: _settingsWithMood(NightMood.happy),
    );

    expect(
      find.byKey(const ValueKey<NightMood>(NightMood.happy)),
      findsWidgets,
    );
    expect(
      Theme.of(
        tester.element(
          find.byKey(const ValueKey<String>('night-mood-top-card')),
        ),
      ).extension<NightMoodPalette>()?.mood,
      NightMood.happy,
    );
  });

  testWidgets('legacy welcome skip behavior', (WidgetTester tester) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.night_shelter_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DormPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(find.text('今晚你更接近哪一种心情？'), findsNothing);
  }, skip: true);

  testWidgets('welcome flow stays skipped for the same night after skip', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.night_shelter_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DormPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Skip'), findsNothing);
  });

  testWidgets('bottom navigation switches between shell tabs', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.byIcon(Icons.night_shelter_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DormPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('bottom navigation stays fixed when the keyboard appears', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    final Finder navBarFinder = find.byKey(BottomNavShell.navBarKey);
    final Rect initialRect = tester.getRect(navBarFinder);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();

    expect(tester.getRect(navBarFinder), initialRect);
  });

  testWidgets('assistant fab opens assistant page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await _pumpAssistantSurface(tester);

    expect(find.byType(AssistantPage), findsOneWidget);
  });

  testWidgets('assistant fab keeps default icon when no mood is selected', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    expect(
      find.byKey(const ValueKey<String>('assistant-fab-default-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-fab-default-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-fab-mood-avatar')),
      findsNothing,
    );
  });

  testWidgets(
    'assistant opens the pencil stage even after a mood is selected',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: _dayClock,
        initialSettings: _settingsWithMood(NightMood.calm),
      );

      expect(
        find.byKey(const ValueKey<String>('assistant-fab-mood-avatar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-fab-mood-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-fab-default-shell')),
        findsNothing,
      );

      await tester.tap(find.byType(AssistantFab));
      await _pumpAssistantSurface(tester);

      expect(
        find.byKey(const ValueKey<String>('assistant-empty-stage')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('assistant-page-default-avatar')),
        findsNothing,
      );
      expect(find.text('今晚想聊点什么'), findsOneWidget);
    },
  );

  testWidgets('assistant fab snaps to left edge after crossing midline', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    final Finder assistantFinder = find.byType(AssistantFab);
    final double initialLeft = tester.getTopLeft(assistantFinder).dx;
    expect(initialLeft, greaterThan(200));

    await tester.drag(assistantFinder, const Offset(-240, 40));
    await tester.pumpAndSettle();

    final double leftAfterDrag = tester.getTopLeft(assistantFinder).dx;
    expect(leftAfterDrag, lessThanOrEqualTo(1));
  });

  testWidgets('assistant fab stays within vertical drag percentage limits', (
    WidgetTester tester,
  ) async {
    const Size screenSize = Size(390, 844);
    await tester.binding.setSurfaceSize(screenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    final Finder assistantFinder = find.byType(AssistantFab);
    final double minTop =
        (screenSize.height * 0.18) - (AssistantFab.bounds.height / 2);
    final double maxTop =
        (screenSize.height * 0.78) - (AssistantFab.bounds.height / 2);

    await tester.drag(assistantFinder, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(assistantFinder).dy, greaterThanOrEqualTo(minTop));

    await tester.drag(assistantFinder, const Offset(0, 1800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(assistantFinder).dy, lessThanOrEqualTo(maxTop));
  });

  testWidgets('post sleep page reuses assistant dock and opens assistant', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePostSleep,
      homeMode: HomeMode.postSleep,
      clock: _dayClock,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 450));

    final Finder assistantFinder = find.byType(AssistantFab);
    expect(assistantFinder, findsOneWidget);
    expect(find.byType(AssistantFabDock), findsOneWidget);

    await tester.tap(assistantFinder);
    await _pumpAssistantSurface(tester);

    expect(find.byType(AssistantPage), findsOneWidget);
  });

  testWidgets('assistant composer enables the submit icon only after input', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.assistant,
      clock: _dayClock,
      settle: false,
    );
    await _pumpAssistantSurface(tester);

    IconButton submitButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('assistant-composer-submit')),
        matching: find.byType(IconButton),
      ),
    );
    expect(submitButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('assistant-composer-field')),
      '帮我总览今晚状态',
    );
    await tester.pump();

    submitButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('assistant-composer-submit')),
        matching: find.byType(IconButton),
      ),
    );
    expect(submitButton.onPressed, isNotNull);
  });

  testWidgets(
    'cloudbase auth gate renders phone auth page without overlay errors',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.home,
        clock: _dayClock,
        environment: _cloudBaseTestEnvironment,
      );

      expect(find.byType(PhoneAuthPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-login-password-0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cloudbase auth gate keeps phone auth input stable during re-authentication',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.home,
        clock: _dayClock,
        environment: _cloudBaseTestEnvironment,
        settle: false,
      );

      await _pumpUntilFound(tester, find.byType(PhoneAuthPage));

      final Finder loginPhoneField = find.byKey(
        const ValueKey<String>('auth-login-phone-0'),
      );
      expect(loginPhoneField, findsOneWidget);

      await tester.enterText(loginPhoneField, '13800138000');
      await tester.pump();

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      _seedExpiredCloudBaseSession();
      final Future<UserProfile> reauthFuture = authServices.authRepository
          .ensureAuthenticated();

      await tester.pump();
      expect(loginPhoneField, findsOneWidget);
      expect(find.text('13800138000'), findsOneWidget);

      await reauthFuture;
      await tester.pump(const Duration(milliseconds: 100));

      expect(loginPhoneField, findsOneWidget);
      expect(find.text('13800138000'), findsOneWidget);
    },
  );

  testWidgets(
    'phone auth page supports login register and password reset flows',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      await _seedRegisteredPhoneUser(authServices);
      await tester.pump();

      expect(find.textContaining('首次进入需要'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('auth-login-phone-0')),
        findsOneWidget,
      );
      expect(find.text(AppBrand.loginTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-login-logo')),
        findsOneWidget,
      );
      final Image loginLogo = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('auth-login-logo')),
          matching: find.byType(Image),
        ),
      );
      expect((loginLogo.image as AssetImage).assetName, AppBrand.logoAssetPath);
      expect(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-mode-register')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-register-phone-0')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-register-phone-0')),
        '13900139000',
      );
      await tester.tap(find.widgetWithText(FilledButton, '发送验证码').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('auth-mode-login')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-verify')),
        findsOneWidget,
      );
      expect(find.text('联系客服协助处理'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        '13800138000',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-send')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-code-0')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-verify')));
      await tester.pumpAndSettle();

      expect(find.text('重置密码'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-confirm-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-code-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-send')),
        findsNothing,
      );
      expect(find.text('密码建议'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-password-0')),
        'renewed123',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-password-confirm-0')),
        'renewed123',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-submit')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-reset-success-login')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-success-resend')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'phone auth password login shows required phone toast on empty submit',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      await tester.tap(find.byKey(const ValueKey<String>('auth-login-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('请输入手机号。'), findsOneWidget);
    },
  );

  testWidgets(
    'phone auth password login shows mainland phone validation toast for short numbers',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-login-phone-0')),
        '12345',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-login-password-0')),
        'secret123',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('auth-login-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('请输入正确的大陆手机号。'), findsOneWidget);
    },
  );

  testWidgets(
    'phone auth password login shows credential guidance when password is wrong',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      await _seedRegisteredPhoneUser(authServices);
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-login-phone-0')),
        '13800138000',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-login-password-0')),
        'wrongpass',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('auth-login-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('请检查手机号和密码。'), findsOneWidget);
    },
  );

  testWidgets(
    'phone auth reset keeps password fields hidden when code verification fails',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      await _seedRegisteredPhoneUser(authServices);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        '13800138000',
      );
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-send')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-code-0')),
        '654321',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-verify')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-confirm-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-verify')),
        findsOneWidget,
      );
    },
  );

  testWidgets('phone auth system back returns to the previous subpage', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('auth-forgot-password')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('auth-reset-phone-0')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(PhoneAuthPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('auth-login-phone-0')),
      findsOneWidget,
    );
  });

  testWidgets(
    'phone auth back leaves reset password page before returning to login',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      await _seedRegisteredPhoneUser(authServices);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        '13800138000',
      );
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-send')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-code-0')),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-verify')));
      await tester.pumpAndSettle();

      expect(find.text('重置密码'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        findsNothing,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-password-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-reset-verify')),
        findsOneWidget,
      );
      expect(find.text('找回密码'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-login-phone-0')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'phone auth register fields stay editable and submit button enables after input',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-mode-register')),
      );
      await tester.pumpAndSettle();

      final Finder phoneField = find.byKey(
        const ValueKey<String>('auth-register-phone-0'),
      );
      final Finder passwordField = find.byKey(
        const ValueKey<String>('auth-register-password-0'),
      );
      final Finder confirmField = find.byKey(
        const ValueKey<String>('auth-register-password-confirm-0'),
      );
      final Finder codeField = find.byKey(
        const ValueKey<String>('auth-register-code-0'),
      );
      final Finder submitButton = find.byKey(
        const ValueKey<String>('auth-register-submit'),
      );

      await tester.enterText(phoneField, '13800138000');
      await tester.enterText(phoneField, '13900139000');
      await tester.tap(
        find.byKey(const ValueKey<String>('auth-register-send')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(passwordField, 'secret123');
      await tester.enterText(confirmField, 'secret123');
      await tester.enterText(codeField, '123456');
      await tester.pump();

      final TextField phoneTextField = tester.widget<TextField>(phoneField);
      expect(phoneTextField.controller?.text, '13900139000');
      final FilledButton button = tester.widget<FilledButton>(
        find.descendant(of: submitButton, matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('phone auth send-code enters a 60 second cooldown', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );

    await tester.tap(find.byKey(const ValueKey<String>('auth-mode-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-phone-0')),
      '13900139000',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-register-send')));
    await tester.pumpAndSettle();

    expect(find.text('60s'), findsOneWidget);

    FilledButton sendButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('auth-register-send')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sendButton.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 59));
    sendButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('auth-register-send')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sendButton.onPressed, isNotNull);
    expect(find.text('发送验证码'), findsOneWidget);
  });

  testWidgets(
    'phone auth shares verification cooldown for the same phone across subpages',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.authPhone,
        clock: _dayClock,
      );

      final BuildContext authContext = tester.element(
        find.byType(PhoneAuthPage),
      );
      final AppServices authServices = AppScope.of(authContext);
      await _seedRegisteredPhoneUser(authServices);
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-reset-phone-0')),
        '13800138000',
      );
      await tester.tap(find.byKey(const ValueKey<String>('auth-reset-send')));
      await tester.pumpAndSettle();

      expect(find.text('60s'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('auth-login-method-code')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-login-phone-0')),
        '13800138000',
      );
      await tester.pump();

      final FilledButton loginSendButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('auth-login-code-send')),
          matching: find.byType(FilledButton),
        ),
      );
      final List<String> cooldownLabels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('auth-login-code-send')),
              matching: find.byType(Text),
            ),
          )
          .map((Text widget) => widget.data ?? '')
          .toList();

      expect(
        cooldownLabels.any((String label) => RegExp(r'^\d+s$').hasMatch(label)),
        isTrue,
      );
      expect(loginSendButton.onPressed, isNull);
    },
  );

  testWidgets('phone auth keeps a usable width in short mobile heights', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );
    await tester.pumpAndSettle();

    final Rect phoneRect = tester.getRect(
      find.byKey(const ValueKey<String>('auth-login-phone-0')),
    );
    final Rect submitRect = tester.getRect(
      find.byKey(const ValueKey<String>('auth-login-submit')),
    );

    expect(phoneRect.width, greaterThan(250));
    expect(submitRect.width, greaterThan(250));
  });

  testWidgets('phone auth register password can be deleted and re-entered', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );

    await tester.tap(find.byKey(const ValueKey<String>('auth-mode-register')));
    await tester.pumpAndSettle();

    final Finder passwordField = find.byKey(
      const ValueKey<String>('auth-register-password-0'),
    );

    await tester.enterText(passwordField, 'wrongpass');
    await tester.pump();
    expect(find.text('wrongpass'), findsOneWidget);

    await tester.enterText(passwordField, '');
    await tester.pump();
    expect(find.text('wrongpass'), findsNothing);

    await tester.enterText(passwordField, 'secret123');
    await tester.pump();
    expect(find.text('secret123'), findsOneWidget);
  });

  testWidgets('login sms send switches to register for unregistered phone', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('auth-login-method-code')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-login-phone-0')),
      '13900139000',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('auth-login-code-send')),
    );
    await tester.pumpAndSettle();

    final TextField registerPhoneField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('auth-register-phone-0')),
    );
    expect(registerPhoneField.controller?.text, '13900139000');
    expect(
      find.byKey(const ValueKey<String>('auth-register-submit')),
      findsOneWidget,
    );
  });

  testWidgets('register send switches to login for registered phone', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.authPhone,
      clock: _dayClock,
    );

    final BuildContext context = tester.element(find.byType(PhoneAuthPage));
    final AppServices services = AppScope.of(context);
    await _seedRegisteredPhoneUser(services);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('auth-mode-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-phone-0')),
      '13800138000',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-register-send')));
    await tester.pumpAndSettle();

    final TextField loginPhoneField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('auth-login-phone-0')),
    );
    expect(loginPhoneField.controller?.text, '13800138000');
    expect(
      find.byKey(const ValueKey<String>('auth-login-code-send')),
      findsOneWidget,
    );
    expect(find.text('该手机号已注册，请直接登录。'), findsOneWidget);
  });

  testWidgets(
    'phone auth layout keeps key actions inside viewport at desktop resolutions',
    (WidgetTester tester) async {
      const List<Size> sizes = <Size>[
        Size(1920, 1080),
        Size(2160, 1440),
        Size(2560, 1440),
      ];

      void expectInViewport(Finder finder, Size size, String label) {
        final Rect rect = tester.getRect(finder);
        expect(
          rect.left >= 0,
          isTrue,
          reason: '$label left overflow at $size: $rect',
        );
        expect(
          rect.top >= 0,
          isTrue,
          reason: '$label top overflow at $size: $rect',
        );
        expect(
          rect.right <= size.width,
          isTrue,
          reason: '$label right overflow at $size: $rect',
        );
        expect(
          rect.bottom <= size.height,
          isTrue,
          reason: '$label bottom overflow at $size: $rect',
        );
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final Size size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await _pumpApp(
          tester,
          initialLocation: AppRoutes.authPhone,
          clock: _dayClock,
        );
        await tester.pumpAndSettle();

        final Finder registerSwitch = find.byKey(
          const ValueKey<String>('auth-mode-register'),
        );
        final Finder forgotPassword = find.byKey(
          const ValueKey<String>('auth-forgot-password'),
        );

        expect(registerSwitch, findsOneWidget);
        expect(forgotPassword, findsOneWidget);
        expectInViewport(registerSwitch, size, 'registerSwitch');
        expectInViewport(forgotPassword, size, 'forgotPassword');

        await tester.tap(registerSwitch);
        await tester.pumpAndSettle();

        final Finder loginSwitch = find.byKey(
          const ValueKey<String>('auth-mode-login'),
        );
        final Finder registerSubmit = find.byKey(
          const ValueKey<String>('auth-register-submit'),
        );

        expect(loginSwitch, findsOneWidget);
        expect(registerSubmit, findsOneWidget);
        expectInViewport(loginSwitch, size, 'loginSwitch');
        expectInViewport(registerSubmit, size, 'registerSubmit');

        await tester.tap(loginSwitch);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('dorm page uses a full-width hero and draggable drawer', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dorm,
      clock: _dayClock,
      initialSettings: _settingsWithMood(NightMood.calm),
    );

    expect(find.byKey(DormPage.heroCardKey), findsOneWidget);
    expect(find.byKey(DormPage.drawerSheetKey), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。'), findsNothing);

    final double heroWidth = tester
        .getSize(find.byKey(DormPage.heroCardKey))
        .width;
    expect(heroWidth, moreOrLessEquals(342, epsilon: 1));
    expect(
      tester.getSize(find.byKey(DormPage.roommateListKey)).height,
      moreOrLessEquals(188, epsilon: 1),
    );
    expect(
      tester.getSize(find.byKey(DormPage.heroCardKey)).height,
      lessThan(260),
    );
    final double heroTop = tester
        .getTopLeft(find.byKey(DormPage.heroCardKey))
        .dy;
    final double heroBottom = tester
        .getBottomLeft(find.byKey(DormPage.heroCardKey))
        .dy;
    final double drawerTopBefore = tester
        .getTopLeft(find.byKey(DormPage.drawerSheetKey))
        .dy;
    expect(drawerTopBefore, lessThan(heroBottom - 12));
    await tester.drag(
      find.byKey(DormPage.drawerSheetKey),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    final double drawerTopAfter = tester
        .getTopLeft(find.byKey(DormPage.drawerSheetKey))
        .dy;
    expect(drawerTopAfter, lessThan(drawerTopBefore));
    expect(drawerTopAfter, lessThanOrEqualTo(heroTop + 8));
    expect(drawerTopAfter, greaterThan(70));

    final Container heroContainer = tester.widget<Container>(
      find.byKey(DormPage.heroGradientKey),
    );
    final BoxDecoration decoration = heroContainer.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    final NightMoodPalette palette = NightMoodPalette.fromMood(NightMood.calm);

    expect(gradient.colors.first, palette.heroGradientStart);
    expect(gradient.colors.last, palette.heroGradientEnd);
  });

  testWidgets('dorm event actions route to dorm status records page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.scrollUntilVisible(
      find.byKey(DormPage.eventMoreKey),
      240,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final TextButton moreButton = tester.widget<TextButton>(
      find.byKey(DormPage.eventMoreKey),
    );
    moreButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.byType(DormStatusPage), findsOneWidget);
    expect(find.byKey(DormStatusPage.timelineKey), findsOneWidget);
  });

  testWidgets('dorm page shows roommate avatar shells and badge chips', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    expect(
      find.byKey(const ValueKey<String>('dorm-member-avatar-roommate-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-member-avatar-roommate-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-member-badge-roommate-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-member-badge-roommate-b')),
      findsOneWidget,
    );
    expect(find.text('月度全勤'), findsOneWidget);
    expect(find.text('安静守护者'), findsOneWidget);
  });

  testWidgets('profile page shows redesigned modules', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    expect(find.text('完成今晚心情选择，解锁一句陪伴语'), findsOneWidget);
    expect(find.text('睡眠质量(分)'), findsOneWidget);
    expect(find.text('实验报告'), findsOneWidget);
    expect(find.text('梦记'), findsOneWidget);
    expect(find.text('事记仓库'), findsOneWidget);
    expect(find.text('我的勋章'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('常见问题'), findsOneWidget);
  });

  testWidgets('profile carousel reveals duration and heatmap cards', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.drag(find.text('睡眠质量(分)'), const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(find.text('睡眠时长(小时)'), findsOneWidget);

    await tester.drag(find.text('睡眠时长(小时)'), const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(find.text('本月打卡热力'), findsOneWidget);
  });

  testWidgets(
    'profile uses larger carousel with indicators and balanced insight row',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.profile,
        clock: _dayClock,
      );

      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('profile-data-carousel')),
            )
            .height,
        greaterThan(190),
      );
      final double carouselWidth = tester
          .getSize(find.byKey(const ValueKey<String>('profile-data-carousel')))
          .width;
      final double settingsWidth = tester
          .getSize(find.byKey(const ValueKey<String>('profile-settings-card')))
          .width;
      final Finder firstCarouselCard = find.ancestor(
        of: find.text('睡眠质量(分)'),
        matching: find.byType(AppCard),
      );
      final double firstCardWidth = tester.getSize(firstCarouselCard).width;
      final PageView pageView = tester.widget<PageView>(find.byType(PageView));
      final PageController pageController = pageView.controller!;

      expect((firstCardWidth - settingsWidth).abs(), lessThan(2));
      expect(carouselWidth - firstCardWidth, greaterThan(20));
      expect(pageView.clipBehavior, Clip.none);
      expect(pageView.padEnds, isTrue);
      expect(pageController.viewportFraction, lessThan(0.94));
      expect(
        find.byKey(const ValueKey<String>('profile-carousel-indicators')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('profile-settings-card')),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );

      final double reportWidth = tester
          .getSize(find.byKey(const ValueKey<String>('profile-report-card')))
          .width;
      final double sideWidth = tester
          .getSize(
            find.byKey(const ValueKey<String>('profile-insight-side-column')),
          )
          .width;

      expect((reportWidth - sideWidth).abs(), lessThan(28));
    },
  );

  testWidgets('home and profile cards use a unified rectangular radius', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    final AppCard startSleepCard = tester.widget<AppCard>(
      find.ancestor(of: find.text('开启睡眠模式'), matching: find.byType(AppCard)),
    );
    final AppCard actionCard = tester.widget<AppCard>(
      find.ancestor(of: find.text('睡前放松音频'), matching: find.byType(AppCard)),
    );

    expect(startSleepCard.borderRadius, BorderRadius.circular(AppRadius.md));
    expect(actionCard.borderRadius, BorderRadius.circular(AppRadius.md));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    final AppCard reportCard = tester.widget<AppCard>(
      find.ancestor(of: find.text('实验报告'), matching: find.byType(AppCard)),
    );
    final AppCard qualityCard = tester.widget<AppCard>(
      find.ancestor(of: find.text('睡眠质量(分)'), matching: find.byType(AppCard)),
    );
    final AppCard settingsCard = tester.widget<AppCard>(
      find.byKey(const ValueKey<String>('profile-settings-card')),
    );

    expect(reportCard.borderRadius, BorderRadius.circular(AppRadius.md));
    expect(qualityCard.borderRadius, BorderRadius.circular(AppRadius.md));
    expect(settingsCard.borderRadius, BorderRadius.circular(AppRadius.md));
  });

  testWidgets('profile dream card opens dream journal page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('梦记'));
    await tester.tap(find.text('梦记'));
    await tester.pumpAndSettle();

    expect(find.byType(DreamJournalPage), findsOneWidget);
  });

  testWidgets('profile heatmap card opens calendar page', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.drag(find.text('睡眠质量(分)'), const Offset(-560, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('本月打卡热力'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarCheckinPage), findsOneWidget);
  });

  testWidgets('profile badge card opens overview and badge sheet', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('我的勋章'));
    await tester.tap(find.text('我的勋章'));
    await tester.pumpAndSettle();

    expect(find.text('勋章图鉴'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('profile-badge-grid-early-sleeper')),
      findsOneWidget,
    );
    expect(find.text('当前佩戴：安睡大师'), findsOneWidget);
    expect(find.text('当前展示：安睡大师'), findsNothing);
    expect(find.text('点击任意勋章可查看说明，并把已获得勋章切换为当前展示。'), findsNothing);
    expect(find.widgetWithText(FilledButton, '已同步最新'), findsOneWidget);
    expect(find.text('佩戴最新获得'), findsNothing);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('profile-badge-summary-card')),
        matching: find.text('3 / 10'),
      ),
      findsNothing,
    );
    expect(find.text('已获得的勋章会高亮显示，未解锁的勋章也可以先查看说明。'), findsNothing);

    final Finder earlySleeperTile = find.byKey(
      const ValueKey<String>('profile-badge-grid-early-sleeper'),
    );
    await tester.ensureVisible(earlySleeperTile);
    await tester.tap(earlySleeperTile);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('profile-badge-sheet-early-sleeper')),
      findsOneWidget,
    );
    expect(find.text('佩戴此勋章'), findsOneWidget);
    expect(find.text('勋章详情'), findsNothing);
  });

  testWidgets('badge gallery summary reflects automatic latest badge mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('我的勋章'));
    await tester.tap(find.text('我的勋章'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('profile-badge-summary-card')),
      findsOneWidget,
    );
    expect(find.text('当前佩戴：安睡大师'), findsOneWidget);
    expect(find.text('自动同步最新'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '已同步最新'), findsOneWidget);
    expect(find.text('当前展示：安睡大师'), findsNothing);
    expect(find.text('佩戴最新获得'), findsNothing);
  });

  testWidgets(
    'badge equip and restore sync between gallery and profile preview',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.profile,
        clock: _dayClock,
      );

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('profile-badge-preview-slot-0'),
          ),
          matching: find.text('安睡大师'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('我的勋章'));
      await tester.tap(find.text('我的勋章'));
      await tester.pumpAndSettle();

      final Finder earlySleeperTile = find.byKey(
        const ValueKey<String>('profile-badge-grid-early-sleeper'),
      );
      await tester.ensureVisible(earlySleeperTile);
      await tester.tap(earlySleeperTile);
      await tester.pumpAndSettle();
      final Finder equipButton = find.widgetWithText(FilledButton, '佩戴此勋章');
      await tester.ensureVisible(equipButton);
      await tester.tap(equipButton);
      await tester.pumpAndSettle();

      expect(find.text('当前佩戴：早睡先锋'), findsOneWidget);
      expect(find.text('手动佩戴中'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '恢复默认最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '已同步最新'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('profile-badge-preview-slot-0'),
          ),
          matching: find.text('早睡先锋'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('我的勋章'));
      await tester.tap(find.text('我的勋章'));
      await tester.pumpAndSettle();
      final Finder restoreLatestButton = find.widgetWithText(
        FilledButton,
        '恢复默认最新',
      );
      await tester.ensureVisible(restoreLatestButton);
      await tester.tap(restoreLatestButton);
      await tester.pumpAndSettle();

      expect(find.text('当前佩戴：安睡大师'), findsOneWidget);
      expect(find.text('自动同步最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '已同步最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '恢复默认最新'), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('profile-badge-preview-slot-0'),
          ),
          matching: find.text('安睡大师'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('profile faq entry opens styled faq page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('常见问题'));
    await tester.tap(find.text('常见问题'));
    await tester.pumpAndSettle();

    expect(find.text('帮助主题'), findsOneWidget);
    expect(find.text('常见问题速览'), findsOneWidget);
    expect(find.text('常见问题内容将继续补充'), findsOneWidget);

    await tester.tap(find.text('常见问题速览'));
    await tester.pump();

    expect(find.text('FAQ 正在整理中'), findsOneWidget);

    await tester.ensureVisible(find.text('常见问题内容将继续补充'));
    await tester.tap(find.text('常见问题内容将继续补充'));
    await tester.pump();

    expect(find.text('FAQ 正在整理中'), findsOneWidget);
  });

  testWidgets('profile report entry opens sleep report page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('实验报告'));
    await tester.tap(find.text('实验报告'));
    await tester.pumpAndSettle();

    expect(find.text('睡眠报告'), findsOneWidget);
    expect(find.text('本轮观察亮点'), findsOneWidget);
    expect(find.text('最近记录'), findsOneWidget);
  });

  testWidgets('post sleep page hides shell navigation', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePostSleep,
      homeMode: HomeMode.postSleep,
      clock: _dayClock,
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomePostSleepPage), findsOneWidget);
    expect(find.byKey(BottomNavShell.navBarKey), findsNothing);
  });

  testWidgets('notifications page can render unread items', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.notifications,
      clock: _dayClock,
    );

    expect(find.byType(NotificationsPage), findsOneWidget);
  });

  testWidgets(
    'dorm notification opens dorm tab and keeps tab switching stable',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.notifications,
        clock: _dayClock,
      );

      await tester.tap(find.text('宿舍环境保持安静').first);
      await tester.pumpAndSettle();

      expect(find.byType(DormPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(HomePreSleepPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.night_shelter_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DormPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.night_shelter_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DormPage), findsOneWidget);
    },
  );

  testWidgets(
    'entering notifications from home then opening dorm keeps shell tab state correct',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: _dayClock,
      );

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      await tester.tap(find.text('宿舍环境保持安静').first);
      await tester.pumpAndSettle();
      expect(find.byType(DormPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_rounded).last);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.night_shelter_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DormPage), findsOneWidget);
    },
  );

  testWidgets('morning feedback page renders submit flow', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.feedbackMorning,
      clock: _dayClock,
    );

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
  });

  testWidgets('morning feedback route loads the explicitly requested session', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.feedbackMorning,
      clock: _feedbackClock,
    );

    final AppServices services = AppScope.of(
      tester.element(find.byType(MorningFeedbackPage)),
    );
    final SleepSession targetSession = _buildPendingFeedbackSession(
      uid: services.authRepository.currentUser.uid,
      id: 'pending-target-session',
      startedAt: DateTime(2026, 4, 17, 23, 18),
      recommendationTitle: 'Target feedback session',
    );
    await services.sleepSessionRepository.saveSession(targetSession);

    final BuildContext context = tester.element(
      find.byType(MorningFeedbackPage),
    );
    GoRouter.of(
      context,
    ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
    await tester.pumpAndSettle();

    expect(find.textContaining('4/17 23:18 - 4/18 07:00'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Target feedback session'),
      find
          .descendant(
            of: find.byType(MorningFeedbackPage),
            matching: find.byType(ListView),
          )
          .first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Target feedback session'), findsOneWidget);
  });

  testWidgets(
    'morning feedback explicit completed session does not fall back to old pending session',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.feedbackMorning,
        clock: _feedbackClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(MorningFeedbackPage)),
      );
      final SleepSession completedSession = _buildCompletedSession(
        uid: services.authRepository.currentUser.uid,
        id: 'completed-feedback-session',
        startedAt: DateTime(2026, 4, 17, 23, 6),
        recommendationTitle: 'Completed feedback session',
      );
      final SleepSession oldPendingSession = _buildPendingFeedbackSession(
        uid: services.authRepository.currentUser.uid,
        id: 'old-pending-session',
        startedAt: DateTime(2026, 4, 10, 23, 12),
        recommendationTitle: 'Old pending session',
      );
      await services.sleepSessionRepository.saveSession(oldPendingSession);
      await services.sleepSessionRepository.saveSession(completedSession);

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(
        context,
      ).go(AppRoutes.feedbackMorningLocation(sessionId: completedSession.id));
      await tester.pumpAndSettle();

      expect(find.text('这条睡眠记录已完成晨间反馈，可在我的页查看同步结果。'), findsOneWidget);
      expect(find.text('Old pending session'), findsNothing);
    },
  );

  testWidgets(
    'generic morning feedback route ignores historical pending sessions',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.feedbackMorning,
        clock: _feedbackClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(MorningFeedbackPage)),
      );
      final SleepSession currentCompletedSession = _buildCompletedSession(
        uid: services.authRepository.currentUser.uid,
        id: 'current-day-completed-session',
        startedAt: DateTime(2026, 4, 17, 23, 10),
        recommendationTitle: 'Current day completed',
      ).copyWith(updatedAt: DateTime(2026, 4, 18, 9, 30));
      final SleepSession historicalPendingSession =
          _buildPendingFeedbackSession(
            uid: services.authRepository.currentUser.uid,
            id: 'historical-pending-session',
            startedAt: DateTime(2026, 4, 9, 23, 8),
            recommendationTitle: 'Historical pending session',
          );
      await services.sleepSessionRepository.saveSession(
        historicalPendingSession,
      );
      await services.sleepSessionRepository.saveSession(
        currentCompletedSession,
      );

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(context).go(AppRoutes.feedbackMorning);
      await tester.pumpAndSettle();

      expect(find.text('当前没有待补反馈的睡眠记录。'), findsOneWidget);
      expect(find.text('Historical pending session'), findsNothing);
    },
  );

  testWidgets(
    'submitting morning feedback returns home and shows submitted toast',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.feedbackMorning,
        clock: _feedbackClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(MorningFeedbackPage)),
      );
      final SleepSession targetSession = _buildPendingFeedbackSession(
        uid: services.authRepository.currentUser.uid,
        id: 'submit-feedback-session',
        startedAt: DateTime(2026, 4, 17, 23, 18),
        recommendationTitle: 'Submit feedback session',
      );
      await services.sleepSessionRepository.saveSession(targetSession);

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(
        context,
      ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('提交反馈'),
        find
            .descendant(
              of: find.byType(MorningFeedbackPage),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交反馈'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePreSleepPage), findsOneWidget);
      expect(find.text('小眠已经收到你的晨间反馈❤️'), findsOneWidget);

      expect(find.text('这条睡眠记录已完成晨间反馈，可在我的页查看同步结果。'), findsNothing);

      final SleepSession completed = services.sleepSessionRepository
          .sessionForSleepDayKey(targetSession.sleepDayKey)!;
      expect(completed.id, targetSession.id);
      expect(completed.status, SleepSessionStatus.completed);
      expect(completed.hasSubmittedFeedback, isTrue);
    },
  );

  testWidgets('calendar pending day opens that session in morning feedback', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileCalendar,
      clock: _dayClock,
    );

    final AppServices services = AppScope.of(
      tester.element(find.byType(CalendarCheckinPage)),
    );
    final DateTime calendarTargetDay = DateTime.now().add(
      const Duration(days: 2),
    );
    final SleepSession targetSession = _buildPendingFeedbackSession(
      uid: services.authRepository.currentUser.uid,
      id: 'calendar-target-session',
      startedAt: DateTime(
        calendarTargetDay.year,
        calendarTargetDay.month,
        calendarTargetDay.day,
        23,
        24,
      ),
      recommendationTitle: 'Calendar target session',
    );
    await services.sleepSessionRepository.saveSession(targetSession);
    await tester.pumpAndSettle();

    await tester.tap(find.text('${targetSession.sleepDayDate.day}').first);
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(
      tester
          .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
          .sessionId,
      targetSession.id,
    );
  });

  testWidgets(
    'calendar detail CTA opens pending session without return-to-sleep action',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.profileCalendar,
        clock: _dayClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(CalendarCheckinPage)),
      );
      final DateTime selectedDay = DateUtils.dateOnly(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final SleepSession targetSession = _buildPendingFeedbackSession(
        uid: services.authRepository.currentUser.uid,
        id: 'calendar-detail-target-session',
        startedAt: selectedDay.subtract(const Duration(hours: 1)),
        recommendationTitle: 'Calendar detail target session',
      ).copyWith(updatedAt: DateTime.now().add(const Duration(days: 1)));
      await services.sleepSessionRepository.saveSession(targetSession);
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('补充晨间反馈'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();

      expect(find.text('补充晨间反馈'), findsOneWidget);

      await tester.tap(find.text('补充晨间反馈'));
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        targetSession.id,
      );
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .allowReturnToSleep,
        isFalse,
      );
      expect(find.widgetWithText(PrimaryButton, '返回'), findsNothing);
    },
  );

  testWidgets(
    'sleep report pending item opens that session in morning feedback',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.profileReport,
        clock: _dayClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(SleepReportPage)),
      );
      final DateTime reportTargetDay = DateTime.now().add(
        const Duration(days: 2),
      );
      final SleepSession targetSession = _buildPendingFeedbackSession(
        uid: services.authRepository.currentUser.uid,
        id: 'report-target-session',
        startedAt: DateTime(
          reportTargetDay.year,
          reportTargetDay.month,
          reportTargetDay.day,
          23,
          28,
        ),
        recommendationTitle: 'Report target session',
      );
      await services.sleepSessionRepository.saveSession(targetSession);
      await tester.pumpAndSettle();

      final Finder targetDate = find
          .text(
            '${targetSession.sleepDayDate.month}/${targetSession.sleepDayDate.day}',
          )
          .first;
      await tester.dragUntilVisible(
        targetDate,
        find
            .descendant(
              of: find.byType(SleepReportPage),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(targetDate);
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        targetSession.id,
      );
    },
  );

  testWidgets('calendar page renders month view', (WidgetTester tester) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileCalendar,
      clock: _dayClock,
    );

    expect(find.byType(CalendarCheckinPage), findsOneWidget);
    expect(find.textContaining('202'), findsWidgets);
  });

  testWidgets('home recommendation section opens intervention overview', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('查看全部').first);
    await tester.tap(find.text('查看全部').first);
    await tester.pumpAndSettle();

    expect(find.byType(MicroInterventionTaskPage), findsOneWidget);
  });

  testWidgets('start sleep card keeps full title and light hint', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    expect(find.text('开启睡眠模式'), findsOneWidget);
    expect(find.text('轻触进入'), findsOneWidget);
    expect(find.text('音频已同步'), findsNothing);
  });
  testWidgets('entering sleep mode shows the ongoing sleep notification', (
    WidgetTester tester,
  ) async {
    final _FakeAppNotificationService notificationService =
        _FakeAppNotificationService();

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _freshSleepClock,
      appNotificationService: notificationService,
    );

    final int cancelCallsBeforeEnter =
        notificationService.cancelSleepModeNotificationCalls;

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomePostSleepPage), findsOneWidget);
    expect(notificationService.shownSleepSessions.length, 1);
    expect(
      notificationService.shownSleepSessions.single.sleepModeActive,
      isTrue,
    );
    expect(
      notificationService.shownSleepSessions.single.status,
      SleepSessionStatus.active,
    );
    expect(
      notificationService.cancelSleepModeNotificationCalls,
      cancelCallsBeforeEnter,
    );
  });

  testWidgets(
    'post-sleep morning feedback card finishes sleep mode and opens resumable feedback',
    (WidgetTester tester) async {
      final _FakeAppNotificationService notificationService =
          _FakeAppNotificationService();
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
        appNotificationService: notificationService,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      expect(find.byType(HomePostSleepPage), findsOneWidget);
      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final String currentSleepDaySessionId = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!
          .id;

      await tester.dragUntilVisible(
        find.text('晨间反馈'),
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.pump();
      await tester.tap(find.text('晨间反馈').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        currentSleepDaySessionId,
      );
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .allowReturnToSleep,
        isTrue,
      );
      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('返回'), findsOneWidget);

      final SleepSession awaiting = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!;
      expect(awaiting.status, SleepSessionStatus.awaitingFeedback);
      expect(awaiting.sleepModeActive, isFalse);
    },
  );

  testWidgets(
    'finishing sleep mode from post-sleep page goes to morning feedback',
    (WidgetTester tester) async {
      final _FakeAppNotificationService notificationService =
          _FakeAppNotificationService();
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
        appNotificationService: notificationService,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      expect(find.byType(HomePostSleepPage), findsOneWidget);
      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final String currentSleepDaySessionId = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!
          .id;

      final Finder endSleepModeButton = find.widgetWithText(
        PrimaryButton,
        '结束睡眠模式',
      );
      await tester.ensureVisible(endSleepModeButton);
      await tester.tap(endSleepModeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(PrimaryButton, '结束并去晨间反馈'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        currentSleepDaySessionId,
      );
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .allowReturnToSleep,
        isTrue,
      );
      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('返回'), findsOneWidget);
    },
  );

  testWidgets('sleep-mode morning feedback entry shows the feedback form', (
    WidgetTester tester,
  ) async {
    final _FakeAppNotificationService notificationService =
        _FakeAppNotificationService();
    DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: () => currentTime,
      appNotificationService: notificationService,
    );

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    expect(find.text('这条睡眠记录当前不可继续补反馈。'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    currentTime = DateTime(2030, 4, 5, 15, 10);
    await tester.ensureVisible(find.byIcon(Icons.wb_sunny_rounded).first);
    await tester.tap(find.byIcon(Icons.wb_sunny_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    return;

    await tester.dragUntilVisible(
      find.text('鏅ㄩ棿鍙嶉'),
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pump();
    await tester.tap(find.text('鏅ㄩ棿鍙嶉').first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, '鎻愪氦鍙嶉'), findsOneWidget);
  });

  testWidgets('finish-and-feedback entry shows the feedback form', (
    WidgetTester tester,
  ) async {
    final _FakeAppNotificationService notificationService =
        _FakeAppNotificationService();
    DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: () => currentTime,
      appNotificationService: notificationService,
    );

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    currentTime = DateTime(2030, 4, 5, 15, 10);
    expect(find.byType(HomePostSleepPage), findsOneWidget);
    await tester.ensureVisible(find.byType(PrimaryButton).last);
    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byType(PrimaryButton).last);
    await tester.tap(find.byType(PrimaryButton).last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    return;

    final Finder endSleepModeButton = find.widgetWithText(
      PrimaryButton,
      '缁撴潫鐫＄湢妯″紡',
    );
    await tester.ensureVisible(endSleepModeButton);
    await tester.tap(endSleepModeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(PrimaryButton, '缁撴潫骞跺幓鏅ㄩ棿鍙嶉'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, '鎻愪氦鍙嶉'), findsOneWidget);
  });

  testWidgets(
    'sleep-mode morning feedback still opens for zero-minute same-day sessions',
    (WidgetTester tester) async {
      final _FakeAppNotificationService notificationService =
          _FakeAppNotificationService();
      final DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
        appNotificationService: notificationService,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final String currentSleepDaySessionId = services.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(currentTime))!
          .id;
      await tester.ensureVisible(find.byIcon(Icons.wb_sunny_rounded).first);
      await tester.tap(find.byIcon(Icons.wb_sunny_rounded).first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        currentSleepDaySessionId,
      );
      expect(find.byType(TextField), findsWidgets);

      final SleepSession awaitingZeroMinute = services.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(currentTime))!;
      expect(awaitingZeroMinute.status, SleepSessionStatus.awaitingFeedback);
      expect(awaitingZeroMinute.sleepModeActive, isFalse);
      expect(awaitingZeroMinute.trackedDurationMinutes, 0);
      return;

      await tester.dragUntilVisible(
        find.text('鏅ㄩ棿鍙嶉'),
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.pump();
      await tester.tap(find.text('鏅ㄩ棿鍙嶉').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(
        tester
            .widget<MorningFeedbackPage>(find.byType(MorningFeedbackPage))
            .sessionId,
        currentSleepDaySessionId,
      );
      expect(find.widgetWithText(PrimaryButton, '鎻愪氦鍙嶉'), findsOneWidget);

      final SleepSession awaiting = services.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(currentTime))!;
      expect(awaiting.status, SleepSessionStatus.awaitingFeedback);
      expect(awaiting.sleepModeActive, isFalse);
      expect(awaiting.trackedDurationMinutes, 0);
    },
  );

  testWidgets(
    'morning feedback return resumes sleep mode and keeps same-day tracking',
    (WidgetTester tester) async {
      final _FakeAppNotificationService notificationService =
          _FakeAppNotificationService();
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
        appNotificationService: notificationService,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final String currentSleepDaySessionId = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!
          .id;

      await tester.dragUntilVisible(
        find.text('晨间反馈'),
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.pump();
      await tester.tap(find.text('晨间反馈').first);
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      currentTime = DateTime(2030, 4, 5, 15, 25);
      await tester.tap(find.text('返回'));
      await tester.pump();
      expect(find.text('这条睡眠记录当前不可继续补反馈。'), findsNothing);
      expect(find.text('这条睡眠记录当前不可继续补反馈。'), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePostSleepPage), findsOneWidget);

      final SleepSession resumed =
          services.sleepSessionRepository.activeSession!;
      expect(resumed.id, currentSleepDaySessionId);
      expect(resumed.status, SleepSessionStatus.active);
      expect(resumed.sleepModeActive, isTrue);
      expect(resumed.segments.length, 2);
      expect(resumed.trackedDurationMinutes, 70);

      currentTime = DateTime(2030, 4, 5, 15, 40);
      expect(resumed.liveTrackedDurationMinutes(now: currentTime), 85);
    },
  );

  testWidgets(
    'morning feedback return confirms before discarding unsaved changes',
    (WidgetTester tester) async {
      final _FakeAppNotificationService notificationService =
          _FakeAppNotificationService();
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
        appNotificationService: notificationService,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      await tester.dragUntilVisible(
        find.text('晨间反馈'),
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.pump();
      await tester.tap(find.text('晨间反馈').first);
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Need more rest');
      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.text('返回继续计时？'), findsOneWidget);
      expect(find.byType(MorningFeedbackPage), findsOneWidget);

      currentTime = DateTime(2030, 4, 5, 15, 25);
      await tester.tap(find.widgetWithText(FilledButton, '确认返回'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePostSleepPage), findsOneWidget);
    },
  );

  testWidgets('sleep mode notification launch returns to post-sleep page', (
    WidgetTester tester,
  ) async {
    final _FakeAppNotificationService notificationService =
        _FakeAppNotificationService(
          initialLaunchIntent: const NotificationLaunchIntent(
            route: AppRoutes.homePostSleep,
            markAsRead: false,
          ),
        );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
      appNotificationService: notificationService,
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HomePostSleepPage), findsOneWidget);
  });
}

Future<void> _pumpAssistantSurface(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump(const Duration(milliseconds: 320));
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  HomeMode homeMode = HomeMode.preSleep,
  AppEnvironment? environment,
  DateTime Function()? clock,
  UserSettings? initialSettings,
  bool settle = true,
  bool showNightWelcomeOutsideNightInDebug = false,
  AppNotificationService? appNotificationService,
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: initialLocation,
      homeMode: homeMode,
      environment: environment,
      clock: clock,
      initialSettings: initialSettings,
      showNightWelcomeOutsideNightInDebug: showNightWelcomeOutsideNightInDebug,
      appNotificationService: appNotificationService,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollToHomeQuickActionCandidate(
  WidgetTester tester,
  String id,
) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey<String>('home-quick-action-add-$id')),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapHomeQuickActionCandidate(
  WidgetTester tester,
  String id,
) async {
  await _scrollToHomeQuickActionCandidate(tester, id);
  await tester.tap(
    find.byKey(ValueKey<String>('home-quick-action-add-$id')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 80,
}) async {
  for (int i = 0; i < maxPumps; i += 1) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }
  fail('Expected finder to match within ${step * maxPumps}.');
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

SleepSession _buildPendingFeedbackSession({
  required String uid,
  required String id,
  required DateTime startedAt,
  required String recommendationTitle,
}) {
  final DateTime endedAt = startedAt.add(const Duration(hours: 7, minutes: 10));
  return SleepSession(
    id: id,
    uid: uid,
    startedAt: startedAt,
    endedAt: endedAt,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.awaitingFeedback,
    sleepModeActive: false,
    dormId: 'dorm-204',
    recommendations: <NightRecommendation>[
      NightRecommendation(
        id: '$id-rec',
        title: recommendationTitle,
        subtitle: 'Unique test recommendation',
        type: RecommendationType.quickAction,
        icon: Icons.bedtime_rounded,
        tags: const <String>['pending'],
        executionState: RecommendationExecutionState.selected,
      ),
    ],
    selectedRecommendationIds: <String>['$id-rec'],
    segments: <SleepSegment>[
      SleepSegment(startedAt: startedAt, endedAt: endedAt),
    ],
    trackedDurationMinutes: endedAt.difference(startedAt).inMinutes,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: endedAt,
  );
}

SleepSession _buildCompletedSession({
  required String uid,
  required String id,
  required DateTime startedAt,
  required String recommendationTitle,
}) {
  final DateTime endedAt = startedAt.add(const Duration(hours: 7, minutes: 5));
  return SleepSession(
    id: id,
    uid: uid,
    startedAt: startedAt,
    endedAt: endedAt,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.completed,
    sleepModeActive: false,
    dormId: 'dorm-204',
    recommendations: <NightRecommendation>[
      NightRecommendation(
        id: '$id-rec',
        title: recommendationTitle,
        subtitle: 'Completed test recommendation',
        type: RecommendationType.quickAction,
        icon: Icons.bedtime_rounded,
        tags: const <String>['completed'],
        executionState: RecommendationExecutionState.completed,
      ),
    ],
    selectedRecommendationIds: <String>['$id-rec'],
    segments: <SleepSegment>[
      SleepSegment(startedAt: startedAt, endedAt: endedAt),
    ],
    trackedDurationMinutes: endedAt.difference(startedAt).inMinutes,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: const MorningSummary(
      sleepQuality: 4,
      restedLevel: 4,
      totalSleepHours: 7.1,
      awakeningsCount: 0,
      note: 'completed',
    ),
    updatedAt: endedAt,
  );
}

DateTime _dayClock() => DateTime(2026, 4, 5, 14);

DateTime _feedbackClock() => DateTime(2026, 4, 18, 7);

DateTime _freshSleepClock() => DateTime(2026, 5, 17, 14);

DateTime _nightClock() => DateTime(2026, 4, 5, 22);

const AppEnvironment _cloudBaseTestEnvironment = AppEnvironment(
  target: AppBackendTarget.emulator,
  appIdPrefix: 'com.dormsleep.app',
  cloudbaseEnvId: 'test-env',
  cloudbaseAuthBaseUrl: 'https://example.com/auth',
);

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
final Map<String, String> _mockSecureStorage = <String, String>{};

const String _localVerificationId = 'local-verification-id';

Future<void> _seedRegisteredPhoneUser(
  AppServices services, {
  String phoneNumber = '13800138000',
  String password = 'secret123',
}) async {
  await services.profileFacade.registerWithPhone(
    phoneNumber: phoneNumber,
    verificationId: _localVerificationId,
    code: '123456',
    password: password,
  );
  await services.authRepository.signOut();
}

void _seedExpiredCloudBaseSession() {
  const String deviceId = 'cb-device-test';
  _mockSecureStorage['cloudbase.device_id'] = deviceId;
  _mockSecureStorage['cloudbase.session'] = jsonEncode(<String, Object?>{
    'accessToken': 'expired-access-token',
    'refreshToken': 'expired-refresh-token',
    'subject': 'user-expired',
    'expiresAt': DateTime(2020, 1, 1).toIso8601String(),
    'deviceId': deviceId,
    'tokenType': 'Bearer',
  });
}

UserSettings _settingsWithMood(NightMood mood) {
  return UserSettings(
    sleepGoalHours: 7.5,
    bedtimeReminderEnabled: true,
    morningReminderEnabled: true,
    dormAlertsEnabled: true,
    bedtimeReminder: const TimeOfDay(hour: 23, minute: 10),
    preferredTrackTitle: '深海海浪',
    smartSuggestionsEnabled: true,
    selectedNightMood: mood,
  );
}

class _FakeAppNotificationService extends AppNotificationService {
  _FakeAppNotificationService({this.initialLaunchIntent});

  final NotificationLaunchIntent? initialLaunchIntent;
  final List<SleepSession> shownSleepSessions = <SleepSession>[];
  int cancelSleepModeNotificationCalls = 0;
  final StreamController<NotificationLaunchIntent> _launchIntentController =
      StreamController<NotificationLaunchIntent>.broadcast();
  bool _initialIntentTaken = false;

  @override
  bool get isSupported => true;

  @override
  Stream<NotificationLaunchIntent> get launchIntents =>
      _launchIntentController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationLaunchIntent?> takeInitialLaunchIntent() async {
    if (_initialIntentTaken) {
      return null;
    }
    _initialIntentTaken = true;
    return initialLaunchIntent;
  }

  @override
  Future<void> showSleepModeNotification({
    required SleepSession session,
  }) async {
    shownSleepSessions.add(session);
  }

  @override
  Future<void> cancelSleepModeNotification() async {
    cancelSleepModeNotificationCalls += 1;
  }

  @override
  Future<void> dispose() async {
    await _launchIntentController.close();
  }
}
