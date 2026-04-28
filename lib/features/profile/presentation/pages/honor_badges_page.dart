import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/modals/app_modal.dart';

class HonorBadgesPage extends StatefulWidget {
  const HonorBadgesPage({super.key});

  @override
  State<HonorBadgesPage> createState() => _HonorBadgesPageState();
}

class _HonorBadgesPageState extends State<HonorBadgesPage> {
  bool? _pendingShowDormPulseBadge;
  bool _hasPendingDormBadgeSelection = false;
  String? _pendingSelectedDormBadgeId;

  void _showMeaningSheet(BuildContext context, DormHonorBadge badge) {
    showAppModal<void>(
      context,
      spec: AppDetailSheetSpec<void>(
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          return SafeArea(
            top: false,
            child: AppBottomSheetScaffold(
              key: const ValueKey<String>('app-bottom-sheet-detail'),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppBottomSheetCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFA0F2E0),
                            ),
                            child: Icon(
                              badge.icon,
                              color: const Color(0xFF076B5E),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              badge.label,
                              style: Theme.of(sheetContext).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2E3334),
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        badge.meaning,
                        style: Theme.of(sheetContext).textTheme.bodyLarge
                            ?.copyWith(
                              color: const Color(0xFF5A6061),
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.appServices;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.authRepository,
        services.dormRepository,
      ]),
      builder: (BuildContext context, Widget? child) {
        final UserProfile profile = services.authRepository.currentUser;
        final Dorm dorm = services.dormRepository.currentDorm;
        final String? latestBadgeId = dorm.latestEarnedDormBadgeId;
        final bool effectiveShowDormPulseBadge =
            _pendingShowDormPulseBadge ?? profile.showDormPulseBadge;
        final String? preferredDormBadgeId = _hasPendingDormBadgeSelection
            ? _pendingSelectedDormBadgeId
            : profile.selectedDormBadgeId;
        final String resolvedPreviewId =
            preferredDormBadgeId != null &&
                dorm.hasEarnedDormBadge(preferredDormBadgeId)
            ? preferredDormBadgeId
            : latestBadgeId ?? kDormHonorBadgeCatalog.first.id;
        final DormHonorBadge activeBadge =
            dormHonorBadgeById(resolvedPreviewId) ??
            kDormHonorBadgeCatalog.first;
        final int unlockedCount = dorm.earnedDormBadgeIds.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9F9),
          body: Stack(
            children: <Widget>[
              CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        96,
                        AppSpacing.xl,
                        150,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _HeroBadgeCard(
                            activeBadge: activeBadge,
                            onIconTap: () =>
                                _showMeaningSheet(context, activeBadge),
                          ),
                          const SizedBox(height: 48),
                          Row(
                            children: <Widget>[
                              Text(
                                '勋章成就',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                '点击勋章查看详情',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xFF5A6061),
                                      fontSize: 11,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: kDormHonorBadgeCatalog.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: AppSpacing.sm,
                                  mainAxisSpacing: 28,
                                  childAspectRatio: 0.72,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final DormHonorBadge badge =
                                  kDormHonorBadgeCatalog[index];
                              final bool unlocked = dorm.hasEarnedDormBadge(
                                badge.id,
                              );
                              final bool isActive = badge.id == activeBadge.id;
                              return _ReferenceBadgeTile(
                                badge: badge,
                                isActive: isActive,
                                unlocked: unlocked,
                                onTap: unlocked
                                    ? () async {
                                        setState(() {
                                          _hasPendingDormBadgeSelection = true;
                                          _pendingSelectedDormBadgeId =
                                              badge.id;
                                        });
                                        try {
                                          await services.profileFacade
                                              .saveDormBadgeSelection(badge.id);
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _hasPendingDormBadgeSelection =
                                                  false;
                                            });
                                          }
                                        }
                                      }
                                    : null,
                                onIconTap: () =>
                                    _showMeaningSheet(context, badge),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  profile.selectedDormBadgeId == null &&
                                          !_hasPendingDormBadgeSelection
                                      ? '当前默认同步最新获得的宿舍勋章'
                                      : '当前仅对你显示：${activeBadge.label}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF5A6061),
                                      ),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    (profile.selectedDormBadgeId == null &&
                                        !_hasPendingDormBadgeSelection)
                                    ? null
                                    : () async {
                                        setState(() {
                                          _hasPendingDormBadgeSelection = true;
                                          _pendingSelectedDormBadgeId = null;
                                        });
                                        try {
                                          await services.profileFacade
                                              .saveDormBadgeSelection(null);
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _hasPendingDormBadgeSelection =
                                                  false;
                                            });
                                          }
                                        }
                                      },
                                child: const Text('恢复默认最新勋章'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          _DormPulseBadgeVisibilityCard(
                            value: effectiveShowDormPulseBadge,
                            badgeLabel: activeBadge.label,
                            onChanged: (bool value) async {
                              setState(() {
                                _pendingShowDormPulseBadge = value;
                              });
                              try {
                                await services.profileFacade
                                    .setDormPulseBadgeVisibility(value);
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _pendingShowDormPulseBadge = null;
                                  });
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 56),
                          Center(
                            child: Column(
                              children: <Widget>[
                                Container(
                                  width: 48,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDEE3E4),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xl,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '更多荣誉室正在筹备中...',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0x805A6061),
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _HonorHeader(
                countLabel: '$unlockedCount / ${kDormHonorBadgeCatalog.length}',
                onLeadingTap: () => Navigator.of(context).maybePop(),
              ),
              const _HonorBottomDock(),
            ],
          ),
        );
      },
    );
  }
}

class _HonorHeader extends StatelessWidget {
  const _HonorHeader({required this.countLabel, required this.onLeadingTap});

  final String countLabel;
  final VoidCallback onLeadingTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          color: const Color(0xCCF8F9F9),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: onLeadingTap,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF076B5E),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '荣誉勋章',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF0F3A34),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E9E9),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Text(
                  countLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF076B5E),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadgeCard extends StatelessWidget {
  const _HeroBadgeCard({required this.activeBadge, required this.onIconTap});

  final DormHonorBadge activeBadge;
  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onIconTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFA0F2E0),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x26076B5E),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      activeBadge.icon,
                      size: 48,
                      color: const Color(0xFF076B5E),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF076B5E),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    'Active',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFE3FFF7),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            '当前佩戴',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5A6061)),
          ),
          const SizedBox(height: 4),
          Text(
            activeBadge.label,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E3334),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceBadgeTile extends StatelessWidget {
  const _ReferenceBadgeTile({
    required this.badge,
    required this.isActive,
    required this.unlocked,
    required this.onIconTap,
    this.onTap,
  });

  final DormHonorBadge badge;
  final bool isActive;
  final bool unlocked;
  final VoidCallback onIconTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: unlocked ? 1 : 0.6,
        child: Column(
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onIconTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? isActive
                              ? const Color(0xFFA0F2E0)
                              : const Color(0x66A0F2E0)
                        : const Color(0xFFE5E9E9),
                    border: isActive
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    boxShadow: isActive
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x26076B5E),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: Icon(
                    badge.icon,
                    size: 28,
                    color: unlocked
                        ? const Color(0xFF076B5E)
                        : const Color(0xFF767C7D),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2E3334),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? '当前佩戴'
                  : unlocked
                  ? '点击佩戴'
                  : '未获得',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive
                    ? const Color(0xFF076B5E)
                    : unlocked
                    ? const Color(0xFF406C64)
                    : const Color(0xFF5A6061),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DormPulseBadgeVisibilityCard extends StatelessWidget {
  const _DormPulseBadgeVisibilityCard({
    required this.value,
    required this.badgeLabel,
    required this.onChanged,
  });

  final bool value;
  final String badgeLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '宿舍脉搏勋章显示',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E3334),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '在宿舍脉搏右上角显示最新宿舍勋章：$badgeLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5A6061),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HonorBottomDock extends StatelessWidget {
  const _HonorBottomDock();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: Center(
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.9,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _DockItem(
                  icon: Icons.home_outlined,
                  label: '首页',
                  selected: false,
                  onTap: () => context.go(AppRoutes.homePreSleep),
                ),
                _DockItem(
                  icon: Icons.apartment_outlined,
                  label: '宿舍',
                  selected: false,
                  onTap: () => context.go(AppRoutes.dorm),
                ),
                _DockItem(
                  icon: Icons.person,
                  label: '我的',
                  selected: true,
                  onTap: () => context.go(AppRoutes.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          color: selected ? const Color(0xFF0F3A34) : const Color(0xFF8A8F9F),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? const Color(0xFF0F3A34) : const Color(0xFF8A8F9F),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          decoration: selected
              ? BoxDecoration(
                  color: const Color(0xFFE4F6F1),
                  borderRadius: BorderRadius.circular(999),
                )
              : null,
          child: content,
        ),
      ),
    );
  }
}
