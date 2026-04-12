import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormEventRecord {
  const DormEventRecord({
    required this.title,
    required this.detail,
    required this.color,
    required this.timeLabel,
    required this.icon,
    this.actionRoute,
  });

  final String title;
  final String detail;
  final Color color;
  final String timeLabel;
  final IconData icon;
  final String? actionRoute;
}

List<DormEventRecord> buildDormEventRecords({
  required Dorm dorm,
  required List<NotificationItem> notifications,
  required NightMoodPalette palette,
  DateTime? now,
}) {
  final DateTime effectiveNow = now ?? DateTime.now();
  final List<DormEventRecord> records = <DormEventRecord>[];
  final List<DormEvent> sortedEvents = dorm.events.toList(growable: false)
    ..sort((DormEvent a, DormEvent b) => b.createdAt.compareTo(a.createdAt));

  for (final DormEvent event in sortedEvents.take(3)) {
    records.add(
      DormEventRecord(
        title: event.title,
        detail: event.detail,
        color: _colorForDormEvent(event, palette),
        timeLabel: _relativeTimeLabel(event.createdAt, effectiveNow),
        icon: _iconForDormEvent(event),
      ),
    );
  }

  NotificationItem? dormNotification;
  for (final NotificationItem item in notifications) {
    if (item.category == NotificationCategory.dorm) {
      dormNotification = item;
      break;
    }
  }
  if (dormNotification != null &&
      !records.any(
        (DormEventRecord item) => item.title == dormNotification!.title,
      )) {
    records.add(
      DormEventRecord(
        title: dormNotification.title,
        detail: dormNotification.body,
        color: palette.primary,
        timeLabel: _relativeTimeLabel(dormNotification.createdAt, effectiveNow),
        icon: Icons.notifications_active_rounded,
      ),
    );
  }

  if (dorm.rules.isNotEmpty) {
    records.add(
      DormEventRecord(
        title: '今晚默认执行寝室公约',
        detail: dorm.rules.first.title,
        color: const Color(0xFF63D4ED),
        timeLabel: '规则',
        icon: Icons.rule_rounded,
        actionRoute: AppRoutes.dormRules,
      ),
    );
  }

  return records.take(4).toList(growable: false);
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
    DormEventType.memberStatus => const Color(0xFFF1A936),
    DormEventType.ruleUpdate => const Color(0xFF63D4ED),
    DormEventType.notification => palette.primary,
    DormEventType.invite => const Color(0xFF5B8CFF),
    DormEventType.system => AppColors.textSecondary,
  };
}
