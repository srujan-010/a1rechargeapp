import '../models/fastag_models.dart';
import '../services/fastag_api_service.dart';

class FastagRepository {
  const FastagRepository(this._apiService);
  final FastagApiService _apiService;

  Future<List<FastagOperator>> getOperators({String? search, int page = 1}) {
    return _apiService.getOperators(search: search, page: page);
  }

  Future<FastagDetails> fetchDetails({
    required String billerId,
    required Map<String, String> parameters,
  }) {
    return _apiService.fetchDetails(billerId: billerId, parameters: parameters);
  }

  Future<Map<String, dynamic>> payFastag({
    required String billerId,
    required int amountPaise,
    required String vehicleNumber,
  }) {
    return _apiService.payFastag(
      billerId: billerId,
      amountPaise: amountPaise,
      vehicleNumber: vehicleNumber,
    );
  }
}
