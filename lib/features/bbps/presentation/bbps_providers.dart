import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_exception.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../data/bbps_repository_mock.dart';
import '../data/bbps_repository_impl.dart';
import '../domain/bbps_repository.dart';
import '../domain/models/bbps_models.dart';

final bbpsRepositoryProvider = Provider<BbpsRepository>((ref) {
  final mockFallback = BbpsRepositoryMock();
  return BbpsRepositoryImpl(mockFallback);
});

class BillerFetchParams extends Equatable {
  final String category;
  final String? state;

  const BillerFetchParams({required this.category, this.state});

  @override
  List<Object?> get props => [category, state];
}

final billersProvider = FutureProvider.family<List<Biller>, BillerFetchParams>((ref, params) async {
  final repo = ref.watch(bbpsRepositoryProvider);
  final result = await repo.getBillers(category: params.category, state: params.state);
  return result.getOrElseCompute((e) => throw e);
});

final statesProvider = FutureProvider.family<List<String>, String>((ref, category) async {
  final repo = ref.watch(bbpsRepositoryProvider);
  final result = await repo.getStates(category: category);
  return result.getOrElseCompute((e) => throw e);
});

final billerDistrictsProvider = FutureProvider.family<List<BillerDistrict>, String>((ref, operatorCode) async {
  final repo = ref.watch(bbpsRepositoryProvider);
  final result = await repo.getDistricts(operatorCode: operatorCode);
  return result.getOrElseCompute((e) => throw e);
});

class BbpsState {
  final Biller? selectedBiller;
  final BillerDistrict? selectedDistrict;
  final Map<String, String> enteredParameters;
  final BillDetails? fetchedBill;

  const BbpsState({
    this.selectedBiller,
    this.selectedDistrict,
    this.enteredParameters = const {},
    this.fetchedBill,
  });

  BbpsState copyWith({
    Biller? selectedBiller,
    BillerDistrict? selectedDistrict,
    Map<String, String>? enteredParameters,
    BillDetails? fetchedBill,
    bool clearBill = false,
    bool clearDistrict = false,
  }) {
    return BbpsState(
      selectedBiller: selectedBiller ?? this.selectedBiller,
      selectedDistrict: clearDistrict ? null : (selectedDistrict ?? this.selectedDistrict),
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
      clearDistrict: true,
    );
  }

  void setDistrict(BillerDistrict district) {
    state = state.copyWith(
      selectedDistrict: district,
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
