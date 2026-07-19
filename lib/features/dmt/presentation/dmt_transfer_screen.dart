import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../domain/models/dmt_models.dart';
import 'dmt_providers.dart';

class DmtTransferScreen extends ConsumerStatefulWidget {
  const DmtTransferScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;

  @override
  ConsumerState<DmtTransferScreen> createState() => _DmtTransferScreenState();
}

class _DmtTransferScreenState extends ConsumerState<DmtTransferScreen> {
  final _amountController = TextEditingController();
  bool _showPinEntry = false;
  bool _isProcessing = false;
  String? _errorMsg;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final num = int.tryParse(val) ?? 0;
    ref.read(dmtFlowProvider.notifier).setAmount(num * 100);
  }

  Future<void> _processTransfer(String pin) async {
    setState(() {
      _isProcessing = true;
      _errorMsg = null;
    });

    try {
      final result = await ref.read(dmtFlowProvider.notifier).processTransfer(pin);
      if (!mounted) return;
      
      if (result.status) {
        if (!mounted) return;
        context.go(RouteNames.dashboard);
        context.push(RouteNames.dmtReceipt, extra: result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception: ', '');
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dmtFlowProvider);
    final ben = state.selectedBeneficiary;
    final remitter = state.currentRemitter;

    if (ben == null || remitter == null || ben.id != widget.beneficiaryId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer')),
        body: const Center(child: Text('Invalid State')),
      );
    }

    if (_showPinEntry) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Confirm Transfer')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text('Transfer to ${ben.name}', style: AppTextTheme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(ben.accountNumber, style: AppTextTheme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        CurrencyFormatter.fromPaise(state.transferAmountPaise!),
                        style: AppTextTheme.textTheme.displayMedium?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          state.transferMode == DmtTransferMode.imps ? 'IMPS Transfer' : 'NEFT Transfer',
                          style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                Text('Enter 6-digit MPIN', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  PinEntryWidget(
                    errorText: _errorMsg,
                    onCompleted: _processTransfer,
                  )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transfer Money')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceVariant,
                    child: Icon(Icons.account_balance, color: AppColors.primaryBlue),
                  ),
                  title: Text(ben.name, style: AppTextTheme.textTheme.titleSmall),
                  subtitle: Text('${ben.bankName}\n${ben.accountNumber}'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              Text('Amount', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onAmountChanged,
                style: AppTextTheme.textTheme.headlineMedium,
                decoration: const InputDecoration(
                  hintText: '₹ 0',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Available Limit: ${CurrencyFormatter.fromPaise(remitter.availableLimitPaise)}',
                style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Transfer Mode', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(dmtFlowProvider.notifier).setMode(DmtTransferMode.imps),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: state.transferMode == DmtTransferMode.imps ? AppColors.primaryBlue : AppColors.border,
                            width: state.transferMode == DmtTransferMode.imps ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: state.transferMode == DmtTransferMode.imps ? AppColors.primaryBlueLight : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            'IMPS',
                            style: AppTextTheme.textTheme.titleSmall?.copyWith(
                              color: state.transferMode == DmtTransferMode.imps ? AppColors.primaryBlue : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(dmtFlowProvider.notifier).setMode(DmtTransferMode.neft),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: state.transferMode == DmtTransferMode.neft ? AppColors.primaryBlue : AppColors.border,
                            width: state.transferMode == DmtTransferMode.neft ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          color: state.transferMode == DmtTransferMode.neft ? AppColors.primaryBlueLight : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            'NEFT',
                            style: AppTextTheme.textTheme.titleSmall?.copyWith(
                              color: state.transferMode == DmtTransferMode.neft ? AppColors.primaryBlue : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),

              AppButton(
                label: 'Proceed',
                onPressed: state.transferAmountPaise != null && state.transferAmountPaise! > 0
                    ? () {
                        setState(() => _showPinEntry = true);
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
