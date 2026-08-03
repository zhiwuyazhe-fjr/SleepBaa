import 'dart:typed_data';

/// A user's avatar is a resource, not a URL.
///
/// [storagePath] is the stable identity persisted by CloudBase. [url] is only
/// a replaceable access credential and may expire while the resource stays the
/// same. [bytes] and [localPath] are local upload previews.
class AvatarResource {
  const AvatarResource({
    this.localPath,
    this.bytes,
    this.url,
    this.storagePath,
  });

  final String? localPath;
  final Uint8List? bytes;
  final String? url;
  final String? storagePath;

  String? get normalizedUrl => _nonEmpty(url);
  String? get normalizedStoragePath => _nonEmpty(storagePath);

  bool get hasLocalBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasRemoteUrl => normalizedUrl != null;

  bool sameResourceAs(AvatarResource other) {
    final String? currentStoragePath = normalizedStoragePath;
    final String? otherStoragePath = other.normalizedStoragePath;
    if (currentStoragePath != null || otherStoragePath != null) {
      return currentStoragePath != null &&
          currentStoragePath == otherStoragePath;
    }

    final String? currentUrlIdentity = _urlIdentity(normalizedUrl);
    final String? otherUrlIdentity = _urlIdentity(other.normalizedUrl);
    return currentUrlIdentity != null && currentUrlIdentity == otherUrlIdentity;
  }

  /// Merges a newly fetched remote representation into this resource.
  ///
  /// A non-empty incoming URL always wins, even when it points to the same
  /// storage path, because signed URLs are expected to rotate. The previous URL
  /// is retained only when the same stable storage resource is returned without
  /// a URL (for example, a temporary signing failure).
  AvatarResource mergeRemote(AvatarResource incoming) {
    final String? currentStoragePath = normalizedStoragePath;
    final String? incomingStoragePath = incoming.normalizedStoragePath;
    final String? incomingUrl = incoming.normalizedUrl;
    final bool sameStableResource =
        currentStoragePath != null && currentStoragePath == incomingStoragePath;
    final bool stableResourceChanged =
        currentStoragePath != incomingStoragePath &&
        (currentStoragePath != null || incomingStoragePath != null);

    return AvatarResource(
      localPath: stableResourceChanged
          ? incoming.localPath
          : incoming.localPath ?? localPath,
      bytes: stableResourceChanged ? incoming.bytes : incoming.bytes ?? bytes,
      url: incomingUrl ?? (sameStableResource ? normalizedUrl : null),
      storagePath: incomingStoragePath,
    );
  }

  static String? _nonEmpty(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _urlIdentity(String? value) {
    if (value == null) {
      return null;
    }
    final Uri? parsed = Uri.tryParse(value);
    if (parsed == null || !parsed.hasScheme) {
      return value.split('?').first.split('#').first;
    }
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path,
    ).toString();
  }
}
