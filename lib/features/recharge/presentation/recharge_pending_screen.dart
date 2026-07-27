import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/models/recharge_result.dart';

class RechargePendingScreen extends StatelessWidget {
  final RechargeReceipt receipt;

  const RechargePendingScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(receipt.timestamp);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Recharge Submitted', style: TextStyle(fontWeight: FontWeight.bold)),
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

                // ── AMBER HOURGLASS BADGE ──
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 40,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Recharge Submitted',
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
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 20),

                // ── PRODUCTION REASSURANCE CARD ──
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submitted Successfully',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Your recharge request has been submitted successfully.\n\n'
                        'The operator is taking longer than usual to confirm the recharge.\n\n'
                        'No action is required from your side.\n\n'
                        'We will automatically notify you once the final status is received.',
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── TRANSACTION DETAILS CARD ──
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

                // ── ACTION BUTTONS: GO HOME & VIEW TRANSACTION ──
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
                    child: const Text('Go Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      context.go(RouteNames.dashboard);
                      context.push(RouteNames.transactionHistory);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
