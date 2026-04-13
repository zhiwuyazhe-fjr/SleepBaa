import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/utils/avatar_picker.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_badge_support.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_page_sections.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.authRepository,
        services.sleepSessionRepository,
        services.insightsFacade,
      ]),
      builder: (BuildContext context, Widget? child) {
        final UserProfile profile = services.authRepository.currentUser;
        final List<SleepSession> weekly = services.sleepSessionRepository
            .recentSessions();
        final DateTime now = DateTime.now();
        final DateTime currentMonth = DateTime(now.year, now.month);
        final List<SleepSession> monthSessions = services.sleepSessionRepository
            .sessionsForMonth(currentMonth);
        final SleepReport report = services.insightsFacade.currentReport;
        final List<ProfileBadgeStatusData> previewBadges =
            buildProfileBadgePreview(profile);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: ProfileHeaderSection(
                      profile: profile,
                      onAvatarTap: () => pickAndSaveAvatar(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: ProfileQuoteCard(quote: '每天都是成长和积极改变的新机会。'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ProfileDataCarousel(
                    sessions: weekly,
                    heatmapValues: _buildMonthPreviewIntensity(
                      month: currentMonth,
                      sessions: monthSessions,
                    ),
                    onHeatmapTap: () => context.push(AppRoutes.profileCalendar),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: ProfileInsightBlock(
                      report: report,
                      badges: previewBadges,
                      onReportTap: () => context.push(AppRoutes.profileReport),
                      onDreamTap: () => context.push(AppRoutes.dreamJournal),
                      onThoughtTap: () =>
                          context.push(AppRoutes.profileThoughtVault),
                      onBadgeOverviewTap: () =>
                          context.push(AppRoutes.profileBadges),
                      onBadgeTap: (ProfileBadgeStatusData badge) =>
                          showProfileBadgeDetailsSheet(
                            context,
                            badge: badge.badge,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: ProfileSettingsCard(
                      onSettingsTap: () =>
                          context.push(AppRoutes.profileSettings),
                      onFaqTap: () => context.push(AppRoutes.profileFaq),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<int> _buildMonthPreviewIntensity({
    required DateTime month,
    required List<SleepSession> sessions,
  }) {
    final Map<DateTime, int> qualityByDay = <DateTime, int>{
      for (final SleepSession session in sessions)
        DateUtils.dateOnly(session.startedAt):
            (session.summary?.sleepQuality ?? 0).clamp(0, 5),
    };
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;
    final int trailingEmpty = (7 - ((leadingEmpty + daysInMonth) % 7)) % 7;

    return <int>[
      ...List<int>.filled(leadingEmpty, 0),
      for (int day = 1; day <= daysInMonth; day++)
        qualityByDay[DateTime(month.year, month.month, day)] ?? 0,
      ...List<int>.filled(trailingEmpty, 0),
    ];
  }
}
