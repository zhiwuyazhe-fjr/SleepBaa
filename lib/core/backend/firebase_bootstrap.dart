import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/backend/firebase_runtime_options.dart';

Future<void> initializeFirebaseBackend(AppEnvironment environment) async {
  if (!environment.usesFirebase) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: firebaseOptionsForEnvironment(environment),
    );
  }

  if (environment.useEmulators) {
    final String host = kIsWeb
        ? environment.authEmulatorHost
        : _normalizeDeviceHost(environment.authEmulatorHost);
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      environment.authEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      _normalizeDeviceHost(environment.firestoreEmulatorHost),
      environment.firestoreEmulatorPort,
    );
    FirebaseStorage.instance.useStorageEmulator(
      _normalizeDeviceHost(environment.storageEmulatorHost),
      environment.storageEmulatorPort,
    );
    FirebaseFunctions.instance.useFunctionsEmulator(
      _normalizeDeviceHost(environment.functionsEmulatorHost),
      environment.functionsEmulatorPort,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    return;
  }

  if (environment.useAppCheck) {
    try {
      await FirebaseAppCheck.instance.activate();
    } catch (_) {
      // App Check is optional during local scaffolding and can be finalized
      // once platform-specific providers are configured.
    }
  }
}

String _normalizeDeviceHost(String host) {
  if (kIsWeb) {
    return host;
  }
  return defaultTargetPlatform == TargetPlatform.android && host == '127.0.0.1'
      ? '10.0.2.2'
      : host;
}
