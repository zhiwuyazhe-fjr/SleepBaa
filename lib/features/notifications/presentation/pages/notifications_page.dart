import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/section_title.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    final NightMoodPalette palette = context.nightMoodPalette;
    return Scaffold(
      backgroundColor: AppColors.background,
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
            padding: AppPageInsets.floatingPage(bottom: 88),
            children: <Widget>[
              _NotificationOverviewCard(unreadCount: unread.length),
              const SizedBox(height: AppSpacing.sm),
              _NotificationSection(
                title: '待处理',
                items: unread,
                palette: palette,
                onTap: (NotificationItem item) async {
                  await services.notificationRepository.markRead(item.id);
                  if (context.mounted) {
                    _navigateFromNotification(context, item.route);
                  }
                },
              ),
              _NotificationSection(
                title: '今天',
                items: today,
                palette: palette,
                onTap: (NotificationItem item) =>
                    _navigateFromNotification(context, item.route),
              ),
              _NotificationSection(
                title: '更早',
                items: earlier,
                palette: palette,
                onTap: (NotificationItem item) =>
                    _navigateFromNotification(context, item.route),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionTitle(
            title: title,
            titleStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (NotificationItem item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: AppCard(
                onTap: () => onTap(item),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppSpacing.sm,
                ),
                borderRadius: AppRadius.compactCard,
                color: item.isRead
                    ? AppColors.surface
                    : AppColors.legacyCardSurface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.primaryHighlight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _iconForCategory(item.category),
                        size: 18,
                        color: _colorForCategory(item.category),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _localizedTitle(item),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _localizedBody(item),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: const Color(0xFF888888),
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
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
    return palette.primary;
  }

  String _localizedTitle(NotificationItem item) {
    if (_isLegacyMorningFeedback(item)) {
      return '晨间反馈';
    }
    return item.title;
  }

  String _localizedBody(NotificationItem item) {
    if (_isLegacyMorningFeedback(item)) {
      return '昨晚的睡眠记录已经准备好，醒来后记得补充晨间反馈。';
    }
    return item.body;
  }

  bool _isLegacyMorningFeedback(NotificationItem item) {
    if (!AppRoutes.isFeedbackMorningRoute(item.route)) {
      return false;
    }
    final String combined = '${item.title} ${item.body}'.toLowerCase();
    return RegExp(r'[a-z]').hasMatch(combined);
  }
}

void _navigateFromNotification(BuildContext context, String route) {
  if (_isShellRootRoute(route)) {
    context.go(route);
    return;
  }
  context.push(route);
}

class _NotificationOverviewCard extends StatelessWidget {
  const _NotificationOverviewCard({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = context.nightMoodPalette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: AppRadius.compactCard,
      color: AppColors.surface,
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.primaryHighlight,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_active_rounded,
              size: 18,
              color: palette.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  unreadCount > 0 ? '有 $unreadCount 条待处理消息' : '消息都已处理',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unreadCount > 0 ? '建议先查看「待处理」分组' : '今晚可以专注休息了',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF888888),
                    fontWeight: FontWeight.w400,
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

bool _isShellRootRoute(String route) {
  return route == AppRoutes.homePreSleep ||
      route == AppRoutes.dorm ||
      route == AppRoutes.profile;
}
