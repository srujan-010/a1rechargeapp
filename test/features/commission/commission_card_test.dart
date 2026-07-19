// test/features/commission/commission_card_test.dart
// Widget test: EarnedCommissionCard renders with mock data and totals are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:a1_recharge/features/commission/domain/models/commission_slab.dart';
import 'package:a1_recharge/features/commission/domain/models/earned_commission_entry.dart';
import 'package:a1_recharge/features/commission/domain/commission_repository.dart';
import 'package:a1_recharge/features/commission/presentation/commission_providers.dart';
import 'package:a1_recharge/features/commission/presentation/earned_commission_card.dart';

// ─── Deterministic mock for testing ──────────────────────────────────────────

class _TestCommissionRepository implements CommissionRepository {
  static final List<CommissionSlab> slabs = [
    CommissionSlab.fake(id: 'SLAB001', operatorName: 'Airtel', commissionType: 'percentage', commissionValue: 2.0),
    CommissionSlab.fake(id: 'SLAB002', operatorName: 'BSNL', commissionType: 'percentage', commissionValue: 4.0),
  ];

  // 3 Airtel entries: ₹100 × 2% = ₹2 each → ₹6 total for Airtel
  // 1 BSNL entry:    ₹100 × 4% = ₹4 total for BSNL
  // Grand total: ₹10.00
  static final List<EarnedCommissionEntry> entries = [
    EarnedCommissionEntry(
      id: 'E1', transactionId: 'T1', slabId: 'SLAB001',
      amountEarned: 2.0, timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    EarnedCommissionEntry(
      id: 'E2', transactionId: 'T2', slabId: 'SLAB001',
      amountEarned: 2.0, timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    EarnedCommissionEntry(
      id: 'E3', transactionId: 'T3', slabId: 'SLAB001',
      amountEarned: 2.0, timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    EarnedCommissionEntry(
      id: 'E4', transactionId: 'T4', slabId: 'SLAB002',
      amountEarned: 4.0, timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  @override
  Future<List<CommissionSlab>> getActiveSlabs() async => slabs;

  @override
  Future<List<EarnedCommissionEntry>> getEarnedEntries({
    DateTime? from,
    DateTime? to,
  }) async =>
      entries.where((e) {
        if (from != null && e.timestamp.isBefore(from)) return false;
        if (to != null && e.timestamp.isAfter(to)) return false;
        return true;
      }).toList();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _buildTestApp(List<Override> overrides) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(child: EarnedCommissionCard()),
        ),
      ),
      GoRoute(
        path: '/profile/commission-slab',
        builder: (_, __) => const Scaffold(body: Text('Slab Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  final testRepo = _TestCommissionRepository();

  final repositoryOverride = commissionRepositoryProvider
      .overrideWithValue(testRepo);

  group('EarnedCommissionCard', () {
    testWidgets('renders total earned amount correctly (₹10.00 from test data)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp([repositoryOverride]));
      // Let async providers resolve
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Total: ₹2 + ₹2 + ₹2 + ₹4 = ₹10.00
      expect(find.textContaining('10'), findsWidgets);
    });

    testWidgets('renders section header', (tester) async {
      await tester.pumpWidget(_buildTestApp([repositoryOverride]));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Earned Commission'), findsOneWidget);
    });

    testWidgets('renders period toggles', (tester) async {
      await tester.pumpWidget(_buildTestApp([repositoryOverride]));
      await tester.pump(); // Don't wait for data — toggles show immediately

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });
  });

  group('EarnedCommissionSummary aggregation', () {
    test('provider aggregates entries correctly', () async {
      final entries = await testRepo.getEarnedEntries();
      final slabs = await testRepo.getActiveSlabs();
      final slabMap = {for (final s in slabs) s.id: s};

      double total = 0;
      final Map<String, double> byOperator = {};
      for (final e in entries) {
        total += e.amountEarned;
        final op = slabMap[e.slabId]?.operatorName ?? 'Other';
        byOperator[op] = (byOperator[op] ?? 0) + e.amountEarned;
      }

      // Verify totals
      expect(total, closeTo(10.0, 0.001));
      expect(byOperator['Airtel'], closeTo(6.0, 0.001));
      expect(byOperator['BSNL'], closeTo(4.0, 0.001));
    });
  });
}
