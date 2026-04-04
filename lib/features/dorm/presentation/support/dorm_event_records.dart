import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class DormEventRecord {
  const DormEventRecord({
    required this.title,
    required this.detail,
    required this.color,
    required this.timeLabel,
    required this.icon,
  });

  final String title;
  final String detail;
  final Color color;
  final String timeLabel;
  final IconData icon;
}

List<DormEventRecord> buildDormEventRecords({
  required Dorm dorm,
  required List<NotificationItem> notifications,
  required NightMoodPalette palette,
  DateTime? now,
}) {
  final DateTime effectiveNow = now ?? DateTime.now();

  NotificationItem? dormNotification;
  for (final NotificationItem item in notifications) {
    if (item.category == NotificationCategory.dorm) {
      dormNotification = item;
      break;
    }
  }

  DormMember? latestMember;
  for (final DormMember member in dorm.members) {
    if (latestMember == null ||
        member.lastActiveAt.isAfter(latestMember.lastActiveAt)) {
      latestMember = member;
    }
  }

  return <DormEventRecord>[
    if (dormNotification != null)
      DormEventRecord(
        title: dormNotification.title,
        detail: dormNotification.body,
        color: palette.primary,
        timeLabel: _relativeTimeLabel(dormNotification.createdAt, effectiveNow),
        icon: Icons.notifications_active_rounded,
      ),
    if (latestMember != null)
      DormEventRecord(
        title: '${latestMember.name} 刚刚更新了状态',
        detail: latestMember.note,
        color: const Color(0xFFF1A936),
        timeLabel: _relativeTimeLabel(latestMember.lastActiveAt, effectiveNow),
        icon: Icons.bedtime_rounded,
      ),
    if (dorm.rules.isNotEmpty)
      DormEventRecord(
        title: '今晚默认执行寝室公约',
        detail: dorm.rules.first.title,
        color: const Color(0xFF63D4ED),
        timeLabel: '规则',
        icon: Icons.rule_rounded,
      ),
  ];
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
