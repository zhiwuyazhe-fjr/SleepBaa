import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/models/avatar_resource.dart';
import 'package:sleep_dorm_app/core/widgets/avatar_image.dart';

class DormMemberAvatar extends StatelessWidget {
  const DormMemberAvatar({
    super.key,
    required this.size,
    required this.accentColor,
    required this.fallbackSeed,
    required this.resource,
  });

  final double size;
  final Color accentColor;
  final AvatarResource resource;
  final String fallbackSeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withAlpha(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: AvatarImage(
        resource: resource,
        width: size,
        height: size,
        fallbackBuilder: _buildFallback,
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final String fallbackText = fallbackSeed.trim().isEmpty
        ? '?'
        : fallbackSeed.characters.first.toUpperCase();
    return Container(
      color: accentColor.withAlpha(18),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
