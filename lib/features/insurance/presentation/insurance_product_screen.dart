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
import '../../../core/models/app_exception.dart';
import 'insurance_providers.dart';

class InsuranceProductScreen extends ConsumerStatefulWidget {
  const InsuranceProductScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<InsuranceProductScreen> createState() => _InsuranceProductScreenState();
}

class _InsuranceProductScreenState extends ConsumerState<InsuranceProductScreen> {
  final _policyController = TextEditingController();
  final _dobController = TextEditingController();

  bool _isFetching = false;
  bool _isProcessing = false;
  String? _errorMsg;
  String? _paymentErrorMsg;

  @override
  void dispose() {
    _policyController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _fetchPolicy() async {
    final policyNo = _policyController.text.trim();
    final dob = _dobController.text.trim();

    if (policyNo.isEmpty) {
      setState(() => _errorMsg = 'Policy Number is required');
      return;
    }

    setState(() {
      _isFetching = true;
      _errorMsg = null;
    });

    try {
      await ref.read(insuranceFlowProvider.notifier).fetchPolicyDetails(policyNo, dob: dob);
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

  Future<void> _payPremium(String pin) async {
    setState(() {
      _isProcessing = true;
      _paymentErrorMsg = null;
    });

    try {
      final result = await ref.read(insuranceFlowProvider.notifier).payPremium(pin);
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
    final state = ref.watch(insuranceFlowProvider);
    final provider = state.selectedProvider;
    final policy = state.fetchedPolicy;

    if (provider == null || provider.id != widget.productId) {
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
              if (policy == null) ...[
                // Fetch Policy Form
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enter Policy Details', style: AppTextTheme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _policyController,
                        decoration: const InputDecoration(
                          hintText: 'Policy Number',
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      if (provider.requiresDob) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _dobController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            hintText: 'Date of Birth (DD-MM-YYYY)',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (_errorMsg != null) ...[
                        Text(
                          _errorMsg!,
                          style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.error),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(
                        label: 'Fetch Premium',
                        isLoading: _isFetching,
                        onPressed: _fetchPolicy,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Pay Premium Form
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text('Policy Details', style: AppTextTheme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(label: 'Customer Name', value: policy.customerName),
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(label: 'Policy No.', value: policy.policyNumber),
                      const SizedBox(height: AppSpacing.sm),
                      _DetailRow(label: 'Due Date', value: DateFormat('dd MMM yyyy').format(policy.dueDate)),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Total Premium',
                        style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        CurrencyFormatter.fromPaise(policy.premiumAmountPaise),
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
                    onCompleted: _payPremium,
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
