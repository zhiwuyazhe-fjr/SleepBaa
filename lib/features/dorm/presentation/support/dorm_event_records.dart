import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormEventRecord {
  const DormEventRecord({
    required this.id,
    required this.title,
    required this.detail,
    required this.color,
    required this.timeLabel,
    required this.icon,
    required this.createdAt,
    required this.isRead,
    this.actionRoute,
    this.notificationId,
  });

  final String id;
  final String title;
  final String detail;
  final Color color;
  final String timeLabel;
  final IconData icon;
  final DateTime createdAt;
  final bool isRead;
  final String? actionRoute;
  final String? notificationId;
}

List<DormEventRecord> buildDormEventRecords({
  required Dorm dorm,
  required List<NotificationItem> notifications,
  required NightMoodPalette palette,
  DateTime? now,
  bool fullHistory = false,
}) {
  final DateTime effectiveNow = now ?? DateTime.now();
  final List<DormEventRecord> records = <DormEventRecord>[];
  final List<DormEvent> sortedEvents = dorm.events.toList(growable: false)
    ..sort((DormEvent a, DormEvent b) => b.createdAt.compareTo(a.createdAt));

  final Iterable<DormEvent> eventRecords = fullHistory
      ? sortedEvents
      : sortedEvents.take(3);
  for (final DormEvent event in eventRecords) {
    records.add(
      DormEventRecord(
        id: 'event-${event.id}',
        title: event.title,
        detail: event.detail,
        color: _colorForDormEvent(event, palette),
        timeLabel: _relativeTimeLabel(event.createdAt, effectiveNow),
        icon: _iconForDormEvent(event),
        createdAt: event.createdAt,
        isRead: false,
      ),
    );
  }

  final List<NotificationItem> dormNotifications =
      notifications
          .where(
            (NotificationItem item) =>
                item.category == NotificationCategory.dorm,
          )
          .toList(growable: false)
        ..sort(
          (NotificationItem a, NotificationItem b) =>
              b.createdAt.compareTo(a.createdAt),
        );
  final Iterable<NotificationItem> notificationRecords = fullHistory
      ? dormNotifications
      : dormNotifications.take(1);
  for (final NotificationItem dormNotification in notificationRecords) {
    if (records.any(
      (DormEventRecord item) => item.title == dormNotification.title,
    )) {
      continue;
    }
    records.add(
      DormEventRecord(
        id: 'notification-${dormNotification.id}',
        title: dormNotification.title,
        detail: dormNotification.body,
        color: palette.primary,
        timeLabel: _relativeTimeLabel(dormNotification.createdAt, effectiveNow),
        icon: Icons.notifications_active_rounded,
        createdAt: dormNotification.createdAt,
        isRead: dormNotification.isRead,
        notificationId: dormNotification.id,
        actionRoute: dormNotification.route,
      ),
    );
  }

  if (dorm.rules.isNotEmpty) {
    records.add(
      DormEventRecord(
        id: 'rule-${dorm.rules.first.id}',
        title: '今晚默认执行寝室公约',
        detail: dorm.rules.first.title,
        color: palette.primary,
        timeLabel: '规则',
        icon: Icons.rule_rounded,
        createdAt: effectiveNow,
        isRead: false,
        actionRoute: AppRoutes.dormRules,
      ),
    );
  }

  return fullHistory ? records : records.take(4).toList(growable: false);
}

String relativeDormEventTimeLabel(DateTime dateTime, {DateTime? now}) {
  return _relativeTimeLabel(dateTime, now ?? DateTime.now());
}

String _relativeTimeLabel(DateTime dateTime, DateTime now) {
  final Duration difference = now.difference(dateTime);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  return '${difference.inDays} 天前';
}

IconData _iconForDormEvent(DormEvent event) {
  return switch (event.type) {
    DormEventType.memberStatus => Icons.bedtime_rounded,
    DormEventType.ruleUpdate => Icons.rule_rounded,
    DormEventType.notification => Icons.notifications_active_rounded,
    DormEventType.invite => Icons.group_add_rounded,
    DormEventType.system => Icons.info_outline_rounded,
  };
}

Color _colorForDormEvent(DormEvent event, NightMoodPalette palette) {
  return switch (event.type) {
    DormEventType.memberStatus => palette.primary,
    DormEventType.ruleUpdate => palette.primary,
    DormEventType.notification => palette.primary,
    DormEventType.invite => palette.welcomeAccentColor,
    DormEventType.system => AppColors.textSecondary,
  };
}
