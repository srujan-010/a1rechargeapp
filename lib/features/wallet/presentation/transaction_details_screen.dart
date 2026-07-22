import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/models/wallet_transaction.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../history/presentation/history_providers.dart';
import 'widgets/share_receipt_bottom_sheet.dart';

class TransactionDetailsScreen extends ConsumerWidget {
  const TransactionDetailsScreen({
    super.key,
    required this.txnId,
    this.transaction,
  });
  
  final String txnId;
  final WalletTransaction? transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Resolve transaction: directly passed object first, then historyProvider, then recentProvider
    WalletTransaction? txn = transaction;

    if (txn == null) {
      final historyTxns = ref.watch(historyTransactionsProvider).valueOrNull ?? [];
      txn = historyTxns.cast<WalletTransaction?>().firstWhere(
        (t) => t?.id == txnId || t?.referenceId == txnId,
        orElse: () => null,
      );
    }

    if (txn == null) {
      final recentTxns = ref.watch(recentTransactionsProvider).valueOrNull ?? [];
      txn = recentTxns.cast<WalletTransaction?>().firstWhere(
        (t) => t?.id == txnId || t?.referenceId == txnId,
        orElse: () => null,
      );
    }

    // If transaction is null, show clear Error UI without fallback mocks!
    if (txn == null) {
      debugPrint('[TRANSACTION DETAILS] Error: Transaction not found for ID: $txnId');
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Transaction Details'),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Transaction Not Found',
                  style: AppTextTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The requested transaction (ID: $txnId) could not be loaded.',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Back to History',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Print runtime details as requested
    debugPrint('''
[TRANSACTION DETAILS] Navigation Received:
Selected Transaction:
id: ${txn.id}
type: ${txn.serviceType}
amount: ₹${txn.amountPaise / 100}
operator: ${txn.operatorName}
mobile: ${txn.customerIdentifier}
status: ${txn.status.name}
reference: ${txn.referenceId}
apiReference: ${txn.apiReference ?? 'N/A'}
serviceType: ${txn.serviceType}
''');

    final String amountStr = CurrencyFormatter.fromPaise(txn.amountPaise);
    final String readableServiceType = _formatServiceType(txn.serviceType);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // Top Header Card
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
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: txn.isCredit ? const Color(0xFF10B981) : AppColors.textPrimary,
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

            // Main Details Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Recharge / Service Type', value: readableServiceType, isBold: true),
                  if (txn.operatorName.isNotEmpty)
                    _DetailRow(label: 'Operator / Biller', value: txn.operatorName),
                  if (txn.customerIdentifier.isNotEmpty)
                    _DetailRow(label: 'Mobile / Subscriber ID', value: txn.customerIdentifier, isBold: true),
                  _DetailRow(label: 'Amount', value: amountStr, isBold: true),
                  _DetailRow(
                    label: 'Status', 
                    value: txn.status.name.toUpperCase(),
                    valueColor: _getStatusColor(txn.status),
                    isBold: true,
                  ),
                  if (txn.commissionEarnedPaise > 0)
                    _DetailRow(
                      label: 'Commission Earned', 
                      value: '+${CurrencyFormatter.fromPaise(txn.commissionEarnedPaise)}',
                      valueColor: const Color(0xFF10B981),
                      isBold: true,
                    ),
                  _DetailRow(label: 'Payment Method', value: txn.paymentMethod.toUpperCase()),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  
                  _DetailRow(label: 'Order / Ref ID', value: txn.referenceId.isNotEmpty ? txn.referenceId : txn.id),
                  if (txn.apiReference != null && txn.apiReference!.isNotEmpty)
                    _DetailRow(label: 'Provider Transaction ID', value: txn.apiReference!, isBold: true),
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

            // Failure Reason Card if Failed
            if ((txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) &&
                txn.description != null &&
                txn.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Failure Reason',
                            style: TextStyle(
                              color: Color(0xFF991B1B),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            txn.description!,
                            style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      builder: (context) => ShareReceiptBottomSheet(transaction: txn!),
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

  String _formatServiceType(String type) {
    return switch (type.toLowerCase()) {
      'mobile' || 'mobile_recharge' => 'Mobile Recharge',
      'dth' => 'DTH Recharge',
      'bbps' => 'BBPS Bill Payment',
      'wallet_topup' => 'Wallet Topup',
      'commission' => 'Commission Credit',
      'settlement' => 'Bank Settlement',
      _ => type.toUpperCase(),
    };
  }

  IconData _getIcon(WalletTransaction txn) {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) return Icons.error_outline;
    
    final title = txn.transactionTitle.toLowerCase();
    final service = txn.serviceType.toLowerCase();
    if (service == 'commission' || title.contains('commission')) return Icons.redeem;
    if (service == 'wallet_topup' || title.contains('wallet')) return Icons.account_balance_wallet;
    if (service == 'dth' || title.contains('dth')) return Icons.tv;
    if (service == 'mobile' || service == 'mobile_recharge' || title.contains('mobile')) return Icons.phone_android;
    if (service == 'bbps' || title.contains('electricity') || title.contains('water') || title.contains('gas')) return Icons.receipt_long;
    if (txn.isCredit) return Icons.arrow_downward;
    
    return Icons.receipt_long;
  }

  Color _getIconColor(WalletTransaction txn) {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) {
      return const Color(0xFFDC2626);
    }
    if (txn.status == TransactionStatus.pending) {
      return const Color(0xFFF59E0B);
    }
    
    final service = txn.serviceType.toLowerCase();
    if (service == 'commission') return const Color(0xFF10B981);
    if (service == 'wallet_topup') return const Color(0xFF8B5CF6);
    if (service == 'dth') return const Color(0xFFF43F5E);
    if (service == 'mobile' || service == 'mobile_recharge') return const Color(0xFF3B82F6);
    if (txn.isCredit) return const Color(0xFF10B981);
    
    return const Color(0xFF3B82F6);
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
