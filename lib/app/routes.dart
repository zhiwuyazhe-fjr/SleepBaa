import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/core/data/repositories.dart';
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
import 'package:sleep_dorm_app/features/home/presentation/pages/home_quick_actions_edit_page.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_post_sleep_page.dart';
import 'package:sleep_dorm_app/features/intervention/presentation/pages/micro_intervention_task_page.dart';
import 'package:sleep_dorm_app/features/logs/presentation/pages/night_awakening_log_page.dart';
import 'package:sleep_dorm_app/features/night_mood/presentation/pages/night_welcome_gate_page.dart';
import 'package:sleep_dorm_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/calendar_checkin_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/honor_badges_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_badges_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_account_pages.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_account_reset_password_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_faq_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/settings_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/sleep_report_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/thought_note_detail_page.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/thought_vault_page.dart';
import 'package:sleep_dorm_app/features/sleep/presentation/pages/cant_sleep_page.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_category_page.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_page.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_topic_page.dart';

abstract final class AppRoutes {
  static const String root = '/';
  static const String home = '/home';
  static const String homePreSleep = '/home/pre_sleep';
  static const String homePostSleep = '/home/post_sleep';
  static const String homeQuickActionsEdit = '/home/quick_actions/edit';
  static const String feedbackReceivedNotice = 'feedback_received';
  static const String feedbackSubmittedNotice = 'feedback_submitted';
  static const String analysisInterferenceFactors =
      '/analysis/interference_factors';
  static const String interventionTask = '/intervention/task';
  static const String feedbackMorning = '/feedback/morning';
  static const String logNightAwakening = '/log/night_awakening';
  static const String dreamDetail = '/dream/detail';
  static const String dreamJournal = '/dream/journal';
  static const String sleepCantSleep = '/sleep/cant_sleep';
  static const String sleepEncyclopedia = '/sleep/encyclopedia';
  static const String sleepEncyclopediaCategory =
      '/sleep/encyclopedia/category';
  static const String sleepEncyclopediaTopic = '/sleep/encyclopedia/topic';
  static const String dorm = '/dorm';
  static const String dormRules = '/dorm/rules';
  static const String dormInvite = '/dorm/invite';
  static const String dormStatus = '/dorm/status';
  static const String dormBadges = '/dorm/badges';
  static const String profile = '/profile';
  static const String profileBadges = '/profile/badges';
  static const String profileReport = '/profile/report';
  static const String profileCalendar = '/profile/calendar';
  static const String profileSettings = '/profile/settings';
  static const String profileAccountCenter = '/profile/settings/account';
  static const String profileAccountProfile =
      '/profile/settings/account/profile';
  static const String profileEdit = '/profile/settings/account/profile/edit';
  static const String profileEditLegacy = '/profile/settings/edit';
  static const String profileAccountPassword =
      '/profile/settings/account/password';
  static const String profileAccountLogin = '/profile/settings/account/login';
  static const String profileAccountDorm = '/profile/settings/account/dorm';
  static const String profileFaq = '/profile/faq';
  static const String profileThoughtVault = '/profile/thought_vault';
  static const String profileThoughtDetail = '/profile/thought_detail';
  static const String notifications = '/notifications';
  static const String assistant = '/assistant';
  static const String assistantHistory = '/assistant/history';
  static const String authPhone = '/auth/phone';

  static String homePreSleepLocation({String? notice}) {
    final String normalizedNotice = notice?.trim() ?? '';
    if (normalizedNotice.isEmpty) {
      return homePreSleep;
    }
    return Uri(
      path: homePreSleep,
      queryParameters: <String, String>{'notice': normalizedNotice},
    ).toString();
  }

  static String feedbackMorningLocation({
    String? sessionId,
    bool resumeToSleep = false,
  }) {
    final String normalizedSessionId = sessionId?.trim() ?? '';
    if (normalizedSessionId.isEmpty && !resumeToSleep) {
      return feedbackMorning;
    }
    final Map<String, String> queryParameters = <String, String>{
      if (normalizedSessionId.isNotEmpty) 'sessionId': normalizedSessionId,
      if (resumeToSleep) 'resumeToSleep': '1',
    };
    return Uri(
      path: feedbackMorning,
      queryParameters: queryParameters,
    ).toString();
  }

  static String assistantSleepCaptureLocation({
    required AssistantCaptureTab mode,
    String? sessionId,
    bool allowSessionRepair = false,
  }) {
    final String normalizedSessionId = sessionId?.trim() ?? '';
    return Uri(
      path: assistant,
      queryParameters: <String, String>{
        'flow': 'sleep_capture',
        'mode': mode == AssistantCaptureTab.memo ? 'memo' : 'dream',
        if (normalizedSessionId.isNotEmpty) 'sessionId': normalizedSessionId,
        if (allowSessionRepair) 'repairSession': '1',
      },
    ).toString();
  }

  static bool isFeedbackMorningRoute(String route) {
    final Uri? parsed = Uri.tryParse(route);
    return (parsed?.path ?? route) == feedbackMorning;
  }

  static String sleepEncyclopediaCategoryLocation(String slug) {
    return Uri(
      path: sleepEncyclopediaCategory,
      queryParameters: <String, String>{'slug': slug},
    ).toString();
  }

  static String sleepEncyclopediaTopicLocation(String slug) {
    return Uri(
      path: sleepEncyclopediaTopic,
      queryParameters: <String, String>{'slug': slug},
    ).toString();
  }
}

GoRouter createRouter({
  required bool usesCloudBase,
  required AuthRepository authRepository,
  required SleepSessionRepository sleepSessionRepository,
  HomeMode homeMode = HomeMode.preSleep,
  String initialLocation = AppRoutes.home,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge(<Listenable>[
      authRepository,
      sleepSessionRepository,
    ]),
    redirect: (BuildContext context, GoRouterState state) {
      if (usesCloudBase) {
        if (!authRepository.hasCompletedInitialAuthBootstrap ||
            authRepository.isAuthenticating) {
          return null;
        }

        final bool isAuthRoute = state.uri.path == AppRoutes.authPhone;
        final bool hasVerifiedPhoneIdentity =
            authRepository.hasVerifiedPhoneIdentity == true;
        if (!hasVerifiedPhoneIdentity && !isAuthRoute) {
          return AppRoutes.authPhone;
        }
      }

      if (shouldRedirectToActiveSleepMode(
        location: state.uri.toString(),
        activeSession: sleepSessionRepository.activeSession,
      )) {
        return AppRoutes.homePostSleep;
      }
      return null;
    },
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
                      child: NightWelcomeGatePage(
                        notice: state.uri.queryParameters['notice'],
                      ),
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
        path: AppRoutes.homeQuickActionsEdit,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeQuickActionsEditPage(),
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
        builder: (BuildContext context, GoRouterState state) => MorningFeedbackPage(
          key: ValueKey<String>(
            '${state.uri.queryParameters['sessionId'] ?? '__latest__'}:'
            '${state.uri.queryParameters['resumeToSleep'] == '1' ? 'resume' : 'plain'}',
          ),
          sessionId: state.uri.queryParameters['sessionId'],
          allowReturnToSleep: state.uri.queryParameters['resumeToSleep'] == '1',
        ),
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
        path: AppRoutes.sleepEncyclopedia,
        builder: (BuildContext context, GoRouterState state) =>
            const SleepEncyclopediaPage(),
      ),
      GoRoute(
        path: AppRoutes.sleepEncyclopediaCategory,
        builder: (BuildContext context, GoRouterState state) =>
            SleepEncyclopediaCategoryPage(
              categorySlug: state.uri.queryParameters['slug'] ?? '',
            ),
      ),
      GoRoute(
        path: AppRoutes.sleepEncyclopediaTopic,
        builder: (BuildContext context, GoRouterState state) =>
            SleepEncyclopediaTopicPage(
              topicSlug: state.uri.queryParameters['slug'] ?? '',
            ),
      ),
      GoRoute(
        path: AppRoutes.dormRules,
        builder: (BuildContext context, GoRouterState state) => DormRulesPage(
          showReviewOverlayOnOpen: state.uri.queryParameters['review'] == '1',
        ),
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
        path: AppRoutes.dormBadges,
        builder: (BuildContext context, GoRouterState state) =>
            const HonorBadgesPage(),
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
        path: AppRoutes.profileAccountCenter,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountManagementPage(),
      ),
      GoRoute(
        path: AppRoutes.profileAccountProfile,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.profileEditLegacy,
        redirect: (BuildContext context, GoRouterState state) =>
            AppRoutes.profileEdit,
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileEditPage(),
      ),
      GoRoute(
        path: AppRoutes.profileAccountPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const AccountResetPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.profileAccountLogin,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginManagementPage(),
      ),
      GoRoute(
        path: AppRoutes.profileAccountDorm,
        builder: (BuildContext context, GoRouterState state) =>
            const DormManagementPage(),
      ),
      GoRoute(
        path: AppRoutes.profileFaq,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileFaqPage(),
      ),
      GoRoute(
        path: AppRoutes.profileBadges,
        builder: (BuildContext context, GoRouterState state) =>
            const ProfileBadgesPage(),
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
            captureSessionId: state.uri.queryParameters['sessionId'],
            allowCaptureSessionRepair:
                state.uri.queryParameters['repairSession'] == '1',
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

bool shouldRedirectToActiveSleepMode({
  required String location,
  required SleepSession? activeSession,
}) {
  final Uri? uri = Uri.tryParse(location);
  final String path = uri?.path.isNotEmpty == true ? uri!.path : location;
  final bool isSleepModeEntryRoute =
      path == AppRoutes.root ||
      path == AppRoutes.home ||
      path == AppRoutes.homePreSleep;
  if (!isSleepModeEntryRoute) {
    return false;
  }
  return isActiveSleepModeSession(activeSession);
}

bool isActiveSleepModeSession(SleepSession? session) {
  return session != null &&
      session.status == SleepSessionStatus.active &&
      session.sleepModeActive &&
      session.endedAt == null;
}

NoTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
