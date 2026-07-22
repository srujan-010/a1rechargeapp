import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../data/recharge_repository_impl.dart';
import '../domain/recharge_repository.dart';
import '../domain/models/operator.dart';
import '../../../models/mobile_plan.dart';
import '../domain/models/recharge_result.dart';
import '../domain/models/recent_contact.dart';
import '../domain/models/circle.dart';
import '../../../models/plan_category.dart';
import '../../../services/plan_api_service.dart';
import '../../../repositories/mobile_plan_repository.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../../core/constants/operator_registry.dart';

final rechargeRepositoryProvider = Provider<RechargeRepository>((ref) {
  return RechargeRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final planApiServiceProvider = Provider<PlanApiService>((ref) {
  return PlanApiService();
});

final mobilePlanRepositoryProvider = Provider<MobilePlanRepository>((ref) {
  return MobilePlanRepository(ref.watch(planApiServiceProvider));
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
final plansProvider = FutureProvider.family<List<PlanCategory>, ({String operatorId, String circle, String serviceType})>((ref, params) async {
  print("ENTERED: recharge_providers.dart plansProvider");
  try {
    debugPrint("==================================================");
    debugPrint("STEP 3");
    
    // Convert Operator Name/ID to PlanAPI Numeric Code
    String operatorCode = params.operatorId;
    // We try to find the operator from registry if we can, else fallback
    final ops = ref.read(operatorsProvider(params.serviceType)).valueOrNull ?? [];
    final op = ops.where((o) => o.id == params.operatorId || o.shortCode == params.operatorId).firstOrNull;
    
    if (op != null) {
       // Look it up in OperatorRegistry by name
       final registeredOp = OperatorRegistry.instance.getOperatorByName(op.name);
       if (registeredOp != null) {
         operatorCode = registeredOp.code.toString();
       } else if (op.shortCode != null && op.shortCode!.isNotEmpty) {
         operatorCode = op.shortCode!;
       }
    } else {
       // It might be the name or shortCode already if passed from PlanSelectionScreen
       final registeredOp = OperatorRegistry.instance.getOperatorByName(params.operatorId);
       if (registeredOp != null) {
         operatorCode = registeredOp.code.toString();
       }
    }

    // Convert Circle Name/ID to PlanAPI Numeric Code
    String circleCode = params.circle;
    
    // Define a basic Circle Registry map for PlanAPI based on provided list
    final Map<String, String> circleRegistry = {
      'manipur': '106',
      'jharkhand': '105',
      'mizzoram': '104',
      'meghalay': '103',
      'goa': '102',
      'chhatisgarh': '101', 'mp and chattisgarh': '101', 'chhattisgarh': '101',
      'tripura': '100',
      'sikkim': '99',
      'ap': '49', 'andhra pradesh': '49',
      'kerala': '95',
      'tamil nadu': '94', 'tamilnadu': '94',
      'chennai': '40',
      'karnataka': '06',
      'bihar': '52', 'bihar & jharkhand': '52',
      'nesa': '16', 'north east': '16',
      'assam': '56',
      'orissa': '53', 'odisha': '53',
      'west bengal': '51',
      'kolkatta': '31', 'kolkata': '31',
      'rajasthan': '70',
      'mp': '93', 'madhya pradesh': '93',
      'gujarat': '98',
      'maharashtra': '90', 'maharashtra & goa': '90',
      'mumbai': '92',
      'up(east)': '54', 'up east': '54',
      'j&k': '55', 'jammu & kashmir': '55', 'jammu and kashmir': '55',
      'haryana': '96',
      'hp': '03', 'himachal pradesh': '03',
      'punjab': '02',
      'up(west)': '97', 'up west': '97',
      'delhi': '10', 'delhi ncr': '10',
    };
    
    final normalizedCircle = params.circle.toLowerCase().trim();
    if (circleRegistry.containsKey(normalizedCircle)) {
      circleCode = circleRegistry[normalizedCircle]!;
    } else if (int.tryParse(params.circle) != null) {
      circleCode = params.circle;
    }

    debugPrint("operatorcode=$operatorCode");
    debugPrint("cricle=$circleCode");
    debugPrint("API URL=https://planapi.in/api/Mobile/NewMobilePlans");
    debugPrint("==================================================");

    final repo = ref.watch(mobilePlanRepositoryProvider);
    final result = await repo.fetchMobilePlans(operatorCode, circleCode);
    return result.getOrElseCompute((e) {
      debugPrint("==================================================");
      debugPrint("Failed to load plans");
      debugPrint("Operator Code Used: $operatorCode");
      debugPrint("Circle Code Used: $circleCode");
      debugPrint("Expected Codes: numeric (e.g. 2, 49)");
      debugPrint("Raw API Response: $e");
      debugPrint("==================================================");
      throw e;
    });
  } catch (e, st) {
    debugPrint("PLANS CRASH: recharge_providers.dart, plansProvider");
    debugPrint(e.toString());
    rethrow;
  }
});

// A provider to fetch DTH packs based on operatorId
final dthPacksProvider = FutureProvider.family<List<dynamic>, String>((ref, operatorId) async {
  // DTH plans fetching is temporarily disabled due to migration
  throw UnimplementedError('DTH plans fetching is not yet implemented in PlanAPI');
});

// State classes for the recharge flow
class RechargeState {
  final String? phoneNumber;
  final Operator? autoOperator;
  final Circle? autoCircle;
  final Operator? manualOperator;
  final Circle? manualCircle;
  final MobilePlan? selectedPlan;
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
    MobilePlan? selectedPlan,
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
      selectedPlan: selectedPlan ?? (clearPlan ? null : this.selectedPlan),
      customAmountPaise: customAmountPaise ?? (clearPlan ? null : this.customAmountPaise),
      isDetecting: isDetecting ?? this.isDetecting,
    );
  }
}

// Notifier to hold the state of a recharge in progress
class RechargeFlowNotifier extends Notifier<RechargeState> {
  @override
  RechargeState build() => const RechargeState();

  void setPhoneNumber(String number, {bool clearOperator = true, bool? clearPlan}) {
    final shouldClearPlan = clearPlan ?? clearOperator;
    if (state.phoneNumber != number) {
      state = state.copyWith(
        phoneNumber: number,
        clearManual: clearOperator,
        clearAuto: clearOperator,
        clearPlan: shouldClearPlan,
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

  void setPlan(MobilePlan plan) {
    state = state.copyWith(selectedPlan: plan, customAmountPaise: (double.tryParse(plan.rs ?? '0') ?? 0).toInt() * 100);
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(customAmountPaise: amountPaise, clearPlan: true);
  }
  
  void reset() {
    state = const RechargeState();
  }

  // Action method to process the recharge
  Future<RechargeReceipt> processRecharge({String? mpin, String paymentMode = 'wallet'}) async {
    final isDth = state.operator?.type == OperatorType.dth;
    if (state.phoneNumber == null || state.operator == null || (!isDth && state.circle == null) || state.customAmountPaise == null) {
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

    String finalOperatorId = state.operator!.id;
    String finalOperatorName = state.operator!.name;

    // BSNL Operator Mapping Architecture
    // If the plan has a specific rechargeOperatorCode (e.g. BT for Topup, BR for STV),
    // we MUST use that specific operator ID for the recharge to succeed.
    // NOTE: Temporarily disabled as MobilePlan does not have rechargeOperatorCode yet
    /*
    if (state.selectedPlan?.rechargeOperatorCode != null && 
        state.selectedPlan!.rechargeOperatorCode != state.operator!.shortCode) {
      try {
        final operatorsList = await ref.read(operatorsProvider(serviceType).future);
        final mappedOp = operatorsList.firstWhere(
          (op) => op.shortCode == state.selectedPlan!.rechargeOperatorCode,
        );
        finalOperatorId = mappedOp.id;
        finalOperatorName = mappedOp.name;
        debugPrint('Applied BSNL Architecture Mapping: Overrode ${state.operator!.shortCode} -> ${mappedOp.shortCode}');
      } catch (e) {
        debugPrint('Warning: Failed to map rechargeOperatorCode ${state.selectedPlan!.rechargeOperatorCode}: $e');
      }
    }
    */

    final result = await repo.processRecharge(
      phoneNumber: state.phoneNumber!,
      operatorId: finalOperatorId,
      operatorName: finalOperatorName,
      circleId: state.circle?.id ?? '',
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
