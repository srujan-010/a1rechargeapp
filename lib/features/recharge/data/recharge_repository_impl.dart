import 'package:flutter/foundation.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/result.dart';
import '../domain/models/operator.dart';
import '../domain/models/recharge_result.dart';
import '../domain/recharge_repository.dart';
import '../domain/models/recent_contact.dart';
import '../../../core/services/local_cache_service.dart';
import '../domain/models/circle.dart';

class RechargeRepositoryImpl implements RechargeRepository {
  RechargeRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<Result<List<Operator>, AppException>> getOperators({required String serviceType}) async {
    try {
      debugPrint('==========================');
      debugPrint('STEP 1 - API REQUEST');
      debugPrint('==========================');
      debugPrint('Calling GET /api/master/operators');
      debugPrint('Request URL: /master/operators?service=$serviceType');
      
      int? statusCode;
      final response = await apiClient.get<List<dynamic>>(
        '/master/operators?service=$serviceType',
        fromJson: (json) {
          debugPrint('Raw JSON Response: $json');
          return json as List<dynamic>;
        },
      );
      
      debugPrint('Status Code: ${response.success ? "200 (Success)" : "Error"}');

      debugPrint('==========================');
      debugPrint('STEP 2 - PARSE');
      debugPrint('==========================');
      if (response.success && response.data != null) {
        final List<dynamic> data = (response.data as List?) ?? [];
        debugPrint('Raw JSON count: ${data.length}');
        
        final List<Operator> operators = [];
        for (var item in data) {
          if (item is Map) {
            final Map<String, dynamic> jsonMap = Map<String, dynamic>.from(item);
            final op = Operator.fromJson(jsonMap);
            operators.add(op);
            debugPrint('${op.name}\ncode=${op.shortCode}\nserviceType=${jsonMap['serviceType']}\ntype=${op.type}\n');
          }
        }
        
        debugPrint('Parsed operators count: ${operators.length}');
        
        debugPrint('==========================');
        debugPrint('STEP 3 - FILTER');
        debugPrint('==========================');
        debugPrint('Before filtering:\noperators.length = ${operators.length}');
        // We do not have any internal repository filtering here.
        debugPrint('After filtering:\nprepaid.length = ${operators.where((o) => o.type == OperatorType.prepaid).length}\npostpaid.length = ${operators.where((o) => o.type == OperatorType.postpaid).length}');
        
        return Success(operators);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<Circle>, AppException>> getCircles() async {
    try {
      final response = await apiClient.get<List<dynamic>>(
        '/master/circles',
        fromJson: (json) => json as List<dynamic>,
      );
      if (response.success && response.data != null) {
        final List<dynamic> data = (response.data as List?) ?? [];
        final circles = data.whereType<Map<String, dynamic>>().map((json) => Circle.fromJson(json)).toList();
        return Success(circles);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }



  @override
  Future<Result<RechargeReceipt, AppException>> processRecharge({
    required String phoneNumber,
    required String operatorId,
    required String operatorName,
    required String circleId,
    required String serviceType,
    required int amountPaise,
    String? mpin,
    String? paymentMode,
  }) async {
    try {
      final response = await apiClient.post<RechargeReceipt>(
        '/services/recharge/initiate',
        data: {
          'mobileNumber': phoneNumber,
          'operatorId': operatorId,
          'operatorName': operatorName,
          'circleId': circleId,
          'serviceType': serviceType,
          'amountPaise': amountPaise,
          if (mpin != null) 'mpin': mpin,
          if (paymentMode != null) 'paymentMode': paymentMode,
        },
        fromJson: (json) => RechargeReceipt.fromJson(json is Map ? Map<String, dynamic>.from(json) : {}),
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      return Success(response.data!);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, st) {
      AppLogger.error('processRecharge failed', tag: 'RechargeRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<List<RecentContact>> getRecentContacts() async {
    try {
      // 1. Check local cache first
      final box = LocalCacheService.instance.recentContactsBox;
      final List<dynamic>? rawList = box.get('history');
      
      List<RecentContact> localContacts = [];
      if (rawList != null) {
        localContacts = rawList
            .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      // 2. Fetch from backend to sync
      try {
        final response = await apiClient.get('/user/recent-contacts');
        if (response.data != null && response.data is List) {
          final backendContacts = (response.data as List)
              .map((e) => RecentContact.fromJson(e as Map<String, dynamic>))
              .toList();
              
          // If backend has data, prefer backend data for now
          // (In a real app, you might merge based on timestamps)
          if (backendContacts.isNotEmpty) {
            await box.put('history', backendContacts.map((e) => e.toJson()).toList());
            return backendContacts;
          }
        }
      } catch (e) {
        // Silently fail backend sync and return local
        AppLogger.warning('Failed to sync recent contacts from backend', tag: 'RechargeRepo', error: e);
      }

      return localContacts;
    } catch (e) {
      AppLogger.error('Failed to get recent contacts', tag: 'RechargeRepo', error: e);
      return [];
    }
  }

  @override
  Future<void> saveRecentContact(RecentContact contact) async {
    try {
      final box = LocalCacheService.instance.recentContactsBox;
      final List<dynamic> rawList = box.get('history') ?? [];
      
      List<RecentContact> contacts = rawList
          .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Find if contact exists
      final existingIndex = contacts.indexWhere((c) => c.phone == contact.phone);
      
      if (existingIndex != -1) {
        // Increment count and update timestamp/amount
        final existing = contacts[existingIndex];
        final updated = existing.copyWith(
          lastRechargeDate: contact.lastRechargeDate,
          lastRechargeAmountPaise: contact.lastRechargeAmountPaise,
          operatorId: contact.operatorId,
          circle: contact.circle,
          rechargeCount: existing.rechargeCount + 1,
        );
        contacts.removeAt(existingIndex);
        contacts.insert(0, updated);
      } else {
        // New contact
        contacts.insert(0, contact);
      }
      
      // Keep only top 10
      if (contacts.length > 10) {
        contacts = contacts.sublist(0, 10);
      }
      
      // Save locally
      await box.put('history', contacts.map((e) => e.toJson()).toList());
      
      // Sync to backend
      try {
        await apiClient.put(
          '/user/recent-contacts',
          data: {'contacts': contacts.map((e) => e.toJson()).toList()},
        );
      } catch (e) {
        AppLogger.warning('Failed to sync recent contacts to backend', tag: 'RechargeRepo', error: e);
      }
    } catch (e) {
      AppLogger.error('Failed to save recent contact', tag: 'RechargeRepo', error: e);
    }
  }

  @override
  Future<void> removeRecentContact(String phone) async {
    try {
      final box = LocalCacheService.instance.recentContactsBox;
      final List<dynamic>? rawList = box.get('history');
      if (rawList == null) return;
      
      List<RecentContact> contacts = rawList
          .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      contacts.removeWhere((c) => c.phone == phone);
      await box.put('history', contacts.map((e) => e.toJson()).toList());
      
      // Sync to backend
      try {
        await apiClient.put(
          '/user/recent-contacts',
          data: {'contacts': contacts.map((e) => e.toJson()).toList()},
        );
      } catch (e) {
        // Ignore
      }
    } catch (e) {
      AppLogger.error('Failed to remove recent contact', tag: 'RechargeRepo', error: e);
    }
  }

  @override
  Future<Result<RechargeReceipt, AppException>> checkRechargeStatus(String orderId) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/provider/a1topup/status/$orderId',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (!response.success || response.data == null) {
        return Failure(ServerException(message: response.message));
      }
      final data = response.data!['data'];
      final statusStr = (data?['status'] as String? ?? 'PENDING').toLowerCase();
      final isSuccess = statusStr == 'success';
      final isPending = statusStr == 'pending';

      final receipt = RechargeReceipt(
        transactionId: data?['orderId'] ?? orderId,
        referenceId: data?['orderId'] ?? orderId,
        operatorRef: data?['operatorReference'] ?? data?['providerTransactionId'],
        status: isSuccess
            ? RechargeStatus.success
            : (isPending ? RechargeStatus.pending : RechargeStatus.failed),
        amountPaise: 0, // preserved from UI
        mobileNumber: '',
        operatorName: '',
        timestamp: DateTime.now(),
        failureReason: data?['message'],
      );

      return Success(receipt);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, st) {
      AppLogger.error('checkRechargeStatus failed for orderId $orderId', tag: 'RechargeRepo', error: e, stackTrace: st);
      return Failure(UnknownException.from(e));
    }
  }
}
