import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/app_colors.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
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
    final NightMoodPalette palette = context.nightMoodPalette;
    final Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.primarySoft, palette.primaryHighlight],
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
                color: palette.primary,
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

    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      return Image.network(
        profile.avatarUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _buildFallback(context);
            },
      );
    }

    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final String fallbackText =
        (profile.avatarFallbackSeed?.isNotEmpty ?? false)
        ? profile.avatarFallbackSeed!.characters.first.toUpperCase()
        : (profile.displayName.isEmpty
              ? '?'
              : profile.displayName.characters.first.toUpperCase());

    return Container(
      color: context.nightMoodPalette.primarySoft.withAlpha(90),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: context.nightMoodPalette.primaryDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
