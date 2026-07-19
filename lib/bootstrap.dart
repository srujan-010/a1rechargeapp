// lib/bootstrap.dart
// App initialization sequence — runs before MaterialApp is built.
// Order matters:
//   1. Firebase (must be first)
//   2. Hive (local cache)
//   3. WidgetsFlutterBinding
//   4. System UI overlay style
// Note: Firebase requires google-services.json (Android) and GoogleService-Info.plist (iOS).
// See README.md for Firebase setup instructions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/local_cache_service.dart';
import '../core/utils/logger.dart';
import '../core/config/app_config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment and base URLs
  await AppConfig.init();


  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style (transparent status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive local cache
  try {
    await LocalCacheService.initialize();
    AppLogger.info('Hive cache initialized', tag: 'Bootstrap');
  } catch (e, st) {
    AppLogger.error('Hive init failed', tag: 'Bootstrap', error: e, stackTrace: st);
    // Non-fatal: app can run without local cache
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized', tag: 'Bootstrap');
  } catch (e, st) {
    AppLogger.error('Firebase init failed', tag: 'Bootstrap', error: e, stackTrace: st);
  }

  AppLogger.info('Bootstrap complete — launching app', tag: 'Bootstrap');
  runApp(app);
}
