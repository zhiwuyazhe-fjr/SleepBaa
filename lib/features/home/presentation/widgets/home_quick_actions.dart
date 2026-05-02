import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class HomeQuickActionDefinition {
  const HomeQuickActionDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.location,
  });

  final String id;
  final String label;
  final IconData icon;
  final String location;

  void open(BuildContext context) {
    context.push(location);
  }
}

const List<HomeQuickActionDefinition> kHomeQuickActionCatalog =
    <HomeQuickActionDefinition>[
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.sleepMusic,
        label: '音乐',
        icon: Icons.music_note_rounded,
        location: AppRoutes.sleepAudioCatalog,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.dreamJournal,
        label: '梦记一则',
        icon: Icons.auto_stories_rounded,
        location: AppRoutes.dreamJournal,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.profileCalendar,
        label: '打卡日历',
        icon: Icons.calendar_month_rounded,
        location: AppRoutes.profileCalendar,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.sleepEncyclopedia,
        label: '睡眠百科',
        icon: Icons.menu_book_rounded,
        location: AppRoutes.sleepEncyclopedia,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.thoughtClean,
        label: '思绪清理',
        icon: Icons.psychology_alt_rounded,
        location: '${AppRoutes.assistant}?flow=sleep_capture&mode=memo',
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.thoughtVault,
        label: '事记仓库',
        icon: Icons.inventory_2_rounded,
        location: AppRoutes.profileThoughtVault,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.profileBadges,
        label: '我的勋章',
        icon: Icons.workspace_premium_rounded,
        location: AppRoutes.profileBadges,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.profileReport,
        label: '实验报告',
        icon: Icons.science_rounded,
        location: AppRoutes.profileReport,
      ),
      HomeQuickActionDefinition(
        id: HomeQuickActionIds.profileSettings,
        label: '设置',
        icon: Icons.settings_rounded,
        location: AppRoutes.profileSettings,
      ),
    ];

HomeQuickActionDefinition homeQuickActionDefinitionFor(String id) {
  return kHomeQuickActionCatalog.firstWhere(
    (HomeQuickActionDefinition action) => action.id == id,
  );
}

List<HomeQuickActionDefinition> homeQuickActionDefinitionsFor(
  Iterable<String> ids,
) {
  return normalizeHomeQuickActionIds(
    ids,
  ).map(homeQuickActionDefinitionFor).toList(growable: false);
}
