import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/plan_api_config.dart';
import '../models/operator_circle_response.dart';
import '../models/mobile_plan.dart';
import '../models/plan_category.dart';
import '../features/dth/domain/models/dth_customer_info.dart';

class PlanApiException implements Exception {
  final String message;
  final String type; // Network Error, Authentication Error, API Error, Empty Plans, Invalid Operator, Invalid Circle, Parsing Error
  PlanApiException(this.message, this.type);
  @override
  String toString() => '[$type] $message';
}

class PlanApiService {
  // detectOperator - https://planapi.in/api/Mobile/OperatorFetchNew
  Future<OperatorCircleResponse> detectOperator(String mobile) async {
    final url = Uri.parse('${PlanApiConfig.baseUrl}/Mobile/OperatorFetchNew?ApiUserID=${PlanApiConfig.memberId}&ApiPassword=${PlanApiConfig.password}&Mobileno=$mobile');
    
    print('[PLAN API] Request URL: $url');
    print('[PLAN API] Parameters: Mobileno=$mobile');
    
    try {
      final response = await http.get(url);
      print('[PLAN API] Response Status: ${response.statusCode}');
      print('[PLAN API] Raw Response: ${response.body}');
      
      if (response.statusCode != 200) {
        throw PlanApiException('Failed to connect with status ${response.statusCode}', 'Network Error');
      }

      final decoded = jsonDecode(response.body);
      
      if (decoded['STATUS'] == '0' || decoded['status'] == '0') {
        throw PlanApiException(decoded['message'] ?? 'API returned error', 'API Error');
      }
      
      final result = OperatorCircleResponse.fromJson(decoded);
      return result;
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to parse response: $e', 'Parsing Error');
    }
  }

  // fetchMobilePlans - https://planapi.in/api/Mobile/NewMobilePlans
  Future<List<PlanCategory>> fetchMobilePlans(String operatorCode, String circleCode) async {
    print("ENTERED: plan_api_service.dart fetchMobilePlans");
    final url = Uri.parse('${PlanApiConfig.baseUrl}/Mobile/NewMobilePlans?apimember_id=${PlanApiConfig.memberId}&api_password=${PlanApiConfig.password}&operatorcode=$operatorCode&cricle=$circleCode');
    
    print('[PLAN API] Request URL: $url');
    print('[PLAN API] Parameters: operatorcode=$operatorCode, cricle=$circleCode');
    
    try {
      final response = await http.get(url);
      print('[PLAN API] Response Status: ${response.statusCode}');
      print('[PLAN API] Raw Response: ${response.body}');
      
      if (response.statusCode != 200) {
        throw PlanApiException('Failed to connect with status ${response.statusCode}', 'Network Error');
      }

      final decoded = jsonDecode(response.body);
      
      print('=== DEEP LOGGING START ===');
      print('1. response.runtimeType: ${response.runtimeType}');
      print('2. response.body.runtimeType: ${response.body.runtimeType}');
      print('3. Complete decoded JSON length: ${response.body.length} chars');
      
      // The API returns a direct array of plans
      if (decoded is List) {
        print('5. Branch Executed: Raw List branch');
        print('Runtime Type: ${decoded.runtimeType}');
        print('Response Length: ${decoded.length}');
        
        if (decoded.isEmpty) {
          print('6. RETURNING FROM: fetchMobilePlans');
          print('Reason: Raw List branch, but decoded is empty');
          throw PlanApiException('No plans available for this operator/circle', 'Empty Plans');
        }
        
        final plans = decoded.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
        
        print('First Plan: ${plans.first.rs} - ${plans.first.desc}');
        print('Last Plan: ${plans.last.rs} - ${plans.last.desc}');
        print('Parsed Plan Count: ${plans.length}');
        
        print('6. RETURNING FROM: fetchMobilePlans');
        print('Reason: Raw List branch, parsed ${plans.length} plans successfully');
        return [PlanCategory(name: '⭐ All Plans', plans: plans)];
      }
      
      // Fallback for wrapped response just in case
      if (decoded is Map) {
        print('5. Branch Executed: Map branch');
        print('Runtime Type: Map');
        
        print('4. Every key in the decoded Map: ${decoded.keys.join(', ')}');
        
        final List<PlanCategory> categories = [];
        
        // Handle PlanAPI RDATA format where categories are keys in a map
        final dynamic rdata = decoded['RDATA'] ?? decoded['rdata'];
        if (rdata is Map) {
          print('Found RDATA Map');
          for (final entry in rdata.entries) {
            if (entry.value is List) {
              final categoryList = entry.value as List;
              print('Category Name: ${entry.key} | Number of Plans: ${categoryList.length}');
              if (categoryList.isNotEmpty) {
                final plans = categoryList.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
                categories.add(PlanCategory(name: entry.key, plans: plans));
              }
            }
          }
        } else {
          // Fallback to normal arrays
          final List<dynamic> data = decoded['data'] ?? decoded['DATA'] ?? decoded['records'] ?? decoded['plans'] ?? [];
          if (data.isNotEmpty) {
            final plans = data.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
            categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
          }
        }
        
        print('Total Categories Parsed: ${categories.length}');
        
        if (categories.isNotEmpty) {
          print('6. RETURNING FROM: fetchMobilePlans');
          print('Reason: Map branch, found categories successfully');
          return categories;
        }

        // Check if there are other keys that might be the array
        for (final key in decoded.keys) {
          if (decoded[key] is List) {
             print('WARNING: Found an array in key: $key');
          } else if (decoded[key] is String && decoded[key].startsWith('[')) {
             print('WARNING: Found a string that looks like a JSON array in key: $key');
          }
        }

        // Only throw if RDATA is missing or empty, AND there's an actual error.
        // We DO NOT use STATUS == '0' for error since it means success here.
        if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0') {
           print('7. THROW: plan_api_service.dart');
           print('Condition: ERROR != 0 && STATUS != 0');
           print('Reason: ${decoded['message'] ?? 'API returned error'}');
           print('6. RETURNING FROM: fetchMobilePlans (THROW)');
           print('Reason: API explicit error block');
           throw PlanApiException(decoded['message'] ?? 'API returned error', 'API Error');
        }

        print('6. RETURNING FROM: fetchMobilePlans (THROW)');
        print('Reason: Map branch, no plans found inside RDATA');
        throw PlanApiException('No plans available for this operator/circle', 'Empty Plans');
      }
      
      print('5. Branch Executed: Error branch');
      print('6. RETURNING FROM: fetchMobilePlans (THROW)');
      print('Reason: Invalid response format');
      throw PlanApiException('Invalid response format. Expected List or Map, got ${decoded.runtimeType}', 'Parsing Error');
    } catch (e) {
      print('5. Branch Executed: Exception branch');
      print('Exception caught: $e');
      if (e is PlanApiException) rethrow;
      print('6. RETURNING FROM: fetchMobilePlans (THROW)');
      print('Reason: Exception block hit');
      throw PlanApiException('Failed to parse response: $e', 'Parsing Error');
    }
  }

  // ====================================================
  // DTH ENDPOINTS
  // ====================================================

  // fetchDthOperator - https://planapi.in/api/Mobile/DthOperatorFetch
  Future<OperatorCircleResponse> fetchDthOperator(String subscriberId) async {
    print("ENTERED: plan_api_service.dart fetchDthOperator");
    final url = Uri.parse('${PlanApiConfig.baseUrl}/Mobile/DthOperatorFetch?apimember_id=${PlanApiConfig.memberId}&api_password=${PlanApiConfig.password}&dth_number=$subscriberId');
    
    print('[PLAN API DTH] Request URL: $url');
    
    try {
      final response = await http.get(url);
      print('[PLAN API DTH] Response Status: ${response.statusCode}');
      print('[PLAN API DTH] Raw Response: ${response.body}');
      
      if (response.statusCode != 200) {
        throw PlanApiException('Failed to connect with status ${response.statusCode}', 'Network Error');
      }

      final decoded = jsonDecode(response.body);
      
      if (decoded['STATUS'] == '0' || decoded['status'] == '0' || decoded['ERROR'] == '0') {
         // Some endpoints use 0 for success, others use it for error. For OperatorFetch, it's usually STATUS=1 for success.
         // Wait, the user said for NewMobilePlans STATUS=0 is success. 
         // For DthOperatorFetch, we'll extract directly if operator is present.
      }
      
      // If there is no operator name, we consider it a failure.
      if (decoded['Operator'] == null && decoded['operator'] == null && decoded['DthName'] == null) {
         throw PlanApiException(decoded['message'] ?? 'Could not detect DTH operator', 'API Error');
      }

      final result = OperatorCircleResponse.fromJson(decoded);
      return result;
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to parse DTH Operator response: $e', 'Parsing Error');
    }
  }

  // fetchDthBasicDetails - https://planapi.in/api/Mobile/DTHBasicDetails
  Future<DthCustomerInfo> fetchDthBasicDetails(String subscriberId, String operatorCode) async {
    print("ENTERED: plan_api_service.dart fetchDthBasicDetails");
    final url = Uri.parse('${PlanApiConfig.baseUrl}/Mobile/DTHBasicDetails?apimember_id=${PlanApiConfig.memberId}&api_password=${PlanApiConfig.password}&mobile_no=$subscriberId&Opcode=$operatorCode');
    
    print('[PLAN API DTH] Request URL: $url');
    
    try {
      final response = await http.get(url);
      print('[PLAN API DTH] Response Status: ${response.statusCode}');
      print('[PLAN API DTH] Raw Response: ${response.body}');
      
      if (response.statusCode != 200) {
        throw PlanApiException('Failed to connect with status ${response.statusCode}', 'Network Error');
      }

      final decoded = jsonDecode(response.body);
      
      if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0' && decoded['STATUS'] != '1') {
         throw PlanApiException(decoded['message'] ?? 'Failed to fetch basic details', 'API Error');
      }

      return DthCustomerInfo.fromJson(decoded);
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to parse DTH Basic Details: $e', 'Parsing Error');
    }
  }

  // fetchDthPlans - https://planapi.in/api/Mobile/DthPlans
  Future<List<PlanCategory>> fetchDthPlans(String operatorCode) async {
    print("ENTERED: plan_api_service.dart fetchDthPlans");
    final url = Uri.parse('${PlanApiConfig.baseUrl}/Mobile/DthPlans?apimember_id=${PlanApiConfig.memberId}&api_password=${PlanApiConfig.password}&operatorcode=$operatorCode');
    
    print('[PLAN API DTH] Request URL: $url');
    
    try {
      final response = await http.get(url);
      print('[PLAN API DTH] Response Status: ${response.statusCode}');
      // Don't print the whole raw response as it can be huge, but maybe length
      print('[PLAN API DTH] Raw Response length: ${response.body.length}');
      
      if (response.statusCode != 200) {
        throw PlanApiException('Failed to connect with status ${response.statusCode}', 'Network Error');
      }

      final decoded = jsonDecode(response.body);
      
      print('=== DTH PLANS LOGGING START ===');
      print('1. response.runtimeType: ${response.runtimeType}');
      print('2. response.body.runtimeType: ${response.body.runtimeType}');
      print('3. Complete decoded JSON length: ${response.body.length} chars');
      print('Top-level keys: ${decoded is Map ? decoded.keys.join(', ') : "List"}');
      
      if (decoded is List) {
        if (decoded.isEmpty) {
          throw PlanApiException('No DTH plans available', 'Empty Plans');
        }
        
        final firstPlan = decoded.first as Map<String, dynamic>;
        print('First plan object keys: ${firstPlan.keys.join(', ')}');
        print('First plan: $firstPlan');
        
        final plans = decoded.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
        return [PlanCategory(name: '⭐ All Plans', plans: plans)];
      }
      
      if (decoded is Map) {
        final List<PlanCategory> categories = [];
        
        final dynamic rdata = decoded['RDATA'] ?? decoded['rdata'];
        
        if (rdata is Map) {
          print('Found RDATA map.');
          for (final entry in rdata.entries) {
            if (entry.value is List) {
              final listData = entry.value as List;
              if (listData.isNotEmpty) {
                final firstItem = listData.first as Map<String, dynamic>;
                
                // DTH JSON FORMAT: { "Language": "...", "Details": [ { "PlanName": "...", "PricingList": [ ... ] } ] }
                if (firstItem.containsKey('Language') && firstItem.containsKey('Details')) {
                   print('Parsing DTH specific nested format for key: ${entry.key}');
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
                // STANDARD MOBILE FORMAT
                else {
                  final plans = listData.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
                  categories.add(PlanCategory(name: entry.key, plans: plans));
                }
              }
            }
          }
        } else if (rdata is List) {
          print('Found RDATA list of length ${rdata.length}');
          if (rdata.isNotEmpty) {
             final firstPlan = rdata.first as Map<String, dynamic>;
             print('Keys in first plan: ${firstPlan.keys.join(', ')}');
             print('First plan data: $firstPlan');
          }
          final plans = rdata.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
          categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
        } else {
          final List<dynamic> data = decoded['data'] ?? decoded['DATA'] ?? decoded['records'] ?? decoded['plans'] ?? [];
          print('Fallback data array length: ${data.length}');
          if (data.isNotEmpty) {
             final firstPlan = data.first as Map<String, dynamic>;
             print('Keys in first plan: ${firstPlan.keys.join(', ')}');
             print('First plan data: $firstPlan');
             
            final plans = data.map((json) => MobilePlan.fromJson(json as Map<String, dynamic>)).toList();
            categories.add(PlanCategory(name: '⭐ All Plans', plans: plans));
          }
        }
        
        if (categories.isNotEmpty) {
          return categories;
        }

        if (decoded['ERROR'] != '0' && decoded['ERROR'] != null && decoded['STATUS'] != '0' && decoded['STATUS'] != '1') {
           throw PlanApiException(decoded['message'] ?? 'API returned error', 'API Error');
        }

        throw PlanApiException('No DTH plans available', 'Empty Plans');
      }
      
      throw PlanApiException('Invalid response format', 'Parsing Error');
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException('Failed to parse DTH Plans response: $e', 'Parsing Error');
    }
  }
}
