import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      appBar: AppBar(title: const Text('消息中心')),
      body: ListenableBuilder(
        listenable: services.notificationRepository,
        builder: (BuildContext context, Widget? child) {
          final List<NotificationItem> items =
              services.notificationRepository.notifications;
          final DateTime now = DateTime.now();
          final List<NotificationItem> unread = items
              .where((NotificationItem item) => !item.isRead)
              .toList();
          final List<NotificationItem> today = items
              .where(
                (NotificationItem item) =>
                    item.createdAt.year == now.year &&
                    item.createdAt.month == now.month &&
                    item.createdAt.day == now.day &&
                    item.isRead,
              )
              .toList();
          final List<NotificationItem> earlier = items
              .where(
                (NotificationItem item) =>
                    item.createdAt.day != now.day ||
                    item.createdAt.month != now.month ||
                    item.createdAt.year != now.year,
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              _NotificationSection(
                title: '待处理',
                items: unread,
                palette: palette,
                onTap: (NotificationItem item) async {
                  await services.notificationRepository.markRead(item.id);
                  if (context.mounted) {
                    context.push(item.route);
                  }
                },
              ),
              _NotificationSection(
                title: '今天',
                items: today,
                palette: palette,
                onTap: (NotificationItem item) => context.push(item.route),
              ),
              _NotificationSection(
                title: '更早',
                items: earlier,
                palette: palette,
                onTap: (NotificationItem item) => context.push(item.route),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.title,
    required this.items,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final List<NotificationItem> items;
  final NightMoodPalette palette;
  final ValueChanged<NotificationItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...items.map(
            (NotificationItem item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                onTap: () => onTap(item),
                color: item.isRead
                    ? AppColors.surface
                    : palette.primarySoft.withAlpha(45),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _colorForCategory(item.category).withAlpha(24),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _iconForCategory(item.category),
                        color: _colorForCategory(item.category),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.body,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary.withAlpha(140),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.reminder => Icons.wb_sunny_outlined,
      NotificationCategory.session => Icons.bedtime_rounded,
      NotificationCategory.dorm => Icons.night_shelter_rounded,
      NotificationCategory.system => Icons.info_outline_rounded,
    };
  }

  Color _colorForCategory(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.reminder => palette.primary,
      NotificationCategory.session => palette.calmBlue,
      NotificationCategory.dorm => palette.primaryDeep,
      NotificationCategory.system => AppColors.textSecondary,
    };
  }
}
