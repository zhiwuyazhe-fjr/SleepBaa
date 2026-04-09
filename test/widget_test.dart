import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/notifications/passive_toast_notification.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/bottom_nav_shell.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_status_page.dart';
import 'package:sleep_dorm_app/features/dream/presentation/pages/dream_journal_page.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/widgets/night_mood_welcome_flow.dart';
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

  testWidgets('welcome flow is not shown again after it is handled once', (
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
    expect(find.text('今晚你更接近哪一种心情？'), findsNothing);
  });

  testWidgets('welcome top card keeps about 52.5% viewport height', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    final double availableHeight = tester
        .getSize(
          find.byKey(
            const ValueKey<NightMoodFlowStep>(NightMoodFlowStep.select),
          ),
        )
        .height;
    final Size topCardSize = tester.getSize(
      find.byKey(const ValueKey<String>('night-mood-top-card')),
    );
    expect(
      topCardSize.height,
      moreOrLessEquals(availableHeight * 0.525, epsilon: 4),
    );
  });

  testWidgets('welcome title uses predefined line break on narrow width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);
    expect(find.text('今晚你更接近哪一种心情？'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(360, 844));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('今晚你更接近\n哪一种心情？'), findsOneWidget);
    expect(find.text('今晚你更接近哪一种心情？'), findsNothing);
  });

  testWidgets('welcome action bar stays aligned across all three steps', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    final double step1Top = tester
        .getTopLeft(find.widgetWithText(FilledButton, '下一步'))
        .dy;

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    final double step2Top = tester
        .getTopLeft(find.widgetWithText(FilledButton, '继续'))
        .dy;

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    final double step3Top = tester
        .getTopLeft(find.widgetWithText(FilledButton, '进入今晚首页'))
        .dy;

    expect(step2Top, moreOrLessEquals(step1Top, epsilon: 2));
    expect(step3Top, moreOrLessEquals(step1Top, epsilon: 2));
  });

  testWidgets('welcome flow uses slide transition between steps', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(SlideTransition), findsWidgets);
  });

  testWidgets('welcome flow keeps small viewport without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome confirmation title is 准备就绪', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();

    expect(find.text('准备就绪'), findsOneWidget);
  });

  testWidgets('reasons step allows clearing the last selected reason', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('呼吸很顺'));
    await tester.pumpAndSettle();

    final FilledButton continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '继续'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    expect(find.text('什么在支撑你此刻的平静？'), findsOneWidget);
    expect(find.text('准备就绪'), findsNothing);
  });

  testWidgets('reselecting a reason enables continue and enters welcome step', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, initialLocation: AppRoutes.home, clock: _nightClock);

    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('呼吸很顺'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('脑子清楚了'));
    await tester.pumpAndSettle();

    final FilledButton continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '继续'),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, '继续'));
    await tester.pumpAndSettle();
    expect(find.text('准备就绪'), findsOneWidget);
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

      await tester.enterText(find.byType(TextField), '今晚宿舍有点吵');
      expect(find.text('今晚宿舍有点吵'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
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

  testWidgets('dorm notice keeps current enter animation before switching', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('静音模式'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('安静挑战'));
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsOneWidget);
    expect(find.text('已记录本周安静挑战，明早可以回看完成情况。'), findsNothing);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('已记录本周安静挑战，明早可以回看完成情况。'), findsOneWidget);
    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsNothing);
  });

  testWidgets('dorm notice switches quickly when new message arrives in visible phase', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    final BuildContext context = tester.element(find.byType(DormPage));
    notifyPassiveToast(context, message: '今晚 23:00 后的静音提醒已经准备好了。');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsOneWidget);

    notifyPassiveToast(context, message: '已记录本周安静挑战，明早可以回看完成情况。');
    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('已记录本周安静挑战，明早可以回看完成情况。'), findsOneWidget);
    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsNothing);
  });

  testWidgets('dorm notice consumes burst taps in queued order', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('静音模式'));
    await tester.tap(find.text('安静挑战'));
    await tester.tap(find.text('委婉提醒'));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('已记录本周安静挑战，明早可以回看完成情况。'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 520));
    expect(find.text('已生成一条温和提醒文案，后续可以直接接入消息发送。'), findsOneWidget);
  });

  testWidgets('dorm notice ignores tap while enter animation is playing', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('静音模式'));
    await tester.pump(const Duration(milliseconds: 80));
    final Offset toastCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('dorm-passive-toast')),
    );
    await tester.tapAt(toastCenter);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('今晚 23:00 后的静音提醒已经准备好了。'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2600));
  });

  testWidgets('dorm notice can be dismissed by tapping itself', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('静音模式'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(
      find.byKey(const ValueKey<String>('dorm-passive-toast')),
      findsOneWidget,
    );

    final Offset toastCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('dorm-passive-toast')),
    );
    await tester.tapAt(toastCenter);
    await tester.pump(const Duration(milliseconds: 380));
    expect(
      find.byKey(const ValueKey<String>('dorm-passive-toast')),
      findsNothing,
    );
  });

  testWidgets('dorm notice starts from bottom before entering', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester, initialLocation: AppRoutes.dorm, clock: _dayClock);
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(find.text('静音模式'));
    await tester.pump();

    final AnimatedSlide slide = tester.widget<AnimatedSlide>(
      find.byType(AnimatedSlide).first,
    );
    expect(slide.offset.dy, greaterThan(0));
  });

  testWidgets('dorm notice does not block bottom tab interactions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.homePreSleep,
      clock: _dayClock,
    );

    await tester.tap(find.byIcon(Icons.night_shelter_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('静音模式'),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(DormPage.drawerSheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('静音模式'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey<String>('dorm-passive-toast')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.person_rounded).last);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('profile page shows a full-width month preview grid', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    expect(find.byKey(ProfilePage.monthPreviewGridKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(ProfilePage.monthPreviewGridKey)).width,
      greaterThan(250),
    );
  });

  testWidgets('profile dream journal entry opens dream journal page', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      initialLocation: AppRoutes.profile,
      clock: _dayClock,
    );

    await tester.ensureVisible(find.text('梦境记录'));
    await tester.tap(find.text('梦境记录'));
    await tester.pumpAndSettle();

    expect(find.byType(DreamJournalPage), findsOneWidget);
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

    await tester.tap(find.text('查看全部'));
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
  DateTime Function()? clock,
  UserSettings? initialSettings,
  bool settle = true,
  bool showNightWelcomeOutsideNightInDebug = false,
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: initialLocation,
      homeMode: homeMode,
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
