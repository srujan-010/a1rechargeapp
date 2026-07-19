// lib/features/commission/domain/models/earned_commission_entry.dart
// A single commission credit earned from a completed transaction.
// amountEarned is in INR rupees (double), not paise — commissions are fractional values
// (e.g. 2% of ₹100 = ₹2.00). The chart and summary providers work in rupees directly.

import 'package:equatable/equatable.dart';

class EarnedCommissionEntry extends Equatable {
  const EarnedCommissionEntry({
    required this.id,
    required this.transactionId,
    required this.slabId,
    required this.amountEarned,
    required this.timestamp,
  });

  final String id;
  final String transactionId;
  final String slabId;

  /// Commission earned in INR rupees (not paise). Always ≥ 0.
  final double amountEarned;

  final DateTime timestamp;

  factory EarnedCommissionEntry.fromJson(Map<String, dynamic> json) =>
      EarnedCommissionEntry(
        id: json['id'] as String? ?? '',
        transactionId: json['transactionId'] as String? ?? '',
        slabId: json['slabId'] as String? ?? '',
        amountEarned: (json['amountEarned'] as num?)?.toDouble() ?? 0.0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'slabId': slabId,
        'amountEarned': amountEarned,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, transactionId, slabId, amountEarned, timestamp];
}
