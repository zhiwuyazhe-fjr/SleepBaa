import 'dart:typed_data';

import 'package:flutter/material.dart';

class DormMemberAvatar extends StatefulWidget {
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
  State<DormMemberAvatar> createState() => _DormMemberAvatarState();
}

class _DormMemberAvatarState extends State<DormMemberAvatar> {
  Uint8List? _lastAvatarBytes;
  String? _lastAvatarUrl;

  @override
  void initState() {
    super.initState();
    _rememberLatestAvatar();
  }

  @override
  void didUpdateWidget(DormMemberAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberLatestAvatar();
  }

  void _rememberLatestAvatar() {
    if (widget.avatarBytes != null && widget.avatarBytes!.isNotEmpty) {
      _lastAvatarBytes = widget.avatarBytes;
      _lastAvatarUrl = null;
      return;
    }
    final String? nextUrl = widget.avatarUrl?.trim();
    if (nextUrl != null && nextUrl.isNotEmpty) {
      _lastAvatarUrl = nextUrl;
      _lastAvatarBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accentColor.withAlpha(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final Uint8List? currentBytes =
        widget.avatarBytes != null && widget.avatarBytes!.isNotEmpty
        ? widget.avatarBytes
        : null;
    final String? currentUrl = widget.avatarUrl?.trim();
    final String? normalizedCurrentUrl =
        currentUrl != null && currentUrl.isNotEmpty ? currentUrl : null;
    final Uint8List? displayedBytes = currentBytes ?? _lastAvatarBytes;
    final String? displayedUrl = normalizedCurrentUrl ?? _lastAvatarUrl;

    if (displayedBytes != null && displayedBytes.isNotEmpty) {
      return Image.memory(
        displayedBytes,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        gaplessPlayback: true,
      );
    }
    if (displayedUrl != null && displayedUrl.trim().isNotEmpty) {
      return Image.network(
        displayedUrl,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
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
    final String fallbackText = widget.fallbackSeed.trim().isEmpty
        ? '?'
        : widget.fallbackSeed.characters.first.toUpperCase();
    return Container(
      color: widget.accentColor.withAlpha(18),
      alignment: Alignment.center,
      child: Text(
        fallbackText,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: widget.accentColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
