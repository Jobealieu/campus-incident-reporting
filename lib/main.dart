import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log uncaught framework and async errors instead of losing them.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    log('Flutter error', error: details.exception, stackTrace: details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    log('Uncaught async error', error: error, stackTrace: stack);
    return true;
  };

  if (AppConfig.useEmulators) {
    await _connectToEmulators();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: CampusFixApp()));
}

Future<void> _connectToEmulators() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-key',
      appId: '1:1:android:1',
      messagingSenderId: '1',
      projectId: 'demo-campusfix',
      storageBucket: 'demo-campusfix.appspot.com',
    ),
  );
  // 10.0.2.2 is the host machine as seen from the Android emulator.
  const host = '10.0.2.2';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
