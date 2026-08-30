import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/utils/logger.dart';


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
  return PlanApiService(ref.watch(apiClientProvider));
});

final mobilePlanRepositoryProvider = Provider<MobilePlanRepository>((ref) {
  return MobilePlanRepository(ref.watch(planApiServiceProvider));
});

// A family provider to fetch operators by service type ('mobile', 'dth', etc.)
final operatorsProvider = FutureProvider.family<List<Operator>, String>((ref, serviceType) async {
  final cache = LocalCacheService.instance;
  final cacheKey = 'operators_$serviceType';

  // 1. Check local Hive cache
  final cachedList = cache.get<List<dynamic>>(cache.operatorsBox, cacheKey);
  List<Operator>? cachedOps;
  if (cachedList != null) {
    try {
      cachedOps = cachedList
          .map((e) => Operator.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
  }

  // 2. Fetch fresh data with 3-second timeout
  try {
    final repo = ref.watch(rechargeRepositoryProvider);
    final result = await repo.getOperators(serviceType: serviceType).timeout(const Duration(seconds: 3));
    final ops = result.valueOrNull;
    if (ops != null && ops.isNotEmpty) {
      cache.put(cache.operatorsBox, cacheKey, ops.map((o) => o.toJson()).toList());
      return ops;
    }
  } catch (e) {
    AppLogger.warning('Operators network fetch fallback to cache: $e', tag: 'OperatorsProvider');
  }

  return cachedOps ?? <Operator>[];
});


// A provider to fetch all circles with local cache
final circlesProvider = FutureProvider<List<Circle>>((ref) async {
  final cache = LocalCacheService.instance;
  const cacheKey = 'cached_circles';

  final cachedList = cache.get<List<dynamic>>(cache.operatorsBox, cacheKey);
  List<Circle>? cachedCircles;
  if (cachedList != null) {
    try {
      cachedCircles = cachedList
          .map((e) => Circle.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {}
  }

  try {
    final repo = ref.watch(rechargeRepositoryProvider);
    final result = await repo.getCircles().timeout(const Duration(seconds: 3));
    final freshCircles = result.valueOrNull;
    if (freshCircles != null && freshCircles.isNotEmpty) {
      cache.put(cache.operatorsBox, cacheKey, freshCircles.map((c) => c.toJson()).toList());
      return freshCircles;
    }
  } catch (e) {
    AppLogger.warning('Circles network fetch fallback to cache: $e', tag: 'CirclesProvider');
  }

  return cachedCircles ?? <Circle>[];
});

// A provider to fetch plans based on operatorId, circle, and serviceType with cache
final plansProvider = FutureProvider.family<List<PlanCategory>, ({String operatorId, String circle, String serviceType})>((ref, params) async {
  try {
    // Convert Operator Name/ID to PlanAPI Numeric Code
    String operatorCode = params.operatorId;
    final ops = ref.read(operatorsProvider(params.serviceType)).valueOrNull ?? [];
    final op = ops.where((o) => o.id == params.operatorId || o.shortCode == params.operatorId || o.name == params.operatorId).firstOrNull;
    
    if (op != null) {
       if (op.plansApiCode != null && op.plansApiCode!.isNotEmpty) {
         operatorCode = op.plansApiCode!;
       } else {
         final registeredOp = OperatorRegistry.instance.getOperatorByName(op.name);
         if (registeredOp != null) {
           operatorCode = registeredOp.code.toString();
         } else if (op.shortCode != null && op.shortCode!.isNotEmpty) {
           operatorCode = op.shortCode!;
         }
       }
    } else {
       final registeredOp = OperatorRegistry.instance.getOperatorByName(params.operatorId);
       if (registeredOp != null) {
         operatorCode = registeredOp.code.toString();
       }
    }

    String circleCode = params.circle;
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

    final cache = LocalCacheService.instance;
    final cacheKey = 'mobile_${operatorCode}_$circleCode';

    // 1. Check cached plans
    final cachedList = cache.get<List<dynamic>>(cache.plansBox, cacheKey);
    List<PlanCategory>? cachedCategories;
    if (cachedList != null) {
      try {
        cachedCategories = cachedList
            .map((e) => PlanCategory.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    debugPrint('\n====================================================');
    debugPrint('[PLAN API REQUEST AFTER MANUAL OPERATOR CHANGE]');
    debugPrint('====================================================');
    debugPrint('operator: ${op?.name ?? params.operatorId}');
    debugPrint('operatorId: ${params.operatorId}');
    debugPrint('plansApiOperatorCode: $operatorCode');
    debugPrint('circleCode: $circleCode');
    debugPrint('====================================================\n');

    final repo = ref.watch(mobilePlanRepositoryProvider);
    final result = await repo.fetchMobilePlans(operatorCode, circleCode).timeout(const Duration(seconds: 4));
    final freshCategories = result.valueOrNull;

    if (freshCategories != null && freshCategories.isNotEmpty) {
      cache.put(cache.plansBox, cacheKey, freshCategories.map((c) => c.toJson()).toList());
      return freshCategories;
    }

    return cachedCategories ?? <PlanCategory>[];
  } catch (e) {
    AppLogger.warning('Plans network fetch fallback to cache: $e', tag: 'PlansProvider');
  }

  return <PlanCategory>[];
});

// A provider to fetch DTH packs based on operatorId
final dthPacksProvider = FutureProvider.family<List<dynamic>, String>((ref, operatorId) async {
  // DTH plans fetching is temporarily disabled due to migration
  throw UnimplementedError('DTH plans fetching is not yet implemented in PlanAPI');
});

enum RechargeTransactionState {
  mpinVerified,
  requestSubmitted,
  processing,
  success,
  failed,
  pendingTimeout,
}

// State classes for the recharge flow
class RechargeState {
  final String? phoneNumber;
  final Operator? autoOperator;
  final Circle? autoCircle;
  final Operator? manualOperator;
  final Circle? manualCircle;
  final MobilePlan? selectedPlan;
  final String? selectedPlanCategory;
  final String? selectedPlanType;
  final String? providerOperatorCode;
  final int? customAmountPaise;
  final bool isDetecting;
  final bool isProcessing;
  final RechargeTransactionState transactionState;

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
    this.selectedPlanCategory,
    this.selectedPlanType,
    this.providerOperatorCode,
    this.customAmountPaise,
    this.isDetecting = false,
    this.isProcessing = false,
    this.transactionState = RechargeTransactionState.mpinVerified,
  });

  RechargeState copyWith({
    String? phoneNumber,
    Operator? autoOperator,
    Circle? autoCircle,
    Operator? manualOperator,
    Circle? manualCircle,
    MobilePlan? selectedPlan,
    String? selectedPlanCategory,
    String? selectedPlanType,
    String? providerOperatorCode,
    int? customAmountPaise,
    bool? isDetecting,
    bool? isProcessing,
    RechargeTransactionState? transactionState,
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
      selectedPlanCategory: selectedPlanCategory ?? (clearPlan ? null : this.selectedPlanCategory),
      selectedPlanType: selectedPlanType ?? (clearPlan ? null : this.selectedPlanType),
      providerOperatorCode: providerOperatorCode ?? (clearPlan ? null : this.providerOperatorCode),
      customAmountPaise: customAmountPaise ?? (clearPlan ? null : this.customAmountPaise),
      isDetecting: isDetecting ?? this.isDetecting,
      isProcessing: isProcessing ?? this.isProcessing,
      transactionState: transactionState ?? this.transactionState,
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

  void setPlan(MobilePlan plan, {String? categoryName}) {
    final catName = categoryName ?? '';
    final op = state.operator;
    final opNameUpper = (op?.name ?? '').toUpperCase();
    
    String planType = 'TOPUP';
    String? providerCode = op?.shortCode ?? op?.code;

    if (opNameUpper.contains('BSNL')) {
      final catUpper = catName.toUpperCase();
      if (catUpper.contains('TOPUP') || catUpper.contains('FULLTT') || catUpper.contains('TALKTIME')) {
        planType = 'TOPUP';
        providerCode = 'BT';
      } else {
        planType = 'STV';
        providerCode = 'BR';
      }
    } else {
      if (catName.toUpperCase().contains('TOPUP') || catName.toUpperCase().contains('FULLTT')) {
        planType = 'TOPUP';
      } else {
        planType = 'STV';
      }
    }

    state = state.copyWith(
      selectedPlan: plan,
      customAmountPaise: (double.tryParse(plan.rs ?? '0') ?? 0).toInt() * 100,
      selectedPlanCategory: catName,
      selectedPlanType: planType,
      providerOperatorCode: providerCode,
    );
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(customAmountPaise: amountPaise, clearPlan: true);
  }

  void setupRechargeAgain({
    required String phoneNumber,
    required Operator operator,
    required Circle circle,
    required int amountPaise,
    String? rechargeType,
    String? providerOperatorCode,
  }) {
    final catName = rechargeType ?? '';
    String planType = 'TOPUP';
    final catUpper = catName.toUpperCase();
    if (catUpper.contains('STV') || catUpper.contains('DATA') || catUpper.contains('MONTH') || catUpper.contains('YEAR') || catUpper.contains('PLAN')) {
      planType = 'STV';
    } else if (catUpper.contains('TOPUP') || catUpper.contains('TALKTIME')) {
      planType = 'TOPUP';
    } else {
      planType = catName.isNotEmpty ? catName : 'TOPUP';
    }

    state = RechargeState(
      phoneNumber: phoneNumber,
      autoOperator: operator,
      autoCircle: circle,
      customAmountPaise: amountPaise,
      selectedPlanCategory: catName,
      selectedPlanType: planType,
      providerOperatorCode: providerOperatorCode ?? operator.shortCode ?? operator.code,
    );
  }
  
  void reset() {
    state = const RechargeState();
  }

  // Action method to process the recharge
  Future<RechargeReceipt> processRecharge({String? mpin, String paymentMode = 'wallet'}) async {
    if (state.isProcessing) {
      throw const ValidationException(
        message: 'A recharge is currently being processed. Please wait.',
        code: 'DUPLICATE_SUBMISSION',
      );
    }

    final isDth = state.operator?.type == OperatorType.dth;
    if (state.phoneNumber == null || state.operator == null || (!isDth && state.circle == null) || state.customAmountPaise == null) {
      throw const ValidationException(message: 'Incomplete recharge details', code: 'INVALID_STATE');
    }
    
    if (paymentMode == 'wallet' && mpin == null) {
      throw const ValidationException(message: 'MPIN is required for wallet payments', code: 'INVALID_MPIN');
    }

    debugPrint('[FLOW] Processing State');
    state = state.copyWith(
      isProcessing: true,
      transactionState: RechargeTransactionState.requestSubmitted,
    );

    try {
      final repo = ref.read(rechargeRepositoryProvider);
      
      // Map flutter OperatorType to backend serviceType
      final serviceType = switch (state.operator!.type) {
        OperatorType.prepaid => 'mobile',
        OperatorType.dth => 'dth',
        OperatorType.postpaid => 'bbps',
      };

      String finalOperatorId = state.operator!.id;
      String finalOperatorName = state.operator!.name;

      AppLogger.info('[RECHARGE] Request started for ${state.phoneNumber}', tag: 'RechargeFlow');
      final result = await repo.processRecharge(
        phoneNumber: state.phoneNumber!,
        operatorId: finalOperatorId,
        operatorName: finalOperatorName,
        circleId: state.circle?.id ?? '',
        serviceType: serviceType,
        amountPaise: state.customAmountPaise!,
        mpin: mpin,
        paymentMode: paymentMode,
        planId: state.selectedPlan?.id,
        planName: state.selectedPlan?.desc,
        planType: state.selectedPlanType,
        selectedCategory: state.selectedPlanCategory,
        providerOperatorCode: state.providerOperatorCode,
      );

      final receipt = result.getOrElseCompute((e) => throw e);
      AppLogger.info('[RECHARGE] Provider response received: status=${receipt.status.name}, orderId=${receipt.transactionId}', tag: 'RechargeFlow');
      AppLogger.info('[RECHARGE] Normalized status: ${receipt.status.name.toUpperCase()}', tag: 'RechargeFlow');
      AppLogger.info('[RECHARGE] Order ID: ${receipt.transactionId}', tag: 'RechargeFlow');

      final walletAsync = ref.read(walletBalanceProvider);
      final finalReceipt = receipt.copyWith(
        paymentMode: paymentMode.toUpperCase(),
        circle: state.circle?.state,
        walletBalancePaise: walletAsync.valueOrNull?.availablePaise,
      );

      final nextTxnState = switch (receipt.status) {
        RechargeStatus.success => RechargeTransactionState.success,
        RechargeStatus.failed => RechargeTransactionState.failed,
        RechargeStatus.pending || RechargeStatus.processing => RechargeTransactionState.processing,
      };

      state = state.copyWith(
        isProcessing: receipt.status == RechargeStatus.pending || receipt.status == RechargeStatus.processing,
        transactionState: nextTxnState,
      );

      if (finalReceipt.isSuccess) {
        AppLogger.info('[RECHARGE] FINAL STATUS: SUCCESS', tag: 'RechargeFlow');
      } else if (finalReceipt.isFailed) {
        AppLogger.info('[RECHARGE] FINAL STATUS: FAILED', tag: 'RechargeFlow');
      }

      // ── NON-CRITICAL POST-PROCESSING ──
      // Isolated in safe try-catch so post-processing errors never convert SUCCESS -> FAILED
      try {
        if (finalReceipt.isSuccess && state.operator != null) {
          final contact = RecentContact(
            phone: finalReceipt.mobileNumber,
            operatorId: state.operator!.id,
            circle: state.circle?.state ?? 'Unknown',
            lastRechargeDate: DateTime.now(),
            lastRechargeAmountPaise: finalReceipt.amountPaise,
          );
          await repo.saveRecentContact(contact);
        }

        ref.invalidate(walletBalanceProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(earningsSummaryProvider);
        ref.invalidate(recentContactsProvider);
      } catch (e) {
        AppLogger.warning('[RECHARGE] POST-PROCESSING ERROR: $e', tag: 'RechargeFlow');
        if (finalReceipt.isSuccess) {
          AppLogger.info('[RECHARGE] Recharge already finalized as SUCCESS - NOT changing recharge status to FAILED', tag: 'RechargeFlow');
        }
      }

      return finalReceipt;
    } catch (e) {
      AppLogger.error('[RECHARGE] Recharge execution exception: $e', tag: 'RechargeFlow');
      state = state.copyWith(
        isProcessing: false,
        transactionState: RechargeTransactionState.failed,
      );
      rethrow;
    }
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

final rechargePayableProvider = FutureProvider.family<Map<String, dynamic>, ({
  String phoneNumber,
  String operatorId,
  String operatorName,
  String circleId,
  String serviceType,
  int amountPaise,
  String? planType,
})>((ref, params) async {
  final repo = ref.watch(rechargeRepositoryProvider);
  final res = await repo.calculatePayableAmount(
    phoneNumber: params.phoneNumber,
    operatorId: params.operatorId,
    operatorName: params.operatorName,
    circleId: params.circleId,
    serviceType: params.serviceType,
    amountPaise: params.amountPaise,
    planType: params.planType,
  );
  return res.valueOrNull ?? {};
});

