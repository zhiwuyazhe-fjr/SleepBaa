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
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_text_styles.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/data/in_memory_repositories.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/app_notification_service.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_detail_page_header.dart';
import 'package:sleep_dorm_app/core/widgets/app_message_record_card.dart';
import 'package:sleep_dorm_app/core/widgets/app_settings_group.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab_dock.dart';
import 'package:sleep_dorm_app/core/widgets/bottom_nav_shell.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_page.dart';
import 'package:sleep_dorm_app/features/auth/presentation/pages/phone_auth_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_current_status_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_member_detail_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_rules_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_status_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dream/presentation/pages/dream_journal_page.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_account_pages.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/sleep_report_page.dart';
import 'package:sleep_dorm_app/features/sleep/presentation/pages/cant_sleep_page.dart';

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

  test(
    'night mood palette uses new hero gradients and neutral dark surface',
    () {
      expect(AppColors.darkCard, const Color(0xFF1A1A1A));

      final Map<NightMood?, List<Color>> expectedHeroGradients =
          <NightMood?, List<Color>>{
            null: const <Color>[
              Color(0xFF8EDDF2),
              Color(0xFF8EDDF2),
              Color(0xFF8EDDF2),
            ],
            NightMood.happy: const <Color>[
              Color(0xFFFFA6C9),
              Color(0xFFF7B6D1),
              Color(0xFFB94C7E),
            ],
            NightMood.sad: const <Color>[
              Color(0xFFFF9A72),
              Color(0xFFF6B59A),
              Color(0xFFBE6B4A),
            ],
            NightMood.calm: const <Color>[
              Color(0xFF8DE0C2),
              Color(0xFFA8E5D1),
              Color(0xFF2C8E78),
            ],
          };

      for (final MapEntry<NightMood?, List<Color>> entry
          in expectedHeroGradients.entries) {
        final NightMoodPalette palette = NightMoodPalette.fromMood(entry.key);

        expect(
          <Color>[
            palette.heroGradientStart,
            palette.heroGradientMid,
            palette.heroGradientEnd,
          ],
          entry.value,
          reason: '${entry.key?.name ?? 'default'} hero gradient',
        );
        expect(
          palette.welcomeSurfaceColor,
          AppColors.darkSurface,
          reason: '${entry.key?.name ?? 'default'} welcome surface',
        );
      }
    },
  );

  test('app semantic colors expose tokenized home palette values', () {
    final NightMoodPalette calm = NightMoodPalette.fromMood(NightMood.calm);

    final AppSemanticColors light = AppSemanticColors.light(calm);
    expect(light.pageBackground, AppColors.background);
    expect(light.surface, AppColors.surface);
    expect(light.surfaceMuted, AppColors.surfaceMuted);
    expect(light.textPrimary, AppColors.textPrimary);
    expect(light.textSecondary, AppColors.textSecondary);
    expect(light.accent, calm.welcomeAccentColor);
    expect(light.textOnAccent, calm.welcomeTextOnAccent);
    expect(light.accentDeep, const Color(0xFF516B64));
    expect(light.heroStart, calm.heroGradientStart);
    expect(light.heroMid, calm.heroGradientMid);
    expect(light.heroEnd, calm.heroGradientEnd);

    final AppSemanticColors dark = AppSemanticColors.dark(calm);
    expect(dark.pageBackground, const Color(0xFF161A1E));
    expect(dark.surface, const Color(0xFF20262B));
    expect(dark.surfaceRaised, const Color(0xFF242A30));
    expect(dark.textPrimary, AppColors.onDark);
    expect(dark.textSecondary, AppColors.onDark.withAlpha(180));
    expect(dark.accent, const Color(0xFF7FB8AA));
    expect(dark.textOnAccent, const Color(0xFF102B28));
    expect(dark.accentSoft, const Color(0xFF243531));
  });

  test('app typography exposes approved home font roles', () {
    final TextTheme textTheme = AppTextStyles.buildTextTheme();

    expect(AppTypography.heroTitle(textTheme).fontSize, 24);
    expect(AppTypography.heroTitle(textTheme).fontWeight, FontWeight.w800);
    expect(AppTypography.sectionTitle(textTheme).fontSize, 18);
    expect(AppTypography.sectionTitle(textTheme).fontWeight, FontWeight.w800);
    expect(AppTypography.panelTitle(textTheme).fontSize, 16);
    expect(AppTypography.panelTitle(textTheme).fontWeight, FontWeight.w700);
    expect(AppTypography.cardTitle(textTheme).fontSize, 15);
    expect(AppTypography.cardTitle(textTheme).fontWeight, FontWeight.w700);
    expect(AppTypography.body(textTheme).fontSize, 14);
    expect(AppTypography.body(textTheme).fontWeight, FontWeight.w500);
    expect(AppTypography.bodyMuted(textTheme).fontSize, 13);
    expect(AppTypography.bodyMuted(textTheme).fontWeight, FontWeight.w400);
    expect(AppTypography.meta(textTheme).fontSize, 12);
    expect(AppTypography.meta(textTheme).fontWeight, FontWeight.w600);
    expect(AppTypography.chip(textTheme).fontSize, 11);
    expect(AppTypography.chip(textTheme).fontWeight, FontWeight.w500);
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

    expect(find.text('音乐'), findsOneWidget);
    expect(find.text('梦记一则'), findsOneWidget);
    expect(find.text('打卡日历'), findsOneWidget);
    expect(find.text('思绪清理'), findsOneWidget);

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();

    expect(find.text('编辑快捷功能'), findsOneWidget);
    expect(find.text('睡眠百科'), findsOneWidget);
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

  testWidgets('home section header typography matches dorm standard', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    final Text quickTitle = tester.widget<Text>(find.text('快捷功能'));
    expect(quickTitle.style?.fontSize, 18);
    expect(quickTitle.style?.fontWeight, FontWeight.w800);
    expect(quickTitle.style?.color, AppColors.textPrimary);

    final Finder editFinder = find.text('编辑').first;
    final BuildContext editContext = tester.element(editFinder);
    final AppSemanticColors appColors = editContext.appColors;
    final Text editText = tester.widget<Text>(editFinder);
    expect(editText.style?.fontSize, 12);
    expect(editText.style?.fontWeight, FontWeight.w600);
    expect(editText.style?.color, appColors.accentDeep);

    final Finder editButton = find
        .ancestor(of: editFinder, matching: find.byType(TextButton))
        .first;
    final Icon editChevron = tester.widget<Icon>(
      find
          .descendant(
            of: editButton,
            matching: find.byIcon(Icons.chevron_right_rounded),
          )
          .first,
    );
    expect(editChevron.size, 16);
    expect(editChevron.color, appColors.accentDeep);
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

  testWidgets('home quick action editor uses full-width strips on mobile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();

    final Finder selectedFinder = find.byKey(
      const ValueKey<String>(
        'home-quick-action-selected-${HomeQuickActionIds.dreamJournal}',
      ),
    );
    final Finder availableFinder = find.byKey(
      const ValueKey<String>(
        'home-quick-action-add-${HomeQuickActionIds.thoughtVault}',
      ),
    );

    expect(
      tester.getSize(availableFinder).width,
      closeTo(tester.getSize(selectedFinder).width, 0.1),
    );
  });

  testWidgets(
    'home quick action editor keeps bottom cta at 16 without safe area padding',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: _dayClock,
      );

      await tester.tap(find.text('编辑').first);
      await tester.pumpAndSettle();

      final Finder saveButton = find.widgetWithText(FilledButton, '保存快捷功能');
      final double buttonBottom = tester.getBottomLeft(saveButton).dy;
      expect(844 - buttonBottom, closeTo(16, 0.1));
    },
  );

  testWidgets('home quick action editor uses approved typography roles', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homeQuickActionsEdit,
      clock: _dayClock,
    );

    expect(tester.widget<Text>(find.text('已选择')).style?.fontSize, 18);
    expect(
      tester.widget<Text>(find.text('已选择')).style?.fontWeight,
      FontWeight.w800,
    );
    expect(tester.widget<Text>(find.text('4/4')).style?.fontSize, 12);
    expect(
      tester.widget<Text>(find.text('4/4')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(tester.widget<Text>(find.text('梦记一则')).style?.fontSize, 15);
    expect(
      tester.widget<Text>(find.text('梦记一则')).style?.fontWeight,
      FontWeight.w600,
    );

    final BuildContext context = tester.element(find.text('梦记一则'));
    final AppSemanticColors appColors = context.appColors;
    final Icon dreamIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>(
            'home-quick-action-selected-${HomeQuickActionIds.dreamJournal}',
          ),
        ),
        matching: find.byIcon(Icons.auto_stories_rounded),
      ),
    );
    expect(dreamIcon.color, appColors.accentDeep);
  });

  testWidgets('routed detail pages share the same back title header', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );
    final double baselineGap =
        tester.getTopLeft(find.text('寝室状态记录')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;

    Future<void> expectHeaderForRoute(
      String route,
      String title, {
      Color expectedColor = AppColors.textPrimary,
    }) async {
      await _pumpApp(tester, initialLocation: route, clock: _dayClock);
      expect(tester.takeException(), isNull, reason: route);

      expect(find.byType(AppDetailPageHeader), findsOneWidget);
      final Finder titleFinder = find.text(title).first;
      final Text titleText = tester.widget<Text>(titleFinder);
      final TextTheme textTheme = Theme.of(
        tester.element(titleFinder),
      ).textTheme;
      expect(
        titleText.style?.fontSize,
        AppTypography.sectionTitle(textTheme).fontSize,
      );
      expect(
        titleText.style?.fontWeight,
        AppTypography.sectionTitle(textTheme).fontWeight,
      );
      expect(titleText.style?.color, expectedColor);

      final double gap =
          tester.getTopLeft(titleFinder).dx -
          tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;
      expect(gap, closeTo(baselineGap, 0.1), reason: title);
    }

    await expectHeaderForRoute(AppRoutes.homeQuickActionsEdit, '编辑快捷功能');
    await expectHeaderForRoute(AppRoutes.dormRules, '宿舍公约');
    await expectHeaderForRoute(AppRoutes.dormCurrentStatus, '当前室友状态');
    await expectHeaderForRoute(
      AppRoutes.dormMemberLocation('roommate-a'),
      '舍友详情',
    );
    await expectHeaderForRoute(AppRoutes.dormInvite, '邀请舍友');
    await expectHeaderForRoute(AppRoutes.profileAccountPassword, '找回密码');
    await expectHeaderForRoute(AppRoutes.dreamJournal, '梦记');
    await expectHeaderForRoute(AppRoutes.dreamDetail, '梦境详情');
    await expectHeaderForRoute(
      AppRoutes.sleepAudioCatalog,
      '睡前放松音频',
      expectedColor: AppColors.onDark,
    );
    await expectHeaderForRoute(
      AppRoutes.sleepCantSleep,
      '难以入睡',
      expectedColor: AppColors.onDark,
    );
    await expectHeaderForRoute(
      AppRoutes.logNightAwakening,
      '记录夜醒',
      expectedColor: AppColors.onDark,
    );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormRules,
      clock: _dayClock,
      initialSettings: _settingsWithMood(NightMood.calm),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('dorm-rules-edit-entry')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDetailPageHeader), findsOneWidget);
    final Text editTitle = tester.widget<Text>(find.text('编辑宿舍公约'));
    final TextTheme editTheme = Theme.of(
      tester.element(find.text('编辑宿舍公约')),
    ).textTheme;
    expect(
      editTitle.style?.fontSize,
      AppTypography.sectionTitle(editTheme).fontSize,
    );
    expect(editTitle.style?.color, AppColors.textPrimary);
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

  testWidgets('sleep capture assistant switches dream and memo guidance', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: '${AppRoutes.assistant}?flow=sleep_capture&mode=dream',
      clock: _dayClock,
      settle: false,
    );
    await _pumpAssistantSurface(tester);

    expect(find.text('把梦先轻轻记下来'), findsOneWidget);
    expect(find.text('会保存到“我的 / 梦境记录”。'), findsOneWidget);
    expect(find.text('例如：我梦见自己站在很高的桥上...'), findsOneWidget);

    await tester.tap(find.text('事记'));
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text('把事也先安放下来'), findsOneWidget);
    expect(find.textContaining('会保存到“我的 / 事记仓库”'), findsOneWidget);
    expect(find.textContaining('例如：明早要给导师发材料'), findsOneWidget);
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
      expect(find.byType(AppDetailPageHeader), findsOneWidget);
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
      expect(find.byType(AppDetailPageHeader), findsOneWidget);
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

  testWidgets('dorm page follows the pencil vertical layout', (
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
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('宿舍整体状态平稳，灯光已调暗，适合逐步进入睡眠模式。'), findsNothing);

    final double heroWidth = tester
        .getSize(find.byKey(DormPage.heroCardKey))
        .width;
    expect(heroWidth, moreOrLessEquals(342, epsilon: 1));
    expect(
      tester.getSize(find.byKey(DormPage.roommateListKey)).height,
      moreOrLessEquals(96, epsilon: 1),
    );
    expect(
      tester.getSize(find.byKey(DormPage.heroCardKey)).height,
      lessThan(190),
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(of: find.text('宿舍公约'), matching: find.byType(AppCard))
                .first,
          )
          .height,
      lessThanOrEqualTo(136),
    );

    final Container heroContainer = tester.widget<Container>(
      find.byKey(DormPage.heroGradientKey),
    );
    final BoxDecoration decoration = heroContainer.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    final NightMoodPalette palette = NightMoodPalette.fromMood(NightMood.calm);
    final AppSemanticColors appColors = AppSemanticColors.light(palette);

    expect(gradient.colors.first, appColors.heroStart);
    expect(gradient.colors[1], appColors.heroMid);
    expect(gradient.colors.last, appColors.heroEnd);

    final Finder dormHubCard = find
        .ancestor(of: find.text('宿舍公约'), matching: find.byType(AppCard))
        .first;
    final Icon dormHubIcon = tester.widget<Icon>(
      find
          .descendant(
            of: dormHubCard,
            matching: find.byIcon(Icons.calendar_today_rounded),
          )
          .first,
    );
    expect(dormHubIcon.color, appColors.accentDeep);
  });

  testWidgets('dorm routed intro surfaces use semantic accent tokens', (
    WidgetTester tester,
  ) async {
    const NightMood mood = NightMood.calm;
    final NightMoodPalette palette = NightMoodPalette.fromMood(mood);
    final AppSemanticColors appColors = AppSemanticColors.light(palette);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormInvite,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    final Finder inviteTitle = find.text('梅苑 2 栋 204').first;
    final Text inviteTitleText = tester.widget<Text>(inviteTitle);
    expect(inviteTitleText.style?.color, appColors.accentDeep);
    final AppCard inviteIntroCard = tester.widget<AppCard>(
      find.ancestor(of: inviteTitle, matching: find.byType(AppCard)).first,
    );
    expect(inviteIntroCard.color, appColors.accentSoft);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormRules,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    final Text rulesTitle = tester.widget<Text>(find.text('共同维护良好宿舍环境'));
    expect(rulesTitle.style?.color, appColors.accentDeep);
    final Icon rulesIntroIcon = tester.widget<Icon>(
      find.byIcon(Icons.shield_outlined),
    );
    expect(rulesIntroIcon.color, appColors.accentDeep);
  });

  testWidgets(
    'dorm rules page enters a responsive edit draft from the header',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.dormRules,
        clock: _dayClock,
        initialSettings: _settingsWithMood(NightMood.calm),
        settle: false,
      );
      await tester.pump();

      expect(find.byType(DormRulesPage), findsOneWidget);
      expect(find.text('共同维护良好宿舍环境'), findsOneWidget);
      expect(find.text('基础规则'), findsOneWidget);
      expect(find.text('灯光与安静'), findsOneWidget);
      expect(find.text('闹钟与作息'), findsOneWidget);
      expect(find.text('温度与通风'), findsOneWidget);
      expect(find.text('23:00后保持安静'), findsNothing);
      expect(find.text('以下是大家共同制定的宿舍公约，请每位成员认真遵守。'), findsOneWidget);
      expect(find.text('请使用耳机，避免外放声音'), findsNothing);
      expect(find.text('请使用台灯或小夜灯'), findsNothing);
      expect(find.text('每天至少开窗通风30分钟'), findsNothing);

      final TextTheme rulesTextTheme = Theme.of(
        tester.element(find.byType(DormRulesPage)),
      ).textTheme;
      final Text displayHeaderTitle = tester.widget<Text>(
        find.text('宿舍公约').first,
      );
      expect(
        displayHeaderTitle.style?.fontSize,
        AppTypography.sectionTitle(rulesTextTheme).fontSize,
      );
      expect(
        displayHeaderTitle.style?.fontWeight,
        AppTypography.sectionTitle(rulesTextTheme).fontWeight,
      );
      final Text displayIntroTitle = tester.widget<Text>(
        find.text('共同维护良好宿舍环境'),
      );
      expect(
        displayIntroTitle.style?.fontSize,
        AppTypography.sectionTitle(rulesTextTheme).fontSize,
      );
      expect(
        displayIntroTitle.style?.fontWeight,
        AppTypography.sectionTitle(rulesTextTheme).fontWeight,
      );
      final AppSettingsItem displayBasicGroup = tester.widget<AppSettingsItem>(
        find.byKey(const ValueKey<String>('dorm-rules-display-group-basic')),
      );
      expect(
        displayBasicGroup.titleStyle?.fontSize,
        AppTypography.body(rulesTextTheme).fontSize,
      );
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-display-group-basic')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('dorm-rules-display-group-temperature'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('dorm-rules-display-group-basic')),
      );
      await tester.pumpAndSettle();
      expect(find.text('23:00后保持安静'), findsOneWidget);
      expect(find.text('请使用耳机，避免外放声音'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('dorm-rules-display-group-basic')),
      );
      await tester.pumpAndSettle();
      expect(find.text('23:00后保持安静'), findsNothing);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('dorm-rules-display-group-temperature'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('每天至少开窗通风30分钟'), findsOneWidget);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('dorm-rules-display-group-temperature'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我同意遵守以上公约'), findsOneWidget);
      expect(find.text('保存规则'), findsNothing);

      expect(
        tester.getBottomLeft(find.text('我同意遵守以上公约')).dy,
        lessThanOrEqualTo(844),
      );

      final Finder editButton = find.byKey(
        const ValueKey<String>('dorm-rules-edit-entry'),
      );
      expect(editButton, findsOneWidget);
      final PrimaryButton editEntryButton = tester.widget<PrimaryButton>(
        find.descendant(of: editButton, matching: find.byType(PrimaryButton)),
      );
      expect(editEntryButton.size, PrimaryButtonSize.compact);
      expect(editEntryButton.variant, PrimaryButtonVariant.soft);
      expect(editEntryButton.backgroundColor, isNull);
      expect(editEntryButton.foregroundColor, isNull);
      expect(
        tester.getTopRight(editButton).dx,
        lessThanOrEqualTo(390 - AppSpacing.md),
      );
      final double displayHeaderTop = tester.getTopLeft(find.text('宿舍公约')).dy;

      await tester.tap(editButton);
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('宿舍公约')).dy,
        lessThanOrEqualTo(displayHeaderTop + AppSpacing.xs),
      );

      final SlideTransition editSlideTransition = tester
          .widget<SlideTransition>(
            find
                .ancestor(
                  of: find.byKey(
                    const ValueKey<String>('dorm-rules-edit-view'),
                  ),
                  matching: find.byType(SlideTransition),
                )
                .first,
          );
      expect(editSlideTransition.position.value.dx, greaterThan(0));
      expect(editSlideTransition.position.value.dy, 0);
      await tester.pumpAndSettle();

      expect(find.text('编辑宿舍公约'), findsOneWidget);
      expect(find.text('修改后需要室友确认'), findsOneWidget);
      expect(find.text('本页保存的是调整草案，不会立即覆盖当前正式公约。'), findsOneWidget);
      final Text editHeaderTitle = tester.widget<Text>(find.text('编辑宿舍公约'));
      expect(
        editHeaderTitle.style?.fontSize,
        AppTypography.sectionTitle(rulesTextTheme).fontSize,
      );
      expect(
        editHeaderTitle.style?.fontWeight,
        AppTypography.sectionTitle(rulesTextTheme).fontWeight,
      );
      final Text editIntroTitle = tester.widget<Text>(find.text('修改后需要室友确认'));
      expect(
        editIntroTitle.style?.fontSize,
        AppTypography.cardTitle(rulesTextTheme).fontSize,
      );
      expect(
        editIntroTitle.style?.fontWeight,
        AppTypography.cardTitle(rulesTextTheme).fontWeight,
      );
      expect(find.byType(AppSettingsGroup), findsNWidgets(4));
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-edit-intro-icon')),
        findsOneWidget,
      );
      expect(find.text('基础规则'), findsOneWidget);
      expect(find.text('安静时段'), findsOneWidget);
      expect(find.text('23:00 - 07:00'), findsOneWidget);
      final Finder quietTrailing = find.byKey(
        const ValueKey<String>('dorm-rules-trailing-quiet-hours'),
      );
      final Text quietTrailingText = tester.widget<Text>(
        find.descendant(
          of: quietTrailing,
          matching: find.text('23:00 - 07:00'),
        ),
      );
      final Icon quietTrailingChevron = tester.widget<Icon>(
        find.descendant(
          of: quietTrailing,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
      );
      expect(quietTrailingText.style?.color, AppColors.textSecondary);
      expect(quietTrailingText.style?.fontWeight, FontWeight.w500);
      expect(quietTrailingChevron.size, 18);
      expect(quietTrailingChevron.color, AppColors.textHint);
      expect(find.text('开始'), findsNothing);
      expect(find.text('结束'), findsNothing);
      expect(find.text('熄灯提醒'), findsOneWidget);
      expect(find.text('23:30'), findsOneWidget);
      expect(find.text('补充说明'), findsOneWidget);
      expect(find.text('个人照明要求'), findsOneWidget);
      expect(find.text('60 秒'), findsOneWidget);
      expect(find.text('26°C'), findsOneWidget);
      final Text summerTrailingText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('dorm-rules-trailing-夏季空调')),
          matching: find.text('26°C'),
        ),
      );
      expect(summerTrailingText.style?.color, AppColors.textSecondary);
      expect(summerTrailingText.style?.fontWeight, FontWeight.w500);
      expect(find.text('考试周 · 夜猫子 · 早起党'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('闹钟与作息'), findsOneWidget);
      expect(find.text('温度与通风'), findsOneWidget);
      expect(find.text('保存后发送给 3 位室友确认'), findsNothing);
      expect(find.text('发起确认'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-cancel-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-submit-button')),
        findsOneWidget,
      );
      expect(
        tester.getBottomLeft(find.text('发起确认')).dy,
        lessThanOrEqualTo(844),
      );

      final Finder rulesGroup = find.byKey(
        const ValueKey<String>('dorm-rules-basic-group'),
      );
      final Finder editIntro = find.byKey(
        const ValueKey<String>('dorm-rules-edit-intro'),
      );
      expect(
        tester.getTopLeft(rulesGroup.last).dx,
        greaterThanOrEqualTo(AppSpacing.lg),
      );
      expect(
        tester.getTopLeft(editIntro).dx,
        greaterThanOrEqualTo(AppSpacing.lg),
      );

      final BuildContext buttonContext = tester.element(
        find.byKey(const ValueKey<String>('dorm-rules-submit-button')),
      );
      final PrimaryButton submitButton = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey<String>('dorm-rules-submit-button')),
      );
      final PrimaryButton cancelButton = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey<String>('dorm-rules-cancel-button')),
      );

      final NightMoodPalette editPalette = Theme.of(
        buttonContext,
      ).extension<NightMoodPalette>()!;
      expect(cancelButton.size, PrimaryButtonSize.compact);
      expect(cancelButton.variant, PrimaryButtonVariant.ghost);
      expect(cancelButton.backgroundColor, AppColors.surface);
      expect(cancelButton.foregroundColor, AppColors.textPrimary);
      expect(cancelButton.borderColor, AppColors.surfaceBorder);
      expect(submitButton.size, PrimaryButtonSize.compact);
      expect(submitButton.variant, PrimaryButtonVariant.soft);
      expect(submitButton.backgroundColor, isNull);
      expect(submitButton.foregroundColor, isNull);
      final Container quietIconContainer = tester.widget<Container>(
        find.byKey(const ValueKey<String>('dorm-rules-edit-icon-quiet-hours')),
      );
      final BoxDecoration quietIconDecoration =
          quietIconContainer.decoration! as BoxDecoration;
      expect(quietIconDecoration.color, AppColors.surfaceMuted);
      expect(quietIconDecoration.borderRadius, AppRadius.iconContainer);
      expect(
        tester.getSize(find.byWidget(quietIconContainer)).width,
        AppSpacing.xxxl,
      );
      expect(
        tester.getSize(find.byWidget(quietIconContainer)).height,
        AppSpacing.xxxl,
      );

      final Finder examToggleFinder = find.byKey(
        const ValueKey<String>('dorm-rules-switch-exam-week'),
      );
      final AppSettingsToggle examToggle = tester.widget<AppSettingsToggle>(
        examToggleFinder,
      );
      expect(examToggle.value, isTrue);
      expect(
        find.descendant(of: examToggleFinder, matching: find.byType(Switch)),
        findsNothing,
      );
      final AnimatedContainer examToggleTrack = tester
          .widget<AnimatedContainer>(
            find.descendant(
              of: examToggleFinder,
              matching: find.byType(AnimatedContainer),
            ),
          );
      final BoxDecoration examToggleDecoration =
          examToggleTrack.decoration! as BoxDecoration;
      final Border examToggleBorder = examToggleDecoration.border! as Border;
      expect(examToggleTrack.duration, const Duration(milliseconds: 160));
      expect(tester.getSize(examToggleFinder).width, 52);
      expect(tester.getSize(examToggleFinder).height, 26);
      expect(examToggleTrack.padding, const EdgeInsets.all(2));
      expect(examToggleDecoration.color, editPalette.primarySoft);
      expect(
        examToggleBorder.top.color,
        editPalette.primary.withValues(alpha: 0.28),
      );
      final AnimatedAlign examToggleThumbAlign = tester.widget<AnimatedAlign>(
        find.descendant(
          of: examToggleFinder,
          matching: find.byType(AnimatedAlign),
        ),
      );
      expect(examToggleThumbAlign.duration, const Duration(milliseconds: 160));
      expect(examToggleThumbAlign.curve, Curves.easeOutCubic);
      expect(examToggleThumbAlign.alignment, Alignment.centerRight);

      await tester.tap(find.text('考试周模式'));
      await tester.pump();
      final AppSettingsToggle disabledExamToggle = tester
          .widget<AppSettingsToggle>(examToggleFinder);
      final AnimatedAlign disabledExamToggleThumbAlign = tester
          .widget<AnimatedAlign>(
            find.descendant(
              of: examToggleFinder,
              matching: find.byType(AnimatedAlign),
            ),
          );
      expect(disabledExamToggle.value, isFalse);
      expect(disabledExamToggleThumbAlign.alignment, Alignment.centerLeft);
      await tester.tap(find.text('考试周模式'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppSettingsToggle>(examToggleFinder).value, isTrue);

      expect(find.byType(Slider), findsNothing);
      await tester.scrollUntilVisible(
        find.text('夏季空调'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('夏季空调'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('dorm-rules-summer-temp-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-slider-sheet')),
        findsNothing,
      );
      final Slider summerSlider = tester.widget<Slider>(
        find.byKey(const ValueKey<String>('dorm-rules-summer-temp-slider')),
      );
      expect(summerSlider.value, 26);
      expect(summerSlider.min, 20);
      expect(summerSlider.max, 30);

      await tester.tap(find.text('夏季空调'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-summer-temp-slider')),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.text('通风时长'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('通风时长'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey<String>('dorm-rules-ventilation-duration-slider'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('dorm-rules-ventilation-duration-expander'),
        ),
        findsOneWidget,
      );
      final Finder ventilationExpander = find.byKey(
        const ValueKey<String>('dorm-rules-ventilation-duration-expander'),
      );
      expect(
        find.descendant(
          of: ventilationExpander,
          matching: find.byType(AnimatedSize),
        ),
        findsOneWidget,
      );
      final Finder ventilationSliderPanel = find.byKey(
        const ValueKey<Key>(
          ValueKey<String>('dorm-rules-ventilation-duration-slider'),
        ),
      );
      expect(ventilationSliderPanel, findsOneWidget);
      expect(
        tester.getSize(ventilationSliderPanel).height,
        lessThanOrEqualTo(50),
      );
      final Slider ventilationSlider = tester.widget<Slider>(
        find.byKey(
          const ValueKey<String>('dorm-rules-ventilation-duration-slider'),
        ),
      );
      final double sliderCenterX = tester
          .getCenter(
            find.byKey(
              const ValueKey<String>('dorm-rules-ventilation-duration-slider'),
            ),
          )
          .dx;
      final double panelCenterX = tester.getCenter(ventilationSliderPanel).dx;
      expect(sliderCenterX, closeTo(panelCenterX, AppSpacing.xs));
      expect(ventilationSlider.value, 30);
      expect(ventilationSlider.min, 10);
      expect(ventilationSlider.max, 60);
      expect(
        find.byKey(const ValueKey<String>('dorm-rules-slider-sheet')),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.text('熄灯提醒'),
        -320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('熄灯提醒'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('dorm-rules-lights-sheet')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('dorm event actions route to dorm status records page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.scrollUntilVisible(
      find.byKey(DormPage.eventMoreKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    final TextButton moreButton = tester.widget<TextButton>(
      find.byKey(DormPage.eventMoreKey),
    );
    moreButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.byType(DormStatusPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dorm-status-filter-row')),
      findsOneWidget,
    );
    expect(find.byKey(DormStatusPage.timelineKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dorm-status-active-record')),
      findsWidgets,
    );
    expect(find.byType(AppMessageRecordCard), findsWidgets);
  });

  testWidgets('dorm current status more action opens the dedicated page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.scrollUntilVisible(
      find.byKey(DormPage.currentStatusMoreKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    tester
        .widget<TextButton>(find.byKey(DormPage.currentStatusMoreKey))
        .onPressed!
        .call();
    await tester.pumpAndSettle();

    expect(find.byType(DormCurrentStatusPage), findsOneWidget);
    expect(find.text('当前室友状态'), findsWidgets);
    expect(find.text('按室友查看'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dorm-current-status-filter-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-current-status-filter-quiet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-current-status-filter-pending')),
      findsOneWidget,
    );
  });

  testWidgets('dorm current status overview has no fake view action', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormCurrentStatus,
      clock: _dayClock,
    );

    expect(find.text('当前室友状态'), findsWidgets);
    expect(find.text('查看'), findsNothing);
  });

  testWidgets('dorm hero settings opens existing dorm management page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.tap(find.byKey(DormPage.heroSettingsKey));
    await tester.pumpAndSettle();

    expect(find.byType(DormManagementPage), findsOneWidget);
    expect(find.text('寝室管理'), findsWidgets);
  });

  testWidgets('dorm status page uses read-state tabs and grouped records', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );

    expect(find.text('待处理'), findsWidgets);
    expect(find.text('今天'), findsWidgets);
    expect(find.text('更早'), findsWidgets);
    expect(find.text('当前室友状态'), findsNothing);
    expect(find.byKey(DormStatusPage.unreadOverviewKey), findsOneWidget);
  });

  test('full dorm status records include more than the home summary cap', () {
    final DateTime now = _dayClock();
    final Dorm dorm = Dorm(
      id: 'dorm-test',
      name: '测试寝室',
      overview: '状态记录测试',
      noiseDb: 32,
      lightLabel: '偏暗',
      quietLabel: '良好',
      rules: const <DormRule>[
        DormRule(id: 'quiet-hours', title: '安静时段', detail: '23:00 后安静'),
      ],
      members: const <DormMember>[],
      events: List<DormEvent>.generate(5, (int index) {
        return DormEvent(
          id: 'event-$index',
          type: DormEventType.memberStatus,
          title: '室友状态 $index',
          detail: '第 $index 条状态记录',
          createdAt: now.subtract(Duration(minutes: index + 1)),
        );
      }),
    );
    final List<NotificationItem> notifications =
        List<NotificationItem>.generate(
          2,
          (int index) => NotificationItem(
            id: 'dorm-note-$index',
            category: NotificationCategory.dorm,
            title: '宿舍通知 $index',
            body: '第 $index 条宿舍通知',
            createdAt: now.subtract(Duration(hours: index + 1)),
            route: AppRoutes.dorm,
            readAt: index == 0 ? null : now,
          ),
        );
    final NightMoodPalette palette = NightMoodPalette.fromMood(NightMood.calm);

    final List<DormEventRecord> summaryRecords = buildDormEventRecords(
      dorm: dorm,
      notifications: notifications,
      palette: palette,
      now: now,
    );
    final List<DormEventRecord> fullRecords = buildDormEventRecords(
      dorm: dorm,
      notifications: notifications,
      palette: palette,
      now: now,
      fullHistory: true,
    );

    expect(summaryRecords.length, 4);
    expect(fullRecords, hasLength(8));
    expect(
      fullRecords.map((DormEventRecord record) => record.title),
      containsAll(<String>['室友状态 4', '宿舍通知 1', '今晚默认执行寝室公约']),
    );
  });

  test('dorm member records are filtered before applying the recent cap', () {
    final DateTime now = _dayClock();
    final Dorm dorm = Dorm(
      id: 'dorm-test',
      name: '测试寝室',
      overview: '成员动态测试',
      noiseDb: 32,
      lightLabel: '偏暗',
      quietLabel: '良好',
      rules: const <DormRule>[],
      members: const <DormMember>[],
      events: <DormEvent>[
        for (int index = 0; index < 4; index += 1)
          DormEvent(
            id: 'other-$index',
            type: DormEventType.memberStatus,
            title: '其他室友动态 $index',
            detail: '不应该进入目标室友详情',
            createdAt: now.subtract(Duration(minutes: index + 1)),
            actorUid: 'roommate-b',
          ),
        DormEvent(
          id: 'target-status',
          type: DormEventType.memberStatus,
          title: '林淯已切换到睡眠模式',
          detail: '目标室友自己的动态',
          createdAt: now.subtract(const Duration(minutes: 8)),
          actorUid: 'roommate-a',
        ),
      ],
    );

    final List<DormEventRecord> records = buildDormMemberEventRecords(
      dorm: dorm,
      memberUid: 'roommate-a',
      palette: NightMoodPalette.fromMood(NightMood.sad),
      now: now,
    );

    expect(records.map((DormEventRecord record) => record.title), <String>[
      '林淯已切换到睡眠模式',
    ]);
  });

  testWidgets('tapping unread dorm status record marks it as read', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );

    expect(find.byKey(DormStatusPage.activeRecordKey), findsOneWidget);
    await tester.tap(find.byKey(DormStatusPage.activeRecordKey));
    await tester.pumpAndSettle();

    expect(find.byKey(DormStatusPage.activeRecordKey), findsOneWidget);

    await tester.tap(find.text('更早').first);
    await tester.pumpAndSettle();

    expect(find.byKey(DormStatusPage.readRecordKey), findsOneWidget);
  });

  testWidgets('dorm status read state survives reopening the records page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.scrollUntilVisible(
      find.byKey(DormPage.eventMoreKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<TextButton>(find.byKey(DormPage.eventMoreKey)).onPressed!();
    await tester.pumpAndSettle();

    final AppMessageRecordCard activeRecord = tester
        .widget<AppMessageRecordCard>(
          find.byKey(DormStatusPage.activeRecordKey),
        );
    final String markedTitle = activeRecord.title;
    await tester.tap(find.byKey(DormStatusPage.activeRecordKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(DormPage.eventMoreKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<TextButton>(find.byKey(DormPage.eventMoreKey)).onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('更早').first);
    await tester.pumpAndSettle();

    expect(find.text(markedTitle), findsOneWidget);
  });

  testWidgets('dorm status pages use semantic color accents', (
    WidgetTester tester,
  ) async {
    const NightMood mood = NightMood.calm;
    final NightMoodPalette palette = NightMoodPalette.fromMood(mood);
    final AppSemanticColors appColors = AppSemanticColors.light(palette);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    final ChoiceChip statusTab = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '待处理').first,
    );
    expect(statusTab.selectedColor, appColors.accent);
    expect(
      statusTab.color?.resolve(<WidgetState>{
        WidgetState.selected,
        WidgetState.pressed,
      }),
      appColors.accent,
    );
    final ChoiceChip todayTab = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '今天').first,
    );
    expect(
      todayTab.color?.resolve(<WidgetState>{WidgetState.pressed}),
      appColors.surfaceMuted,
    );
    final AppMessageRecordCard statusOverview = tester
        .widget<AppMessageRecordCard>(
          find.byKey(DormStatusPage.unreadOverviewKey),
        );
    expect(statusOverview.iconBackgroundColor, appColors.accentSoft);
    expect(statusOverview.iconColor, appColors.accentDeep);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormCurrentStatus,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    final Finder currentStatusTab = find.byKey(
      const ValueKey<String>('dorm-current-status-filter-all'),
    );
    final Container currentStatusTabSurface = tester
        .widgetList<Container>(
          find.descendant(
            of: currentStatusTab,
            matching: find.byType(Container),
          ),
        )
        .firstWhere((Container container) {
          return container.decoration is BoxDecoration;
        });
    final BoxDecoration currentStatusDecoration =
        currentStatusTabSurface.decoration! as BoxDecoration;
    expect(currentStatusDecoration.color, appColors.accent);
    final Text currentStatusLabel = tester.widget<Text>(
      find.descendant(of: currentStatusTab, matching: find.text('全部')),
    );
    expect(currentStatusLabel.style?.color, appColors.textOnAccent);
    final AppMessageRecordCard currentStatusOverview = tester
        .widgetList<AppMessageRecordCard>(find.byType(AppMessageRecordCard))
        .first;
    expect(currentStatusOverview.iconBackgroundColor, appColors.accentSoft);
    expect(currentStatusOverview.iconColor, appColors.accentDeep);
  });

  testWidgets('dorm home event time labels are not rendered as action pills', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    await tester.scrollUntilVisible(
      find.byKey(DormPage.eventMoreKey),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('规则'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '规则'), findsNothing);
  });

  testWidgets('dorm quiet rating is aligned to the right of the hero card', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    final Finder hero = find.byKey(DormPage.heroGradientKey);
    final Finder lastStar = find
        .descendant(of: hero, matching: find.byIcon(Icons.star_rounded))
        .last;

    final double heroRight = tester.getTopRight(hero).dx;
    final double ratingRight = tester.getTopRight(lastStar).dx;

    expect(heroRight - ratingRight, lessThanOrEqualTo(AppSpacing.xxl));
  });

  testWidgets('dorm primary color uses the approved CTA token', (
    WidgetTester tester,
  ) async {
    expect(AppColors.primary, const Color(0xFF8EDDF2));
  });

  testWidgets(
    'message record cards default to semantic typography and accents',
    (WidgetTester tester) async {
      final NightMoodPalette palette = NightMoodPalette.fromMood(
        NightMood.calm,
      );
      final AppSemanticColors appColors = AppSemanticColors.light(palette);
      final TextTheme textTheme = AppTextStyles.buildTextTheme();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            textTheme: textTheme,
            extensions: <ThemeExtension<dynamic>>[palette, appColors],
          ),
          home: const Scaffold(
            body: AppMessageRecordCard(
              icon: Icons.nightlight_round,
              title: '记录标题',
              detail: '记录说明',
              timeLabel: '刚刚',
            ),
          ),
        ),
      );

      final Icon recordIcon = tester.widget<Icon>(
        find.byIcon(Icons.nightlight_round),
      );
      expect(recordIcon.color, appColors.accentDeep);
      final Container iconContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.nightlight_round),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration iconDecoration =
          iconContainer.decoration! as BoxDecoration;
      expect(iconDecoration.color, appColors.accentSoft);

      final Text title = tester.widget<Text>(find.text('记录标题'));
      expect(
        title.style?.fontSize,
        AppTypography.cardTitle(textTheme).fontSize,
      );
      expect(
        title.style?.fontWeight,
        AppTypography.cardTitle(textTheme).fontWeight,
      );
      expect(title.style?.color, appColors.textPrimary);

      final Text detail = tester.widget<Text>(find.text('记录说明'));
      expect(
        detail.style?.fontSize,
        AppTypography.bodyMuted(textTheme).fontSize,
      );
      expect(
        detail.style?.fontWeight,
        AppTypography.bodyMuted(textTheme).fontWeight,
      );
      expect(detail.style?.color, appColors.textSecondary);

      final Text time = tester.widget<Text>(find.text('刚刚'));
      expect(time.style?.fontSize, AppTypography.chip(textTheme).fontSize);
      expect(time.style?.fontWeight, AppTypography.chip(textTheme).fontWeight);
      expect(time.style?.color, appColors.textSecondary);
    },
  );

  testWidgets('dorm member detail uses the shared status record style', (
    WidgetTester tester,
  ) async {
    const NightMood mood = NightMood.calm;
    final AppSemanticColors appColors = AppSemanticColors.light(
      NightMoodPalette.fromMood(mood),
    );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormMemberLocation('roommate-a'),
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    expect(find.byType(DormMemberDetailPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('dorm-member-private-status-pill')),
      findsOneWidget,
    );
    expect(find.text('林淯已切换到睡眠模式'), findsOneWidget);
    expect(find.text('宿舍环境保持安静'), findsNothing);
    expect(find.byType(AppMessageRecordCard), findsWidgets);
    final AppMessageRecordCard latestRecord = tester
        .widgetList<AppMessageRecordCard>(find.byType(AppMessageRecordCard))
        .first;
    expect(latestRecord.iconBackgroundColor, appColors.accentSoft);
    expect(latestRecord.iconColor, appColors.accentDeep);

    final Text memberName = tester.widget<Text>(find.text('林淯').first);
    expect(
      memberName.style?.fontSize,
      AppTypography.sectionTitle(
        Theme.of(tester.element(find.text('林淯').first)).textTheme,
      ).fontSize,
    );
    expect(memberName.style?.color, appColors.textPrimary);

    final Text recentTitle = tester.widget<Text>(find.text('最近动态'));
    expect(
      recentTitle.style?.fontSize,
      AppTypography.sectionTitle(
        Theme.of(tester.element(find.text('最近动态'))).textTheme,
      ).fontSize,
    );
    expect(recentTitle.style?.color, appColors.textPrimary);
  });

  testWidgets('dorm management route remains available', (
    WidgetTester tester,
  ) async {
    const NightMood mood = NightMood.calm;
    final AppSemanticColors appColors = AppSemanticColors.light(
      NightMoodPalette.fromMood(mood),
    );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileAccountDorm,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    expect(find.byType(DormManagementPage), findsOneWidget);
    expect(find.text('寝室管理'), findsWidgets);

    final AppSettingsItem inviteItem = tester.widget<AppSettingsItem>(
      find.widgetWithText(AppSettingsItem, '邀请舍友'),
    );
    expect(inviteItem.iconColor, appColors.accentDeep);
    expect(inviteItem.iconBackgroundColor, appColors.surfaceMuted);
    expect(
      inviteItem.titleStyle?.fontSize,
      AppTypography.body(
        Theme.of(
          tester.element(find.widgetWithText(AppSettingsItem, '邀请舍友')),
        ).textTheme,
      ).fontSize,
    );

    final Text currentMembers = tester.widget<Text>(find.text('当前成员'));
    expect(
      currentMembers.style?.fontSize,
      AppTypography.panelTitle(
        Theme.of(tester.element(find.text('当前成员'))).textTheme,
      ).fontSize,
    );
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
    expect(find.text('月度全勤'), findsNothing);
    expect(find.text('安静守护者'), findsNothing);
  });

  testWidgets('dorm gentle reminder opens the shared rich action sheet', (
    WidgetTester tester,
  ) async {
    const NightMood mood = NightMood.calm;
    final AppSemanticColors appColors = AppSemanticColors.light(
      NightMoodPalette.fromMood(mood),
    );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dorm,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    final Finder reminderEntry = find.text('委婉提醒');
    await tester.scrollUntilVisible(
      reminderEntry,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(reminderEntry.first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('app-bottom-sheet-rich-action')),
      findsOneWidget,
    );
    expect(find.text('发送委婉提醒'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('gentle-reminder-content')),
      findsOneWidget,
    );

    final Text sheetTitle = tester.widget<Text>(find.text('委婉提醒').last);
    expect(
      sheetTitle.style?.fontSize,
      AppTypography.sectionTitle(
        Theme.of(tester.element(find.text('委婉提醒').last)).textTheme,
      ).fontSize,
    );
    final Text contentTab = tester.widget<Text>(find.text('内容'));
    expect(contentTab.style?.color, appColors.textOnAccent);
    final Text contentHeading = tester.widget<Text>(find.text('选择提醒内容'));
    expect(
      contentHeading.style?.fontSize,
      AppTypography.panelTitle(
        Theme.of(tester.element(find.text('选择提醒内容'))).textTheme,
      ).fontSize,
    );
    expect(contentHeading.style?.color, appColors.textPrimary);
  });

  testWidgets('dorm gentle reminder sheet stays above the shell tab bar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);

    final Finder reminderEntry = find.text('委婉提醒');
    await tester.scrollUntilVisible(
      reminderEntry,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(reminderEntry.first);
    await tester.pumpAndSettle();

    final Finder sheetFinder = find.byKey(
      const ValueKey<String>('app-bottom-sheet-rich-action'),
    );
    expect(find.byKey(BottomNavShell.navBarKey), findsOneWidget);
    expect(sheetFinder, findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DormPage), findsOneWidget);
    expect(find.byType(HomePreSleepPage), findsNothing);
    expect(sheetFinder, findsOneWidget);
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

  testWidgets('dream journal list uses standard app cards', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dreamJournal,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('漂浮柑橘岛'));

    final AppCard entryCard = tester.widget<AppCard>(
      find.ancestor(of: find.text('漂浮柑橘岛'), matching: find.byType(AppCard)),
    );

    expect(entryCard.borderRadius, AppRadius.compactCard);
  });

  testWidgets(
    'dream journal top tabs suppress default rectangular press overlay',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.dreamJournal,
        clock: _dayClock,
      );

      final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final Color? pressedOverlay = tabBar.overlayColor?.resolve(<WidgetState>{
        WidgetState.pressed,
      });

      expect(pressedOverlay, Colors.transparent);
      expect(tabBar.splashFactory, NoSplash.splashFactory);
    },
  );

  testWidgets(
    'dream journal create tab uses integrated composer and no snackbar feedback',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.dreamJournal,
        clock: _dayClock,
      );

      await tester.tap(find.text('新建'));
      await tester.pumpAndSettle();

      expect(find.byType(PrimaryButton), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('dream-composer-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dream-composer-submit')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '我梦见自己在桥上');
      await tester.tap(
        find.byKey(const ValueKey<String>('dream-composer-submit')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 420));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('我梦见自己在桥上'), findsOneWidget);
    },
  );

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

    expect(
      find.byKey(const ValueKey<String>('badge-catalog-title-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-badge-grid-early-sleeper')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('profile-badge-summary-card')),
        matching: find.text('安睡大师'),
      ),
      findsOneWidget,
    );
    expect(find.text('当前佩戴：安睡大师'), findsNothing);
    expect(find.text('当前展示：安睡大师'), findsNothing);
    expect(find.text('点击任意勋章可查看说明，并把已获得勋章切换为当前展示。'), findsNothing);
    expect(find.widgetWithText(FilledButton, '已同步最新'), findsOneWidget);
    expect(find.text('佩戴最新获得'), findsNothing);
    final UserProfile defaultProfile = buildDefaultUserProfile();
    final String countLabel =
        '${defaultProfile.earnedBadgeIds.length} / ${kHonorBadgeCatalog.length}';
    expect(find.text(countLabel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('profile-badge-summary-card')),
        matching: find.text(countLabel),
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
      find.byKey(const ValueKey<String>('app-bottom-sheet-rich-detail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-badge-sheet-early-sleeper')),
      findsOneWidget,
    );
    expect(find.text('佩戴此勋章'), findsOneWidget);
    expect(find.text('勋章详情'), findsNothing);
  });

  testWidgets('badge gallery switches between personal and dorm catalogs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const NightMood mood = NightMood.calm;
    final AppSemanticColors appColors = AppSemanticColors.light(
      NightMoodPalette.fromMood(mood),
    );

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileBadges,
      clock: _dayClock,
      initialSettings: _settingsWithMood(mood),
    );

    expect(
      find.byKey(const ValueKey<String>('badge-catalog-title-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-badge-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('badge-catalog-mode-dorm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('badge-catalog-mode-dorm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('badge-catalog-title-dorm')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-badge-summary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dorm-badge-grid-no-wake-room')),
      findsOneWidget,
    );
    expect(find.text('寝室脉搏显示当前勋章'), findsOneWidget);
    expect(find.text('寝室脉搏'), findsNothing);
    expect(find.text('显示当前勋章'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('dorm-badge-visibility-item')),
      findsOneWidget,
    );
    expect(find.text('寝室脉搏勋章显示'), findsNothing);

    final TextTheme textTheme = Theme.of(
      tester.element(
        find.byKey(const ValueKey<String>('badge-catalog-title-dorm')),
      ),
    ).textTheme;
    final Text dormCatalogTitle = tester.widget<Text>(
      find.byKey(const ValueKey<String>('badge-catalog-title-dorm')),
    );
    expect(
      dormCatalogTitle.style?.fontSize,
      AppTypography.sectionTitle(textTheme).fontSize,
    );
    expect(dormCatalogTitle.style?.color, AppColors.textPrimary);

    final Finder dormSummaryCard = find.byKey(
      const ValueKey<String>('dorm-badge-summary-card'),
    );
    expect(
      find.descendant(of: dormSummaryCard, matching: find.text('不醒人室')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dormSummaryCard,
        matching: find.textContaining('当前展示'),
      ),
      findsNothing,
    );
    final Text summaryTitle = tester.widget<Text>(
      find.descendant(of: dormSummaryCard, matching: find.text('不醒人室')),
    );
    expect(
      summaryTitle.style?.fontSize,
      AppTypography.sectionTitle(textTheme).fontSize,
    );
    expect(summaryTitle.style?.color, appColors.textPrimary);
    expect(summaryTitle.overflow, isNot(TextOverflow.ellipsis));

    final AppSettingsItem visibilityItem = tester.widget<AppSettingsItem>(
      find.byKey(const ValueKey<String>('dorm-badge-visibility-item')),
    );
    expect(visibilityItem.iconColor, appColors.accentDeep);
    expect(
      visibilityItem.titleStyle?.fontSize,
      AppTypography.body(textTheme).fontSize,
    );

    final Finder selectedDormBadge = find.byKey(
      const ValueKey<String>('dorm-badge-grid-no-wake-room'),
    );
    final Text dormBadgeTileTitle = tester.widget<Text>(
      find.descendant(of: selectedDormBadge, matching: find.text('不醒人室')),
    );
    expect(
      dormBadgeTileTitle.style?.fontSize,
      AppTypography.meta(textTheme).fontSize,
    );

    final Size summarySize = tester.getSize(dormSummaryCard);
    expect(summarySize.height, lessThan(170));
    final Rect summaryRect = tester.getRect(dormSummaryCard);
    final Rect summaryTitleRect = tester.getRect(
      find.descendant(of: dormSummaryCard, matching: find.text('不醒人室')),
    );
    final Rect summaryDescriptionRect = tester.getRect(
      find.text('宿舍成员整体睡眠时间长，睡眠状态良好'),
    );
    expect(
      (summaryTitleRect.center.dy + summaryDescriptionRect.center.dy) / 2,
      closeTo(summaryRect.center.dy, 18),
    );

    expect(tester.getSize(selectedDormBadge).height, lessThan(150));
    final Icon selectedDormBadgeIcon = tester.widget<Icon>(
      find
          .descendant(
            of: selectedDormBadge,
            matching: find.byIcon(Icons.bedtime_rounded),
          )
          .first,
    );
    expect(selectedDormBadgeIcon.color, isNot(AppColors.textStrong));
    expect(selectedDormBadgeIcon.color, appColors.accentDeep);
  });

  testWidgets('badge header follows detail page title rhythm', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileBadges,
      clock: _dayClock,
    );

    final TextTheme textTheme = Theme.of(
      tester.element(
        find.byKey(const ValueKey<String>('badge-catalog-title-profile')),
      ),
    ).textTheme;
    final Text profileTitle = tester.widget<Text>(
      find.byKey(const ValueKey<String>('badge-catalog-title-profile')),
    );
    expect(
      profileTitle.style?.fontSize,
      AppTypography.sectionTitle(textTheme).fontSize,
    );
    expect(
      profileTitle.style?.fontWeight,
      AppTypography.sectionTitle(textTheme).fontWeight,
    );
    expect(profileTitle.style?.color, AppColors.textPrimary);

    final double badgeHeaderGap =
        tester
            .getTopLeft(
              find.byKey(const ValueKey<String>('badge-catalog-title-profile')),
            )
            .dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );
    final double dormHeaderGap =
        tester.getTopLeft(find.text('寝室状态记录')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;
    expect(badgeHeaderGap, closeTo(dormHeaderGap, 0.1));
  });

  testWidgets('profile badge preview sheet stays above the shell tab bar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    final Finder previewSlot = find.byKey(
      const ValueKey<String>('profile-badge-preview-slot-0'),
    );
    expect(find.byKey(BottomNavShell.navBarKey), findsOneWidget);
    await tester.ensureVisible(previewSlot);
    await tester.tap(previewSlot);
    await tester.pumpAndSettle();

    final Finder sheetFinder = find.byKey(
      const ValueKey<String>('profile-badge-sheet-sleep-master'),
    );
    expect(
      find.byKey(const ValueKey<String>('app-bottom-sheet-rich-detail')),
      findsOneWidget,
    );
    expect(sheetFinder, findsOneWidget);
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(HomePreSleepPage), findsNothing);
    expect(sheetFinder, findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('profile-badge-summary-card')),
        matching: find.text('安睡大师'),
      ),
      findsOneWidget,
    );
    expect(find.text('当前佩戴：安睡大师'), findsNothing);
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

      final Finder manualSummary = find.byKey(
        const ValueKey<String>('profile-badge-summary-card'),
      );
      expect(
        find.descendant(of: manualSummary, matching: find.text('早睡先锋')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: manualSummary,
          matching: find.textContaining('当前佩戴'),
        ),
        findsNothing,
      );
      expect(find.text('手动佩戴中'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '恢复默认最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '已同步最新'), findsNothing);
      expect(
        tester.getSize(
          find.byKey(const ValueKey<String>('badge-summary-mode-chip')),
        ),
        tester.getSize(
          find.byKey(const ValueKey<String>('badge-summary-action-button')),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
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

      expect(find.text('安睡大师'), findsWidgets);
      expect(find.text('自动同步最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '已同步最新'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '恢复默认最新'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
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

  testWidgets('intervention task page uses home typography roles', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.interventionTask,
      clock: _dayClock,
    );

    expect(find.byType(AppDetailPageHeader), findsOneWidget);
    final Text headerTitle = tester.widget<Text>(find.text('全部今晚建议'));
    final TextTheme textTheme = Theme.of(
      tester.element(find.text('全部今晚建议')),
    ).textTheme;
    expect(
      headerTitle.style?.fontSize,
      AppTypography.sectionTitle(textTheme).fontSize,
    );
    final double interventionHeaderGap =
        tester.getTopLeft(find.text('全部今晚建议')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );
    final double dormHeaderGap =
        tester.getTopLeft(find.text('寝室状态记录')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;
    expect(interventionHeaderGap, closeTo(dormHeaderGap, 0.1));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.interventionTask,
      clock: _dayClock,
    );

    final Text introTitle = tester.widget<Text>(
      find.text('这些建议来自昨晚环境、宿舍状态和你最近的反馈。'),
    );
    expect(introTitle.style?.fontSize, 16);
    expect(introTitle.style?.fontWeight, FontWeight.w700);

    final Text actionTitle = tester.widget<Text>(find.text('睡前放松音频'));
    expect(actionTitle.style?.fontSize, 15);
    expect(actionTitle.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('interference detail page uses home typography roles', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.analysisInterferenceFactors,
      clock: _dayClock,
    );

    expect(find.byType(AppDetailPageHeader), findsOneWidget);
    expect(find.text('今晚影响因素'), findsOneWidget);
    final double interferenceHeaderGap =
        tester.getTopLeft(find.text('今晚影响因素')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.dormStatus,
      clock: _dayClock,
    );
    final double dormHeaderGap =
        tester.getTopLeft(find.text('寝室状态记录')).dx -
        tester.getTopRight(find.byIcon(Icons.chevron_left_rounded).first).dx;
    expect(interferenceHeaderGap, closeTo(dormHeaderGap, 0.1));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.analysisInterferenceFactors,
      clock: _dayClock,
    );

    final Text sectionTitle = tester.widget<Text>(find.text('今晚的四个观察点'));
    expect(sectionTitle.style?.fontSize, 18);
    expect(sectionTitle.style?.fontWeight, FontWeight.w800);

    final Text noiseTitle = tester.widget<Text>(find.text('宿舍噪声'));
    expect(noiseTitle.style?.fontSize, 15);
    expect(noiseTitle.style?.fontWeight, FontWeight.w700);

    final Text statusChip = tester.widget<Text>(
      find.textContaining('状态').first,
    );
    expect(statusChip.style?.fontSize, 11);
  });

  testWidgets('notification center uses home typography roles', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.notifications,
      clock: _dayClock,
    );

    final Text overviewTitle = tester.widget<Text>(
      find.textContaining('待处理消息').first,
    );
    expect(overviewTitle.style?.fontSize, 16);
    expect(overviewTitle.style?.fontWeight, FontWeight.w700);

    final Text sectionTitle = tester.widget<Text>(find.text('待处理'));
    expect(sectionTitle.style?.fontSize, 18);
    expect(sectionTitle.style?.fontWeight, FontWeight.w800);

    final Text notificationTitle = tester.widget<Text>(
      find.text('宿舍环境保持安静').first,
    );
    expect(notificationTitle.style?.fontSize, 15);
    expect(notificationTitle.style?.fontWeight, FontWeight.w700);

    final Text overviewBody = tester.widget<Text>(find.text('建议先查看「待处理」分组'));
    expect(overviewBody.style?.fontSize, 13);
    expect(overviewBody.style?.fontWeight, FontWeight.w400);
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
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profileCalendar,
      clock: _dayClock,
    );

    final AppServices services = AppScope.of(
      tester.element(find.byType(CalendarCheckinPage)),
    );
    final DateTime now = DateTime.now();
    final int daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final DateTime calendarTargetDay = DateTime(
      now.year,
      now.month,
      now.day < daysInMonth ? now.day + 1 : now.day,
    );
    final SleepSession targetSession = _buildPendingFeedbackSession(
      uid: services.authRepository.currentUser.uid,
      id: 'calendar-target-session',
      startedAt: calendarTargetDay.subtract(const Duration(hours: 1)),
      recommendationTitle: 'Calendar target session',
    );
    await services.sleepSessionRepository.saveSession(targetSession);
    await tester.pumpAndSettle();

    final Finder targetDayFinder = find.descendant(
      of: find.byType(GridView),
      matching: find.text('${targetSession.sleepDayDate.day}'),
    );
    expect(targetDayFinder, findsOneWidget);
    await tester.ensureVisible(targetDayFinder);
    await tester.pumpAndSettle();
    await tester.tap(targetDayFinder);
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

  testWidgets('home recommendation section opens all recommendations page', (
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
    expect(find.text('全部今晚建议'), findsOneWidget);
    expect(find.textContaining('已采纳'), findsOneWidget);
    expect(find.text('睡前放松音频'), findsWidgets);
    expect(find.text('佩戴隔音耳塞'), findsOneWidget);
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
    expect(find.text('轻触进入'), findsNothing);
    expect(find.text('音频已同步'), findsNothing);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
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
    'post-sleep morning feedback card keeps the live sleep session open while entering feedback',
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
        isFalse,
      );
      await tester.dragUntilVisible(
        find.text('提交反馈并结束本次睡眠'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('提交反馈并结束本次睡眠'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('返回'), findsOneWidget);

      final SleepSession active = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!;
      expect(active.status, SleepSessionStatus.active);
      expect(active.sleepModeActive, isTrue);
    },
  );

  testWidgets(
    'exit dialog finish option reuses the live morning feedback entry',
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

      expect(
        find.byKey(const ValueKey<String>('app-center-dialog-rich-choice')),
        findsOneWidget,
      );
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
        isFalse,
      );
      await tester.dragUntilVisible(
        find.text('提交反馈并结束本次睡眠'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('提交反馈并结束本次睡眠'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('返回'), findsOneWidget);

      final PrimaryButton returnButton = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, '返回'),
      );
      expect(returnButton.size, PrimaryButtonSize.compact);

      final SleepSession active = services.sleepSessionRepository
          .sessionForSleepDayKey(
            sleepDayKeyFromDate(DateTime(2030, 4, 5, 15, 10)),
          )!;
      expect(active.status, SleepSessionStatus.active);
      expect(active.sleepModeActive, isTrue);
    },
  );

  testWidgets(
    'sleep exit dialog keeps note above actions and uses dark surface background',
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

      final Finder endSleepModeButton = find.widgetWithText(
        PrimaryButton,
        '结束睡眠模式',
      );
      await tester.ensureVisible(endSleepModeButton);
      await tester.tap(endSleepModeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder dialogFinder = find.byKey(
        const ValueKey<String>('app-center-dialog-rich-choice'),
      );
      final Finder noteFinder = find.text('退出后再次进入，睡眠时长可累计，完成晨间反馈后该日时长就不再累计。');
      final Finder returnButtonFinder = find.widgetWithText(
        PrimaryButton,
        '返回',
      );

      expect(dialogFinder, findsOneWidget);
      expect(noteFinder, findsOneWidget);
      expect(returnButtonFinder, findsOneWidget);

      final Container dialogSurface = tester.widget<Container>(dialogFinder);
      final BoxDecoration decoration =
          dialogSurface.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.darkSurface);
      expect(
        tester.getBottomLeft(noteFinder).dy,
        lessThan(tester.getTopLeft(returnButtonFinder).dy),
      );
    },
  );

  testWidgets(
    'direct morning feedback tool from post-sleep page does not bounce to home first',
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
      expect(find.byType(HomePostSleepPage), findsNothing);
    },
  );

  testWidgets(
    'post-sleep morning feedback card stays on the sleep page after feedback was already submitted',
    (WidgetTester tester) async {
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      expect(find.byType(HomePostSleepPage), findsOneWidget);
      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final SleepSession activeSession =
          services.sleepSessionRepository.activeSession!;
      final SleepSession completedSession = activeSession.copyWith(
        endedAt: currentTime,
        status: SleepSessionStatus.completed,
        sleepModeActive: false,
        segments: <SleepSegment>[
          for (final SleepSegment segment in activeSession.segments)
            SleepSegment(
              startedAt: segment.startedAt,
              endedAt: segment.endedAt ?? currentTime,
            ),
        ],
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 4,
          totalSleepHours: 6.5,
          awakeningsCount: 0,
          note: 'submitted',
        ),
        updatedAt: currentTime,
      );
      await services.sleepSessionRepository.saveSession(completedSession);
      await tester.pump();

      await tester.dragUntilVisible(
        find.text('晨间反馈'),
        find.byType(Scrollable).first,
        const Offset(0, -220),
      );
      await tester.pump();
      await tester.tap(find.text('晨间反馈').first);
      await tester.pump();
      await _pumpUntilFound(tester, find.text('您已经填写过晨间反馈，小眠已经收到🫡'));

      expect(find.byType(HomePostSleepPage), findsOneWidget);
      expect(find.byType(MorningFeedbackPage), findsNothing);
      expect(find.text('您已经填写过晨间反馈，小眠已经收到🫡'), findsOneWidget);
    },
  );

  testWidgets(
    'post-sleep finish via feedback exits home when feedback was already submitted',
    (WidgetTester tester) async {
      DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

      await _pumpApp(
        tester,
        initialLocation: AppRoutes.homePreSleep,
        clock: () => currentTime,
      );

      await tester.tap(find.byType(StartSleepModeCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      currentTime = DateTime(2030, 4, 5, 15, 10);

      expect(find.byType(HomePostSleepPage), findsOneWidget);
      final AppServices services = AppScope.of(
        tester.element(find.byType(HomePostSleepPage)),
      );
      final SleepSession activeSession =
          services.sleepSessionRepository.activeSession!;
      final SleepSession completedSession = activeSession.copyWith(
        endedAt: currentTime,
        status: SleepSessionStatus.completed,
        sleepModeActive: false,
        segments: <SleepSegment>[
          for (final SleepSegment segment in activeSession.segments)
            SleepSegment(
              startedAt: segment.startedAt,
              endedAt: segment.endedAt ?? currentTime,
            ),
        ],
        summary: const MorningSummary(
          sleepQuality: 4,
          restedLevel: 4,
          totalSleepHours: 6.5,
          awakeningsCount: 0,
          note: 'submitted',
        ),
        updatedAt: currentTime,
      );
      await services.sleepSessionRepository.saveSession(completedSession);
      await tester.pump();

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
      await _pumpUntilFound(tester, find.byType(HomePreSleepPage));
      await _pumpUntilFound(tester, find.text('您已经填写过晨间反馈，小眠已经收到🫡'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePreSleepPage), findsOneWidget);
      expect(find.byType(MorningFeedbackPage), findsNothing);
      expect(find.text('结束后怎么处理这段睡眠？'), findsNothing);
      expect(find.text('您已经填写过晨间反馈，小眠已经收到🫡'), findsOneWidget);
    },
  );

  testWidgets('system back from post-sleep page opens exit dialog', (
    WidgetTester tester,
  ) async {
    DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: () => currentTime,
    );

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    currentTime = DateTime(2030, 4, 5, 15, 10);

    expect(find.byType(HomePostSleepPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomePostSleepPage), findsOneWidget);
    expect(find.text('结束后怎么处理这段睡眠？'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, '结束并去晨间反馈'), findsOneWidget);
  });

  testWidgets('post-sleep page stays overflow-free on narrow width', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: () => currentTime,
    );

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    currentTime = DateTime(2030, 4, 5, 15, 10);

    expect(find.byType(HomePostSleepPage), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(320, 780));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    final Finder endSleepModeButton = find.widgetWithText(
      PrimaryButton,
      '结束睡眠模式',
    );
    expect(tester.getBottomRight(endSleepModeButton).dy, greaterThan(680));
    await tester.ensureVisible(endSleepModeButton);
    await tester.tap(endSleepModeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('结束后怎么处理这段睡眠？'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post-sleep tools stay two-column on narrow width', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DateTime currentTime = DateTime(2030, 4, 5, 14, 0);

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: () => currentTime,
    );

    await tester.tap(find.byType(StartSleepModeCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    currentTime = DateTime(2030, 4, 5, 15, 10);

    await tester.binding.setSurfaceSize(const Size(320, 780));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Offset firstTool = tester.getTopLeft(find.text('难以入睡'));
    final Offset secondTool = tester.getTopLeft(find.text('记录夜醒'));

    expect((firstTool.dy - secondTool.dy).abs(), lessThan(24));
    expect((firstTool.dx - secondTool.dx).abs(), greaterThan(80));
  });

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
    await tester.dragUntilVisible(
      find.text('提交反馈并结束本次睡眠'),
      find.byType(ListView).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('提交反馈并结束本次睡眠'), findsOneWidget);
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
    expect(find.text('逐条反馈建议'), findsOneWidget);
    expect(find.text('补充说明'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('提交反馈并结束本次睡眠'),
      find.byType(ListView).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('提交反馈并结束本次睡眠'), findsOneWidget);
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
      await tester.dragUntilVisible(
        find.text('提交反馈并结束本次睡眠'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(find.text('提交反馈并结束本次睡眠'), findsOneWidget);

      final SleepSession awaitingZeroMinute = services.sleepSessionRepository
          .sessionForSleepDayKey(sleepDayKeyFromDate(currentTime))!;
      expect(awaitingZeroMinute.status, SleepSessionStatus.active);
      expect(awaitingZeroMinute.sleepModeActive, isTrue);
      expect(awaitingZeroMinute.trackedDurationMinutes, 0);
    },
  );

  testWidgets(
    'morning feedback return discards live feedback without resuming sleep mode',
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
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('app-center-dialog-destructive')),
        findsOneWidget,
      );
      expect(find.text('放弃本次填写？'), findsOneWidget);
      expect(find.byType(MorningFeedbackPage), findsOneWidget);

      currentTime = DateTime(2030, 4, 5, 15, 25);
      await tester.tap(find.widgetWithText(PrimaryButton, '放弃并返回'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomePostSleepPage), findsOneWidget);

      final SleepSession resumed =
          services.sleepSessionRepository.activeSession!;
      expect(resumed.id, currentSleepDaySessionId);
      expect(resumed.status, SleepSessionStatus.active);
      expect(resumed.sleepModeActive, isTrue);
      expect(resumed.segments.length, 1);
      expect(resumed.trackedDurationMinutes, 0);

      currentTime = DateTime(2030, 4, 5, 15, 40);
      expect(resumed.liveTrackedDurationMinutes(now: currentTime), 100);
    },
  );

  testWidgets(
    'morning feedback return can continue editing from the discard confirmation',
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

      await tester.dragUntilVisible(
        find.text('返回'),
        find.byType(ListView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('app-center-dialog-destructive')),
        findsOneWidget,
      );
      expect(find.text('放弃本次填写？'), findsOneWidget);
      expect(find.byType(MorningFeedbackPage), findsOneWidget);

      await tester.tap(find.widgetWithText(PrimaryButton, '继续填写'));
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(find.text('放弃本次填写？'), findsNothing);
    },
  );

  testWidgets(
    'morning feedback system back opens the discard confirmation for a live session',
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

      expect(find.byType(MorningFeedbackPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(find.text('放弃本次填写？'), findsOneWidget);
      expect(find.text('放弃并返回'), findsOneWidget);
    },
  );

  testWidgets(
    'morning feedback recommendation status opens activity panel and updates selection',
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
        id: 'activity-panel-session',
        startedAt: DateTime(2026, 4, 17, 23, 18),
        recommendationTitle: 'Activity panel session',
      );
      await services.sleepSessionRepository.saveSession(targetSession);

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(
        context,
      ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
      await tester.pumpAndSettle();

      final Finder feedbackListView = find
          .descendant(
            of: find.byType(MorningFeedbackPage),
            matching: find.byType(ListView),
          )
          .first;

      expect(find.byType(MorningFeedbackPage), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);

      await tester.dragUntilVisible(
        find.text('Activity panel session'),
        feedbackListView,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity panel session'), findsOneWidget);
      await tester.tap(find.textContaining('反馈状态').first);
      await tester.pumpAndSettle();

      expect(find.text('选择反馈状态'), findsOneWidget);
      expect(find.text('未执行'), findsOneWidget);

      await tester.tap(find.text('有效').last);
      await tester.pumpAndSettle();

      expect(find.text('选择反馈状态'), findsNothing);
      expect(find.textContaining('反馈状态：有效'), findsWidgets);
    },
  );

  testWidgets(
    'morning feedback mirrors previous night recommendations and execution state',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.feedbackMorning,
        clock: _feedbackClock,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(MorningFeedbackPage)),
      );
      final SleepSession targetSession = _buildMixedExecutionFeedbackSession(
        uid: services.authRepository.currentUser.uid,
        id: 'mixed-recommendation-session',
        startedAt: DateTime(2026, 4, 17, 23, 18),
      );
      await services.sleepSessionRepository.saveSession(targetSession);

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(
        context,
      ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
      await tester.pumpAndSettle();

      final Finder feedbackListView = find
          .descendant(
            of: find.byType(MorningFeedbackPage),
            matching: find.byType(ListView),
          )
          .first;

      await tester.dragUntilVisible(
        find.text('已执行的耳塞建议'),
        feedbackListView,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('昨晚已执行'), findsOneWidget);
      expect(find.textContaining('反馈状态：一般'), findsWidgets);

      await tester.dragUntilVisible(
        find.text('未执行的灯光建议'),
        feedbackListView,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('昨晚未执行'), findsOneWidget);
      expect(find.textContaining('反馈状态：未执行'), findsWidgets);

      await tester.dragUntilVisible(
        find.text('提交反馈'),
        feedbackListView,
        const Offset(0, -300),
      );
      await tester.tap(find.text('提交反馈'));
      await tester.pumpAndSettle();

      final SleepSession completed = services.sleepSessionRepository.sessions
          .firstWhere((SleepSession session) => session.id == targetSession.id);
      expect(completed.feedback, hasLength(2));
      expect(
        completed.feedback
            .firstWhere(
              (RecommendationFeedback item) =>
                  item.recommendationId == 'executed-earplug',
            )
            .status,
        RecommendationFeedbackStatus.neutral,
      );
      expect(
        completed.feedback
            .firstWhere(
              (RecommendationFeedback item) =>
                  item.recommendationId == 'skipped-light',
            )
            .status,
        RecommendationFeedbackStatus.skipped,
      );
    },
  );

  testWidgets(
    'morning feedback recommendation note opens compact sheet from action row',
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
        id: 'compact-action-session',
        startedAt: DateTime(2026, 4, 17, 23, 18),
        recommendationTitle: 'Compact action session',
      );
      await services.sleepSessionRepository.saveSession(targetSession);

      final BuildContext context = tester.element(
        find.byType(MorningFeedbackPage),
      );
      GoRouter.of(
        context,
      ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
      await tester.pumpAndSettle();

      final Finder feedbackListView = find
          .descendant(
            of: find.byType(MorningFeedbackPage),
            matching: find.byType(ListView),
          )
          .first;
      await tester.dragUntilVisible(
        find.text('Compact action session'),
        feedbackListView,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      final Finder statusAction = find.textContaining('反馈状态').first;
      final Finder noteAction = find.text('补充说明').first;

      expect(find.byType(TextField), findsNothing);
      expect(
        (tester.getTopLeft(statusAction).dy - tester.getTopLeft(noteAction).dy)
            .abs(),
        lessThan(18),
      );

      await tester.tap(noteAction);
      await tester.pumpAndSettle();

      expect(find.text('保存说明'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '昨晚这条建议实际有帮助');
      await tester.tap(find.text('保存说明'));
      await tester.pumpAndSettle();

      expect(find.text('保存说明'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('已填写说明'), findsOneWidget);
    },
  );

  testWidgets('morning feedback stays overflow-free on narrow width', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(280, 780));

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
      id: 'narrow-feedback-session',
      startedAt: DateTime(2026, 4, 17, 23, 18),
      recommendationTitle: 'Narrow feedback session',
    );
    await services.sleepSessionRepository.saveSession(targetSession);

    final BuildContext context = tester.element(
      find.byType(MorningFeedbackPage),
    );
    GoRouter.of(
      context,
    ).go(AppRoutes.feedbackMorningLocation(sessionId: targetSession.id));
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.dragUntilVisible(
      find.text('Narrow feedback session'),
      find
          .descendant(
            of: find.byType(MorningFeedbackPage),
            matching: find.byType(ListView),
          )
          .first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('反馈状态：'), findsOneWidget);
    expect(find.text('提交反馈'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cant sleep page stays compact on narrow width', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(280, 780));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.sleepCantSleep,
      clock: _nightClock,
    );

    expect(find.byType(CantSleepPage), findsOneWidget);
    expect(find.text('难以入睡'), findsOneWidget);
    expect(find.text('点击选择'), findsOneWidget);
    expect(find.text('思绪太多'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('点击选择'));
    await tester.pumpAndSettle();

    expect(find.text('选择当前困扰'), findsOneWidget);
    expect(find.text('环境打扰'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

SleepSession _buildMixedExecutionFeedbackSession({
  required String uid,
  required String id,
  required DateTime startedAt,
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
        id: 'executed-earplug',
        title: '已执行的耳塞建议',
        subtitle: '昨晚点击过，所以晨间反馈默认评估效果。',
        type: RecommendationType.quickAction,
        icon: Icons.hearing_rounded,
        tags: const <String>['executed'],
        executionState: RecommendationExecutionState.selected,
      ),
      NightRecommendation(
        id: 'skipped-light',
        title: '未执行的灯光建议',
        subtitle: '昨晚没有点击，所以晨间反馈默认未执行。',
        type: RecommendationType.quickAction,
        icon: Icons.lightbulb_outline_rounded,
        tags: const <String>['skipped'],
        executionState: RecommendationExecutionState.idle,
      ),
    ],
    selectedRecommendationIds: const <String>['executed-earplug'],
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

DateTime _freshSleepClock() => DateTime(2030, 5, 17, 14);

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
