import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/api_client.dart';
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
import '../../../../core/constants/operator_registry.dart';
import '../../../recharge/presentation/recharge_providers.dart';
import '../../../../core/utils/result.dart';

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
      error: error,
      customerInfo: clearCustomerInfo ? null : (customerInfo ?? this.customerInfo),
    );
  }

  @override
  List<Object?> get props => [selectedOperator, subscriberId, selectedPack, selectedPlan, customAmountPaise, isLoading, isDetecting, error, customerInfo];
}

// DTH Flow Notifier
class DthFlowNotifier extends StateNotifier<DthFlowState> {
  final DthRepository _repository;
  final DthPlanRepository _planRepository;
  final Ref _ref;

  DthFlowNotifier(this._repository, this._planRepository, this._ref) : super(const DthFlowState());

  void setOperator(Operator operator) {
    state = state.copyWith(selectedOperator: operator, clearCustomerInfo: true);
    if (state.subscriberId != null && state.subscriberId!.length >= 4) {
      _fetchCustomerInfo(state.subscriberId!, operator);
    }
  }

  void setSubscriberId(String subscriberId) {
    if (state.subscriberId == subscriberId) return;
    state = state.copyWith(subscriberId: subscriberId);

    // Auto-detect when length is sufficient
    if (subscriberId.length >= 6) {
      _autoDetectOperator(subscriberId);
    }
  }

  Future<void> _autoDetectOperator(String subscriberId) async {
    state = state.copyWith(isDetecting: true);
    final result = await _planRepository.fetchDthOperator(subscriberId);
    
    if (result is Success) {
      final response = (result as Success).value;
      if (response.operatorName != null) {
        final ops = _ref.read(dthOperatorsProvider).valueOrNull ?? [];
        final normalized = response.operatorName!.toLowerCase().replaceAll(' ', '');
        
        final op = ops.where((o) => o.name.toLowerCase().replaceAll(' ', '').contains(normalized)).firstOrNull;
        
        if (op != null) {
          final detectedCode = response.operatorCode ?? '';
          final registryCode = op.planApiCode ?? '';
          
          print('Operator Detection returned: $detectedCode');
          print('Operator Registry PlanAPI Code: $registryCode');
          
          if (detectedCode.isNotEmpty && registryCode.isNotEmpty && detectedCode != registryCode) {
            state = state.copyWith(
              isDetecting: false,
              error: 'Operator mismatch: API returned $detectedCode but registry has $registryCode',
            );
            return;
          }
          
          state = state.copyWith(
            selectedOperator: op, 
            isDetecting: false,
            clearCustomerInfo: true,
          );
          _fetchCustomerInfo(subscriberId, op);
          return;
        }
      }
      state = state.copyWith(isDetecting: false);
    } else {
      state = state.copyWith(isDetecting: false);
    }
  }

  Future<void> _fetchCustomerInfo(String subscriberId, Operator operator) async {
    final planApiCode = operator.planApiCode;
    
    if (planApiCode == null || planApiCode.isEmpty) {
      state = state.copyWith(clearCustomerInfo: true);
      return;
    }
    
    print('==================================================');
    print('Operator: ${operator.name}');
    print('Mongo ID: ${operator.id}');
    print('PlanAPI Code: $planApiCode');
    print('A1 Code: ${operator.shortCode}');
    print('Basic Details Request: Opcode=$planApiCode');
    print('==================================================');

    final result = await _planRepository.fetchDthBasicDetails(subscriberId, planApiCode);
    
    if (result is Success) {
      state = state.copyWith(customerInfo: (result as Success).value);
    } else {
      // We don't throw, we just don't populate info
      state = state.copyWith(clearCustomerInfo: true);
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
