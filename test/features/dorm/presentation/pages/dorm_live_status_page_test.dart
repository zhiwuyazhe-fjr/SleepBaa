import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_status_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dorm live status polling only stays active while a dorm surface is visible',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.dorm,
        clock: DateTime.now,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(DormPage)),
      );
      expect(services.dormLiveStatusController.isPolling, isTrue);

      final BuildContext dormContext = tester.element(find.byType(DormPage));
      GoRouter.of(dormContext).push(AppRoutes.dormStatus);
      await tester.pumpAndSettle();

      expect(find.byType(DormStatusPage), findsOneWidget);
      expect(services.dormLiveStatusController.isPolling, isTrue);

      final BuildContext statusContext = tester.element(
        find.byType(DormStatusPage),
      );
      GoRouter.of(statusContext).go(AppRoutes.profile);
      await tester.pumpAndSettle();

      expect(services.dormLiveStatusController.isPolling, isFalse);
    },
  );

  testWidgets(
    'dorm page online count expires after the heartbeat window elapses',
    (WidgetTester tester) async {
      DateTime currentTime = DateTime.now();
      await _pumpApp(
        tester,
        initialLocation: AppRoutes.dorm,
        clock: () => currentTime,
      );

      final AppServices services = AppScope.of(
        tester.element(find.byType(DormPage)),
      );
      final String currentUserId = services.authRepository.currentUser.uid;

      await services.dormRepository.updateCurrentUserOnlineStatus(
        uid: currentUserId,
        online: true,
      );
      final DateTime heartbeatAt = services.dormRepository.currentDorm.members
          .firstWhere((member) => member.uid == currentUserId)
          .appLastSeenAt!;

      currentTime = heartbeatAt;
      services.dormLiveStatusController.handleAppLifecycleState(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(_findText('在线 1 人'), findsOneWidget);

      currentTime = heartbeatAt.add(const Duration(seconds: 91));
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(_findText('在线 0 人'), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required DateTime Function() clock,
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: initialLocation,
      clock: clock,
      showNightWelcomeOutsideNightInDebug: false,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _findText(String text) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is Text && widget.data == text,
  );
}
