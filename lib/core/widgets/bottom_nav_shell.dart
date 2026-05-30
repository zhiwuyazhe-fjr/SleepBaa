import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab.dart';
import 'package:sleep_dorm_app/core/widgets/assistant_fab_dock.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  static const ValueKey<String> navBarKey = ValueKey<String>(
    'bottom-nav-shell',
  );

  final StatefulNavigationShell navigationShell;

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int? _lastSyncedIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleVisibilitySync();
  }

  @override
  void didUpdateWidget(covariant BottomNavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleVisibilitySync();
  }

  void _scheduleVisibilitySync() {
    final int currentIndex = widget.navigationShell.currentIndex;
    if (_lastSyncedIndex == currentIndex) {
      return;
    }
    _lastSyncedIndex = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.appServices.nightWelcomeController.syncHomeVisibility(
        currentIndex == 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleVisibilitySync();
    final AppServices services = context.appServices;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.nightWelcomeController,
        services.settingsRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final AppSemanticColors appColors = context.appColors;
        final bool hideShellChrome =
            widget.navigationShell.currentIndex == 0 &&
            services.nightWelcomeController.shouldShowWelcome(
              homeMode: HomeMode.preSleep,
              persistedEveningWelcomePeriodKey: services
                  .settingsRepository
                  .currentSettings
                  .eveningEncouragementPeriodKey,
            );

        return Scaffold(
          extendBody: true,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: <Widget>[
              Positioned.fill(child: widget.navigationShell),
              if (!hideShellChrome)
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    child: AssistantFabDock(child: const AssistantFab()),
                  ),
                ),
              if (!hideShellChrome)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Container(
                      key: BottomNavShell.navBarKey,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        10,
                        AppSpacing.xl,
                        22,
                      ),
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        border: Border(
                          top: BorderSide(
                            color: appColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: List<Widget>.generate(_items.length, (
                          int index,
                        ) {
                          final _BottomNavItem item = _items[index];
                          final bool selected =
                              index == widget.navigationShell.currentIndex;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _NavPillButton(
                                item: item,
                                selected: selected,
                                onTap: () => widget.navigationShell.goBranch(
                                  index,
                                  initialLocation:
                                      index ==
                                      widget.navigationShell.currentIndex,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
    final AppSemanticColors appColors = context.appColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? AppColors.darkPill : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: AppHaptics.selectionHandler(onTap),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 22 : 16,
            vertical: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                item.icon,
                color: selected ? AppColors.onDark : appColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.onDark : appColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
