import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';

class DormStatusPage extends StatelessWidget {
  const DormStatusPage({super.key});

  static const ValueKey<String> timelineKey = ValueKey<String>(
    'dorm-status-timeline',
  );

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      appBar: AppBar(title: const Text('寝室状态记录')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.dormRepository,
            services.notificationRepository,
          ]),
          builder: (BuildContext context, Widget? child) {
            final NightMoodPalette palette = context.nightMoodPalette;
            final Dorm dorm = services.dormRepository.currentDorm;
            final List<DormEventRecord> events = buildDormEventRecords(
              dorm: dorm,
              notifications: services.notificationRepository.notifications,
              palette: palette,
            );
            final int sleepingCount = sleepingDormMemberCount(dorm.members);
            final String onlineLabel = dormOnlineCountLabel(dorm.members);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                96,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppCard(
                    padding: EdgeInsets.zero,
                    boxShadow: AppColors.floatingShadow,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            palette.heroGradientStart,
                            palette.heroGradientMid,
                            palette.heroGradientEnd,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            dorm.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.onDark,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            dorm.overview,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.onDark.withAlpha(196),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              _SummaryChip(label: onlineLabel),
                              _SummaryChip(label: '睡眠中 $sleepingCount 人'),
                              _SummaryChip(label: '安静 ${dorm.quietLabel}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionTitle(
                    title: '状态记录',
                    actionLabel: '宿舍公约',
                    onAction: () => context.push(AppRoutes.dormRules),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    key: timelineKey,
                    children: events
                        .map(
                          (DormEventRecord event) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _StatusEventCard(event: event),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle(title: '当前室友状态'),
                  const SizedBox(height: AppSpacing.md),
                  ...dorm.members.map(
                    (DormMember member) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        boxShadow: const <BoxShadow>[],
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dormPresenceSleepColor(
                                  member,
                                ).withAlpha(24),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                member.name.characters.first,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: dormPresenceSleepColor(member),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    member.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    member.note,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dormPresenceSleepColor(
                                      member,
                                    ).withAlpha(18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    dormPresenceSleepLabel(member),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: dormPresenceSleepColor(member),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dormActivityColor(
                                      member,
                                    ).withAlpha(18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    dormActivityLabel(member),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: dormActivityColor(member),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle(title: '环境状态'),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Column(
                      children: <Widget>[
                        _EnvironmentRow(
                          icon: Icons.volume_down_rounded,
                          label: '噪音',
                          value: '${dorm.noiseDb} dB',
                        ),
                        const Divider(height: AppSpacing.xl),
                        _EnvironmentRow(
                          icon: Icons.light_mode_rounded,
                          label: '灯光',
                          value: dorm.lightLabel,
                        ),
                        const Divider(height: AppSpacing.xl),
                        _EnvironmentRow(
                          icon: Icons.bedroom_parent_rounded,
                          label: '安静状态',
                          value: dorm.quietLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusEventCard extends StatelessWidget {
  const _StatusEventCard({required this.event});

  final DormEventRecord event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceMuted,
      boxShadow: const <BoxShadow>[],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: event.color.withAlpha(24),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(event.icon, color: event.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      event.timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
