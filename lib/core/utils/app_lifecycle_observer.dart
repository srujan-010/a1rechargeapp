import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/security_pin/providers/security_pin_provider.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/logger.dart';

import '../../features/payment/providers/payment_session_provider.dart';

class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({
    super.key,
    required this.child,
    this.lockTimeout = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration lockTimeout;

  @override
  ConsumerState<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final paymentSession = ref.read(paymentSessionProvider);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      if (paymentSession.isPaymentInProgress) {
        AppLogger.info('[LIFECYCLE] Active external payment session detected (${paymentSession.status}). Background relock suppressed.', tag: 'LIFECYCLE');
        return;
      }
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (paymentSession.isPaymentInProgress) {
        AppLogger.info('[LIFECYCLE] App resumed during active payment session. Triggering recovery check...', tag: 'LIFECYCLE');
        ref.read(paymentSessionProvider.notifier).onAppResumed();
        return;
      }

      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        _pausedAt = null;

        if (elapsed >= widget.lockTimeout) {
          _checkAndLockApp();
        }
      }
    }
  }

  Future<void> _checkAndLockApp() async {
    final secureStorage = ref.read(secureStorageProvider);
    final isSecPinEnabled = await secureStorage.isSecurityPinEnabled();
    final pinState = ref.read(securityPinProvider);
    final isConfigured = pinState.securityPinConfigured ?? isSecPinEnabled;

    if (isConfigured && pinState.isAppUnlocked) {
      AppLogger.info('[SECURITY_PIN] Background lock condition reached', tag: 'SECURITY_PIN');
      ref.read(securityPinProvider.notifier).lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
