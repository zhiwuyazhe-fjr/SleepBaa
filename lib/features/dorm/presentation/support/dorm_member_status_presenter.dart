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
const Duration kDormAppOnlineMaxIdle = Duration(minutes: 15);

/// Roommates considered online: same dorm list entry, app recently active.
int dormAppOnlineMemberCount(
  List<DormMember> members, {
  DateTime? now,
  Duration maxIdle = kDormAppOnlineMaxIdle,
}) {
  final DateTime clock = now ?? DateTime.now();
  return members
      .where(
        (DormMember m) =>
            clock.difference(m.lastActiveAt) <= maxIdle,
      )
      .length;
}

String dormOnlineCountLabel(List<DormMember> members) {
  return '在线 ${dormAppOnlineMemberCount(members)} 人';
}

int sleepingDormMemberCount(List<DormMember> members) {
  return members.where((DormMember member) => member.sleepModeActive).length;
}

/// Mean noise (dB) for members currently in dorm range who reported a level.
/// Falls back to [dormAggregateNoiseDb] when no per-member data exists.
double averageNoiseDbForReturnedMembers({
  required List<DormMember> members,
  required int dormAggregateNoiseDb,
}) {
  final List<DormMember> inRange = members
      .where(
        (DormMember m) => m.presenceStatus == DormPresenceStatus.returned,
      )
      .toList(growable: false);
  final List<int> levels = inRange
      .map((DormMember m) => m.noiseDb)
      .whereType<int>()
      .where((int db) => db >= 0)
      .toList(growable: false);
  if (levels.isEmpty) {
    return dormAggregateNoiseDb.toDouble();
  }
  final int sum = levels.fold<int>(0, (int a, int b) => a + b);
  return sum / levels.length;
}

String dormPresenceSleepLabel(DormMember member) {
  final String presenceLabel =
      member.presenceStatus == DormPresenceStatus.returned ? '已返' : '未返';
  final String sleepLabel = member.sleepModeActive ? '已睡' : '未睡';
  return '$presenceLabel$sleepLabel';
}

String dormActivityLabel(DormMember member) {
  return member.status == DormMemberStatus.active ? '活动中' : '安静中';
}

String dormRoommateDynamicNote(DormMember member) {
  final String note = member.note.trim();
  if (note.isEmpty || _isSleepModeNote(note)) {
    return member.presenceStatus == DormPresenceStatus.returned
        ? '已回到宿舍，状态已同步'
        : '暂时不在宿舍';
  }
  return note;
}

Color dormActivityColor(DormMember member) {
  return member.status == DormMemberStatus.active
      ? const Color(0xFFF39A3C)
      : const Color(0xFF2D9272);
}

Color dormPresenceSleepColor(DormMember member) {
  if (member.presenceStatus == DormPresenceStatus.away) {
    return const Color(0xFF8A8F9F);
  }
  if (member.sleepModeActive) {
    return const Color(0xFF4458D8);
  }
  return const Color(0xFF2D9272);
}

bool _isSleepModeNote(String note) {
  return note.contains('睡眠模式') ||
      note.contains('睡眠计时') ||
      note.contains('晨间反馈') ||
      note.contains('已睡') ||
      note.contains('未睡');
}
