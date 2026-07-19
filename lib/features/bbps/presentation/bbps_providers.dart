import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../data/bbps_repository_mock.dart';
import '../domain/bbps_repository.dart';
import '../domain/models/bbps_models.dart';

final bbpsRepositoryProvider = Provider<BbpsRepository>((ref) {
  return BbpsRepositoryMock();
});

final billersProvider = FutureProvider.family<List<Biller>, String>((ref, category) async {
  final repo = ref.watch(bbpsRepositoryProvider);
  final result = await repo.getBillers(category: category);
  return result.getOrElseCompute((e) => throw e);
});

class BbpsState {
  final Biller? selectedBiller;
  final Map<String, String> enteredParameters;
  final BillDetails? fetchedBill;

  const BbpsState({
    this.selectedBiller,
    this.enteredParameters = const {},
    this.fetchedBill,
  });

  BbpsState copyWith({
    Biller? selectedBiller,
    Map<String, String>? enteredParameters,
    BillDetails? fetchedBill,
    bool clearBill = false,
  }) {
    return BbpsState(
      selectedBiller: selectedBiller ?? this.selectedBiller,
      enteredParameters: enteredParameters ?? this.enteredParameters,
      fetchedBill: clearBill ? null : (fetchedBill ?? this.fetchedBill),
    );
  }
}

class BbpsFlowNotifier extends Notifier<BbpsState> {
  @override
  BbpsState build() => const BbpsState();

  void setBiller(Biller biller) {
    state = state.copyWith(
      selectedBiller: biller,
      enteredParameters: {}, // reset params
      clearBill: true,
    );
  }

  void updateParameter(String key, String value) {
    final newParams = Map<String, String>.from(state.enteredParameters);
    newParams[key] = value;
    state = state.copyWith(enteredParameters: newParams, clearBill: true);
  }

  Future<void> fetchBill() async {
    if (state.selectedBiller == null) return;
    
    final repo = ref.read(bbpsRepositoryProvider);
    final result = await repo.fetchBill(
      billerId: state.selectedBiller!.id,
      parameters: state.enteredParameters,
    );
    
    result.onSuccess((bill) {
      state = state.copyWith(fetchedBill: bill);
    }).onFailure((e) {
      throw e;
    });
  }
  
  Future<RechargeReceipt> payBill(String mpin) async {
    if (state.fetchedBill == null) {
      throw const ValidationException(message: 'No bill fetched to pay.');
    }
    
    final repo = ref.read(bbpsRepositoryProvider);
    final result = await repo.payBill(
      billDetails: state.fetchedBill!,
      mpin: mpin,
    );
    
    return result.getOrElseCompute((e) => throw e);
  }

  void reset() {
    state = const BbpsState();
  }
}

final bbpsFlowProvider = NotifierProvider<BbpsFlowNotifier, BbpsState>(
  BbpsFlowNotifier.new,
);
