import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import 'bbps_providers.dart';

import '../../../core/models/app_exception.dart';

class BbpsPayConfirmScreen extends ConsumerStatefulWidget {
  const BbpsPayConfirmScreen({super.key, required this.billerId});
  final String billerId;

  @override
  ConsumerState<BbpsPayConfirmScreen> createState() => _BbpsPayConfirmScreenState();
}

class _BbpsPayConfirmScreenState extends ConsumerState<BbpsPayConfirmScreen> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _processPayment(String pin) async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final receipt = await ref.read(bbpsFlowProvider.notifier).payBill(pin);
      if (!mounted) return;
      
      // Navigate to the shared receipt screen
      context.go(RouteNames.dashboard);
      context.push(RouteNames.rechargeReceipt.replaceFirst(':txnId', receipt.transactionId), extra: receipt);
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is AppException) {
          errorMsg = e.message;
        }

        if (errorMsg.toLowerCase().contains('insufficient balance') ||
            errorMsg.toLowerCase().contains('insufficient fund') ||
            errorMsg.toLowerCase().contains('balance')) {
          errorMsg = 'Insufficient funds. Please add funds to your wallet.';
        } else if (errorMsg.toLowerCase().contains('mpin') || errorMsg.toLowerCase().contains('pin')) {
          errorMsg = 'Invalid MPIN entered. Please try again.';
        }

        setState(() {
          _errorText = errorMsg;
          _isLoading = false;
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bbpsFlowProvider);
    final bill = state.fetchedBill;

    if (bill == null || bill.billerId != widget.billerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Payment')),
        body: const Center(child: Text('Invalid state. Bill details not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bill Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bill Summary Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryBlueLight,
                      child: Text(
                        bill.billerName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      bill.billerName,
                      style: AppTextTheme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      CurrencyFormatter.fromPaise(bill.billAmountPaise),
                      style: AppTextTheme.textTheme.displayMedium?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due by ${DateFormat('dd MMM yyyy').format(bill.dueDate)}',
                      style: AppTextTheme.textTheme.labelMedium?.copyWith(
                        color: bill.dueDate.isBefore(DateTime.now()) ? AppColors.error : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryRow(label: 'Customer Name', value: bill.customerName),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryRow(label: 'Bill Number', value: bill.billNumber),
                    const SizedBox(height: AppSpacing.sm),
                    _SummaryRow(label: 'Bill Date', value: DateFormat('dd MMM yyyy').format(bill.billDate)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // PIN Entry
              Text(
                'Enter 6-digit MPIN to pay',
                style: AppTextTheme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              
              if (_isLoading)
                const CircularProgressIndicator()
              else
                PinEntryWidget(
                  controller: _pinController,
                  errorText: _errorText,
                  onCompleted: _processPayment,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextTheme.textTheme.titleSmall,
        ),
      ],
    );
  }
}
