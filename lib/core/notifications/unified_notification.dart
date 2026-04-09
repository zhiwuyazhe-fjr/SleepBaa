import 'package:flutter/foundation.dart';

enum NotificationDeliveryKind { inApp, system }

enum InAppNotificationChannelType { passiveToast, topBanner, centerOverlay }

@immutable
class UnifiedNotificationPayload {
  const UnifiedNotificationPayload({
    required this.message,
    this.title,
    this.metadata = const <String, Object?>{},
  });

  final String message;
  final String? title;
  final Map<String, Object?> metadata;
}

@immutable
class UnifiedNotificationRequest {
  const UnifiedNotificationRequest({
    required this.kind,
    required this.channel,
    required this.payload,
    this.duration = const Duration(seconds: 2),
  });

  final NotificationDeliveryKind kind;
  final String channel;
  final UnifiedNotificationPayload payload;
  final Duration duration;
}

abstract interface class UnifiedNotificationApi {
  Future<void> notify(UnifiedNotificationRequest request);
}

abstract interface class NotificationChannelProtocol {
  NotificationDeliveryKind get kind;
  String get channel;
  bool supports(UnifiedNotificationRequest request);
  Future<void> deliver(UnifiedNotificationRequest request);
}

abstract base class InAppNotificationChannelProtocol
    implements NotificationChannelProtocol {
  @override
  NotificationDeliveryKind get kind => NotificationDeliveryKind.inApp;

  @override
  bool supports(UnifiedNotificationRequest request) {
    return request.kind == kind && request.channel == channel;
  }
}

abstract base class SystemNotificationChannelProtocol
    implements NotificationChannelProtocol {
  @override
  NotificationDeliveryKind get kind => NotificationDeliveryKind.system;

  @override
  bool supports(UnifiedNotificationRequest request) {
    return request.kind == kind && request.channel == channel;
  }
}

class UnifiedNotificationDispatcher implements UnifiedNotificationApi {
  UnifiedNotificationDispatcher({
    List<NotificationChannelProtocol> channels =
        const <NotificationChannelProtocol>[],
  }) : _channels = List<NotificationChannelProtocol>.from(channels);

  final List<NotificationChannelProtocol> _channels;

  void register(NotificationChannelProtocol channel) {
    _channels.add(channel);
  }

  @override
  Future<void> notify(UnifiedNotificationRequest request) async {
    final Iterable<NotificationChannelProtocol> matched = _channels.where(
      (NotificationChannelProtocol item) => item.supports(request),
    );
    for (final NotificationChannelProtocol channel in matched) {
      await channel.deliver(request);
    }
  }
}
