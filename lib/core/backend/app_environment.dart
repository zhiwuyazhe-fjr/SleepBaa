enum AppBackendTarget { inMemory, emulator, staging, production }

class AppEnvironment {
  const AppEnvironment({
    required this.target,
    required this.appIdPrefix,
    this.cloudbaseEnvId,
    this.cloudbaseGatewayBaseUrl,
    this.cloudbaseAuthBaseUrl,
    this.cloudbaseAppApiBaseUrl,
    this.cloudbasePublishableKey,
    this.cloudbaseClientId,
  });

  factory AppEnvironment.inMemory() {
    return const AppEnvironment(
      target: AppBackendTarget.inMemory,
      appIdPrefix: 'com.dormsleep.app',
    );
  }

  factory AppEnvironment.fromDefines() {
    final String backendValue = const String.fromEnvironment(
      'APP_BACKEND',
      defaultValue: 'in_memory',
    );
    final AppBackendTarget target = switch (backendValue) {
      'emulator' => AppBackendTarget.emulator,
      'staging' => AppBackendTarget.staging,
      'production' => AppBackendTarget.production,
      _ => AppBackendTarget.inMemory,
    };

    final String envId = const String.fromEnvironment(
      'CLOUDBASE_ENV_ID',
      defaultValue: '',
    );
    final String defaultGateway = envId.isEmpty
        ? ''
        : 'https://$envId.api.tcloudbasegateway.com';
    final String gatewayBaseUrl = const String.fromEnvironment(
      'CLOUDBASE_GATEWAY_BASE_URL',
      defaultValue: '',
    );
    final String authBaseUrl = const String.fromEnvironment(
      'CLOUDBASE_AUTH_BASE_URL',
      defaultValue: '',
    );
    final String appApiBaseUrl = const String.fromEnvironment(
      'CLOUDBASE_APP_API_BASE_URL',
      defaultValue: '',
    );
    final String clientId = const String.fromEnvironment(
      'CLOUDBASE_CLIENT_ID',
      defaultValue: '',
    );

    return AppEnvironment(
      target: target,
      appIdPrefix: const String.fromEnvironment(
        'APP_ID_PREFIX',
        defaultValue: 'com.dormsleep.app',
      ),
      cloudbaseEnvId: envId.isEmpty ? null : envId,
      cloudbaseGatewayBaseUrl: _normalizeBaseUrl(
        gatewayBaseUrl.isEmpty ? defaultGateway : gatewayBaseUrl,
      ),
      cloudbaseAuthBaseUrl: _normalizeBaseUrl(
        authBaseUrl.isEmpty
            ? (gatewayBaseUrl.isEmpty ? defaultGateway : gatewayBaseUrl)
            : authBaseUrl,
      ),
      cloudbaseAppApiBaseUrl: _normalizeBaseUrl(appApiBaseUrl),
      cloudbasePublishableKey: _emptyToNull(
        const String.fromEnvironment(
          'CLOUDBASE_PUBLISHABLE_KEY',
          defaultValue: '',
        ),
      ),
      cloudbaseClientId: _emptyToNull(clientId.isEmpty ? envId : clientId),
    );
  }

  final AppBackendTarget target;
  final String appIdPrefix;
  final String? cloudbaseEnvId;
  final String? cloudbaseGatewayBaseUrl;
  final String? cloudbaseAuthBaseUrl;
  final String? cloudbaseAppApiBaseUrl;
  final String? cloudbasePublishableKey;
  final String? cloudbaseClientId;

  bool get usesCloudBase => target != AppBackendTarget.inMemory;

  bool get hasCloudBaseAuthConfig {
    return (cloudbaseEnvId?.isNotEmpty ?? false) &&
        (cloudbaseAuthBaseUrl?.isNotEmpty ?? false);
  }

  bool get hasCloudBaseAppApi {
    return (cloudbaseAppApiBaseUrl?.isNotEmpty ?? false);
  }

  AppEnvironment copyWith({
    AppBackendTarget? target,
    String? appIdPrefix,
    String? cloudbaseEnvId,
    String? cloudbaseGatewayBaseUrl,
    String? cloudbaseAuthBaseUrl,
    String? cloudbaseAppApiBaseUrl,
    String? cloudbasePublishableKey,
    String? cloudbaseClientId,
  }) {
    return AppEnvironment(
      target: target ?? this.target,
      appIdPrefix: appIdPrefix ?? this.appIdPrefix,
      cloudbaseEnvId: cloudbaseEnvId ?? this.cloudbaseEnvId,
      cloudbaseGatewayBaseUrl:
          cloudbaseGatewayBaseUrl ?? this.cloudbaseGatewayBaseUrl,
      cloudbaseAuthBaseUrl: cloudbaseAuthBaseUrl ?? this.cloudbaseAuthBaseUrl,
      cloudbaseAppApiBaseUrl:
          cloudbaseAppApiBaseUrl ?? this.cloudbaseAppApiBaseUrl,
      cloudbasePublishableKey:
          cloudbasePublishableKey ?? this.cloudbasePublishableKey,
      cloudbaseClientId: cloudbaseClientId ?? this.cloudbaseClientId,
    );
  }
}

String? _emptyToNull(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizeBaseUrl(String value) {
  final String? normalized = _emptyToNull(value);
  if (normalized == null) {
    return null;
  }
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}
