import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/core/models/avatar_resource.dart';

/// Shared avatar image renderer for user and dorm-member avatars.
///
/// It treats remote URLs as replaceable credentials. A refreshed URL is used
/// immediately, while a failed request is retried after the app resumes.
class AvatarImage extends StatefulWidget {
  const AvatarImage({
    super.key,
    required this.resource,
    required this.fallbackBuilder,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final AvatarResource resource;
  final WidgetBuilder fallbackBuilder;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> with WidgetsBindingObserver {
  String? _failedUrl;
  int _retryEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.normalizedUrl != widget.resource.normalizedUrl ||
        oldWidget.resource.normalizedStoragePath !=
            widget.resource.normalizedStoragePath ||
        !identical(oldWidget.resource.bytes, widget.resource.bytes)) {
      _failedUrl = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final String? url = widget.resource.normalizedUrl;
    if (url == null || _failedUrl != url) {
      return;
    }
    NetworkImage(url).evict().whenComplete(() {
      if (!mounted || widget.resource.normalizedUrl != url) {
        return;
      }
      setState(() {
        _failedUrl = null;
        _retryEpoch += 1;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AvatarResource resource = widget.resource;
    if (resource.hasLocalBytes) {
      return Image.memory(
        resource.bytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
      );
    }

    final String? url = resource.normalizedUrl;
    if (url == null || _failedUrl == url) {
      return widget.fallbackBuilder(context);
    }

    return Image(
      key: ValueKey<int>(_retryEpoch),
      image: NetworkImage(url),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      gaplessPlayback: true,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        _rememberFailure(url);
        return widget.fallbackBuilder(context);
      },
    );
  }

  void _rememberFailure(String url) {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted ||
          widget.resource.normalizedUrl != url ||
          _failedUrl == url) {
        return;
      }
      setState(() => _failedUrl = url);
    });
  }
}
