import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../data/insurance_repository_mock.dart';
import '../domain/insurance_repository.dart';
import '../domain/models/insurance_models.dart';

final insuranceRepositoryProvider = Provider<InsuranceRepository>((ref) {
  return InsuranceRepositoryMock();
});

final insuranceProvidersListProvider = FutureProvider<List<InsuranceProvider>>((ref) async {
  final repo = ref.watch(insuranceRepositoryProvider);
  final result = await repo.getProviders();
  return result.getOrElseCompute((e) => throw e);
});

class InsuranceState {
  final InsuranceProvider? selectedProvider;
  final PolicyDetails? fetchedPolicy;

  const InsuranceState({
    this.selectedProvider,
    this.fetchedPolicy,
  });

  InsuranceState copyWith({
    InsuranceProvider? selectedProvider,
    PolicyDetails? fetchedPolicy,
    bool clearPolicy = false,
  }) {
    return InsuranceState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      fetchedPolicy: clearPolicy ? null : (fetchedPolicy ?? this.fetchedPolicy),
    );
  }
}

class InsuranceFlowNotifier extends Notifier<InsuranceState> {
  @override
  InsuranceState build() => const InsuranceState();

  void selectProvider(InsuranceProvider provider) {
    state = state.copyWith(selectedProvider: provider, clearPolicy: true);
  }

  Future<void> fetchPolicyDetails(String policyNumber, {String? dob}) async {
    if (state.selectedProvider == null) return;

    final repo = ref.read(insuranceRepositoryProvider);
    final result = await repo.fetchPolicyDetails(
      provider: state.selectedProvider!,
      policyNumber: policyNumber,
      dob: dob,
    );

    result.onSuccess((policy) {
      state = state.copyWith(fetchedPolicy: policy);
    }).onFailure((e) => throw e);
  }

  Future<RechargeReceipt> payPremium(String mpin) async {
    if (state.fetchedPolicy == null) {
      throw const ValidationException(message: 'No policy details fetched.');
    }

    final repo = ref.read(insuranceRepositoryProvider);
    final result = await repo.payPremium(
      policy: state.fetchedPolicy!,
      mpin: mpin,
    );

    return result.getOrElseCompute((e) => throw e);
  }

  void reset() {
    state = const InsuranceState();
  }
}

final insuranceFlowProvider = NotifierProvider<InsuranceFlowNotifier, InsuranceState>(
  InsuranceFlowNotifier.new,
);
