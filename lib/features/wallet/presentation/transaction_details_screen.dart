import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/models/wallet_transaction.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import 'widgets/share_receipt_bottom_sheet.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({super.key, required this.txnId});
  
  final String txnId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTxns = ref.watch(recentTransactionsProvider).valueOrNull ?? [];
    
    // Find transaction by ID. If not found in recent, it might be in full history,
    // but for this demo we assume it's loaded.
    final WalletTransaction? txn = recentTxns.firstWhere(
      (t) => t.id == txnId,
      orElse: () => WalletTransaction.fakeList().firstWhere(
        (t) => t.id == txnId,
        orElse: () => WalletTransaction.fakeList().first,
      ),
    );

    if (txn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final bool isSuccess = txn.status == TransactionStatus.success;
    final String amountStr = CurrencyFormatter.fromPaise(txn.amountPaise);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  Hero(
                    tag: 'txn_icon_${txn.id}',
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _getIconColor(txn).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(txn),
                        color: _getIconColor(txn),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Hero(
                    tag: 'txn_amount_${txn.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        '${txn.isCredit ? '+' : '-'}$amountStr',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(txn.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      txn.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(txn.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    txn.transactionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.md),

            // Details Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Dynamic fields based on data existence
                  if (txn.operatorName.isNotEmpty)
                    _DetailRow(label: 'Operator / Biller', value: txn.operatorName),
                  if (txn.customerIdentifier.isNotEmpty)
                    _DetailRow(label: 'Identifier / Mobile', value: txn.customerIdentifier, isBold: true),
                  if (txn.commissionEarnedPaise > 0)
                    _DetailRow(
                      label: 'Commission Earned', 
                      value: '+${CurrencyFormatter.fromPaise(txn.commissionEarnedPaise)}',
                      valueColor: const Color(0xFF10B981),
                    ),
                  if (txn.serviceType == 'wallet_topup')
                    _DetailRow(label: 'Payment Method', value: txn.paymentMethod),
                  if (txn.serviceType == 'commission' && txn.description != null)
                    _DetailRow(label: 'Linked Transaction', value: txn.description!),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  
                  // Common Fields
                  _DetailRow(label: 'Transaction ID', value: txn.referenceId),
                  if (txn.apiReference != null && txn.apiReference!.isNotEmpty)
                    _DetailRow(label: 'Bank / Operator Ref', value: txn.apiReference!),
                  _DetailRow(
                    label: 'Date & Time', 
                    value: DateFormat('dd MMM yyyy • hh:mm a').format(txn.completedAt),
                  ),
                  if (txn.closingBalancePaise != null)
                    _DetailRow(
                      label: 'Wallet Balance After', 
                      value: CurrencyFormatter.fromPaise(txn.closingBalancePaise!),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Share Receipt',
                  variant: AppButtonVariant.outline,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ShareReceiptBottomSheet(transaction: txn),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Need Help?',
                  onPressed: () {
                    context.pushNamed(
                      'need-help',
                      extra: txn,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(WalletTransaction txn) {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) return Icons.error_outline;
    
    final title = txn.transactionTitle.toLowerCase();
    if (title.contains('commission')) return Icons.redeem; // 💰 Commission
    if (title.contains('wallet')) return Icons.account_balance_wallet; // 💳 Wallet
    if (title.contains('electricity')) return Icons.bolt; // ⚡ Electricity
    if (title.contains('water')) return Icons.water_drop; // 💧 Water
    if (title.contains('gas')) return Icons.local_fire_department; // 🔥 Gas
    if (title.contains('broadband')) return Icons.wifi; // 🌐 Broadband
    if (title.contains('dth')) return Icons.tv; // 📺 DTH
    if (title.contains('mobile')) return Icons.phone_android; // 📱 Mobile
    if (txn.isCredit) return Icons.arrow_downward; // Default Credit
    
    return Icons.receipt_long;
  }

  Color _getIconColor(WalletTransaction txn) {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) {
      return const Color(0xFFDC2626); // Red
    }
    if (txn.status == TransactionStatus.pending) {
      return const Color(0xFFF59E0B); // Orange
    }
    
    final title = txn.transactionTitle.toLowerCase();
    if (title.contains('commission')) return const Color(0xFF10B981); // Green
    if (title.contains('wallet')) return const Color(0xFF8B5CF6); // Purple
    if (title.contains('electricity')) return const Color(0xFFEAB308); // Yellow/Amber
    if (title.contains('water')) return const Color(0xFF0EA5E9); // Light Blue
    if (title.contains('gas')) return const Color(0xFFF97316); // Orange
    if (title.contains('broadband')) return const Color(0xFF6366F1); // Indigo
    if (title.contains('dth')) return const Color(0xFFF43F5E); // Rose
    if (title.contains('mobile')) return const Color(0xFF3B82F6); // Blue
    if (txn.isCredit) return const Color(0xFF10B981); // Default Credit
    
    return const Color(0xFF3B82F6); // Default Blue
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return const Color(0xFF10B981);
      case TransactionStatus.pending:
        return const Color(0xFFF59E0B);
      case TransactionStatus.failed:
      case TransactionStatus.reversed:
        return const Color(0xFFEF4444);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
