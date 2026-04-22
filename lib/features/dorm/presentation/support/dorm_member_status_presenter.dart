import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

/// Members currently within the dorm geofence ("已返").
int returnedDormMemberCount(List<DormMember> members) {
  return members
      .where(
        (DormMember member) =>
            member.presenceStatus == DormPresenceStatus.returned,
      )
      .length;
}

/// Max idle duration to still count as "APP 在线" (recent heartbeat).
const Duration kDormAppOnlineMaxIdle = Duration(seconds: 90);

/// Roommates considered online: same dorm list entry with a fresh app heartbeat.
int dormAppOnlineMemberCount(
  List<DormMember> members, {
  DateTime? now,
  Duration maxIdle = kDormAppOnlineMaxIdle,
}) {
  final DateTime clock = now ?? DateTime.now();
  return members
      .where(
        (DormMember member) =>
            member.appOnline &&
            member.appLastSeenAt != null &&
            clock.difference(member.appLastSeenAt!) <= maxIdle,
      )
      .length;
}

String dormOnlineCountLabel(List<DormMember> members, {DateTime? now}) {
  return '在线 ${dormAppOnlineMemberCount(members, now: now)} 人';
}

int sleepingDormMemberCount(List<DormMember> members) {
  return members.where((DormMember member) => member.sleepModeActive).length;
}

/// Mean noise (dB) for members currently in dorm range who reported a level.
/// Falls back to [dormAggregateNoiseDb] when no per-member data exists.
double averageNoiseDbForReturnedMembers({
  required List<DormMember> members,
  required int dormAggregateNoiseDb,
  bool showPresence = true,
}) {
  if (!showPresence) {
    return dormAggregateNoiseDb.toDouble();
  }
  final List<DormMember> inRange = members
      .where((DormMember member) {
        return member.presenceStatus == DormPresenceStatus.returned;
      })
      .toList(growable: false);
  final List<int> levels = inRange
      .map((DormMember member) => member.noiseDb)
      .whereType<int>()
      .where((int db) => db >= 0)
      .toList(growable: false);
  if (levels.isEmpty) {
    return dormAggregateNoiseDb.toDouble();
  }
  final int sum = levels.fold<int>(0, (int a, int b) => a + b);
  return sum / levels.length;
}

bool shouldShowDormPresence(Dorm dorm, DormMember member) {
  return dorm.locationAnchor != null &&
      member.presenceStatus != DormPresenceStatus.unknown;
}

String dormPresenceSleepLabel(DormMember member, {bool showPresence = true}) {
  final String sleepLabel = member.sleepModeActive ? '已睡' : '未睡';
  if (!showPresence || member.presenceStatus == DormPresenceStatus.unknown) {
    return sleepLabel;
  }
  final String presenceLabel =
      member.presenceStatus == DormPresenceStatus.returned ? '已返' : '未返';
  return '$presenceLabel$sleepLabel';
}

String dormActivityLabel(DormMember member) {
  return member.status == DormMemberStatus.active ? '活动中' : '安静中';
}

Color dormActivityColor(DormMember member) {
  return member.status == DormMemberStatus.active
      ? const Color(0xFFF39A3C)
      : const Color(0xFF2D9272);
}

Color dormPresenceSleepColor(DormMember member, {bool showPresence = true}) {
  if (!showPresence || member.presenceStatus == DormPresenceStatus.unknown) {
    return member.sleepModeActive
        ? const Color(0xFF4458D8)
        : const Color(0xFF8A8F9F);
  }
  if (member.presenceStatus == DormPresenceStatus.away) {
    return const Color(0xFF8A8F9F);
  }
  if (member.sleepModeActive) {
    return const Color(0xFF4458D8);
  }
  return const Color(0xFF2D9272);
}
