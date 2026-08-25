import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

import '../../features/recharge/presentation/recharge_providers.dart';
import '../../features/dth/presentation/providers/dth_providers.dart';
import '../../features/bbps/presentation/bbps_providers.dart';
import '../../features/dmt/presentation/dmt_providers.dart';
import '../../features/aeps/presentation/aeps_providers.dart';
import '../../features/loan/presentation/loan_providers.dart';
import '../../features/insurance/presentation/insurance_providers.dart';
import '../../features/commission/presentation/commission_providers.dart';

class RechargeSessionState {
  final String? sessionId;
  final String? serviceType;
  final DateTime? startTime;

  bool get isActive => sessionId != null;

  const RechargeSessionState({
    this.sessionId,
    this.serviceType,
    this.startTime,
  });

  RechargeSessionState copyWith({
    String? sessionId,
    String? serviceType,
    DateTime? startTime,
  }) {
    return RechargeSessionState(
      sessionId: sessionId ?? this.sessionId,
      serviceType: serviceType ?? this.serviceType,
      startTime: startTime ?? this.startTime,
    );
  }
}

class RechargeSessionNotifier extends Notifier<RechargeSessionState> {
  @override
  RechargeSessionState build() => const RechargeSessionState();

  /// Starts a fresh recharge/payment session for the given service type.
  /// Resets all previous temporary flow data across all services.
  String startNewSession(String serviceType) {
    final cleanService = serviceType.toUpperCase().trim();
    final newSessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}_$cleanService';

    AppLogger.info('\n====================================================', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Starting new session: $newSessionId', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Service: $cleanService', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Clearing previous session', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Mobile/Subscriber/Consumer data reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Operator reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Circle reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Plan reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Amount reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Commission reset', tag: 'RECHARGE SESSION');
    AppLogger.info('[RECHARGE SESSION] Payment state reset', tag: 'RECHARGE SESSION');
    AppLogger.info('====================================================\n', tag: 'RECHARGE SESSION');

    _resetAllFlowNotifiers();

    state = RechargeSessionState(
      sessionId: newSessionId,
      serviceType: cleanService,
      startTime: DateTime.now(),
    );

    return newSessionId;
  }

  /// Clears/ends the active recharge session.
  void endSession() {
    if (state.sessionId != null) {
      AppLogger.info('\n====================================================', tag: 'RECHARGE SESSION');
      AppLogger.info('[RECHARGE SESSION] Session ended: ${state.sessionId}', tag: 'RECHARGE SESSION');
      AppLogger.info('[RECHARGE SESSION] Service: ${state.serviceType ?? 'N/A'}', tag: 'RECHARGE SESSION');
      AppLogger.info('[RECHARGE SESSION] Clearing session state', tag: 'RECHARGE SESSION');
      AppLogger.info('====================================================\n', tag: 'RECHARGE SESSION');
    }

    _resetAllFlowNotifiers();
    state = const RechargeSessionState();
  }

  /// Resets all underlying Riverpod flow notifiers across prepaid, postpaid, dth, bbps, dmt, aeps, loan, insurance.
  void _resetAllFlowNotifiers() {
    try {
      ref.read(rechargeFlowProvider.notifier).reset();
      ref.read(dthFlowProvider.notifier).reset();
      ref.read(bbpsFlowProvider.notifier).reset();
      ref.read(dmtFlowProvider.notifier).reset();
      ref.read(aepsFlowProvider.notifier).reset();
      ref.read(loanFlowProvider.notifier).reset();
      ref.read(insuranceFlowProvider.notifier).reset();

      ref.invalidate(rechargePayableProvider);
      ref.invalidate(activeCommissionSlabsProvider);
    } catch (e) {
      AppLogger.warning('Error resetting flow notifiers: $e', tag: 'RECHARGE SESSION');
    }
  }

  /// Validates if an async request's session ID matches the currently active session.
  bool validateSession(String? requestSessionId) {
    if (requestSessionId == null || state.sessionId == null || requestSessionId != state.sessionId) {
      AppLogger.warning('\n[RECHARGE SESSION] Async response session ID: $requestSessionId', tag: 'RECHARGE SESSION');
      AppLogger.warning('[RECHARGE SESSION] Current session ID: ${state.sessionId}', tag: 'RECHARGE SESSION');
      AppLogger.warning('[RECHARGE SESSION] STALE RESPONSE IGNORED\n', tag: 'RECHARGE SESSION');
      return false;
    }
    return true;
  }
}

final rechargeSessionProvider = NotifierProvider<RechargeSessionNotifier, RechargeSessionState>(
  RechargeSessionNotifier.new,
);
