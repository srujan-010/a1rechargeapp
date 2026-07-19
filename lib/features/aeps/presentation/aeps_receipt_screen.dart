import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/models/aeps_models.dart';

class AepsReceiptScreen extends StatelessWidget {
  const AepsReceiptScreen({super.key, required this.result});
  final AepsResult result;

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.status;
    final primaryColor = isSuccess ? AppColors.success : AppColors.error;
    final icon = isSuccess ? Icons.check_circle : Icons.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
        automaticallyImplyLeading: false, // Force user to use Home button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(icon, color: primaryColor, size: 64),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isSuccess ? 'Transaction Successful' : 'Transaction Failed',
                      style: AppTextTheme.textTheme.titleMedium?.copyWith(color: primaryColor),
                    ),
                    if (!isSuccess && result.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        result.errorMessage!,
                        style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    
                    if (result.amountPaise != null) ...[
                      Text(
                        CurrencyFormatter.fromPaise(result.amountPaise!),
                        style: AppTextTheme.textTheme.displayMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    
                    _ReceiptRow(label: 'Bank', value: result.bankName),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'Aadhaar No.', value: 'XXXX XXXX ${result.aadhaarLast4}'),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'RRN', value: result.referenceId),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(
                      label: 'Date & Time', 
                      value: DateFormat('dd MMM yyyy, hh:mm a').format(result.timestamp),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'Txn ID', value: result.transactionId),
                    
                    if (result.balancePaise != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      _ReceiptRow(
                        label: 'Available Balance', 
                        value: CurrencyFormatter.fromPaise(result.balancePaise!),
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),
              
              if (result.statementLines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Mini Statement', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: result.statementLines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(line, style: AppTextTheme.textTheme.bodyMedium),
                    )).toList(),
                  ),
                ),
              ],
              
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'Done',
                onPressed: () {
                  context.go(RouteNames.dashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value, this.isBold = false});
  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextTheme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextTheme.textTheme.titleSmall?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
