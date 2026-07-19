import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../data/loan_repository_mock.dart';
import '../domain/loan_repository.dart';
import '../domain/models/loan_models.dart';

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepositoryMock();
});

final loanProvidersListProvider = FutureProvider<List<LoanProvider>>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  final result = await repo.getProviders();
  return result.getOrElseCompute((e) => throw e);
});

class LoanState {
  final LoanProvider? selectedProvider;
  final LoanDetails? fetchedLoan;

  const LoanState({
    this.selectedProvider,
    this.fetchedLoan,
  });

  LoanState copyWith({
    LoanProvider? selectedProvider,
    LoanDetails? fetchedLoan,
    bool clearLoan = false,
  }) {
    return LoanState(
      selectedProvider: selectedProvider ?? this.selectedProvider,
      fetchedLoan: clearLoan ? null : (fetchedLoan ?? this.fetchedLoan),
    );
  }
}

class LoanFlowNotifier extends Notifier<LoanState> {
  @override
  LoanState build() => const LoanState();

  void selectProvider(LoanProvider provider) {
    state = state.copyWith(selectedProvider: provider, clearLoan: true);
  }

  Future<void> fetchLoanDetails(String loanAccountNumber) async {
    if (state.selectedProvider == null) return;

    final repo = ref.read(loanRepositoryProvider);
    final result = await repo.fetchLoanDetails(
      provider: state.selectedProvider!,
      loanAccountNumber: loanAccountNumber,
    );

    result.onSuccess((loan) {
      state = state.copyWith(fetchedLoan: loan);
    }).onFailure((e) => throw e);
  }

  Future<RechargeReceipt> payEmi(String mpin) async {
    if (state.fetchedLoan == null) {
      throw const ValidationException(message: 'No loan details fetched.');
    }

    final repo = ref.read(loanRepositoryProvider);
    final result = await repo.payEmi(
      loan: state.fetchedLoan!,
      mpin: mpin,
    );

    return result.getOrElseCompute((e) => throw e);
  }

  void reset() {
    state = const LoanState();
  }
}

final loanFlowProvider = NotifierProvider<LoanFlowNotifier, LoanState>(
  LoanFlowNotifier.new,
);
