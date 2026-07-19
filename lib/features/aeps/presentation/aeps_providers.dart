import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../data/aeps_repository_mock.dart';
import '../domain/aeps_repository.dart';
import '../domain/models/aeps_models.dart';

final aepsRepositoryProvider = Provider<AepsRepository>((ref) {
  return AepsRepositoryMock();
});

final aepsBanksProvider = FutureProvider<List<Bank>>((ref) async {
  final repo = ref.watch(aepsRepositoryProvider);
  final result = await repo.getBanks();
  return result.getOrElseCompute((e) => throw e);
});

class AepsState {
  final AepsTransactionType? transactionType;
  final Bank? selectedBank;
  final String? aadhaarNumber;
  final int? amountPaise;
  final String? selectedDevice; // 'mantra', 'morpho', etc.

  const AepsState({
    this.transactionType,
    this.selectedBank,
    this.aadhaarNumber,
    this.amountPaise,
    this.selectedDevice,
  });

  AepsState copyWith({
    AepsTransactionType? transactionType,
    Bank? selectedBank,
    String? aadhaarNumber,
    int? amountPaise,
    String? selectedDevice,
  }) {
    return AepsState(
      transactionType: transactionType ?? this.transactionType,
      selectedBank: selectedBank ?? this.selectedBank,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      amountPaise: amountPaise ?? this.amountPaise,
      selectedDevice: selectedDevice ?? this.selectedDevice,
    );
  }
}

class AepsFlowNotifier extends Notifier<AepsState> {
  @override
  AepsState build() => const AepsState();

  void setTransactionType(AepsTransactionType type) {
    state = state.copyWith(transactionType: type);
  }

  void setBank(Bank bank) {
    state = state.copyWith(selectedBank: bank);
  }

  void setAadhaarNumber(String aadhaar) {
    state = state.copyWith(aadhaarNumber: aadhaar);
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(amountPaise: amountPaise);
  }

  void setDevice(String deviceId) {
    state = state.copyWith(selectedDevice: deviceId);
  }

  Future<AepsResult> processTransaction() async {
    if (state.transactionType == null || 
        state.selectedBank == null || 
        state.aadhaarNumber == null || 
        state.aadhaarNumber!.length != 12) {
      throw const ValidationException(message: 'Incomplete transaction details.');
    }

    final repo = ref.read(aepsRepositoryProvider);
    final result = await repo.performTransaction(
      type: state.transactionType!,
      bank: state.selectedBank!,
      aadhaarNumber: state.aadhaarNumber!,
      amountPaise: state.amountPaise,
    );

    return result.getOrElseCompute((e) => throw e);
  }

  void reset() {
    state = const AepsState();
  }
}

final aepsFlowProvider = NotifierProvider<AepsFlowNotifier, AepsState>(
  AepsFlowNotifier.new,
);
