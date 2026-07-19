import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../data/dmt_repository_mock.dart';
import '../domain/dmt_repository.dart';
import '../domain/models/dmt_models.dart';

final dmtRepositoryProvider = Provider<DmtRepository>((ref) {
  return DmtRepositoryMock();
});

class DmtState {
  final Remitter? currentRemitter;
  final String? searchMobileNumber;
  final Beneficiary? selectedBeneficiary;
  final int? transferAmountPaise;
  final DmtTransferMode transferMode;

  const DmtState({
    this.currentRemitter,
    this.searchMobileNumber,
    this.selectedBeneficiary,
    this.transferAmountPaise,
    this.transferMode = DmtTransferMode.imps,
  });

  DmtState copyWith({
    Remitter? currentRemitter,
    String? searchMobileNumber,
    Beneficiary? selectedBeneficiary,
    int? transferAmountPaise,
    DmtTransferMode? transferMode,
    bool clearBeneficiary = false,
  }) {
    return DmtState(
      currentRemitter: currentRemitter ?? this.currentRemitter,
      searchMobileNumber: searchMobileNumber ?? this.searchMobileNumber,
      selectedBeneficiary: clearBeneficiary ? null : (selectedBeneficiary ?? this.selectedBeneficiary),
      transferAmountPaise: transferAmountPaise ?? this.transferAmountPaise,
      transferMode: transferMode ?? this.transferMode,
    );
  }
}

class DmtFlowNotifier extends Notifier<DmtState> {
  @override
  DmtState build() => const DmtState();

  Future<void> searchRemitter(String mobile) async {
    state = state.copyWith(searchMobileNumber: mobile);
    final repo = ref.read(dmtRepositoryProvider);
    final result = await repo.getRemitter(mobile);
    
    result.onSuccess((remitter) {
      state = state.copyWith(currentRemitter: remitter, clearBeneficiary: true);
    });
  }

  Future<void> registerRemitter(String name, String otp) async {
    if (state.searchMobileNumber == null) return;
    
    final repo = ref.read(dmtRepositoryProvider);
    final result = await repo.registerRemitter(
      mobileNumber: state.searchMobileNumber!,
      name: name,
      otp: otp,
    );
    
    result.onSuccess((remitter) {
      state = state.copyWith(currentRemitter: remitter);
    }).onFailure((e) => throw e);
  }

  void setBeneficiary(Beneficiary ben) {
    state = state.copyWith(selectedBeneficiary: ben);
  }

  void setAmount(int amountPaise) {
    state = state.copyWith(transferAmountPaise: amountPaise);
  }

  void setMode(DmtTransferMode mode) {
    state = state.copyWith(transferMode: mode);
  }

  Future<DmtResult> processTransfer(String mpin) async {
    if (state.currentRemitter == null || state.selectedBeneficiary == null || state.transferAmountPaise == null) {
      throw const ValidationException(message: 'Incomplete transfer details.');
    }
    
    final repo = ref.read(dmtRepositoryProvider);
    final result = await repo.processTransfer(
      remitterId: state.currentRemitter!.id,
      beneficiaryId: state.selectedBeneficiary!.id,
      amountPaise: state.transferAmountPaise!,
      mode: state.transferMode,
      mpin: mpin,
    );
    
    return result.getOrElseCompute((e) => throw e);
  }
  
  void reset() {
    state = const DmtState();
  }
}

final dmtFlowProvider = NotifierProvider<DmtFlowNotifier, DmtState>(
  DmtFlowNotifier.new,
);

final dmtBeneficiariesProvider = FutureProvider<List<Beneficiary>>((ref) async {
  final state = ref.watch(dmtFlowProvider);
  if (state.currentRemitter == null) return [];
  
  final repo = ref.watch(dmtRepositoryProvider);
  final result = await repo.getBeneficiaries(state.currentRemitter!.id);
  return result.getOrElseCompute((e) => throw e);
});
