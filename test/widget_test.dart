import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
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
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'app boots into pre-sleep home via /home redirect during daytime',
    (WidgetTester tester) async {
      await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _dayClock);

      expect(find.byType(HomePreSleepPage), findsOneWidget);
      expect(find.byKey(BottomNavShell.navBarKey), findsOneWidget);
    },
  );

  testWidgets('night entry from /home opens the welcome flow first', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    expect(find.text('今晚你更接近哪一种心情？'), findsOneWidget);
    expect(find.byType(HomePreSleepPage), findsNothing);
    expect(find.byKey(BottomNavShell.navBarKey), findsNothing);
  });

  testWidgets('debug override can show the welcome flow during daytime', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.home,
      clock: _dayClock,
      showNightWelcomeOutsideNightInDebug: true,
    );

    expect(find.text('今晚你更接近哪一种心情？'), findsOneWidget);
  });

  testWidgets('skip uses the default blue theme and enters home', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(find.text('今晚你更接近哪一种心情？'), findsNothing);
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

    expect(find.text('想把这份轻盈带进今晚'), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.text('今晚你更接近哪一种心情？')),
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

  testWidgets('welcome flow can show again after skip until completion', (
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

    expect(find.byType(HomePreSleepPage), findsNothing);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
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

  testWidgets('assistant fab opens assistant page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pumpAndSettle();

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

  testWidgets('assistant surfaces mood avatars after a mood is selected', (
    WidgetTester tester,
  ) async {
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
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('assistant-page-mood-avatar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-page-default-avatar')),
      findsNothing,
    );
  });

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
    await tester.pumpAndSettle();

    expect(find.byType(AssistantPage), findsOneWidget);
  });

  testWidgets(
    'assistant page provides holographic avatar and local text input',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.assistant,
        clock: _dayClock,
      );

      expect(
        find.byKey(const ValueKey<String>('assistant-page-default-avatar')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('和助手说点什么'), findsNothing);

      await tester.enterText(find.byType(TextField), '今晚宿舍有点吵');
      expect(find.text('今晚宿舍有点吵'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '发送'), findsOneWidget);
    },
  );

  testWidgets('assistant composer enables send only after input', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.assistant,
      clock: _dayClock,
    );

    FilledButton sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '发送'),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('assistant-composer-field')),
      '帮我总览今晚状态',
    );
    await tester.pump();

    sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '发送'),
    );
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets(
    'cloudbase auth gate renders phone auth page without overlay errors',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.home,
        clock: _dayClock,
        environment: const AppEnvironment(
          target: AppBackendTarget.emulator,
          appIdPrefix: 'com.dormsleep.app',
        ),
      );

      expect(find.byType(PhoneAuthPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('auth-login-password')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
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

      expect(find.textContaining('首次进入需要'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('auth-login-phone')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('auth-mode-register')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-register-phone')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('auth-register-phone')),
        '13800138000',
      );
      await tester.tap(find.widgetWithText(FilledButton, '发送验证码').first);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('auth-mode-login')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('auth-forgot-password')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('auth-reset-phone')),
        findsOneWidget,
      );
      expect(find.text('返回登录'), findsOneWidget);
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
        const ValueKey<String>('auth-register-phone'),
      );
      final Finder passwordField = find.byKey(
        const ValueKey<String>('auth-register-password'),
      );
      final Finder confirmField = find.byKey(
        const ValueKey<String>('auth-register-password-confirm'),
      );
      final Finder codeField = find.byKey(
        const ValueKey<String>('auth-register-code'),
      );
      final Finder submitButton = find.byKey(
        const ValueKey<String>('auth-register-submit'),
      );

      await tester.enterText(phoneField, '13800138000');
      await tester.enterText(phoneField, '13900139000');
      await tester.enterText(passwordField, 'secret123');
      await tester.enterText(confirmField, 'secret123');
      await tester.enterText(codeField, '123456');
      await tester.pump();

      expect(find.text('13900139000'), findsOneWidget);
      final PrimaryButton button = tester.widget<PrimaryButton>(submitButton);
      expect(button.onPressed, isNotNull);
    },
  );

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
      const ValueKey<String>('auth-register-password'),
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
      find.byKey(const ValueKey<String>('auth-login-phone')),
      '13900139000',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('auth-login-code-send')),
    );
    await tester.pumpAndSettle();

    final TextField registerPhoneField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('auth-register-phone')),
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
    await services.profileFacade.registerWithPhone(
      phoneNumber: '13800138000',
      verificationId: 'verification-id',
      code: '123456',
      password: 'secret123',
    );
    await services.authRepository.signOut();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('auth-mode-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-phone')),
      '13800138000',
    );
    await tester.tap(find.byKey(const ValueKey<String>('auth-register-send')));
    await tester.pumpAndSettle();

    final TextField loginPhoneField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('auth-login-phone')),
    );
    expect(loginPhoneField.controller?.text, '13800138000');
    expect(
      find.byKey(const ValueKey<String>('auth-login-code-send')),
      findsOneWidget,
    );
    expect(find.text('该手机号已注册，请直接登录。'), findsOneWidget);
  });

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

    expect(find.text('每天都是成长和积极改变的新机会。'), findsOneWidget);
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
      expect(carouselWidth - firstCardWidth, greaterThan(10));
      expect(pageView.clipBehavior, Clip.none);
      expect(pageView.padEnds, isTrue);
      expect(pageController.viewportFraction, lessThan(1));
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

  testWidgets('profile badge card opens overview and detail pages', (
    WidgetTester tester,
  ) async {
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
      find.byKey(const ValueKey<String>('profile-badge-strip-card-0')),
      findsOneWidget,
    );

    final Finder earlyBirdCardFinder = find.ancestor(
      of: find.text('早睡先锋'),
      matching: find.byType(AppCard),
    );
    expect(earlyBirdCardFinder, findsOneWidget);
    final AppCard earlyBirdCard = tester.widget<AppCard>(earlyBirdCardFinder);
    expect(earlyBirdCard.borderRadius, BorderRadius.circular(AppRadius.lg));
    expect(earlyBirdCard.padding, const EdgeInsets.all(16));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('profile-badge-strip-card-0')),
        matching: find.byIcon(Icons.east_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('早睡先锋'));
    await tester.pumpAndSettle();

    expect(find.text('勋章详情'), findsOneWidget);
  });

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

  testWidgets('profile report placeholder uses passive toast feedback', (
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

    expect(find.text('本页将逐步补全'), findsOneWidget);

    await tester.ensureVisible(find.text('报告页待补全'));
    await tester.tap(find.text('报告页待补全'));
    await tester.pump();

    expect(find.text('睡眠报告 正在整理中'), findsOneWidget);
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
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: initialLocation,
      homeMode: homeMode,
      environment: environment,
      clock: clock,
      initialSettings: initialSettings,
      showNightWelcomeOutsideNightInDebug: showNightWelcomeOutsideNightInDebug,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

DateTime _dayClock() => DateTime(2026, 4, 5, 14);

DateTime _nightClock() => DateTime(2026, 4, 5, 22);

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
