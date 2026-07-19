import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import 'loan_providers.dart';
import '../../../core/models/app_exception.dart';

class LoanEmiScreen extends ConsumerStatefulWidget {
  const LoanEmiScreen({super.key, required this.providerId});
  final String providerId;

  @override
  ConsumerState<LoanEmiScreen> createState() => _LoanEmiScreenState();
}

class _LoanEmiScreenState extends ConsumerState<LoanEmiScreen> {
  final _accountController = TextEditingController();

  bool _isFetching = false;
  bool _isProcessing = false;
  String? _errorMsg;
  String? _paymentErrorMsg;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoan() async {
    final accountNo = _accountController.text.trim();

    if (accountNo.isEmpty) {
      setState(() => _errorMsg = 'Loan Account Number is required');
      return;
    }

    setState(() {
      _isFetching = true;
      _errorMsg = null;
    });

    try {
      await ref.read(loanFlowProvider.notifier).fetchLoanDetails(accountNo);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _payEmi(String pin) async {
    setState(() {
      _isProcessing = true;
      _paymentErrorMsg = null;
    });

    try {
      final result = await ref.read(loanFlowProvider.notifier).payEmi(pin);
      if (!mounted) return;

      context.go(RouteNames.dashboard);
      context.push(RouteNames.rechargeReceipt.replaceFirst(':txnId', result.transactionId), extra: result);
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
          _paymentErrorMsg = errorMsg;
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanFlowProvider);
    final provider = state.selectedProvider;
    final loan = state.fetchedLoan;

    if (provider == null || provider.id != widget.providerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Invalid State')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(provider.name),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loan == null) ...[
                // Fetch Loan Form
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enter Loan Details', style: AppTextTheme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          hintText: 'Loan Account Number',
                          prefixIcon: Icon(Icons.account_box),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_errorMsg != null) ...[
                        Text(
                          _errorMsg!,
                          style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(
                        label: 'Fetch EMI Amount',
                        isLoading: _isFetching,
                        onPressed: _fetchLoan,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Pay EMI Form
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text('Loan Details', style: AppTextTheme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(label: 'Customer Name', value: loan.customerName),
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(label: 'Loan A/c No.', value: loan.loanAccountNumber),
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(label: 'Due Date', value: DateFormat('dd MMM yyyy').format(loan.dueDate)),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Total EMI Due',
                        style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.fromPaise(loan.emiAmountPaise),
                        style: AppTextTheme.textTheme.displayMedium?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text('Enter 6-digit MPIN to Pay', style: AppTextTheme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  PinEntryWidget(
                    errorText: _paymentErrorMsg,
                    onCompleted: _payEmi,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextTheme.textTheme.titleSmall),
      ],
    );
  }
}
