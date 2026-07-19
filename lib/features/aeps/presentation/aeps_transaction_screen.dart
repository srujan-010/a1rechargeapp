import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/models/aeps_models.dart';
import 'aeps_providers.dart';

class AepsTransactionScreen extends ConsumerStatefulWidget {
  const AepsTransactionScreen({super.key});

  @override
  ConsumerState<AepsTransactionScreen> createState() => _AepsTransactionScreenState();
}

class _AepsTransactionScreenState extends ConsumerState<AepsTransactionScreen> {
  final _aadhaarController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _aadhaarController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _selectBank() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final banksAsync = ref.watch(aepsBanksProvider);
              return Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text('Select Bank', style: AppTextTheme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: banksAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (banks) => ListView.builder(
                        controller: scrollController,
                        itemCount: banks.length,
                        itemBuilder: (context, i) {
                          final bank = banks[i];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.surfaceVariant,
                              child: Icon(Icons.account_balance, color: AppColors.primaryBlue),
                            ),
                            title: Text(bank.name),
                            subtitle: Text('IIN: ${bank.iin}'),
                            onTap: () {
                              ref.read(aepsFlowProvider.notifier).setBank(bank);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aepsFlowProvider);
    final type = state.transactionType;

    if (type == null) {
      return const Scaffold(body: Center(child: Text('Invalid AEPS State')));
    }

    final title = switch (type) {
      AepsTransactionType.cashWithdrawal => 'Cash Withdrawal',
      AepsTransactionType.balanceEnquiry => 'Balance Enquiry',
      AepsTransactionType.miniStatement => 'Mini Statement',
      AepsTransactionType.aadhaarPay => 'Aadhaar Pay',
    };

    final requiresAmount = type == AepsTransactionType.cashWithdrawal || type == AepsTransactionType.aadhaarPay;

    final isValid = state.selectedBank != null &&
        state.aadhaarNumber != null &&
        state.aadhaarNumber!.length == 12 &&
        (!requiresAmount || (state.amountPaise != null && state.amountPaise! > 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bank Selection
              Text('Select Bank', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryBlueLight,
                    child: Icon(Icons.account_balance, color: AppColors.primaryBlue),
                  ),
                  title: Text(state.selectedBank?.name ?? 'Choose your bank'),
                  trailing: state.selectedBank == null
                      ? const Icon(Icons.arrow_forward_ios, size: 16)
                      : TextButton(onPressed: _selectBank, child: const Text('Change')),
                  onTap: state.selectedBank == null ? _selectBank : null,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Aadhaar Number
              Text('Aadhaar Number', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => ref.read(aepsFlowProvider.notifier).setAadhaarNumber(v),
                decoration: const InputDecoration(
                  hintText: 'Enter 12-digit Aadhaar Number',
                  prefixIcon: Icon(Icons.fingerprint),
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Amount (if applicable)
              if (requiresAmount) ...[
                Text('Amount', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    final num = int.tryParse(v) ?? 0;
                    ref.read(aepsFlowProvider.notifier).setAmount(num * 100);
                  },
                  style: AppTextTheme.textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    hintText: '₹ 0',
                    prefixText: '₹ ',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              const SizedBox(height: AppSpacing.xxl),

              AppButton(
                label: 'Capture Biometric',
                onPressed: isValid
                    ? () {
                        context.push(RouteNames.aepsBiometric);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
