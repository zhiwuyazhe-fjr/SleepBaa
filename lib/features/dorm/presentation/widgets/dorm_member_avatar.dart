import 'dart:typed_data';

import 'package:flutter/material.dart';

class DormMemberAvatar extends StatelessWidget {
  const DormMemberAvatar({
    super.key,
    required this.size,
    required this.accentColor,
    required this.fallbackSeed,
    this.avatarBytes,
    this.avatarUrl,
  });

  final double size;
  final Color accentColor;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
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
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (avatarBytes != null && avatarBytes!.isNotEmpty) {
      return Image.memory(
        avatarBytes!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return Image.network(
        avatarUrl!,
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
