import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/core/widgets/bottom_nav_shell.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/analysis/presentation/pages/interference_factor_page.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_page.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/pages/assistant_history_page.dart';
import 'package:sleep_dorm_app/features/auth/presentation/pages/phone_auth_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_invite_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_rules_page.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/pages/dorm_status_page.dart';
import 'package:sleep_dorm_app/features/dream/presentation/pages/dream_detail_page.dart';
import 'package:sleep_dorm_app/features/dream/presentation/pages/dream_journal_page.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/logs/presentation/pages/night_awakening_log_page.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/pages/night_welcome_gate_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/settings_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/sleep_report_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/thought_note_detail_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/thought_vault_page.dart';
import 'package:sleep_dorm_app/features/sleep/presentation/pages/cant_sleep_page.dart';

abstract final class AppRoutes {
  static const String root = '/';
  static const String home = '/home';
  static const String homePreSleep = '/home/pre_sleep';
  static const String homePostSleep = '/home/post_sleep';
  static const String analysisInterferenceFactors =
      '/analysis/interference_factors';
  static const String interventionTask = '/intervention/task';
  static const String feedbackMorning = '/feedback/morning';
  static const String logNightAwakening = '/log/night_awakening';
  static const String dreamDetail = '/dream/detail';
  static const String dreamJournal = '/dream/journal';
  static const String sleepCantSleep = '/sleep/cant_sleep';
  static const String dorm = '/dorm';
  static const String dormRules = '/dorm/rules';
  static const String dormInvite = '/dorm/invite';
  static const String dormStatus = '/dorm/status';
  static const String profile = '/profile';
  static const String profileReport = '/profile/report';
  static const String profileCalendar = '/profile/calendar';
  static const String profileSettings = '/profile/settings';
  static const String profileEdit = '/profile/settings/edit';
  static const String profileThoughtVault = '/profile/thought_vault';
  static const String profileThoughtDetail = '/profile/thought_detail';
  static const String notifications = '/notifications';
  static const String assistant = '/assistant';
  static const String assistantHistory = '/assistant/history';
  static const String authPhone = '/auth/phone';
}

GoRouter createRouter({
  HomeMode homeMode = HomeMode.preSleep,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.root,
        redirect: (BuildContext context, GoRouterState state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (BuildContext context, GoRouterState state) =>
            homeMode == HomeMode.postSleep
            ? AppRoutes.homePostSleep
            : AppRoutes.homePreSleep,
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return BottomNavShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.homePreSleep,
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _noTransitionPage(
                      state: state,
                      child: const NightWelcomeGatePage(),
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dorm,
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _noTransitionPage(state: state, child: const DormPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (BuildContext context, GoRouterState state) =>
                    _noTransitionPage(state: state, child: const ProfilePage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.homePostSleep,
        builder: (BuildContext context, GoRouterState state) =>
            const HomePostSleepPage(),
      ),
      GoRoute(
        path: AppRoutes.analysisInterferenceFactors,
        builder: (BuildContext context, GoRouterState state) =>
            const InterferenceFactorPage(),
      ),
      GoRoute(
        path: AppRoutes.interventionTask,
        builder: (BuildContext context, GoRouterState state) =>
            const MicroInterventionTaskPage(),
      ),
      GoRoute(
        path: AppRoutes.feedbackMorning,
        builder: (BuildContext context, GoRouterState state) =>
            const MorningFeedbackPage(),
      ),
      GoRoute(
        path: AppRoutes.logNightAwakening,
        builder: (BuildContext context, GoRouterState state) =>
            const NightAwakeningLogPage(),
      ),
      GoRoute(
        path: AppRoutes.dreamDetail,
        builder: (BuildContext context, GoRouterState state) =>
            const DreamDetailPage(),
      ),
      GoRoute(
        path: AppRoutes.dreamJournal,
        builder: (BuildContext context, GoRouterState state) =>
            const DreamJournalPage(),
      ),
      GoRoute(
        path: AppRoutes.sleepCantSleep,
        builder: (BuildContext context, GoRouterState state) =>
            const CantSleepPage(),
      ),
      GoRoute(
        path: AppRoutes.dormRules,
        builder: (BuildContext context, GoRouterState state) =>
            const DormRulesPage(),
      ),
      GoRoute(
        path: AppRoutes.dormInvite,
        builder: (BuildContext context, GoRouterState state) =>
            const DormInvitePage(),
      ),
      GoRoute(
        path: AppRoutes.dormStatus,
        builder: (BuildContext context, GoRouterState state) =>
            const DormStatusPage(),
      ),
      GoRoute(
        path: AppRoutes.profileReport,
        builder: (BuildContext context, GoRouterState state) =>
            const SleepReportPage(),
      ),
      GoRoute(
        path: AppRoutes.profileCalendar,
        builder: (BuildContext context, GoRouterState state) =>
            const CalendarCheckinPage(),
      ),
      GoRoute(
        path: AppRoutes.profileSettings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileEditPage(),
      ),
      GoRoute(
        path: AppRoutes.profileThoughtVault,
        builder: (BuildContext context, GoRouterState state) =>
            const ThoughtVaultPage(),
      ),
      GoRoute(
        path: AppRoutes.profileThoughtDetail,
        builder: (BuildContext context, GoRouterState state) {
          final SleepCaptureRecord record = state.extra! as SleepCaptureRecord;
          return ThoughtNoteDetailPage(record: record);
        },
      ),
      GoRoute(
        path: AppRoutes.assistant,
        builder: (BuildContext context, GoRouterState state) {
          final bool captureModeEnabled =
              state.uri.queryParameters['flow'] == 'sleep_capture';
          final AssistantCaptureTab initialTab =
              state.uri.queryParameters['mode'] == 'memo'
              ? AssistantCaptureTab.memo
              : AssistantCaptureTab.dream;
          return AssistantPage(
            captureModeEnabled: captureModeEnabled,
            initialCaptureTab: initialTab,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.assistantHistory,
        builder: (BuildContext context, GoRouterState state) =>
            const AssistantHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.authPhone,
        builder: (BuildContext context, GoRouterState state) =>
            const PhoneAuthPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsPage(),
      ),
    ],
  );
}

NoTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
