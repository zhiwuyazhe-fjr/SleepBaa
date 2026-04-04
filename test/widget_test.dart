import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/bottom_nav_shell.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots into pre-sleep home via /home redirect', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(
        initialLocation: AppRoutes.home,
        homeMode: HomeMode.preSleep,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomePreSleepPage), findsOneWidget);
    expect(find.byKey(BottomNavShell.navBarKey), findsOneWidget);
  });

  testWidgets('bottom navigation switches between shell tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.homePreSleep),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('宿舍'));
    await tester.pumpAndSettle();
    expect(find.byType(DormPage), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('assistant fab opens assistant page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.homePreSleep),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(AssistantPage), findsOneWidget);
  });

  testWidgets('post sleep page hides shell navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(
        initialLocation: AppRoutes.homePostSleep,
        homeMode: HomeMode.postSleep,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(HomePostSleepPage), findsOneWidget);
    expect(find.byKey(BottomNavShell.navBarKey), findsNothing);
  });

  testWidgets('notifications page can render unread items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.notifications),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('待处理'), findsOneWidget);
  });

  testWidgets('morning feedback page renders submit flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.feedbackMorning),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MorningFeedbackPage), findsOneWidget);
  });

  testWidgets('calendar page renders month view', (WidgetTester tester) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.profileCalendar),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarCheckinPage), findsOneWidget);
    expect(find.textContaining('202'), findsWidgets);
  });

  testWidgets('home recommendation section opens intervention overview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const SleepDormApp(initialLocation: AppRoutes.homePreSleep),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(find.text('今晚全部建议'), findsOneWidget);
  });
}
