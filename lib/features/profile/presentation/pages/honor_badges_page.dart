import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';

class HonorBadgesPage extends StatefulWidget {
  const HonorBadgesPage({super.key});

  @override
  State<HonorBadgesPage> createState() => _HonorBadgesPageState();
}

class _HonorBadgesPageState extends State<HonorBadgesPage> {
  int _activeIndex = 0;

  static const List<_ReferenceBadge> _badges = <_ReferenceBadge>[
    _ReferenceBadge(
      label: '不醒人室',
      icon: Icons.bedtime_rounded,
      state: _ReferenceBadgeState.unlocked,
    ),
    _ReferenceBadge(
      label: '无琐事室',
      icon: Icons.handshake_rounded,
      state: _ReferenceBadgeState.unlocked,
    ),
    _ReferenceBadge(
      label: '若无其室',
      icon: Icons.door_front_door_outlined,
      state: _ReferenceBadgeState.locked,
    ),
    _ReferenceBadge(
      label: '嘘张声室',
      icon: Icons.campaign_outlined,
      state: _ReferenceBadgeState.locked,
    ),
    _ReferenceBadge(
      label: '实是囚室',
      icon: Icons.heart_broken_outlined,
      state: _ReferenceBadgeState.locked,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final _ReferenceBadge activeBadge = _badges[_activeIndex];
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
                      _HeroBadgeCard(activeBadge: activeBadge),
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                        itemCount: _badges.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: 28,
                              childAspectRatio: 0.72,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          final _ReferenceBadge badge = _badges[index];
                          final bool isActive = index == _activeIndex;
                          return _ReferenceBadgeTile(
                            badge: badge,
                            isActive: isActive,
                            onTap: badge.state == _ReferenceBadgeState.locked
                                ? null
                                : () => setState(() => _activeIndex = index),
                          );
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
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '更多荣誉室正在筹备中...',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
          _HonorHeader(onLeadingTap: () => Navigator.of(context).maybePop()),
          _HonorBottomDock(),
        ],
      ),
    );
  }
}

class _HonorHeader extends StatelessWidget {
  const _HonorHeader({required this.onLeadingTap});

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
                    Icons.menu_rounded,
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
                  '2 / 5',
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
  const _HeroBadgeCard({required this.activeBadge});

  final _ReferenceBadge activeBadge;

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
              Container(
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5A6061),
            ),
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
    this.onTap,
  });

  final _ReferenceBadge badge;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = badge.state == _ReferenceBadgeState.unlocked;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Opacity(
        opacity: unlocked ? 1 : 0.6,
        child: Column(
          children: <Widget>[
            Container(
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

class _HonorBottomDock extends StatelessWidget {
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

enum _ReferenceBadgeState { unlocked, locked }

class _ReferenceBadge {
  const _ReferenceBadge({
    required this.label,
    required this.icon,
    required this.state,
  });

  final String label;
  final IconData icon;
  final _ReferenceBadgeState state;
}
