import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import 'providers/dth_providers.dart';

class DthConfirmationScreen extends ConsumerStatefulWidget {
  const DthConfirmationScreen({super.key});

  @override
  ConsumerState<DthConfirmationScreen> createState() => _DthConfirmationScreenState();
}

class _DthConfirmationScreenState extends ConsumerState<DthConfirmationScreen> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _processDthRecharge(String pin) async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final receipt = await ref.read(dthFlowProvider.notifier).processDthRecharge(mpin: pin, paymentMode: 'wallet');
      if (!mounted) return;
      
      context.go(RouteNames.dashboard);
      context.push(RouteNames.dthReceipt.replaceFirst(':txnId', receipt.transactionId), extra: receipt);
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is AppException) {
          errorMsg = e.message;
        }

        if (errorMsg.toLowerCase().contains('insufficient balance') ||
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
    final state = ref.watch(dthFlowProvider);
    final walletBalanceAsync = ref.watch(walletBalanceProvider);

    if (state.subscriberId == null || state.selectedOperator == null || state.customAmountPaise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm DTH Recharge')),
        body: const Center(child: Text('Invalid DTH recharge details.')),
      );
    }

    final slabsAsync = ref.watch(activeCommissionSlabsProvider);
    double commissionEarnedPaise = 0;
    String commissionDisplay = '0.00%';

    slabsAsync.whenData((slabs) {
      final slab = slabs.where((s) => s.operatorName.toLowerCase() == state.selectedOperator!.name.toLowerCase()).firstOrNull;
      if (slab != null) {
        if (slab.commissionType == 'percentage') {
          commissionEarnedPaise = (state.customAmountPaise! * slab.commissionValue / 100);
          commissionDisplay = '${slab.commissionValue.toStringAsFixed(2)}%';
        } else {
          commissionEarnedPaise = slab.commissionValue * 100;
          commissionDisplay = '₹${slab.commissionValue.toStringAsFixed(2)} Flat';
        }
      }
    });

    final walletDeductionPaise = state.customAmountPaise! - commissionEarnedPaise.toInt();
    
    int availableWalletPaise = 0;
    walletBalanceAsync.whenData((balance) {
      availableWalletPaise = balance.availablePaise;
    });

    final bool isWalletInsufficient = availableWalletPaise < walletDeductionPaise;
    final int shortfallPaise = walletDeductionPaise - availableWalletPaise;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Confirm DTH Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── COMPACT SUMMARY HEADER ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.satellite_alt, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${state.subscriberId!}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(state.selectedOperator!.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyFormatter.fromPaise(state.customAmountPaise!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        Text(state.selectedPack?.resolution ?? 'DTH Pack', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── WALLET BREAKDOWN ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 8),
                        const Text('Wallet Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        walletBalanceAsync.when(
                          data: (b) => Text('Bal: ${CurrencyFormatter.fromPaiseNoDecimal(b.availablePaise)}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                          loading: () => const SizedBox(width: 40, height: 10, child: LinearProgressIndicator(minHeight: 2)),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    _PaymentBreakdownRow(label: 'Recharge Amount', amount: state.customAmountPaise!),
                    const SizedBox(height: 6),
                    _PaymentBreakdownRow(label: 'You Earn ($commissionDisplay)', amount: commissionEarnedPaise.toInt(), isCredit: true),
                    const SizedBox(height: 12),
                    const Text('Commission is adjusted instantly.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── INSUFFICIENT BALANCE WARNING OR MPIN ENTRY ──
              if (isWalletInsufficient) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 24),
                          const SizedBox(width: 8),
                          const Text('Wallet balance is low', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          Text(CurrencyFormatter.fromPaise(availableWalletPaise), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Short by', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                          Text(CurrencyFormatter.fromPaise(shortfallPaise), style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push(RouteNames.walletTopup),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF57C00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Add ${CurrencyFormatter.fromPaise(shortfallPaise)} to Wallet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: Text(
                    'Enter 6-digit MPIN to pay via Wallet',
                    style: AppTextTheme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  PinEntryWidget(
                    controller: _pinController,
                    errorText: _errorText,
                    onCompleted: _processDthRecharge,
                  ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentBreakdownRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isCredit;

  const _PaymentBreakdownRow({required this.label, required this.amount, this.isCredit = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(
          '${isCredit ? "+" : ""}${CurrencyFormatter.fromPaise(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isCredit ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
