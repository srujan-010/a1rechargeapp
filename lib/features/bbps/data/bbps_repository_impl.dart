import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../domain/bbps_repository.dart';
import '../domain/models/bbps_models.dart';
import 'bbps_repository_mock.dart';

class BbpsRepositoryImpl implements BbpsRepository {
  BbpsRepositoryImpl(this._mockFallback);

  final BbpsRepositoryMock _mockFallback;

  @override
  Future<Result<List<Biller>, AppException>> getBillers({required String category, String? state}) async {
    // If it's not electricity, fallback to mock for now
    if (category.toLowerCase() != 'electricity') {
      return _mockFallback.getBillers(category: category, state: state);
    }

    try {
      final dio = Dio();
      String url = '${AppConfig.baseUrl}/electricity/operators';
      if (state != null && state.isNotEmpty) {
        url += '?state=${Uri.encodeComponent(state)}';
      }
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final items = data['data'] as List;
          final billers = items.map((item) {
            final reqFields = item['requiredFields'] as List? ?? [];
            final parameters = reqFields.map((field) {
              return BillerParameter(
                name: field['key'] ?? '',
                displayName: field['label'] ?? '',
                regex: '', // We can add regex from backend later
                minLength: 1,
                maxLength: 50,
                isOptional: field['required'] == false,
                helperText: field['placeholder'],
              );
            }).toList();

            return Biller(
              id: item['operatorCode'].toString(), // Use operatorCode as ID to match backend routes
              name: item['name'] ?? '',
              category: item['category'] ?? 'Electricity',
              iconUrl: item['logo'] ?? '',
              parameters: parameters,
              isFetchRequirement: true,
              sampleBillUrl: null, // Update when backend provides it
              requiresDistrictCode: item['requiresDistrictCode'] == true,
              requiresMobile: item['requiresMobile'] == true,
              requiresDOB: item['requiresDOB'] == true,
            );
          }).toList();

          return Success<List<Biller>, AppException>(billers);
        } else {
          return Failure<List<Biller>, AppException>(ServerException(message: data['message'] ?? 'Failed to load operators'));
        }
      } else {
        return Failure<List<Biller>, AppException>(ServerException(message: 'Server Error: ${response.statusCode}'));
      }
    } catch (e) {
      return Failure<List<Biller>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<List<BillerDistrict>, AppException>> getDistricts({required String operatorCode}) async {
    try {
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/electricity/operators/$operatorCode/districts';
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final items = data['data'] as List;
          final districts = items.map((item) {
            return BillerDistrict(
              operatorCode: item['operatorCode'] as int,
              state: item['state'] ?? '',
              districtName: item['districtName'] ?? '',
              districtCode: item['districtCode'] ?? '',
            );
          }).toList();

          return Success<List<BillerDistrict>, AppException>(districts);
        } else {
          return Failure<List<BillerDistrict>, AppException>(ServerException(message: data['message'] ?? 'Failed to load districts'));
        }
      } else {
        return Failure<List<BillerDistrict>, AppException>(ServerException(message: 'Server Error: ${response.statusCode}'));
      }
    } catch (e) {
      return Failure<List<BillerDistrict>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<List<String>, AppException>> getStates({required String category}) async {
    if (category.toLowerCase() != 'electricity') {
      return _mockFallback.getStates(category: category);
    }

    try {
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/electricity/states';
      final response = await dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final items = data['data'] as List;
          final statesList = items.map((e) => e.toString()).toList();
          return Success<List<String>, AppException>(statesList);
        } else {
          return Failure<List<String>, AppException>(ServerException(message: data['message'] ?? 'Failed to load states'));
        }
      } else {
        return Failure<List<String>, AppException>(ServerException(message: 'Server Error: ${response.statusCode}'));
      }
    } catch (e) {
      return Failure<List<String>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<BillDetails, AppException>> fetchBill({
    required String billerId,
    required Map<String, String> parameters,
  }) async {
    try {
      final dio = Dio();
      final url = '${AppConfig.baseUrl}/electricity/fetch';
      
      final payload = {
        'billerId': billerId,
        'parameters': parameters,
      };

      print('\n[FLUTTER REPOSITORY] fetchBill called');
      print('[FLUTTER API CLIENT] POST $url');
      print('[FLUTTER API CLIENT] Request Payload: $payload');

      final response = await dio.post(
        url,
        data: payload,
      );

      print('[FLUTTER API CLIENT] Raw backend response status: ${response.statusCode}');
      print('[FLUTTER API CLIENT] Raw backend response body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final billData = data['data'];
          
          // Safe Date Parsing
          String rawBillDate = billData['billDate']?.toString() ?? '';
          String rawDueDate = billData['dueDate']?.toString() ?? '';
          
          DateTime? parsedBillDate;
          DateTime? parsedDueDate;
          
          try {
            if (rawBillDate.isNotEmpty) {
              if (rawBillDate.contains(RegExp(r'[a-zA-Z]'))) {
                parsedBillDate = DateFormat("dd MMM yyyy").parse(rawBillDate);
              } else {
                parsedBillDate = DateTime.parse(rawBillDate);
              }
            }
          } catch (e) {
            print('[FLUTTER PARSER WARNING] Failed to parse billDate "$rawBillDate": $e');
          }
          
          try {
            if (rawDueDate.isNotEmpty) {
              if (rawDueDate.contains(RegExp(r'[a-zA-Z]'))) {
                parsedDueDate = DateFormat("dd MMM yyyy").parse(rawDueDate);
              } else {
                parsedDueDate = DateTime.parse(rawDueDate);
              }
            }
          } catch (e) {
            print('[FLUTTER PARSER WARNING] Failed to parse dueDate "$rawDueDate": $e');
          }

          final billDetails = BillDetails(
            billerId: billData['billerId']?.toString() ?? billerId,
            billerName: billData['billerName']?.toString() ?? 'Not Available',
            customerName: billData['customerName']?.toString() ?? 'Not Available',
            billAmountPaise: ((double.tryParse(billData['billAmount']?.toString() ?? '0') ?? 0) * 100).toInt(),
            rawBillDate: rawBillDate,
            rawDueDate: rawDueDate,
            parsedBillDate: parsedBillDate,
            parsedDueDate: parsedDueDate,
            billNumber: billData['billNumber']?.toString() ?? 'Not Available',
          );

          print('[FLUTTER PARSER] Successfully parsed BillDetails: $billDetails\n');

          return Success<BillDetails, AppException>(billDetails);
        } else {
          return Failure<BillDetails, AppException>(ServerException(message: data['message'] ?? 'Failed to fetch bill'));
        }
      } else {
        return Failure<BillDetails, AppException>(ServerException(message: 'Server Error: ${response.statusCode}'));
      }
    } catch (e) {
      print('[FLUTTER API CLIENT] Request Failed: $e');
      if (e is DioException && e.response != null) {
         final data = e.response?.data;
         if (data is Map && data['message'] != null) {
            return Failure<BillDetails, AppException>(ValidationException(message: data['message']));
         }
      }
      return Failure<BillDetails, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<RechargeReceipt, AppException>> payBill({
    required BillDetails billDetails,
    required String mpin,
  }) async {
    // Currently, bill payment is not implemented on the backend.
    // We fall back to the mock implementation for demonstration.
    return _mockFallback.payBill(billDetails: billDetails, mpin: mpin);
  }
}
