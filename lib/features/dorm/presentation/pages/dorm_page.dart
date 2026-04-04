import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/icon_badge.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class DormPage extends StatelessWidget {
  const DormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: services.dormRepository,
      builder: (BuildContext context, Widget? child) {
        final Dorm dorm = services.dormRepository.currentDorm;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              160,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dorm Overview',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  dorm.overview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        dorm.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: AppRadius.card,
                        ),
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.groups_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Roommate Status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '当前宿舍有 ${dorm.members.where((DormMember item) => item.sleepModeActive).length} 位成员处于睡眠模式。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: 'Invite Dormmate',
                              icon: Icons.person_add_alt_rounded,
                              onPressed: () =>
                                  context.push(AppRoutes.dormInvite),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SectionTitle(
                  title: 'Roommate Status',
                  actionLabel: '更多状态',
                  onAction: () => context.push(AppRoutes.dormStatus),
                ),
                const SizedBox(height: AppSpacing.md),
                ...dorm.members.map(
                  (DormMember roommate) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      borderRadius: AppRadius.card,
                      child: Row(
                        children: <Widget>[
                          IconBadge(
                            icon: _memberIcon(roommate.status),
                            backgroundColor: _memberColor(
                              roommate.status,
                            ).withAlpha(28),
                            iconColor: _memberColor(roommate.status),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  roommate.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  roommate.note,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: _memberColor(
                                roommate.status,
                              ).withAlpha(20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _memberLabel(roommate.status),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: _memberColor(roommate.status),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Noise / Light / Quiet Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  children: <Widget>[
                    _SignalCard(
                      icon: Icons.volume_down_rounded,
                      label: 'Noise',
                      value: '${dorm.noiseDb} dB',
                    ),
                    _SignalCard(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      value: dorm.lightLabel,
                    ),
                    _SignalCard(
                      icon: Icons.bedroom_parent_rounded,
                      label: 'Quiet',
                      value: dorm.quietLabel,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Dorm Rules',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    children: dorm.rules
                        .map(
                          (DormRule rule) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        rule.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        rule.detail,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _memberIcon(DormMemberStatus status) {
    return switch (status) {
      DormMemberStatus.sleeping => Icons.dark_mode_rounded,
      DormMemberStatus.quiet => Icons.night_shelter_rounded,
      DormMemberStatus.away => Icons.directions_walk_rounded,
      DormMemberStatus.active => Icons.campaign_rounded,
    };
  }

  Color _memberColor(DormMemberStatus status) {
    return switch (status) {
      DormMemberStatus.sleeping => AppColors.primary,
      DormMemberStatus.quiet => AppColors.success,
      DormMemberStatus.away => AppColors.textSecondary,
      DormMemberStatus.active => AppColors.warning,
    };
  }

  String _memberLabel(DormMemberStatus status) {
    return switch (status) {
      DormMemberStatus.sleeping => '睡眠中',
      DormMemberStatus.quiet => '安静中',
      DormMemberStatus.away => '不在宿舍',
      DormMemberStatus.active => '仍有活动',
    };
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const Spacer(),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
