// lib/bootstrap.dart
// App initialization sequence — runs before MaterialApp is built.
// Order matters:
//   1. Hive (must be initialized & boxes opened before any providers/UI)
//   2. Environment & AppConfig
//   3. Operator Registry
//   4. WidgetsBinding & UI Overlay Settings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/utils/logger.dart';
import '../core/utils/startup_tracker.dart';
import '../core/config/app_config.dart';
import '../core/constants/operator_registry.dart';
import '../core/services/local_cache_service.dart';

Future<void> bootstrap(Widget app) async {
  // Mark t0: App Started
  StartupTracker.instance.markAppStarted();

  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Local Storage & Open all required boxes upfront
  AppLogger.info('Bootstrap: Starting Hive Initialization', tag: 'Bootstrap');
  await LocalCacheService.initialize();
  AppLogger.info('Bootstrap: Hive Initialization Completed', tag: 'Bootstrap');

  // 2. Initialize environment and base URLs
  await AppConfig.init();

  // 3. Initialize Operator Registry from local assets
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
