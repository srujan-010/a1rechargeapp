import 'dart:math';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../domain/recharge_repository.dart';
import '../domain/models/operator.dart';
import '../domain/models/recharge_plan.dart';
import '../domain/models/recharge_result.dart';
import '../domain/models/recent_contact.dart';
import '../../../core/services/local_cache_service.dart';

class RechargeRepositoryMock implements RechargeRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<Operator>, AppException>> getOperators({required String serviceType}) async {
    await _delay();
    
    if (serviceType == 'dth') {
      return const Success([
        Operator(id: 'dth_tata', name: 'Tata Play', type: OperatorType.dth, isActive: true, logoUrl: 'https://placeholder.com/tata'),
        Operator(id: 'dth_airtel', name: 'Airtel DTH', type: OperatorType.dth, isActive: true, logoUrl: 'https://placeholder.com/airtel'),
        Operator(id: 'dth_dish', name: 'Dish TV', type: OperatorType.dth, isActive: true, logoUrl: 'https://placeholder.com/dish'),
      ]);
    }
    
    // Default: Mobile
    return const Success([
      Operator(id: 'jio', name: 'Jio', type: OperatorType.prepaid, isActive: true, logoUrl: 'https://placeholder.com/jio'),
      Operator(id: 'airtel', name: 'Airtel', type: OperatorType.prepaid, isActive: true, logoUrl: 'https://placeholder.com/airtel'),
      Operator(id: 'vi', name: 'Vi (Vodafone Idea)', type: OperatorType.prepaid, isActive: true, logoUrl: 'https://placeholder.com/vi'),
      Operator(id: 'bsnl', name: 'BSNL', type: OperatorType.prepaid, isActive: true, logoUrl: 'https://placeholder.com/bsnl'),
    ]);
  }

  @override
  Future<Result<Operator, AppException>> resolveOperator(String phoneNumber) async {
    await _delay();
    // Simulate auto-resolution based on prefixes (just a mock logic)
    if (phoneNumber.startsWith('9')) {
      return const Success(Operator(id: 'airtel', name: 'Airtel', type: OperatorType.prepaid, isActive: true, logoUrl: ''));
    } else if (phoneNumber.startsWith('8')) {
      return const Success(Operator(id: 'vi', name: 'Vi', type: OperatorType.prepaid, isActive: true, logoUrl: ''));
    }
    return const Success(Operator(id: 'jio', name: 'Jio', type: OperatorType.prepaid, isActive: true, logoUrl: ''));
  }

  @override
  Future<Result<List<RechargePlan>, AppException>> getPlans({
    required String operatorId,
    required String circle,
  }) async {
    await _delay();
    
    return const Success([
      // Unlimited Plans
      RechargePlan(id: 'p1', pricePaise: 29900, category: PlanCategory.unlimited, description: '2GB/day, Unlimited Calls, 100 SMS/day', validity: '28 Days'),
      RechargePlan(id: 'p2', pricePaise: 66600, category: PlanCategory.unlimited, description: '1.5GB/day, Unlimited Calls, 100 SMS/day', validity: '84 Days'),
      RechargePlan(id: 'p3', pricePaise: 71900, category: PlanCategory.unlimited, description: '2GB/day, Unlimited Calls, 100 SMS/day', validity: '84 Days'),
      RechargePlan(id: 'p4', pricePaise: 299900, category: PlanCategory.unlimited, description: '2.5GB/day, Unlimited Calls, 100 SMS/day', validity: '365 Days'),
      
      // Data Add-ons
      RechargePlan(id: 'p5', pricePaise: 1500, category: PlanCategory.data, description: '1GB Data Add-on', validity: 'Base Plan Validity'),
      RechargePlan(id: 'p6', pricePaise: 2500, category: PlanCategory.data, description: '2GB Data Add-on', validity: 'Base Plan Validity'),
      RechargePlan(id: 'p7', pricePaise: 6100, category: PlanCategory.data, description: '6GB Data Add-on', validity: 'Base Plan Validity'),
      
      // Top-up (Talktime)
      RechargePlan(id: 'p8', pricePaise: 1000, category: PlanCategory.topup, description: '₹7.47 Talktime', validity: 'Unlimited'),
      RechargePlan(id: 'p9', pricePaise: 2000, category: PlanCategory.topup, description: '₹14.95 Talktime', validity: 'Unlimited'),
      RechargePlan(id: 'p10', pricePaise: 5000, category: PlanCategory.topup, description: '₹39.37 Talktime', validity: 'Unlimited'),
      
      // International Roaming
      RechargePlan(id: 'p11', pricePaise: 110100, category: PlanCategory.special, description: 'IR Pack - 100 mins outgoing/incoming, 250MB data', validity: '28 Days'),
    ]);
  }

  @override
  Future<Result<RechargeReceipt, AppException>> processRecharge({
    required String phoneNumber,
    required String operatorId,
    required String operatorName,
    required String serviceType,
    required int amountPaise,
    String? mpin,
    String? paymentMode,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    // For wallet, mock mpin validation failure
    if (paymentMode != 'upi' && mpin != '123456') {
      return const Failure(ValidationException(message: 'Invalid MPIN', code: 'INVALID_MPIN'));
    }
    
    // Success scenario
    final receipt = RechargeReceipt(
      transactionId: 'TXN${_random.nextInt(999999999).toString().padLeft(9, '0')}',
      referenceId: 'REF${_random.nextInt(9999999).toString().padLeft(7, '0')}',
      mobileNumber: phoneNumber,
      amountPaise: amountPaise,
      timestamp: DateTime.now(),
      status: RechargeStatus.success,
      operatorName: operatorId.toUpperCase(),
      operatorRef: 'OP${_random.nextInt(9999999).toString().padLeft(7, '0')}',
    );
    
    return Success(receipt);
  }

  @override
  Future<List<RecentContact>> getRecentContacts() async {
    final box = LocalCacheService.instance.recentContactsBox;
    final List<dynamic>? rawList = box.get('history');
    if (rawList == null) return [];
    
    return rawList
        .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> saveRecentContact(RecentContact contact) async {
    final box = LocalCacheService.instance.recentContactsBox;
    final List<dynamic> rawList = box.get('history') ?? [];
    
    List<RecentContact> contacts = rawList
        .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Remove if already exists (to move to top)
    contacts.removeWhere((c) => c.phone == contact.phone);
    
    // Add to top
    contacts.insert(0, contact);
    
    // Keep only top 5
    if (contacts.length > 5) {
      contacts = contacts.sublist(0, 5);
    }
    
    await box.put('history', contacts.map((e) => e.toJson()).toList());
  }

  @override
  Future<void> removeRecentContact(String phone) async {
    final box = LocalCacheService.instance.recentContactsBox;
    final List<dynamic>? rawList = box.get('history');
    if (rawList == null) return;
    
    List<RecentContact> contacts = rawList
        .map((e) => RecentContact.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    contacts.removeWhere((c) => c.phone == phone);
    await box.put('history', contacts.map((e) => e.toJson()).toList());
  }
}
