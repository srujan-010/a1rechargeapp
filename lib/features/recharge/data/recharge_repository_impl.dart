// lib/features/recharge/data/recharge_repository_impl.dart
import '../../../core/models/app_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/result.dart';
import '../domain/models/operator.dart';
import '../domain/models/recharge_plan.dart';
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
      // e.g. /master/operators?service=mobile
      final response = await apiClient.get<List<dynamic>>(
        '/master/operators?service=$serviceType',
        fromJson: (json) => json as List<dynamic>,
      );
      if (response.success && response.data != null) {
        final data = response.data!;
        final operators = data.map((json) => Operator.fromJson(json as Map<String, dynamic>)).toList();
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
        final data = response.data!;
        final circles = data.map((json) => Circle.fromJson(json as Map<String, dynamic>)).toList();
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
  Future<Result<OperatorResolveResult, AppException>> resolveOperator(String phoneNumber) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/master/resolve?mobile=$phoneNumber',
        fromJson: (json) => json as Map<String, dynamic>,
      );
      if (response.success && response.data != null) {
        final data = response.data!;
        final operator = Operator.fromJson(data['operator'] as Map<String, dynamic>);
        final circle = Circle.fromJson(data['circle'] as Map<String, dynamic>);
        return Success(OperatorResolveResult(operator: operator, circle: circle));
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<RechargePlan>, AppException>> getPlans({
    required String operatorId,
    required String circle,
    required String serviceType,
  }) async {
    try {
      String endpoint = '/plans/mobile/prepaid';
      if (serviceType.toLowerCase() == 'postpaid') {
        endpoint = '/plans/mobile/postpaid';
      } else if (serviceType.toLowerCase() == 'dth') {
        endpoint = '/plans/dth/packs';
      }

      final response = await apiClient.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          'operatorId': operatorId,
          'circleId': circle,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final List<dynamic> plansData = response.data!['plans'] ?? [];
        final plans = plansData.map((json) => RechargePlan.fromJson(json as Map<String, dynamic>)).toList();
        return Success(plans);
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
        fromJson: (json) => RechargeReceipt.fromJson(json as Map<String, dynamic>),
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
}
