import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  static const ValueKey<String> navBarKey = ValueKey<String>(
    'bottom-nav-shell',
  );

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 72),
        child: AssistantFab(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          8,
        ),
        child: Container(
          key: navBarKey,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(240),
            borderRadius: AppRadius.pill,
            border: Border.all(color: Colors.white.withAlpha(170)),
            boxShadow: AppColors.floatingShadow,
          ),
          child: Row(
            children: List<Widget>.generate(_items.length, (int index) {
              final _BottomNavItem item = _items[index];
              final bool selected = index == navigationShell.currentIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _NavPillButton(
                    item: item,
                    selected: selected,
                    onTap: () => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

const List<_BottomNavItem> _items = <_BottomNavItem>[
  _BottomNavItem(
    label: '首页',
    icon: Icons.home_rounded,
    location: AppRoutes.homePreSleep,
  ),
  _BottomNavItem(
    label: '宿舍',
    icon: Icons.night_shelter_rounded,
    location: AppRoutes.dorm,
  ),
  _BottomNavItem(
    label: '我的',
    icon: Icons.person_rounded,
    location: AppRoutes.profile,
  ),
];

class _BottomNavItem {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final String location;
}

class _NavPillButton extends StatelessWidget {
  const _NavPillButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.pill,
      ),
      child: InkWell(
        borderRadius: AppRadius.pill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                item.icon,
                color: selected ? AppColors.onDark : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.onDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
