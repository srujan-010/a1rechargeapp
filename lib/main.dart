// lib/main.dart
// App entry point. ProviderScope wraps the entire widget tree.
// ThemeMode is locked to light — dark mode is coming soon.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

import 'core/utils/app_lifecycle_observer.dart';

import 'dart:async';

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[GLOBAL FLUTTER ERROR] ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  runZonedGuarded(() {
    bootstrap(const ProviderScope(child: A1RechargeApp()));
  }, (error, stack) {
    debugPrint("[UNCAUGHT ZONED ERROR]: $error");
    debugPrintStack(stackTrace: stack);
  });
}

class A1RechargeApp extends ConsumerWidget {
  const A1RechargeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'A1 Recharge',
      debugShowCheckedModeBanner: false,

      // Theme — light mode only. Dark Mode → Coming Soon (see Settings screen)
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,   // intentionally same
      themeMode: ThemeMode.light,        // locked, ignores system dark mode

      // Navigation
      routerConfig: router,

      // Accessibility & App Lock Lifecycle Observer
      builder: (context, child) {
        return AppLifecycleObserver(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
