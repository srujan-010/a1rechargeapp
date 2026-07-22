import '../core/services/api_client.dart';
import '../models/operator_circle_response.dart';
import '../models/mobile_plan.dart';
import '../models/plan_category.dart';
import '../features/dth/domain/models/dth_customer_info.dart';

class PlanApiException implements Exception {
  final String message;
  final String type;
  PlanApiException(this.message, this.type);
  @override
  String toString() => '[$type] $message';
}

class PlanApiService {
  PlanApiService(this.apiClient);
  
  final ApiClient apiClient;

  Future<OperatorCircleResponse> detectOperator(String mobile) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/plans/mobile/operator',
        queryParameters: {'mobile': mobile},
        fromJson: (json) => json,
      );
      
      
      print('=== PARSER TRACE: detectOperator ===');
      print('1. Received Response: ${response.data}');
      
      final decoded = response.data;
      if (decoded == null) {
        print('2. ERROR: data is null');
        throw PlanApiException('API returned null data. Raw Response: ${response.toString()}', 'API Error');
      }
      
      print('2. Detected Response Type: ${decoded.runtimeType}');

      if (decoded['STATUS'] == '0' || decoded['status'] == '0' || (decoded['ERROR'] != '0' && decoded['ERROR'] != null)) {
        print('3. ERROR: API returned failure status or error flag');
        throw PlanApiException(decoded['message'] ?? decoded['Message'] ?? 'API returned error', 'API Error');
      }
      
      print('3. Extracting operator from valid payload');
      final result = OperatorCircleResponse.fromJson(decoded);
      
      if (result.operatorName.isEmpty && result.operatorCode == null) {
        print('4. ERROR: Parsed operator is completely empty.');
        throw PlanApiException('Could not resolve operator for this number.', 'Detection Failed');
      }
      
      print('4. Returning OperatorCircleResponse: ${result.operatorName}');
      return result;
    } catch (e) {
      print('ERROR TRACE: detectOperator failed - $e');
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to fetch operator: $e', 'Network Error');
    }
  }

  Future<List<PlanCategory>> fetchMobilePlans(String operatorCode, String circleCode) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/plans/mobile/packs',
        queryParameters: {
          'operatorcode': operatorCode,
          'circle': circleCode
        },
        fromJson: (json) => json,
      );
      
      final decoded = response.data;
      if (decoded == null) {
        throw PlanApiException('API returned null data. Raw Response: ${response.toString()}', 'API Error');
      }

      if (decoded is List) {
        if (decoded.isEmpty) throw PlanApiException('No plans available', 'Empty Plans');
        final plans = decoded.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
        return [PlanCategory(name: '⭐ All Plans', plans: plans)];
      }
      
      if (decoded is Map) {
        final List<PlanCategory> categories = [];
        final dynamic rdata = decoded['RDATA'] ?? decoded['rdata'];
        
        if (rdata is Map) {
          for (final entry in rdata.entries) {
            if (entry.value is List) {
              final categoryList = entry.value as List;
              if (categoryList.isNotEmpty) {
                final plans = categoryList.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
                categories.add(PlanCategory(name: entry.key, plans: plans));
              }
            }
          }
        } else {
          final List<dynamic> data = decoded['data'] ?? decoded['DATA'] ?? decoded['records'] ?? decoded['plans'] ?? [];
          if (data.isNotEmpty) {
            final plans = data.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
            categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
          }
        }
        
        if (categories.isNotEmpty) return categories;

        if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0') {
           throw PlanApiException(decoded['message'] ?? 'API returned error', 'API Error');
        }
        throw PlanApiException('No plans available', 'Empty Plans');
      }
      
      throw PlanApiException('Invalid format', 'Parsing Error');
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to fetch mobile plans: $e', 'Parsing Error');
    }
  }

  // DTH ENDPOINTS

  Future<OperatorCircleResponse> fetchDthOperator(String subscriberId) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/plans/dth/operator',
        queryParameters: {'mobile': subscriberId},
        fromJson: (json) => json,
      );
      
      print('=== PARSER TRACE: fetchDthOperator ===');
      print('1. Received Response: ${response.data}');
      
      final decoded = response.data;
      if (decoded == null) {
        print('2. ERROR: data is null');
        throw PlanApiException('API returned null data. Raw Response: ${response.toString()}', 'API Error');
      }
      print('2. Detected Response Type: ${decoded.runtimeType}');

      if (decoded['Operator'] == null && decoded['operator'] == null && decoded['DthName'] == null) {
         print('3. ERROR: Could not detect DTH operator from payload');
         throw PlanApiException(decoded['message'] ?? 'Could not detect DTH operator', 'API Error');
      }

      print('3. Extracting operator from valid payload');
      final result = OperatorCircleResponse.fromJson(decoded);
      print('4. Returning OperatorCircleResponse: ${result.operatorName}');
      return result;
    } catch (e) {
      print('ERROR TRACE: fetchDthOperator failed - $e');
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to fetch DTH Operator: $e', 'Network Error');
    }
  }

  Future<DthCustomerInfo> fetchDthBasicDetails(String subscriberId, String operatorCode) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/plans/dth/info',
        queryParameters: {
          'mobile': subscriberId,
          'operatorcode': operatorCode
        },
        fromJson: (json) => json,
      );
      
      final decoded = response.data;
      if (decoded == null) {
        throw PlanApiException('API returned null data. Raw Response: ${response.toString()}', 'API Error');
      }

      if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0' && decoded['STATUS'] != '1') {
         throw PlanApiException(decoded['message'] ?? 'Failed to fetch basic details', 'API Error');
      }

      return DthCustomerInfo.fromJson(decoded);
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to fetch DTH Basic Details: $e', 'Parsing Error');
    }
  }

  Future<List<PlanCategory>> fetchDthPlans(String operatorCode) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/plans/dth/packs',
        queryParameters: {'operatorcode': operatorCode},
        fromJson: (json) => json,
      );
      
      final decoded = response.data;
      if (decoded == null) {
        throw PlanApiException('API returned null data. Raw Response: ${response.toString()}', 'API Error');
      }

      if (decoded is List) {
        if (decoded.isEmpty) throw PlanApiException('No DTH plans available', 'Empty Plans');
        final plans = decoded.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
        return [PlanCategory(name: '⭐ All Plans', plans: plans)];
      }
      
      if (decoded is Map) {
        final List<PlanCategory> categories = [];
        final dynamic rdata = decoded['RDATA'] ?? decoded['rdata'];
        
        if (rdata is Map) {
          for (final entry in rdata.entries) {
            if (entry.value is List) {
              final listData = entry.value as List;
              if (listData.isNotEmpty) {
                final firstItem = listData.first as Map<String, dynamic>;
                
                if (firstItem.containsKey('Language') && firstItem.containsKey('Details')) {
                   for (final langObj in listData) {
                     final String categoryName = langObj['Language']?.toString() ?? entry.key;
                     final List<dynamic> details = langObj['Details'] ?? [];
                     final List<MobilePlan> plans = [];
                     
                     for (final detail in details) {
                        final String planName = detail['PlanName']?.toString() ?? '';
                        final String channels = detail['Channels']?.toString() ?? '';
                        final String paidChannels = detail['PaidChannels']?.toString() ?? '';
                        final String hdChannels = detail['HdChannels']?.toString() ?? '';
                        final String lastUpdate = detail['last_update']?.toString() ?? '';
                        
                        final List<dynamic> pricingList = detail['PricingList'] ?? [];
                        final List<PlanPricing> pricingOptions = pricingList.map((p) => PlanPricing.fromJson(p as Map<String, dynamic>)).toList();
                        
                        String defaultAmount = '0';
                        String defaultValidity = '';
                        if (pricingOptions.isNotEmpty) {
                          defaultAmount = pricingOptions.first.amount;
                          defaultValidity = pricingOptions.first.validity;
                        } else {
                          defaultAmount = detail['Amount']?.toString() ?? detail['Price']?.toString() ?? '0';
                          defaultAmount = defaultAmount.replaceAll(RegExp(r'[^0-9.]'), '').trim();
                          defaultValidity = detail['Validity']?.toString() ?? detail['validity']?.toString() ?? '';
                        }
                        
                        plans.add(MobilePlan(
                           id: '',
                           rs: defaultAmount,
                           desc: planName,
                           validity: defaultValidity,
                           lastUpdate: lastUpdate,
                           channels: channels,
                           paidChannels: paidChannels,
                           hdChannels: hdChannels,
                           language: categoryName,
                           pricingOptions: pricingOptions.isNotEmpty ? pricingOptions : null,
                        ));
                     }
                     if (plans.isNotEmpty) {
                       categories.add(PlanCategory(name: categoryName, plans: plans));
                     }
                   }
                } 
                else {
                  final plans = listData.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
                  categories.add(PlanCategory(name: entry.key, plans: plans));
                }
              }
            }
          }
        } else if (rdata is List) {
          final plans = rdata.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
          categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
        } else {
          final List<dynamic> data = decoded['data'] ?? decoded['DATA'] ?? decoded['records'] ?? decoded['plans'] ?? [];
          if (data.isNotEmpty) {
            final plans = data.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
            categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
          }
        }
        
        if (categories.isNotEmpty) return categories;

        if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0' && decoded['STATUS'] != '1') {
           throw PlanApiException(decoded['message'] ?? 'API returned error', 'API Error');
        }

        throw PlanApiException('No DTH plans available', 'Empty Plans');
      }
      
      throw PlanApiException('Invalid response format', 'Parsing Error');
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to fetch DTH Plans: $e', 'Parsing Error');
    }
  }
}
