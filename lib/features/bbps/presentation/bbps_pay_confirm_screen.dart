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
import '../../../core/widgets/pin_entry_widget.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
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
  bool _isPaying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showErrorOverlay(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Payment Failed', style: AppTextTheme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              onPressed: () {
                Navigator.pop(ctx);
                _pinController.clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(String pin) async {
    Navigator.pop(context); // close bottom sheet
    
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final receipt = await ref.read(bbpsFlowProvider.notifier).payBill(pin);
      if (!mounted) return;
      
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
        
        _showErrorOverlay(errorMsg);
      }
    }
  }

  void _showPinPrompt() {
    _pinController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          top: AppSpacing.lg,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Confirm Payment', style: AppTextTheme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Enter your 6-digit MPIN', style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            PinEntryWidget(
              controller: _pinController,
              onCompleted: _processPayment,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bbpsFlowProvider);
    final bill = state.fetchedBill;
    final walletAsync = ref.watch(walletBalanceProvider);
    final walletBalance = walletAsync.valueOrNull?.availablePaise ?? 0;

    if (bill == null || bill.billerId != widget.billerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Payment')),
        body: const Center(child: Text('Invalid state. Bill details not found.')),
      );
    }

    final bool isOverdue = bill.parsedDueDate?.isBefore(DateTime.now()) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Payment'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        // Main Receipt Card
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header (Amount)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlueLight,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text('Total Amount Due', style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.primaryBlue)),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        CurrencyFormatter.fromPaise(bill.billAmountPaise),
                                        style: AppTextTheme.textTheme.displaySmall?.copyWith(
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Details
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  children: [
                                    _DetailRow(icon: Icons.person_outline, label: 'Consumer Name', value: bill.customerName),
                                    const Divider(height: AppSpacing.xl),
                                    _DetailRow(icon: Icons.business, label: 'Provider', value: bill.billerName),
                                    const Divider(height: AppSpacing.xl),
                                    _DetailRow(icon: Icons.receipt_long, label: 'Bill Number', value: bill.billNumber),
                                    const Divider(height: AppSpacing.xl),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isOverdue ? AppColors.errorLight : AppColors.surfaceVariant,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.event, size: 20, color: isOverdue ? AppColors.error : AppColors.primaryBlue),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Due Date', style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                                              Text(
                                                bill.parsedDueDate != null ? DateFormat('dd MMM yyyy').format(bill.parsedDueDate!) : (bill.rawDueDate.isNotEmpty ? bill.rawDueDate : 'N/A'),
                                                style: AppTextTheme.textTheme.titleSmall?.copyWith(
                                                  color: isOverdue ? AppColors.error : AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isOverdue)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        
                        // Wallet Balance Card
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryBlueLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.account_balance_wallet, color: AppColors.primaryBlue, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Available Balance', style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
                                    Text(
                                      CurrencyFormatter.fromPaise(walletBalance),
                                      style: AppTextTheme.textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (walletBalance < bill.billAmountPaise)
                                const Icon(Icons.warning, color: AppColors.error, size: 20),
                            ],
                          ),
                        ),
                        if (walletBalance < bill.billAmountPaise)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
                            child: Text(
                              'Insufficient balance to pay this bill.',
                              style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Action
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: AppButton(
                    label: 'Pay ${CurrencyFormatter.fromPaise(bill.billAmountPaise)}',
                    isLoading: _isLoading,
                    onPressed: (walletBalance < bill.billAmountPaise) ? null : _showPinPrompt,
                  ),
                ),
              ],
            ),
            
            // Full screen loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: AppColors.background.withValues(alpha: 0.9),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryBlue),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Processing your payment...',
                        style: AppTextTheme.textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Please do not press back or close the app.',
                        style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryBlue),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
              Text(value, style: AppTextTheme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
