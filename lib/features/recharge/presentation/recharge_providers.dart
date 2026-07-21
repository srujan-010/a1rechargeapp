import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../data/recharge_repository_impl.dart';
import '../domain/recharge_repository.dart';
import '../domain/models/operator.dart';
import '../domain/models/recharge_plan.dart';
import '../domain/models/recharge_result.dart';
import '../domain/models/recent_contact.dart';
import '../domain/models/circle.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

final rechargeRepositoryProvider = Provider<RechargeRepository>((ref) {
  return RechargeRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

// A family provider to fetch operators by service type ('mobile', 'dth', etc.)
final operatorsProvider = FutureProvider.family<List<Operator>, String>((ref, serviceType) async {
  final repo = ref.watch(rechargeRepositoryProvider);
  final result = await repo.getOperators(serviceType: serviceType);
  final ops = result.getOrElseCompute((e) => throw e);
  debugPrint('==========================');
  debugPrint('STEP 4 - PROVIDER');
  debugPrint('==========================');
  debugPrint('OperatorProvider state (serviceType=$serviceType):');
  debugPrint('Number of operators stored: ${ops.length}');
  return ops;
});

// A provider to fetch all circles
final circlesProvider = FutureProvider<List<Circle>>((ref) async {
  final repo = ref.watch(rechargeRepositoryProvider);
  final result = await repo.getCircles();
  return result.getOrElseCompute((e) => throw e);
});

// A provider to fetch plans based on operatorId, circle, and serviceType
final plansProvider = FutureProvider.family<List<RechargePlan>, ({String operatorId, String circle, String serviceType})>((ref, params) async {
  try {
    debugPrint("STEP 1: Calling getPlans in recharge_providers.dart");
    final repo = ref.watch(rechargeRepositoryProvider);
    final result = await repo.getPlans(
      operatorId: params.operatorId,
      circle: params.circle,
      serviceType: params.serviceType,
    );
    debugPrint("STEP 5: Plans Loaded in recharge_providers.dart");
    return result.getOrElseCompute((e) => throw e);
  } catch (e, st) {
    debugPrint("PLANS CRASH: recharge_providers.dart, plansProvider");
    debugPrint(e.toString());
    debugPrintStack(stackTrace: st);
    rethrow;
  }
});

// State classes for the recharge flow
class RechargeState {
  final String? phoneNumber;
  final Operator? autoOperator;
  final Circle? autoCircle;
  final Operator? manualOperator;
  final Circle? manualCircle;
  final RechargePlan? selectedPlan;
  final int? customAmountPaise;
  final bool isDetecting;

  Operator? get operator => manualOperator ?? autoOperator;
  Circle? get circle => manualCircle ?? autoCircle;
  bool get hasManualSelection => manualOperator != null || manualCircle != null;
  bool get isAutoDetected => autoOperator != null && autoCircle != null;

  const RechargeState({
    this.phoneNumber,
    this.autoOperator,
    this.autoCircle,
    this.manualOperator,
    this.manualCircle,
    this.selectedPlan,
    this.customAmountPaise,
    this.isDetecting = false,
  });

  RechargeState copyWith({
    String? phoneNumber,
    Operator? autoOperator,
    Circle? autoCircle,
    Operator? manualOperator,
    Circle? manualCircle,
    RechargePlan? selectedPlan,
    int? customAmountPaise,
    bool? isDetecting,
    bool clearPlan = false,
    bool clearManual = false,
    bool clearAuto = false,
  }) {
    return RechargeState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      autoOperator: clearAuto ? null : (autoOperator ?? this.autoOperator),
      autoCircle: clearAuto ? null : (autoCircle ?? this.autoCircle),
      manualOperator: clearManual ? null : (manualOperator ?? this.manualOperator),
      manualCircle: clearManual ? null : (manualCircle ?? this.manualCircle),
      selectedPlan: clearPlan ? null : (selectedPlan ?? this.selectedPlan),
      customAmountPaise: clearPlan ? null : (customAmountPaise ?? this.customAmountPaise),
      isDetecting: isDetecting ?? this.isDetecting,
    );
  }
}

// Notifier to hold the state of a recharge in progress
class RechargeFlowNotifier extends Notifier<RechargeState> {
  @override
  RechargeState build() => const RechargeState();

  void setPhoneNumber(String number) {
    if (state.phoneNumber != number) {
      state = state.copyWith(
        phoneNumber: number,
        clearManual: true,
        clearAuto: true,
        clearPlan: true,
      );
    }
  }

  void setDetecting(bool detecting) {
    state = state.copyWith(isDetecting: detecting);
  }

  void setAutoDetection(Operator op, Circle c) {
    state = state.copyWith(autoOperator: op, autoCircle: c, isDetecting: false, clearPlan: true);
  }

  void setOperator(Operator op) {
    state = state.copyWith(manualOperator: op, clearPlan: true);
  }

  void clearOperator() {
    state = RechargeState(phoneNumber: state.phoneNumber);
  }

  void setCircle(Circle circle) {
    state = state.copyWith(manualCircle: circle, clearPlan: true);
  }

  void setPlan(RechargePlan plan) {
    state = state.copyWith(selectedPlan: plan, customAmountPaise: plan.pricePaise);
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(customAmountPaise: amountPaise, clearPlan: true);
  }
  
  void reset() {
    state = const RechargeState();
  }

  // Action method to process the recharge
  Future<RechargeReceipt> processRecharge({String? mpin, String paymentMode = 'wallet'}) async {
    if (state.phoneNumber == null || state.operator == null || state.circle == null || state.customAmountPaise == null) {
      throw const ValidationException(message: 'Incomplete recharge details', code: 'INVALID_STATE');
    }
    
    if (paymentMode == 'wallet' && mpin == null) {
      throw const ValidationException(message: 'MPIN is required for wallet payments', code: 'INVALID_MPIN');
    }

    final repo = ref.read(rechargeRepositoryProvider);
    
    // Map flutter OperatorType to backend serviceType
    final serviceType = switch (state.operator!.type) {
      OperatorType.prepaid => 'mobile',
      OperatorType.dth => 'dth',
      OperatorType.postpaid => 'bbps',
    };

    final result = await repo.processRecharge(
      phoneNumber: state.phoneNumber!,
      operatorId: state.operator!.id,
      operatorName: state.operator!.name,
      circleId: state.circle!.id,
      serviceType: serviceType,
      amountPaise: state.customAmountPaise!,
      mpin: mpin,
      paymentMode: paymentMode,
    );

    final receipt = result.getOrElseCompute((e) => throw e);

    // Update the receipt with paymentMode and circle
    final walletAsync = ref.read(walletBalanceProvider);
    final finalReceipt = receipt.copyWith(
      paymentMode: paymentMode.toUpperCase(),
      circle: state.circle?.state,
      walletBalancePaise: walletAsync.valueOrNull?.availablePaise, // Get current wallet balance
    );

    // Save recent contact if successful
    if (finalReceipt.isSuccess) {
      final contact = RecentContact(
        phone: finalReceipt.mobileNumber,
        operatorId: state.operator!.id,
        circle: state.circle?.state ?? 'Unknown',
        lastRechargeDate: DateTime.now(),
        lastRechargeAmountPaise: finalReceipt.amountPaise,
      );
      await repo.saveRecentContact(contact);
    }

    // Invalidate dashboard wallet providers to trigger balance reload
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(earningsSummaryProvider);
    ref.invalidate(recentContactsProvider);

    return finalReceipt;
  }
}

class RecentContactsNotifier extends AsyncNotifier<List<RecentContact>> {
  @override
  Future<List<RecentContact>> build() async {
    return ref.watch(rechargeRepositoryProvider).getRecentContacts();
  }

  Future<void> removeContact(String phone) async {
    await ref.read(rechargeRepositoryProvider).removeRecentContact(phone);
    ref.invalidateSelf();
  }
}

final recentContactsProvider = AsyncNotifierProvider<RecentContactsNotifier, List<RecentContact>>(
  RecentContactsNotifier.new,
);

final rechargeFlowProvider = NotifierProvider<RechargeFlowNotifier, RechargeState>(
  RechargeFlowNotifier.new,
);
