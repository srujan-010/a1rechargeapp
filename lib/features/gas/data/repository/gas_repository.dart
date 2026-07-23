import '../../domain/models/gas_models.dart';
import '../services/gas_api_service.dart';

class GasRepository {
  const GasRepository(this._apiService);
  final GasApiService _apiService;

  Future<List<GasOperator>> getOperators({String? search, int page = 1}) {
    return _apiService.getOperators(search: search, page: page);
  }

  Future<GasBill> fetchBill({
    required String billerId,
    required Map<String, String> parameters,
  }) {
    return _apiService.fetchBill(billerId: billerId, parameters: parameters);
  }

  Future<Map<String, dynamic>> payBill({
    required String billerId,
    required int amountPaise,
    required String customerIdentifier,
  }) {
    return _apiService.payBill(
      billerId: billerId,
      amountPaise: amountPaise,
      customerIdentifier: customerIdentifier,
    );
  }
}
