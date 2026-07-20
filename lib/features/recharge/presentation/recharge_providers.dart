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
  return result.getOrElseCompute((e) => throw e);
});

// A provider to fetch all circles
final circlesProvider = FutureProvider<List<Circle>>((ref) async {
  final repo = ref.watch(rechargeRepositoryProvider);
  final result = await repo.getCircles();
  return result.getOrElseCompute((e) => throw e);
});

// A provider to fetch plans based on operatorId, circle, and serviceType
final plansProvider = FutureProvider.family<List<RechargePlan>, ({String operatorId, String circle, String serviceType})>((ref, params) async {
  final repo = ref.watch(rechargeRepositoryProvider);
  final result = await repo.getPlans(
    operatorId: params.operatorId,
    circle: params.circle,
    serviceType: params.serviceType,
  );
  return result.getOrElseCompute((e) => throw e);
});

// State classes for the recharge flow
class RechargeState {
  final String? phoneNumber;
  final Operator? operator;
  final Circle? circle;
  final RechargePlan? selectedPlan;
  final int? customAmountPaise;

  const RechargeState({
    this.phoneNumber,
    this.operator,
    this.circle,
    this.selectedPlan,
    this.customAmountPaise,
  });

  RechargeState copyWith({
    String? phoneNumber,
    Operator? operator,
    Circle? circle,
    RechargePlan? selectedPlan,
    int? customAmountPaise,
    bool clearPlan = false,
  }) {
    return RechargeState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      operator: operator ?? this.operator,
      circle: circle ?? this.circle,
      selectedPlan: clearPlan ? null : (selectedPlan ?? this.selectedPlan),
      customAmountPaise: customAmountPaise ?? this.customAmountPaise,
    );
  }
}

// Notifier to hold the state of a recharge in progress
class RechargeFlowNotifier extends Notifier<RechargeState> {
  @override
  RechargeState build() => const RechargeState();

  void setPhoneNumber(String number) {
    state = state.copyWith(phoneNumber: number);
  }

  void setOperator(Operator op) {
    state = state.copyWith(operator: op, clearPlan: true);
  }

  void setCircle(Circle circle) {
    state = state.copyWith(circle: circle, clearPlan: true);
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
