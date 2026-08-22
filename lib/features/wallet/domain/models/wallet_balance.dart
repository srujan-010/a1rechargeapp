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
    this.walletFundingMode = 'ADMIN_ONLY',
  });

  /// All monetary values in PAISE (integer). Never use double for money.
  final int availablePaise;
  final int ledgerBalancePaise;
  final int onHoldPaise;
  final int pendingSettlementPaise;
  final DateTime lastUpdated;
  final String walletId;
  final String walletFundingMode;

  bool get isAddMoneyEnabled =>
      walletFundingMode == 'RAZORPAY' || walletFundingMode == 'PAYMENT_GATEWAY' || walletFundingMode == 'BOTH';

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
        walletId: json['walletId'] as String? ?? '',
        walletFundingMode: json['walletFundingMode'] as String? ?? 'ADMIN_ONLY',
      );

  Map<String, dynamic> toJson() => {
        'availableBalance': availablePaise,
        'ledgerBalance': ledgerBalancePaise,
        'onHoldBalance': onHoldPaise,
        'pendingSettlementPaise': pendingSettlementPaise,
        'lastUpdated': lastUpdated.toIso8601String(),
        'walletId': walletId,
        'walletFundingMode': walletFundingMode,
      };

  factory WalletBalance.fake() => WalletBalance(
        availablePaise: 1254025, // ₹12,540.25
        ledgerBalancePaise: 1254000,
        onHoldPaise: 25000, // ₹250.00
        pendingSettlementPaise: 18000, // ₹180.00
        lastUpdated: DateTime.now(),
        walletId: 'RET000001',
        walletFundingMode: 'ADMIN_ONLY',
      );

  factory WalletBalance.zero() => WalletBalance(
        availablePaise: 0,
        ledgerBalancePaise: 0,
        lastUpdated: DateTime.now(),
        walletId: 'UNKNOWN',
        walletFundingMode: 'ADMIN_ONLY',
      );

  WalletBalance copyWith({
    int? availablePaise,
    int? ledgerBalancePaise,
    int? onHoldPaise,
    int? pendingSettlementPaise,
    DateTime? lastUpdated,
    String? walletId,
    String? walletFundingMode,
  }) =>
      WalletBalance(
        availablePaise: availablePaise ?? this.availablePaise,
        ledgerBalancePaise: ledgerBalancePaise ?? this.ledgerBalancePaise,
        onHoldPaise: onHoldPaise ?? this.onHoldPaise,
        pendingSettlementPaise: pendingSettlementPaise ?? this.pendingSettlementPaise,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        walletId: walletId ?? this.walletId,
        walletFundingMode: walletFundingMode ?? this.walletFundingMode,
      );

  @override
  List<Object?> get props =>
      [availablePaise, ledgerBalancePaise, onHoldPaise, pendingSettlementPaise, lastUpdated, walletId, walletFundingMode];
}
