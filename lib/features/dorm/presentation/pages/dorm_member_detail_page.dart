import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_event_records.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_member_avatar.dart';

class DormMemberDetailPage extends StatelessWidget {
  const DormMemberDetailPage({super.key, required this.memberUid});

  final String memberUid;

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            services.authRepository,
            services.dormRepository,
            services.notificationRepository,
          ]),
          builder: (BuildContext context, Widget? child) {
            final Dorm dorm = services.dormRepository.currentDorm;
            final DormMember member = dorm.members.firstWhere(
              (DormMember item) => item.uid == memberUid,
              orElse: () => dorm.members.isNotEmpty
                  ? dorm.members.first
                  : DormMember(
                      uid: memberUid,
                      name: '舍友',
                      status: DormMemberStatus.quiet,
                      presenceStatus: DormPresenceStatus.unknown,
                      sleepModeActive: false,
                      lastActiveAt: DateTime.now(),
                      note: '暂无舍友状态',
                    ),
            );
            final UserProfile currentUser = services.authRepository.currentUser;
            final bool isCurrentUser = member.uid == currentUser.uid;
            final Uint8List? avatarBytes = isCurrentUser
                ? currentUser.avatarBytes
                : null;
            final String? avatarUrl = isCurrentUser
                ? currentUser.avatarUrl ?? member.avatarUrl
                : member.avatarUrl;
            final String fallbackSeed =
                isCurrentUser &&
                    currentUser.avatarFallbackSeed?.trim().isNotEmpty == true
                ? currentUser.avatarFallbackSeed!
                : member.name;
            final NightMoodPalette palette = context.nightMoodPalette;
            final List<DormEventRecord> memberEvents = buildDormEventRecords(
              dorm: dorm,
              notifications: services.notificationRepository.notifications,
              palette: palette,
            );

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double widthFactor = _detailWidthFactor(
                  constraints.maxWidth,
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 112),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      widthFactor: widthFactor,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.xs,
                            AppSpacing.xl,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _DormDetailHeader(
                                title: '舍友详情',
                                onBack: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Center(
                                child: _DormMemberProfileHero(
                                  member: member,
                                  showPresence: shouldShowDormPresence(
                                    dorm,
                                    member,
                                  ),
                                  avatarBytes: avatarBytes,
                                  avatarUrl: avatarUrl,
                                  fallbackSeed: fallbackSeed,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _DormMemberStatCard(
                                      value: dormPresenceSleepLabel(
                                        member,
                                        showPresence: shouldShowDormPresence(
                                          dorm,
                                          member,
                                        ),
                                      ),
                                      label: '睡眠状态',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _DormMemberStatCard(
                                      value: member.noiseDb == null
                                          ? '--'
                                          : '${member.noiseDb}dB',
                                      label: '噪声',
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: _DormMemberStatCard(
                                      value: member.appOnline ? '在线' : '离线',
                                      label: 'APP状态',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                '最近动态',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ...memberEvents.map(
                                (DormEventRecord event) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: _DormMemberActivityTile(event: event),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DormDetailHeader extends StatelessWidget {
  const _DormDetailHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.button,
            onTap: onBack,
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.chevron_left_rounded),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DormMemberProfileHero extends StatelessWidget {
  const _DormMemberProfileHero({
    required this.member,
    required this.showPresence,
    required this.fallbackSeed,
    this.avatarBytes,
    this.avatarUrl,
  });

  final DormMember member;
  final bool showPresence;
  final String fallbackSeed;
  final Uint8List? avatarBytes;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = dormPresenceSleepColor(
      member,
      showPresence: showPresence,
    );
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 3),
          ),
          child: DormMemberAvatar(
            size: 80,
            accentColor: accentColor,
            avatarBytes: avatarBytes,
            avatarUrl: avatarUrl,
            fallbackSeed: fallbackSeed,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          member.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: AppRadius.pill,
          ),
          child: Text(
            dormPresenceSleepLabel(member, showPresence: showPresence),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DormMemberStatCard extends StatelessWidget {
  const _DormMemberStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      borderRadius: AppRadius.control,
      boxShadow: const <BoxShadow>[],
      child: Column(
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DormMemberActivityTile extends StatelessWidget {
  const _DormMemberActivityTile({required this.event});

  final DormEventRecord event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderRadius: AppRadius.control,
      boxShadow: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: event.color.withAlpha(20),
              borderRadius: AppRadius.iconContainer,
            ),
            alignment: Alignment.center,
            child: Icon(event.icon, color: event.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  event.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  event.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            event.timeLabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

double _detailWidthFactor(double maxWidth) {
  if (maxWidth >= 1200) {
    return 0.38;
  }
  if (maxWidth >= 900) {
    return 0.48;
  }
  if (maxWidth >= 700) {
    return 0.68;
  }
  return 1;
}
