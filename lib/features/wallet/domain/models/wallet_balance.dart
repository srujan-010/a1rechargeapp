// lib/features/wallet/domain/models/wallet_balance.dart
import 'package:equatable/equatable.dart';

class WalletBalance extends Equatable {
  const WalletBalance({
    required this.availablePaise,
    required this.ledgerBalancePaise,
    required this.lastUpdated,
    required this.walletId,
    this.onHoldPaise = 0,
    this.pendingSettlementPaise = 0,
  });

  /// All monetary values in PAISE (integer). Never use double for money.
  final int availablePaise;
  final int ledgerBalancePaise;
  final int onHoldPaise;
  final int pendingSettlementPaise;
  final DateTime lastUpdated;
  final String walletId;

  factory WalletBalance.fromJson(Map<String, dynamic> json) => WalletBalance(
        availablePaise: (json['availablePaise'] as num?)?.toInt() ??
            (json['availableBalance'] as num?)?.toInt() ??
            (json['balancePaise'] as num?)?.toInt() ??
            0,
        ledgerBalancePaise: (json['ledgerBalancePaise'] as num?)?.toInt() ??
            (json['ledgerBalance'] as num?)?.toInt() ??
            (json['balancePaise'] as num?)?.toInt() ??
            0,
        onHoldPaise: (json['onHoldPaise'] as num?)?.toInt() ??
            (json['onHoldBalance'] as num?)?.toInt() ??
            0,
        pendingSettlementPaise: (json['pendingSettlementPaise'] as num?)?.toInt() ?? 0,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : DateTime.now(),
        walletId: json['walletId'] as String? ?? 'RET000000',
      );

  Map<String, dynamic> toJson() => {
        'availableBalance': availablePaise,
        'ledgerBalance': ledgerBalancePaise,
        'onHoldBalance': onHoldPaise,
        'pendingSettlementPaise': pendingSettlementPaise,
        'lastUpdated': lastUpdated.toIso8601String(),
        'walletId': walletId,
      };

  factory WalletBalance.fake() => WalletBalance(
        availablePaise: 1254025, // ₹12,540.25
        ledgerBalancePaise: 1254000,
        onHoldPaise: 25000, // ₹250.00
        pendingSettlementPaise: 18000, // ₹180.00
        lastUpdated: DateTime.now(),
        walletId: 'RET000001',
      );

  factory WalletBalance.zero() => WalletBalance(
        availablePaise: 0,
        ledgerBalancePaise: 0,
        lastUpdated: DateTime.now(),
        walletId: 'UNKNOWN',
      );

  WalletBalance copyWith({
    int? availablePaise,
    int? ledgerBalancePaise,
    int? onHoldPaise,
    int? pendingSettlementPaise,
    DateTime? lastUpdated,
    String? walletId,
  }) =>
      WalletBalance(
        availablePaise: availablePaise ?? this.availablePaise,
        ledgerBalancePaise: ledgerBalancePaise ?? this.ledgerBalancePaise,
        onHoldPaise: onHoldPaise ?? this.onHoldPaise,
        pendingSettlementPaise: pendingSettlementPaise ?? this.pendingSettlementPaise,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        walletId: walletId ?? this.walletId,
      );

  @override
  List<Object?> get props =>
      [availablePaise, ledgerBalancePaise, onHoldPaise, pendingSettlementPaise, lastUpdated, walletId];
}
