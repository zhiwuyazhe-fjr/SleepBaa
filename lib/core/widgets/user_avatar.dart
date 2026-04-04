import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    this.size = 72,
    this.editable = false,
    this.onTap,
  });

  final UserProfile profile;
  final double size;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primarySoft,
            AppColors.primaryHighlight,
          ],
        ),
        border: Border.all(color: AppColors.surface, width: 4),
      ),
      child: ClipOval(child: _buildContent(context)),
    );

    final Widget stack = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        avatar,
        if (editable)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
                boxShadow: AppColors.cardShadow,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.photo_camera_rounded,
                size: size * 0.14,
                color: AppColors.onDark,
              ),
            ),
          ),
      ],
    );

    if (onTap == null) {
      return stack;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: stack,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (profile.avatarBytes != null && profile.avatarBytes!.isNotEmpty) {
      return Image.memory(
        profile.avatarBytes!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }

    final String fallbackText = (profile.avatarFallbackSeed?.isNotEmpty ?? false)
        ? profile.avatarFallbackSeed!.characters.first.toUpperCase()
        : profile.displayName.characters.first.toUpperCase();

    return Container(
      color: AppColors.primarySoft.withAlpha(90),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: AppColors.primaryDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
