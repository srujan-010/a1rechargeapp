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
import '../domain/models/dmt_models.dart';

class DmtReceiptScreen extends StatelessWidget {
  const DmtReceiptScreen({super.key, required this.result});
  final DmtResult result;

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.status;
    final primaryColor = isSuccess ? AppColors.success : AppColors.error;
    final icon = isSuccess ? Icons.check_circle : Icons.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transfer Receipt'),
        automaticallyImplyLeading: false, 
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
                      isSuccess ? 'Transfer Successful' : 'Transfer Failed',
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
                    
                    Text(
                      CurrencyFormatter.fromPaise(result.amountPaise),
                      style: AppTextTheme.textTheme.displayMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    
                    _ReceiptRow(label: 'Beneficiary', value: result.beneficiaryName),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'Account No.', value: result.accountNumber),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(
                      label: 'Transfer Mode', 
                      value: result.mode == DmtTransferMode.imps ? 'IMPS' : 'NEFT',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'Bank UTR', value: result.referenceId),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(
                      label: 'Date & Time', 
                      value: DateFormat('dd MMM yyyy, hh:mm a').format(result.timestamp),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ReceiptRow(label: 'Txn ID', value: result.transactionId),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'Back to Dashboard',
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
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;

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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
