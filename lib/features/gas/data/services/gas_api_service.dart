import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/services/api_client.dart';
import '../../domain/models/gas_models.dart';

class GasApiService {
  const GasApiService(this._apiClient);
  final ApiClient _apiClient;

  Future<List<GasOperator>> getOperators({String? search, int page = 1}) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.gasProviders,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
        },
        fromJson: (json) => json as List<dynamic>,
      );
      
      final data = response.data;
      if (data == null) {
        return [];
      }
      
      return data.map((json) => GasOperator.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, st) {
      print('=== GAS OPERATORS PARSE ERROR ===');
      print(e);
      print(st);
      print('=================================');
      rethrow;
    }
  }

  Future<GasBill> fetchBill({
    required String billerId,
    required Map<String, String> parameters,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.gasFetch,
      data: {
        'billerId': billerId,
        'parameters': parameters,
      },
      fromJson: (json) => json as Map<String, dynamic>,
    );
    
    if (response.data == null) {
      throw Exception('Failed to fetch bill: No data returned');
    }
    
    return GasBill.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> payBill({
    required String billerId,
    required int amountPaise,
    required String customerIdentifier,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.gasPay,
      data: {
        'billerId': billerId,
        'amountPaise': amountPaise,
        'customerIdentifier': customerIdentifier,
      },
      fromJson: (json) => json as Map<String, dynamic>,
    );
    
    return response.data ?? {};
  }
}
