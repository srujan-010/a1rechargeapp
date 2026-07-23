import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../../../core/services/api_client.dart';
import '../domain/bbps_repository.dart';
import '../domain/models/bbps_models.dart';
import 'bbps_repository_mock.dart';

class BbpsRepositoryImpl implements BbpsRepository {
  BbpsRepositoryImpl(this._mockFallback, this._apiClient);

  final BbpsRepositoryMock _mockFallback;
  final ApiClient _apiClient;

  @override
  Future<Result<List<Biller>, AppException>> getBillers({required String category, String? state}) async {
    // If it's not electricity, fallback to mock for now
    if (category.toLowerCase() != 'electricity') {
      return _mockFallback.getBillers(category: category, state: state);
    }

    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/electricity/operators',
        queryParameters: {
          if (state != null && state.isNotEmpty) 'state': state,
        },
        fromJson: (json) => json as List<dynamic>,
      );

      final items = response.data ?? [];
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
    } catch (e) {
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return Failure<List<Biller>, AppException>(ServerException(message: data['message']));
        }
      }
      return Failure<List<Biller>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<List<BillerDistrict>, AppException>> getDistricts({required String operatorCode}) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/electricity/operators/$operatorCode/districts',
        fromJson: (json) => json as List<dynamic>,
      );

      final items = response.data ?? [];
      final districts = items.map((item) {
        return BillerDistrict(
          operatorCode: item['operatorCode'] as int,
          state: item['state'] ?? '',
          districtName: item['districtName'] ?? '',
          districtCode: item['districtCode'] ?? '',
        );
      }).toList();

      return Success<List<BillerDistrict>, AppException>(districts);
    } catch (e) {
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return Failure<List<BillerDistrict>, AppException>(ServerException(message: data['message']));
        }
      }
      return Failure<List<BillerDistrict>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<List<String>, AppException>> getStates({required String category}) async {
    if (category.toLowerCase() != 'electricity') {
      return _mockFallback.getStates(category: category);
    }

    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/electricity/states',
        fromJson: (json) => json as List<dynamic>,
      );

      final items = response.data ?? [];
      final statesList = items.map((e) => e.toString()).toList();
      return Success<List<String>, AppException>(statesList);
    } catch (e) {
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return Failure<List<String>, AppException>(ServerException(message: data['message']));
        }
      }
      return Failure<List<String>, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<BillDetails, AppException>> fetchBill({
    required String category,
    required String billerId,
    required Map<String, String> parameters,
  }) async {
    try {
      final endpoint = '/$category/fetch';
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'billerId': billerId,
          'parameters': parameters,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      final billData = response.data;
      if (billData == null) {
        return Failure<BillDetails, AppException>(const ServerException(message: 'Failed to fetch bill: No data returned'));
      }
      
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
        category: category,
        customerName: billData['customerName']?.toString() ?? 'Not Available',
        billAmountPaise: ((double.tryParse(billData['billAmount']?.toString() ?? '0') ?? 0) * 100).toInt(),
        rawBillDate: rawBillDate,
        rawDueDate: rawDueDate,
        parsedBillDate: parsedBillDate,
        parsedDueDate: parsedDueDate,
        billNumber: billData['billNumber']?.toString() ?? 'Not Available',
      );

      return Success<BillDetails, AppException>(billDetails);
    } catch (e) {
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
    try {
      final endpoint = '/${billDetails.category}/pay';
      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'billerId': billDetails.billerId,
          'amountPaise': billDetails.billAmountPaise,
          'customerIdentifier': billDetails.billNumber,
          'mpin': mpin,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      final data = response.data;
      if (data == null) {
        return Failure<RechargeReceipt, AppException>(const ServerException(message: 'Failed to complete payment.'));
      }

      if (data['success'] == true || data['status'] == 'PENDING') {
        final receipt = RechargeReceipt(
          transactionId: data['transactionId']?.toString() ?? data['orderId']?.toString() ?? 'Txn_${DateTime.now().millisecondsSinceEpoch}',
          referenceId: data['orderId']?.toString() ?? '',
          status: data['status'] == 'PENDING' ? RechargeStatus.pending : RechargeStatus.success,
          amountPaise: billDetails.billAmountPaise,
          operatorName: billDetails.billerName,
          mobileNumber: billDetails.billNumber,
          timestamp: DateTime.now(),
        );
        return Success<RechargeReceipt, AppException>(receipt);
      } else {
        return Failure<RechargeReceipt, AppException>(ValidationException(message: data['message'] ?? 'Payment failed'));
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
         final data = e.response?.data;
         if (data is Map && data['message'] != null) {
            return Failure<RechargeReceipt, AppException>(ValidationException(message: data['message']));
         }
      }
      return Failure<RechargeReceipt, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }

  @override
  Future<Result<RechargeReceipt, AppException>> checkStatus({
    required String category,
    required String orderId,
  }) async {
    try {
      final endpoint = '/$category/status/$orderId';
      final response = await _apiClient.get<Map<String, dynamic>>(
        endpoint,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      final data = response.data;
      if (data == null) {
        return Failure<RechargeReceipt, AppException>(const ServerException(message: 'Failed to check status.'));
      }

      final statusStr = data['status']?.toString() ?? 'PENDING';
      RechargeStatus parsedStatus;
      if (statusStr == 'SUCCESS') {
        parsedStatus = RechargeStatus.success;
      } else if (statusStr == 'FAILED') {
        parsedStatus = RechargeStatus.failed;
      } else {
        parsedStatus = RechargeStatus.pending;
      }

      final receipt = RechargeReceipt(
        transactionId: data['providerTransactionId']?.toString() ?? data['orderId']?.toString() ?? '',
        referenceId: data['orderId']?.toString() ?? orderId,
        status: parsedStatus,
        amountPaise: 0, // We only care about the status here
        operatorName: 'Status Check',
        mobileNumber: '',
        timestamp: DateTime.now(),
        failureReason: data['message']?.toString(),
      );
      
      return Success<RechargeReceipt, AppException>(receipt);
    } catch (e) {
      if (e is DioException && e.response != null) {
         final data = e.response?.data;
         if (data is Map && data['message'] != null) {
            return Failure<RechargeReceipt, AppException>(ValidationException(message: data['message']));
         }
      }
      return Failure<RechargeReceipt, AppException>(NetworkException(message: 'Network Error: $e'));
    }
  }
}
