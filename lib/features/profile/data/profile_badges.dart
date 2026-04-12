import 'package:flutter/material.dart';

class ProfileBadgeMeta {
  const ProfileBadgeMeta({
    required this.id,
    required this.title,
    required this.summary,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String id;
  final String title;
  final String summary;
  final String description;
  final IconData icon;
  final bool unlocked;
}

abstract final class ProfileBadges {
  static const List<ProfileBadgeMeta> all = <ProfileBadgeMeta>[
    ProfileBadgeMeta(
      id: 'first-week',
      title: '首周达成',
      summary: '连续完成首周睡眠记录。',
      description: '连续一周保持记录，是建立睡眠节律最重要的第一步。',
      icon: Icons.military_tech_rounded,
      unlocked: true,
    ),
    ProfileBadgeMeta(
      id: 'early-sleeper',
      title: '早睡先锋',
      summary: '最近一段时间更稳定地提前入睡。',
      description: '当你持续把入睡时间往前推进时，这枚勋章会提醒你已经建立起更温和的夜间节奏。',
      icon: Icons.rocket_launch_rounded,
      unlocked: true,
    ),
    ProfileBadgeMeta(
      id: 'calm-master',
      title: '安眠大师',
      summary: '多次达成更平稳、少夜醒的夜晚。',
      description: '安静的环境、合适的睡前准备和稳定的作息，一起帮助你拿到这枚勋章。',
      icon: Icons.dark_mode_rounded,
      unlocked: true,
    ),
    ProfileBadgeMeta(
      id: 'monthly-perfect',
      title: '月度全勤',
      summary: '整月保持记录与反馈。',
      description: '这枚勋章代表长期坚持。当前仍在筹备更完整的达成规则，所以先作为待解锁目标展示。',
      icon: Icons.lock_rounded,
      unlocked: false,
    ),
  ];

  static ProfileBadgeMeta? byId(String id) {
    for (final ProfileBadgeMeta badge in all) {
      if (badge.id == id) {
        return badge;
      }
    }
    return null;
  }
}
