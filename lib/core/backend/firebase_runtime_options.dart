import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/firebase_options.dart';

FirebaseOptions firebaseOptionsForEnvironment(AppEnvironment environment) {
  if (environment.useEmulators) {
    return _emulatorOptions(environment);
  }

  if (!environment.hasRuntimeFirebaseConfig) {
    final FirebaseOptions? configuredOptions =
        _configuredFirebaseOptionsOrNull(environment);
    if (configuredOptions != null) {
      return configuredOptions;
    }

    return _emulatorOptions(environment);
  }

  return FirebaseOptions(
    apiKey: environment.firebaseApiKey!,
    appId: environment.firebaseAppId!,
    messagingSenderId: environment.firebaseMessagingSenderId!,
    projectId: environment.firebaseProjectId!,
    storageBucket: environment.firebaseStorageBucket,
    iosBundleId: environment.appIdPrefix,
  );
}

FirebaseOptions _emulatorOptions(AppEnvironment environment) {
  const String dummyApiKey = 'emulator-api-key';
  const String dummySenderId = '1234567890';
  final String projectId =
      environment.firebaseProjectId?.isNotEmpty == true
      ? environment.firebaseProjectId!
      : 'dormsleep-dev';

  if (kIsWeb) {
    return FirebaseOptions(
      apiKey: dummyApiKey,
      appId: '1:$dummySenderId:web:dormsleep',
      messagingSenderId: dummySenderId,
      projectId: projectId,
      authDomain: '$projectId.firebaseapp.com',
      storageBucket: '$projectId.appspot.com',
    );
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => FirebaseOptions(
      apiKey: dummyApiKey,
      appId: '1:$dummySenderId:android:dormsleep',
      messagingSenderId: dummySenderId,
      projectId: projectId,
      storageBucket: '$projectId.appspot.com',
    ),
    TargetPlatform.iOS => FirebaseOptions(
      apiKey: dummyApiKey,
      appId: '1:$dummySenderId:ios:dormsleep',
      messagingSenderId: dummySenderId,
      projectId: projectId,
      storageBucket: '$projectId.appspot.com',
      iosBundleId: environment.appIdPrefix,
    ),
    TargetPlatform.macOS => FirebaseOptions(
      apiKey: dummyApiKey,
      appId: '1:$dummySenderId:macos:dormsleep',
      messagingSenderId: dummySenderId,
      projectId: projectId,
      storageBucket: '$projectId.appspot.com',
      iosBundleId: '${environment.appIdPrefix}.macos',
    ),
    _ => FirebaseOptions(
      apiKey: dummyApiKey,
      appId: '1:$dummySenderId:flutter:dormsleep',
      messagingSenderId: dummySenderId,
      projectId: projectId,
      storageBucket: '$projectId.appspot.com',
    ),
  };
}

FirebaseOptions? _configuredFirebaseOptionsOrNull(AppEnvironment environment) {
  try {
    final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
    if (environment.firebaseProjectId?.isNotEmpty == true &&
        environment.firebaseProjectId != options.projectId) {
      return null;
    }
    return options;
  } on UnsupportedError {
    return null;
  }
}
