import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/operator_formatter.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/local_cache_service.dart';

/// Defensive Flutter deduplication helper to ensure 1 unique operator entry per service category
List<PersonalBenefitSlab> deduplicateSlabs(List<PersonalBenefitSlab> slabs) {
  final Map<String, PersonalBenefitSlab> uniqueMap = {};
  for (final slab in slabs) {
    final account = slab.accountType.toUpperCase().trim();
    final service = slab.serviceType.toLowerCase().trim();
    final code = slab.operatorCode.toUpperCase().trim();
    final normName = slab.operatorName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final opKey = code.isNotEmpty ? code : normName;
    final compositeKey = '${account}_${service}_$opKey';

    if (!uniqueMap.containsKey(compositeKey)) {
      uniqueMap[compositeKey] = slab;
    } else {
      AppLogger.warning(
        '[Benefits] DUPLICATE OPERATOR RATE DETECTED: operatorId=${slab.id}, operatorCode=${slab.operatorCode}, operatorName=${slab.operatorName}, accountType=${slab.accountType}, category=${slab.serviceType}',
        tag: 'Benefits',
      );
      final existing = uniqueMap[compositeKey]!;
      if (slab.commissionValue > existing.commissionValue) {
        uniqueMap[compositeKey] = slab;
      }
    }
  }
  return uniqueMap.values.toList();
}

class PersonalSavings {
  final double lifetimeSavings;
  final double monthlySavings;
  final double previousMonthSavings;
  final int totalCompletedCount;

  PersonalSavings({
    required this.lifetimeSavings,
    required this.monthlySavings,
    required this.previousMonthSavings,
    required this.totalCompletedCount,
  });

  factory PersonalSavings.fromJson(Map<String, dynamic> json) {
    return PersonalSavings(
      lifetimeSavings: (json['lifetimeSavings'] as num?)?.toDouble() ?? 0.0,
      monthlySavings: (json['monthlySavings'] as num?)?.toDouble() ?? 0.0,
      previousMonthSavings: (json['previousMonthSavings'] as num?)?.toDouble() ?? 0.0,
      totalCompletedCount: (json['totalCompletedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PersonalBenefitSlab {
  final String id;
  final String accountType;
  final String operatorCode;
  final String operatorName;
  final String serviceType;
  final String commissionType;
  final double commissionValue;

  PersonalBenefitSlab({
    required this.id,
    required this.accountType,
    required this.operatorCode,
    required this.operatorName,
    required this.serviceType,
    required this.commissionType,
    required this.commissionValue,
  });

  factory PersonalBenefitSlab.fromJson(Map<String, dynamic> json) {
    return PersonalBenefitSlab(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['operatorCode'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'PERSONAL',
      operatorCode: json['operatorCode'] as String? ?? '',
      operatorName: json['operatorName'] as String? ?? '',
      serviceType: json['serviceType'] as String? ?? 'mobile',
      commissionType: json['commissionType'] as String? ?? 'percentage',
      commissionValue: (json['commissionValue'] as num?)?.toDouble() ??
          (json['personalCommission'] as num?)?.toDouble() ??
          0.8,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountType': accountType,
        'operatorCode': operatorCode,
        'operatorName': operatorName,
        'serviceType': serviceType,
        'commissionType': commissionType,
        'commissionValue': commissionValue,
      };
}

class LastRecharge {
  final String cardType; // 'PENDING' | 'FAILED' | 'SUCCESS' | 'PLAN_STATUS' | 'NO_PLAN'
  final String title;
  final String id;
  final String orderId;
  final String mobileNumber;
  final String operatorName;
  final String operatorCode;
  final String? circleCode;
  final double amount;
  final double payableAmount;
  final double savingsAmount;
  final String status;
  final String? rechargeType;
  final String? failureReason;
  final String? colorState; // 'GREEN' | 'AMBER' | 'RED' | 'EXPIRED'
  final int? daysRemaining;
  final String? expiryDate;
  final String? validity;
  final String? statusText;
  final String createdAt;

  LastRecharge({
    required this.cardType,
    required this.title,
    required this.id,
    required this.orderId,
    required this.mobileNumber,
    required this.operatorName,
    required this.operatorCode,
    this.circleCode,
    required this.amount,
    required this.payableAmount,
    required this.savingsAmount,
    required this.status,
    this.rechargeType,
    this.failureReason,
    this.colorState,
    this.daysRemaining,
    this.expiryDate,
    this.validity,
    this.statusText,
    required this.createdAt,
  });

  factory LastRecharge.fromJson(Map<String, dynamic> json) {
    final dataObj = (json['data'] is Map<String, dynamic>) ? (json['data'] as Map<String, dynamic>) : json;
    final lastRec = (json['lastRecharge'] is Map<String, dynamic>) ? (json['lastRecharge'] as Map<String, dynamic>) : null;

    final String cardType = dataObj['cardType'] as String? ?? (json['hasActivePlan'] == true ? 'PLAN_STATUS' : (json['hasLastRecharge'] == true ? 'SUCCESS' : 'NO_PLAN'));
    final String title = dataObj['title'] as String? ?? (cardType == 'PLAN_STATUS' ? 'Your Current Plan' : (cardType == 'SUCCESS' ? 'Your Last Recharge' : 'Your Current Plan'));

    final rawOpName = dataObj['operatorName'] as String? ?? (json['operator'] as String? ?? (lastRec != null ? lastRec['operator'] as String? ?? '' : ''));
    final rawOpCode = dataObj['operatorCode'] as String? ?? (json['operatorCode'] as String? ?? (lastRec != null ? lastRec['operatorCode'] as String? ?? '' : ''));
    final displayOpName = OperatorFormatter.getDisplayOperatorName(rawOpName.isNotEmpty ? rawOpName : rawOpCode);
    final recType = dataObj['rechargeType'] as String? ?? (lastRec != null ? lastRec['rechargeType'] as String? : null);

    return LastRecharge(
      cardType: cardType,
      title: title,
      id: dataObj['id'] as String? ?? (lastRec != null ? lastRec['id'] as String? ?? '' : ''),
      orderId: dataObj['orderId'] as String? ?? (lastRec != null ? lastRec['orderId'] as String? ?? '' : ''),
      mobileNumber: dataObj['mobileNumber'] as String? ?? (json['mobileNumber'] as String? ?? (lastRec != null ? lastRec['mobileNumber'] as String? ?? '' : '')),
      operatorName: displayOpName,
      operatorCode: rawOpCode,
      circleCode: dataObj['circleCode'] as String?,
      amount: (dataObj['amount'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? (lastRec != null ? (lastRec['amount'] as num?)?.toDouble() ?? 0.0 : 0.0),
      payableAmount: (dataObj['payableAmount'] as num?)?.toDouble() ?? (lastRec != null ? (lastRec['payableAmount'] as num?)?.toDouble() ?? 0.0 : 0.0),
      savingsAmount: (dataObj['savingsAmount'] as num?)?.toDouble() ?? (lastRec != null ? (lastRec['savingsAmount'] as num?)?.toDouble() ?? 0.0 : 0.0),
      status: dataObj['status'] as String? ?? 'SUCCESS',
      rechargeType: recType,
      failureReason: dataObj['failureReason'] as String?,
      colorState: dataObj['colorState'] as String?,
      daysRemaining: (dataObj['daysRemaining'] as num?)?.toInt(),
      expiryDate: dataObj['expiryDate'] as String? ?? json['expiryDate'] as String?,
      validity: dataObj['validity'] as String? ?? json['validity'] as String?,
      statusText: dataObj['statusText'] as String? ?? (json['hasLastRecharge'] == false && json['hasActivePlan'] == false ? 'No active plan' : null),
      createdAt: dataObj['createdAt'] as String? ?? (lastRec != null ? lastRec['date'] as String? ?? '' : ''),
    );
  }
}

class FrequentNumber {
  final String mobileNumber;
  final String operatorName;
  final String operatorCode;
  final String? circleCode;
  final double lastRechargeAmount;
  final int count;

  FrequentNumber({
    required this.mobileNumber,
    required this.operatorName,
    required this.operatorCode,
    this.circleCode,
    required this.lastRechargeAmount,
    required this.count,
  });

  factory FrequentNumber.fromJson(Map<String, dynamic> json) {
    final rawOpName = json['operatorName'] as String? ?? '';
    final rawOpCode = json['operatorCode'] as String? ?? '';
    return FrequentNumber(
      mobileNumber: json['mobileNumber'] as String? ?? '',
      operatorName: OperatorFormatter.getDisplayOperatorName(rawOpName.isNotEmpty ? rawOpName : rawOpCode),
      operatorCode: rawOpCode,
      circleCode: json['circleCode'] as String? ?? json['circle'] as String?,
      lastRechargeAmount: (json['lastRechargeAmount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }
}

final personalSavingsProvider = FutureProvider.autoDispose<PersonalSavings>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>>(
    '/personal/savings',
    fromJson: (json) {
      if (json is Map<String, dynamic>) {
        if (json['data'] is Map<String, dynamic>) {
          return json['data'] as Map<String, dynamic>;
        }
        return json;
      }
      return <String, dynamic>{};
    },
  );
  if (response.success && response.data != null) {
    return PersonalSavings.fromJson(response.data!);
  }
  return PersonalSavings(lifetimeSavings: 0.0, monthlySavings: 0.0, previousMonthSavings: 0.0, totalCompletedCount: 0);
});

final personalBenefitsProvider = FutureProvider.autoDispose<List<PersonalBenefitSlab>>((ref) async {
  final cache = LocalCacheService.instance;
  final cachedList = cache.get<List<dynamic>>(cache.offersBox, 'cached_personal_benefits');
  List<PersonalBenefitSlab> cachedSlabs = [];

  if (cachedList != null) {
    try {
      final parsed = cachedList
          .map((item) => PersonalBenefitSlab.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      cachedSlabs = deduplicateSlabs(parsed);
    } catch (_) {}
  }

  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/personal/benefits',
      fromJson: (json) => json as Map<String, dynamic>,
    );
    if (response.success && response.data != null) {
      final list = response.data!['slabs'] as List? ?? [];
      final fresh = list.map((item) => PersonalBenefitSlab.fromJson(item as Map<String, dynamic>)).toList();
      final deduplicated = deduplicateSlabs(fresh);
      if (deduplicated.isNotEmpty) {
        cache.put(
          cache.offersBox,
          'cached_personal_benefits',
          deduplicated.map((s) => s.toJson()).toList(),
        );
        return deduplicated;
      }
    }
  } catch (e) {
    if (cachedSlabs.isNotEmpty) return cachedSlabs;
    rethrow;
  }
  return cachedSlabs;
});

final currentPlanProvider = FutureProvider.autoDispose<LastRecharge?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>?>(
    '/personal/current-plan',
    fromJson: (json) => json as Map<String, dynamic>?,
  );
  if (response.success && response.data != null) {
    return LastRecharge.fromJson(response.data!);
  }
  return null;
});

final lastRechargeProvider = FutureProvider.autoDispose<LastRecharge?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>?>(
    '/personal/last-recharge',
    fromJson: (json) => json as Map<String, dynamic>?,
  );
  if (response.success && response.data != null) {
    return LastRecharge.fromJson(response.data!);
  }
  return null;
});

final pendingRechargeProvider = FutureProvider.autoDispose<LastRecharge?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>?>(
    '/personal/pending-recharge',
    fromJson: (json) => json as Map<String, dynamic>?,
  );
  if (response.success && response.data != null) {
    return LastRecharge.fromJson(response.data!);
  }
  return null;
});

final frequentNumbersProvider = FutureProvider.autoDispose<List<FrequentNumber>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<List<dynamic>>(
    '/personal/frequent-numbers',
    fromJson: (json) => json as List<dynamic>,
  );
  if (response.success && response.data != null) {
    return response.data!.map((item) => FrequentNumber.fromJson(item as Map<String, dynamic>)).toList();
  }
  return [];
});

class LastSuccessfulRecharge {
  final String id;
  final String orderId;
  final double amount;
  final String mobileNumber;
  final String operatorName;
  final String operatorCode;
  final String status;
  final String rechargeDate;

  LastSuccessfulRecharge({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.mobileNumber,
    required this.operatorName,
    required this.operatorCode,
    required this.status,
    required this.rechargeDate,
  });

  factory LastSuccessfulRecharge.fromJson(Map<String, dynamic> json) {
    final rawOpName = json['operator'] as String? ?? json['operatorName'] as String? ?? '';
    final rawOpCode = json['operatorCode'] as String? ?? '';
    final displayOpName = OperatorFormatter.getDisplayOperatorName(rawOpName.isNotEmpty ? rawOpName : rawOpCode);

    return LastSuccessfulRecharge(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      mobileNumber: json['mobileNumber'] as String? ?? '',
      operatorName: displayOpName,
      operatorCode: rawOpCode,
      status: json['status'] as String? ?? 'SUCCESS',
      rechargeDate: json['rechargeDate'] as String? ?? json['createdAt'] as String? ?? '',
    );
  }
}

final lastSuccessfulRechargeProvider = FutureProvider.autoDispose<LastSuccessfulRecharge?>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.get<Map<String, dynamic>?>(
    '/personal/last-successful',
    fromJson: (json) => json as Map<String, dynamic>?,
  );
  if (response.success && response.data != null) {
    final hasLast = response.data!['hasLastSuccessful'] == true;
    final dataObj = response.data!['data'];
    if (hasLast && dataObj is Map<String, dynamic>) {
      return LastSuccessfulRecharge.fromJson(dataObj);
    }
  }
  return null;
});
