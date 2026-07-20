import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import 'recharge_providers.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/upi_handler.dart';

enum PaymentMethod { wallet, upi }

class RechargeConfirmationScreen extends ConsumerStatefulWidget {
  const RechargeConfirmationScreen({super.key});

  @override
  ConsumerState<RechargeConfirmationScreen> createState() => _RechargeConfirmationScreenState();
}

class _RechargeConfirmationScreenState extends ConsumerState<RechargeConfirmationScreen> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;
  PaymentMethod? _selectedPaymentMethod; // Null = auto-select based on balance

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _processRecharge(String pin) async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final receipt = await ref.read(rechargeFlowProvider.notifier).processRecharge(mpin: pin, paymentMode: 'wallet');
      if (!mounted) return;
      
      // Navigate to home, then push receipt
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

  Future<void> _processUpiPayment(double amount) async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final isSuccess = await UpiHandler.startUpiPayment(
        amount: amount,
        upiId: '9100329521@ptyes',
        name: 'A1 Recharge',
        transactionNote: 'Mobile Recharge',
      );

      if (!isSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Failed or Cancelled.'), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
        return;
      }

      // If successful, proceed to recharge without mpin
      final receipt = await ref.read(rechargeFlowProvider.notifier).processRecharge(paymentMode: 'upi');
      if (!mounted) return;
      
      context.go(RouteNames.dashboard);
      context.push(RouteNames.rechargeReceipt.replaceFirst(':txnId', receipt.transactionId), extra: receipt);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rechargeFlowProvider);
    final walletBalanceAsync = ref.watch(walletBalanceProvider);

    if (state.phoneNumber == null || state.operator == null || state.customAmountPaise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Recharge')),
        body: const Center(child: Text('Invalid recharge state.')),
      );
    }

    final slabsAsync = ref.watch(activeCommissionSlabsProvider);
    double commissionEarnedPaise = 0;
    String commissionDisplay = '0.00%';

    slabsAsync.whenData((slabs) {
      final slab = slabs.where((s) => s.operatorName.toLowerCase() == state.operator!.name.toLowerCase()).firstOrNull;
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

    // Auto-select payment method if not explicitly chosen
    final PaymentMethod activeMethod = _selectedPaymentMethod ?? (isWalletInsufficient ? PaymentMethod.upi : PaymentMethod.wallet);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      child: const Icon(Icons.cell_tower, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.phoneNumber!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${state.operator!.name} • ${state.circle ?? "Unknown"}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyFormatter.fromPaise(state.customAmountPaise!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        Text(state.selectedPlan?.validity ?? 'Valid', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),

              // ── WALLET OPTION ──
              GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.wallet),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: activeMethod == PaymentMethod.wallet ? AppColors.primaryBlueLight.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activeMethod == PaymentMethod.wallet ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5),
                      width: activeMethod == PaymentMethod.wallet ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Radio<PaymentMethod>(
                            value: PaymentMethod.wallet,
                            groupValue: activeMethod,
                            activeColor: AppColors.primaryBlue,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),
                          const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryBlue, size: 24),
                          const SizedBox(width: 8),
                          const Text('Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          walletBalanceAsync.when(
                            data: (b) => Text('Bal: ${CurrencyFormatter.fromPaiseNoDecimal(b.availablePaise)}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                            loading: () => const SizedBox(width: 40, height: 10, child: LinearProgressIndicator(minHeight: 2)),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      if (activeMethod == PaymentMethod.wallet) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        _PaymentBreakdownRow(label: 'You Pay', amount: walletDeductionPaise),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'You Earn ($commissionDisplay)', amount: commissionEarnedPaise.toInt(), isCredit: true),
                        const SizedBox(height: 12),
                        const Text('Commission is adjusted instantly.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── UPI OPTION ──
              GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = PaymentMethod.upi),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: activeMethod == PaymentMethod.upi ? AppColors.primaryBlueLight.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: activeMethod == PaymentMethod.upi ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5),
                      width: activeMethod == PaymentMethod.upi ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Radio<PaymentMethod>(
                            value: PaymentMethod.upi,
                            groupValue: activeMethod,
                            activeColor: AppColors.primaryBlue,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),
                          const Icon(Icons.qr_code_scanner, color: AppColors.primaryBlue, size: 24),
                          const SizedBox(width: 8),
                          const Text('UPI Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (activeMethod == PaymentMethod.upi) ...[
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _UpiAppIcon(name: 'Google Pay', color: Colors.blue),
                            _UpiAppIcon(name: 'PhonePe', color: Colors.purple),
                            _UpiAppIcon(name: 'Paytm', color: Colors.lightBlue),
                            _UpiAppIcon(name: 'BHIM', color: Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _PaymentBreakdownRow(label: 'You Pay', amount: state.customAmountPaise!),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'You Earn ($commissionDisplay)', amount: commissionEarnedPaise.toInt(), isCredit: true),
                        const SizedBox(height: 12),
                        const Text('Commission will be credited to your wallet immediately after a successful recharge.', style: TextStyle(color: AppColors.textHint, fontSize: 12, height: 1.3)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── ACTION SECTION / INSUFFICIENT WALLET ──
              if (activeMethod == PaymentMethod.wallet && isWalletInsufficient) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1), // Light amber
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFE082)), // Amber border
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
                          const Text('Required', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          Text(CurrencyFormatter.fromPaise(walletDeductionPaise), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Color(0xFFFFE082)),
                      ),
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
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: TextButton(
                          onPressed: () => setState(() => _selectedPaymentMethod = PaymentMethod.upi),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF57C00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Continue with UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (activeMethod == PaymentMethod.wallet) ...[
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
                    onCompleted: _processRecharge,
                  ),
              ] else if (activeMethod == PaymentMethod.upi) ...[
                const SizedBox(height: AppSpacing.md),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _processUpiPayment(state.customAmountPaise! / 100.0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text('Continue to UPI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
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

class _UpiAppIcon extends StatelessWidget {
  final String name;
  final Color color;

  const _UpiAppIcon({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 24), // Placeholder icon
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}
