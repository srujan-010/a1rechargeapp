import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/services/api_client.dart';
import '../models/fastag_models.dart';

class FastagApiService {
  const FastagApiService(this._apiClient);
  final ApiClient _apiClient;

  Future<List<FastagOperator>> getOperators({String? search, int page = 1}) async {
    final response = await _apiClient.get(
      ApiEndpoints.fastagProviders,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
      },
    );
    final data = response.data['data'] as List;
    return data.map((json) => FastagOperator.fromJson(json)).toList();
  }

  Future<FastagDetails> fetchDetails({
    required String billerId,
    required Map<String, String> parameters,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.fastagFetch,
      data: {
        'billerId': billerId,
        'parameters': parameters,
      },
    );
    return FastagDetails.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> payFastag({
    required String billerId,
    required int amountPaise,
    required String vehicleNumber,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.fastagPay,
      data: {
        'billerId': billerId,
        'amountPaise': amountPaise,
        'customerIdentifier': vehicleNumber,
      },
    );
    return response.data;
  }
}
