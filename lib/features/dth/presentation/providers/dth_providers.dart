import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_exception.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../../recharge/domain/models/operator.dart';
import '../../../../models/mobile_plan.dart';
import '../../../recharge/domain/models/recharge_result.dart';
import '../../../wallet/domain/models/wallet_transaction.dart';
import '../../data/dth_repository_impl.dart';
import '../../domain/dth_repository.dart';
import '../../domain/dth_plan_repository.dart';
import '../../domain/models/dth_customer_info.dart';
import '../../../../models/plan_category.dart';
import '../../../recharge/presentation/recharge_providers.dart';

// DTH Repository Provider
final dthRepositoryProvider = Provider<DthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DthRepositoryImpl(apiClient: apiClient);
});

// DTH Plan Repository Provider
final dthPlanRepositoryProvider = Provider<DthPlanRepository>((ref) {
  final apiService = ref.watch(planApiServiceProvider);
  return DthPlanRepository(apiService);
});

// DTH Operators Provider
final dthOperatorsProvider = FutureProvider<List<Operator>>((ref) async {
  final repo = ref.watch(dthRepositoryProvider);
  final result = await repo.getDthOperators();
  return result.getOrElseCompute((e) => throw e);
});

// DTH Packs Provider for Selected Operator (using new PlanAPI)
final dthPacksProvider = FutureProvider.family<List<PlanCategory>, Operator>((ref, operator) async {
  final repo = ref.watch(dthPlanRepositoryProvider);
  
  final planApiCode = operator.planApiCode;
  if (planApiCode == null || planApiCode.isEmpty) {
    throw Exception('PlanAPI code is missing for operator ${operator.name}');
  }
  
  print('==================================================');
  print('Operator: ${operator.name}');
  print('Mongo ID: ${operator.id}');
  print('PlanAPI Code: $planApiCode');
  print('A1 Code: ${operator.shortCode}');
  print('Plans Request: operatorcode=$planApiCode');
  print('==================================================');
  
  final result = await repo.fetchDthPlans(planApiCode);
  return result.getOrElseCompute((e) => throw e);
});

// DTH History Provider
final dthHistoryProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final repo = ref.watch(dthRepositoryProvider);
  final result = await repo.getDthHistory();
  return result.getOrElseCompute((e) => throw e);
});

// DTH Flow State
class DthFlowState extends Equatable {
  final Operator? selectedOperator;
  final String? subscriberId;
  final dynamic selectedPack;
  final MobilePlan? selectedPlan;
  final int? customAmountPaise;
  final bool isLoading;
  final bool isDetecting;
  final bool isFetchingCustomerInfo;
  final String? customerInfoError;
  final String? error;
  final DthCustomerInfo? customerInfo;

  const DthFlowState({
    this.selectedOperator,
    this.subscriberId,
    this.selectedPack,
    this.selectedPlan,
    this.customAmountPaise,
    this.isLoading = false,
    this.isDetecting = false,
    this.isFetchingCustomerInfo = false,
    this.customerInfoError,
    this.error,
    this.customerInfo,
  });

  DthFlowState copyWith({
    Operator? selectedOperator,
    String? subscriberId,
    dynamic selectedPack,
    MobilePlan? selectedPlan,
    int? customAmountPaise,
    bool? isLoading,
    bool? isDetecting,
    bool? isFetchingCustomerInfo,
    String? customerInfoError,
    bool clearCustomerInfoError = false,
    String? error,
    DthCustomerInfo? customerInfo,
    bool clearCustomerInfo = false,
  }) {
    return DthFlowState(
      selectedOperator: selectedOperator ?? this.selectedOperator,
      subscriberId: subscriberId ?? this.subscriberId,
      selectedPack: selectedPack ?? this.selectedPack,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      customAmountPaise: customAmountPaise ?? this.customAmountPaise,
      isLoading: isLoading ?? this.isLoading,
      isDetecting: isDetecting ?? this.isDetecting,
      isFetchingCustomerInfo: isFetchingCustomerInfo ?? this.isFetchingCustomerInfo,
      customerInfoError: clearCustomerInfoError ? null : (customerInfoError ?? this.customerInfoError),
      error: error,
      customerInfo: clearCustomerInfo ? null : (customerInfo ?? this.customerInfo),
    );
  }

  @override
  List<Object?> get props => [selectedOperator, subscriberId, selectedPack, selectedPlan, customAmountPaise, isLoading, isDetecting, isFetchingCustomerInfo, customerInfoError, error, customerInfo];
}

// DTH Flow Notifier
class DthFlowNotifier extends StateNotifier<DthFlowState> {
  final DthRepository _repository;
  final DthPlanRepository _planRepository;
  final Ref _ref;

  DthFlowNotifier(this._repository, this._planRepository, this._ref) : super(const DthFlowState());

  void setOperator(Operator operator) {
    state = state.copyWith(selectedOperator: operator, clearCustomerInfo: true, clearCustomerInfoError: true);
    if (state.subscriberId != null && state.subscriberId!.length >= 4) {
      _fetchCustomerInfo(state.subscriberId!, operator);
    }
  }

  void setSubscriberId(String subscriberId) {
    if (state.subscriberId == subscriberId) return;
    state = state.copyWith(subscriberId: subscriberId);

    // Auto-detect when length is sufficient (minimum 10 digits for DTH Subscriber ID / VC Number)
    if (subscriberId.length >= 10) {
      _autoDetectOperator(subscriberId);
    }
  }

  Future<void> _autoDetectOperator(String subscriberId) async {
    state = state.copyWith(isDetecting: true);
    print('[DTH_FIRST_FETCH] consumerNumber=$subscriberId');

    final result = await _planRepository.fetchDthOperator(subscriberId);
    
    if (result is Success) {
      final response = (result as Success).value;
      if (response.operatorName != null) {
        // Fix race condition: await future to guarantee operators list is loaded on first attempt
        final ops = await _ref.read(dthOperatorsProvider.future);
        print('[DTH_FIRST_FETCH] operatorsReady=true (count=${ops.length})');

        final normalized = response.operatorName!.toLowerCase().replaceAll(' ', '');
        
        final op = ops.where((o) => o.name.toLowerCase().replaceAll(' ', '').contains(normalized)).firstOrNull;
        
        if (op != null) {
          final detectedCode = response.operatorCode ?? '';
          final registryCode = op.planApiCode ?? '';
          
          print('[DTH_FIRST_FETCH] resolvedOperator=${op.name}');
          print('[DTH_FIRST_FETCH] resolvedOperatorCode=$registryCode');
          
          state = state.copyWith(
            selectedOperator: op, 
            isDetecting: false,
            clearCustomerInfo: true,
            clearCustomerInfoError: true,
            error: null,
          );
          _fetchCustomerInfo(subscriberId, op);
          return;
        } else {
          print('[DTH_FIRST_FETCH] ERROR: Could not match "${response.operatorName}" in registry of ${ops.length} operators');
        }
      }
      state = state.copyWith(isDetecting: false);
    } else {
      print('[DTH_FIRST_FETCH] ERROR: fetchDthOperator failed: $result');
      state = state.copyWith(isDetecting: false);
    }
  }

  void retryCustomerInfo() {
    if (state.subscriberId != null && state.selectedOperator != null) {
      _fetchCustomerInfo(state.subscriberId!, state.selectedOperator!);
    }
  }

  Future<void> _fetchCustomerInfo(String subscriberId, Operator operator) async {
    final planApiCode = operator.planApiCode;
    
    if (planApiCode == null || planApiCode.isEmpty) {
      print('[DTH_FIRST_FETCH] ERROR: operator.planApiCode is null or empty for ${operator.name}');
      state = state.copyWith(clearCustomerInfo: true, clearCustomerInfoError: true, isFetchingCustomerInfo: false);
      return;
    }
    
    state = state.copyWith(isFetchingCustomerInfo: true, clearCustomerInfoError: true);

    print('[DTH_FIRST_FETCH] startingCustomerInfoRequest=true (subscriberId=$subscriberId, operatorCode=$planApiCode)');

    final result = await _planRepository.fetchDthBasicDetails(subscriberId, planApiCode);
    
    if (result is Success) {
      print('[DTH_FIRST_FETCH] customerInfoResponse=SUCCESS');
      print('[DTH_FIRST_FETCH] customerInfoDisplayed=true');
      state = state.copyWith(
        customerInfo: (result as Success).value,
        isFetchingCustomerInfo: false,
        clearCustomerInfoError: true,
      );
    } else {
      final failureErr = result is Failure ? (result as Failure).error : null;
      final errStr = failureErr is AppException ? failureErr.message : (failureErr?.toString() ?? '');
      print('[DTH_FIRST_FETCH] customerInfoResponse=FAILURE error=$errStr');
      state = state.copyWith(
        isFetchingCustomerInfo: false,
        clearCustomerInfo: true,
        customerInfoError: errStr.isNotEmpty ? errStr : 'Unable to fetch customer information',
      );
    }
  }

  void setPlan(MobilePlan plan) {
    state = state.copyWith(
      selectedPlan: plan, 
      customAmountPaise: (double.tryParse(plan.rs ?? '0') ?? 0).toInt() * 100
    );
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(customAmountPaise: amountPaise);
  }

  void reset() {
    state = const DthFlowState();
  }

  Future<RechargeReceipt> processDthRecharge({String? mpin, String? paymentMode}) async {
    if (state.selectedOperator == null || state.subscriberId == null || state.customAmountPaise == null) {
      throw Exception('Incomplete DTH recharge details');
    }

    state = state.copyWith(isLoading: true, error: null);

    print('==================================================');
    print('Operator: ${state.selectedOperator!.name}');
    print('Mongo ID: ${state.selectedOperator!.id}');
    print('PlanAPI Code: ${state.selectedOperator!.planApiCode}');
    print('A1 Code: ${state.selectedOperator!.shortCode}');
    print('Recharge Request: operatorcode=${state.selectedOperator!.shortCode}');
    print('==================================================');

    final result = await _repository.executeDthRecharge(
      subscriberId: state.subscriberId!,
      operatorId: state.selectedOperator!.id,
      operatorName: state.selectedOperator!.name,
      amountPaise: state.customAmountPaise!,
      packId: null,
      mpin: mpin,
      paymentMode: paymentMode ?? 'wallet',
    );

    return switch (result) {
      Success(value: final receipt) => () {
        state = state.copyWith(isLoading: false);
        return receipt;
      }(),
      Failure(error: final e) => () {
        state = state.copyWith(isLoading: false, error: e.message);
        throw e;
      }(),
    };
  }
}

// DTH Flow Provider
final dthFlowProvider = StateNotifierProvider<DthFlowNotifier, DthFlowState>((ref) {
  final repo = ref.watch(dthRepositoryProvider);
  final planRepo = ref.watch(dthPlanRepositoryProvider);
  return DthFlowNotifier(repo, planRepo, ref);
});
