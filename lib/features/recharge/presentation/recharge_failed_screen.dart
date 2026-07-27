import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/models/recharge_result.dart';

class RechargeFailedScreen extends StatelessWidget {
  final RechargeReceipt receipt;

  const RechargeFailedScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.timestamp);
    final failureReason = receipt.failureReason ?? 'Transaction declined by operator.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Recharge Failed', style: TextStyle(fontWeight: FontWeight.bold)),
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── RED ERROR BADGE ──
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
                    ),
                    child: const Icon(
                      Icons.cancel_rounded,
                      size: 44,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Recharge Failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  CurrencyFormatter.fromPaise(receipt.amountPaise),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 20),

                // ── REFUND NOTICE CARD ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              failureReason,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If any amount was debited from your wallet, it has been automatically released back to your available wallet balance.',
                        style: TextStyle(
                          color: Color(0xFF7F1D1D),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── DETAILS CARD ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _DetailRow(label: 'Mobile / Account', value: receipt.mobileNumber),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _DetailRow(label: 'Operator', value: receipt.operatorName),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _DetailRow(label: 'Order ID', value: receipt.transactionId),
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      _DetailRow(label: 'Date & Time', value: formattedDate),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── ACTION BUTTONS ──
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go(RouteNames.dashboard),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
