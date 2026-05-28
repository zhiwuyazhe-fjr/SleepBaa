import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_page_insets.dart';
import 'package:sleep_dorm_app/app/theme/app_radius.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/app_typography.dart';
import 'package:sleep_dorm_app/core/interaction/app_haptics.dart';

class AppDetailPageHeader extends StatelessWidget {
  const AppDetailPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.titleKey,
    this.trailing,
    this.foregroundColor = AppColors.textPrimary,
  });

  final String title;
  final VoidCallback onBack;
  final Key? titleKey;
  final Widget? trailing;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.button,
            onTap: AppHaptics.navigationHandler(onBack),
            child: SizedBox.square(
              dimension: AppSpacing.xxxl,
              child: Icon(
                Icons.chevron_left_rounded,
                size: AppSpacing.lg,
                color: foregroundColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            title,
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sectionTitle(
              textTheme,
            ).copyWith(color: foregroundColor),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class AppDetailPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AppDetailPageAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.titleKey,
    this.trailing,
    this.foregroundColor = AppColors.textPrimary,
  });

  final String title;
  final VoidCallback onBack;
  final Key? titleKey;
  final Widget? trailing;
  final Color foregroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      elevation: 0,
      leadingWidth: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppPageInsets.horizontal,
      title: Padding(
        padding: const EdgeInsets.only(right: AppPageInsets.horizontal),
        child: AppDetailPageHeader(
          title: title,
          titleKey: titleKey,
          onBack: onBack,
          trailing: trailing,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }
}
