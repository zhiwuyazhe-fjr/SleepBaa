import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

int returnedDormMemberCount(List<DormMember> members) {
  return members
      .where(
        (DormMember member) =>
            member.presenceStatus == DormPresenceStatus.returned,
      )
      .length;
}

int sleepingDormMemberCount(List<DormMember> members) {
  return members.where((DormMember member) => member.sleepModeActive).length;
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
