// lib/features/commission/data/commission_repository_mock.dart
// In-memory mock implementation of CommissionRepository.
// Seeds realistic slabs and earned entries consistent with WalletTransaction.fakeList().
// Injected when USE_MOCK_API=true (see AppConfig.useMockApi).

import 'dart:math';
import '../../../core/config/app_config.dart';
import '../domain/commission_repository.dart';
import '../domain/models/commission_slab.dart';
import '../domain/models/earned_commission_entry.dart';

class CommissionRepositoryMock implements CommissionRepository {
  final _random = Random();

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(
          AppConfig.mockLatencyMax.inMilliseconds -
              AppConfig.mockLatencyMin.inMilliseconds,
        );
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// Canonical seeded slabs — same IDs referenced in _seedEntries() below.
  static final List<CommissionSlab> _slabs = [
    CommissionSlab(
      id: 'SLAB001',
      serviceType: 'mobile',
      operatorName: 'Airtel',
      commissionType: 'percentage',
      commissionValue: 2.0,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
    CommissionSlab(
      id: 'SLAB002',
      serviceType: 'mobile',
      operatorName: 'BSNL',
      commissionType: 'percentage',
      commissionValue: 4.0,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
    CommissionSlab(
      id: 'SLAB003',
      serviceType: 'mobile',
      operatorName: 'Jio',
      commissionType: 'percentage',
      commissionValue: 1.5,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
    CommissionSlab(
      id: 'SLAB004',
      serviceType: 'mobile',
      operatorName: 'Vi',
      commissionType: 'percentage',
      commissionValue: 2.5,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
    CommissionSlab(
      id: 'SLAB005',
      serviceType: 'dth',
      operatorName: 'Tata Play',
      commissionType: 'percentage',
      commissionValue: 3.0,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
    CommissionSlab(
      id: 'SLAB006',
      serviceType: 'bbps',
      operatorName: 'BESCOM Electricity',
      commissionType: 'flat',
      commissionValue: 5.0,
      effectiveFrom: DateTime(2024, 1, 1),
    ),
  ];

  /// Seeded entries tied to fixed transaction IDs and consistent amounts.
  /// Formula check: amountEarned = transactionAmount × commissionValue / 100
  ///   TXN000001 (mobile_recharge): amount ₹100 → Airtel 2% → ₹2.00
  ///   TXN000002 (dth):             amount ₹200 → Tata Play 3% → ₹6.00
  ///   TXN000003 (bbps):            amount ₹300 → BESCOM flat → ₹5.00
  ///   TXN000004 (mobile_recharge): amount ₹400 → Jio 1.5% → ₹6.00
  ///   TXN000005 (mobile_recharge): amount ₹500 → BSNL 4% → ₹20.00
  ///   TXN000006 (mobile_recharge): amount ₹600 → Vi 2.5% → ₹15.00
  ///   TXN000007 (mobile_recharge): amount ₹700 → Airtel 2% → ₹14.00
  ///   TXN000008 (dth):             amount ₹800 → Tata Play 3% → ₹24.00
  static final List<EarnedCommissionEntry> _allEntries = [
    EarnedCommissionEntry(
      id: 'EC001',
      transactionId: 'TXN000001',
      slabId: 'SLAB001', // Airtel 2%
      amountEarned: 2.0, // ₹100 × 2% = ₹2.00
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    EarnedCommissionEntry(
      id: 'EC002',
      transactionId: 'TXN000002',
      slabId: 'SLAB005', // Tata Play 3%
      amountEarned: 6.0, // ₹200 × 3% = ₹6.00
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    EarnedCommissionEntry(
      id: 'EC003',
      transactionId: 'TXN000003',
      slabId: 'SLAB006', // BESCOM flat ₹5
      amountEarned: 5.0, // flat ₹5.00
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    EarnedCommissionEntry(
      id: 'EC004',
      transactionId: 'TXN000004',
      slabId: 'SLAB003', // Jio 1.5%
      amountEarned: 6.0, // ₹400 × 1.5% = ₹6.00
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    EarnedCommissionEntry(
      id: 'EC005',
      transactionId: 'TXN000005',
      slabId: 'SLAB002', // BSNL 4%
      amountEarned: 20.0, // ₹500 × 4% = ₹20.00
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    EarnedCommissionEntry(
      id: 'EC006',
      transactionId: 'TXN000006',
      slabId: 'SLAB004', // Vi 2.5%
      amountEarned: 15.0, // ₹600 × 2.5% = ₹15.00
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
    ),
    EarnedCommissionEntry(
      id: 'EC007',
      transactionId: 'TXN000007',
      slabId: 'SLAB001', // Airtel 2%
      amountEarned: 14.0, // ₹700 × 2% = ₹14.00
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    ),
    EarnedCommissionEntry(
      id: 'EC008',
      transactionId: 'TXN000008',
      slabId: 'SLAB005', // Tata Play 3%
      amountEarned: 24.0, // ₹800 × 3% = ₹24.00
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
    EarnedCommissionEntry(
      id: 'EC009',
      transactionId: 'TXN000009',
      slabId: 'SLAB001', // Airtel 2%
      amountEarned: 4.0, // ₹200 × 2% = ₹4.00
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
    ),
    EarnedCommissionEntry(
      id: 'EC010',
      transactionId: 'TXN000010',
      slabId: 'SLAB003', // Jio 1.5%
      amountEarned: 3.0, // ₹200 × 1.5% = ₹3.00
      timestamp: DateTime.now().subtract(const Duration(days: 5)),
    ),
    EarnedCommissionEntry(
      id: 'EC011',
      transactionId: 'TXN000011',
      slabId: 'SLAB002', // BSNL 4%
      amountEarned: 8.0, // ₹200 × 4% = ₹8.00
      timestamp: DateTime.now().subtract(const Duration(days: 6)),
    ),
    EarnedCommissionEntry(
      id: 'EC012',
      transactionId: 'TXN000012',
      slabId: 'SLAB006', // BESCOM flat ₹5
      amountEarned: 5.0,
      timestamp: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  @override
  Future<List<CommissionSlab>> getActiveSlabs() async {
    await _delay();
    return _slabs.where((s) => s.isActive).toList();
  }

  @override
  Future<List<EarnedCommissionEntry>> getEarnedEntries({
    DateTime? from,
    DateTime? to,
  }) async {
    await _delay();
    return _allEntries.where((e) {
      if (from != null && e.timestamp.isBefore(from)) return false;
      if (to != null && e.timestamp.isAfter(to)) return false;
      return true;
    }).toList();
  }
}
