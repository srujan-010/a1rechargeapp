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
import '../core/utils/logger.dart';
import '../core/utils/startup_tracker.dart';
import '../core/config/app_config.dart';
import '../core/constants/operator_registry.dart';

Future<void> bootstrap(Widget app) async {
  // Mark t0: App Started
  StartupTracker.instance.markAppStarted();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment and base URLs
  await AppConfig.init();

  // Initialize Operator Registry from local assets
  await OperatorRegistry.instance.initialize();

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

  AppLogger.info('Bootstrap complete — launching app', tag: 'Bootstrap');
  runApp(app);
}

