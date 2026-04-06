enum AppBackendTarget { inMemory, emulator, staging, production }

class AppEnvironment {
  const AppEnvironment({
    required this.target,
    required this.appIdPrefix,
    this.firebaseProjectId,
    this.firebaseApiKey,
    this.firebaseAppId,
    this.firebaseMessagingSenderId,
    this.firebaseStorageBucket,
    this.useAppCheck = false,
    this.authEmulatorHost = '127.0.0.1',
    this.authEmulatorPort = 9099,
    this.firestoreEmulatorHost = '127.0.0.1',
    this.firestoreEmulatorPort = 8080,
    this.storageEmulatorHost = '127.0.0.1',
    this.storageEmulatorPort = 9448,
    this.functionsEmulatorHost = '127.0.0.1',
    this.functionsEmulatorPort = 5001,
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

    return AppEnvironment(
      target: target,
      appIdPrefix: const String.fromEnvironment(
        'APP_ID_PREFIX',
        defaultValue: 'com.dormsleep.app',
      ),
      firebaseProjectId: const String.fromEnvironment(
        'FIREBASE_PROJECT_ID',
        defaultValue: '',
      ),
      firebaseApiKey: const String.fromEnvironment(
        'FIREBASE_API_KEY',
        defaultValue: '',
      ),
      firebaseAppId: const String.fromEnvironment(
        'FIREBASE_APP_ID',
        defaultValue: '',
      ),
      firebaseMessagingSenderId: const String.fromEnvironment(
        'FIREBASE_MESSAGING_SENDER_ID',
        defaultValue: '',
      ),
      firebaseStorageBucket: const String.fromEnvironment(
        'FIREBASE_STORAGE_BUCKET',
        defaultValue: '',
      ),
      useAppCheck: const bool.fromEnvironment(
        'FIREBASE_USE_APP_CHECK',
        defaultValue: false,
      ),
      authEmulatorHost: const String.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      authEmulatorPort: int.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      ),
      firestoreEmulatorHost: const String.fromEnvironment(
        'FIREBASE_FIRESTORE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      firestoreEmulatorPort: int.fromEnvironment(
        'FIREBASE_FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      ),
      storageEmulatorHost: const String.fromEnvironment(
        'FIREBASE_STORAGE_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      storageEmulatorPort: int.fromEnvironment(
        'FIREBASE_STORAGE_EMULATOR_PORT',
        defaultValue: 9448,
      ),
      functionsEmulatorHost: const String.fromEnvironment(
        'FIREBASE_FUNCTIONS_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      ),
      functionsEmulatorPort: int.fromEnvironment(
        'FIREBASE_FUNCTIONS_EMULATOR_PORT',
        defaultValue: 5001,
      ),
    );
  }

  final AppBackendTarget target;
  final String appIdPrefix;
  final String? firebaseProjectId;
  final String? firebaseApiKey;
  final String? firebaseAppId;
  final String? firebaseMessagingSenderId;
  final String? firebaseStorageBucket;
  final bool useAppCheck;
  final String authEmulatorHost;
  final int authEmulatorPort;
  final String firestoreEmulatorHost;
  final int firestoreEmulatorPort;
  final String storageEmulatorHost;
  final int storageEmulatorPort;
  final String functionsEmulatorHost;
  final int functionsEmulatorPort;

  bool get usesFirebase => target != AppBackendTarget.inMemory;

  bool get useEmulators => target == AppBackendTarget.emulator;

  bool get hasRuntimeFirebaseConfig {
    return (firebaseProjectId?.isNotEmpty ?? false) &&
        (firebaseApiKey?.isNotEmpty ?? false) &&
        (firebaseAppId?.isNotEmpty ?? false) &&
        (firebaseMessagingSenderId?.isNotEmpty ?? false);
  }

  AppEnvironment copyWith({
    AppBackendTarget? target,
    String? appIdPrefix,
    String? firebaseProjectId,
    String? firebaseApiKey,
    String? firebaseAppId,
    String? firebaseMessagingSenderId,
    String? firebaseStorageBucket,
    bool? useAppCheck,
    String? authEmulatorHost,
    int? authEmulatorPort,
    String? firestoreEmulatorHost,
    int? firestoreEmulatorPort,
    String? storageEmulatorHost,
    int? storageEmulatorPort,
    String? functionsEmulatorHost,
    int? functionsEmulatorPort,
  }) {
    return AppEnvironment(
      target: target ?? this.target,
      appIdPrefix: appIdPrefix ?? this.appIdPrefix,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      firebaseApiKey: firebaseApiKey ?? this.firebaseApiKey,
      firebaseAppId: firebaseAppId ?? this.firebaseAppId,
      firebaseMessagingSenderId:
          firebaseMessagingSenderId ?? this.firebaseMessagingSenderId,
      firebaseStorageBucket:
          firebaseStorageBucket ?? this.firebaseStorageBucket,
      useAppCheck: useAppCheck ?? this.useAppCheck,
      authEmulatorHost: authEmulatorHost ?? this.authEmulatorHost,
      authEmulatorPort: authEmulatorPort ?? this.authEmulatorPort,
      firestoreEmulatorHost:
          firestoreEmulatorHost ?? this.firestoreEmulatorHost,
      firestoreEmulatorPort:
          firestoreEmulatorPort ?? this.firestoreEmulatorPort,
      storageEmulatorHost:
          storageEmulatorHost ?? this.storageEmulatorHost,
      storageEmulatorPort:
          storageEmulatorPort ?? this.storageEmulatorPort,
      functionsEmulatorHost:
          functionsEmulatorHost ?? this.functionsEmulatorHost,
      functionsEmulatorPort:
          functionsEmulatorPort ?? this.functionsEmulatorPort,
    );
  }
}
