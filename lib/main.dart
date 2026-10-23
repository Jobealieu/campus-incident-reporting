import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: CampusFixApp()));
}
