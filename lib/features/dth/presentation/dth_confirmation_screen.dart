import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/razorpay_web_helper.dart';
import '../../../core/services/razorpay_service.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../payment/providers/payment_session_provider.dart';
import '../../recharge/presentation/recharge_providers.dart';
import 'providers/dth_providers.dart';

enum PaymentMethod { wallet, upi }

class DthConfirmationScreen extends ConsumerStatefulWidget {
  const DthConfirmationScreen({super.key});

  @override
  ConsumerState<DthConfirmationScreen> createState() => _DthConfirmationScreenState();
}

class _DthConfirmationScreenState extends ConsumerState<DthConfirmationScreen> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isLoading = false;
  PaymentMethod? _selectedPaymentMethod;

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
      final state = ref.read(dthFlowProvider);
      final receipt = await ref.read(dthFlowProvider.notifier).processDthRecharge(mpin: pin, paymentMode: 'wallet');

      print('[DTH_STATUS_FLOW] orderId=${receipt.transactionId}');
      print('[DTH_STATUS_FLOW] paymentMethod=WALLET');
      print('[DTH_STATUS_FLOW] grossAmount=${state.customAmountPaise != null ? (state.customAmountPaise! / 100) : 0}');
      print('[DTH_STATUS_FLOW] rechargeInitiationStatus=${receipt.status.name}');
      print('[DTH_STATUS_FLOW] operatorRef=${receipt.operatorRef ?? "N/A"}');

      if (!mounted) return;

      context.pushReplacement(
        RouteNames.rechargeProcessing,
        extra: {
          'orderId': receipt.transactionId,
          'receipt': receipt,
          'paymentMode': 'wallet',
          'phoneNumber': state.subscriberId,
          'operatorId': state.selectedOperator?.id,
          'operatorCode': state.selectedOperator?.code,
          'operatorName': state.selectedOperator?.name,
          'amountPaise': state.customAmountPaise,
          'circle': 'DTH',
        },
      );
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

  Future<void> _processUpiPayment() async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final state = ref.read(dthFlowProvider);

      if (state.subscriberId == null || state.selectedOperator == null || state.customAmountPaise == null) {
        setState(() {
          _errorText = 'Incomplete DTH recharge details.';
          _isLoading = false;
        });
        return;
      }

      AppLogger.info('[Razorpay DTH] Creating Razorpay DTH recharge order...', tag: 'DthConfirmation');
      final repo = ref.read(rechargeRepositoryProvider);

      final orderRes = await repo.createRazorpayRechargeOrder(
        phoneNumber: state.subscriberId!,
        operatorId: state.selectedOperator!.id,
        operatorName: state.selectedOperator!.name,
        circleId: '4',
        serviceType: 'dth',
        amountPaise: state.customAmountPaise!,
        planId: state.selectedPack?.id,
        planName: state.selectedPack?.resolution,
        providerOperatorCode: state.selectedOperator!.planApiCode,
      );

      final orderData = orderRes.valueOrNull;
      if (orderData == null) {
        final err = orderRes.errorOrNull?.message ?? 'Failed to initialize DTH payment order.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
        return;
      }

      final internalTxId = orderData['internalTransactionId'] as String;
      final razorpayOrderId = orderData['razorpayOrderId'] as String;
      final razorpayKeyId = orderData['razorpayKeyId'] as String;
      final payablePaise = (orderData['payableAmountPaise'] as num).toInt();

      AppLogger.info(
        '[Razorpay DTH Order Created] Order ID: $razorpayOrderId, Internal Tx: $internalTxId, Payable: $payablePaise paise',
        tag: 'DthConfirmation',
      );

      ref.read(paymentSessionProvider.notifier).startSession(
            internalTransactionId: internalTxId,
            razorpayOrderId: razorpayOrderId,
            type: PaymentSessionType.recharge,
            extraData: {
              'phoneNumber': state.subscriberId,
              'operatorId': state.selectedOperator?.id,
              'operatorCode': state.selectedOperator?.planApiCode,
              'operatorName': state.selectedOperator?.name,
              'amountPaise': state.customAmountPaise,
              'circle': 'DTH',
            },
          );

      if (kIsWeb) {
        AppLogger.info('[Razorpay DTH] Opening Web Checkout JS', tag: 'DthConfirmation');
        openRazorpayWebCheckout(
          key: razorpayKeyId,
          amount: payablePaise,
          orderId: razorpayOrderId,
          contact: state.subscriberId!,
          email: 'retailer@a1recharge.com',
          onSuccess: (paymentId, rzpOrderId, signature) {
            ref.read(paymentSessionProvider.notifier).onRazorpaySuccess(
                  paymentId: paymentId,
                  orderId: rzpOrderId,
                  signature: signature,
                );
          },
          onError: (err) {
            ref.read(paymentSessionProvider.notifier).onRazorpayError(
                  code: -1,
                  message: err,
                );
          },
          onDismiss: () {
            ref.read(paymentSessionProvider.notifier).onRazorpayError(
                  code: 2,
                  message: 'Payment cancelled',
                );
          },
        );
      } else {
        AppLogger.info('[Razorpay DTH] Opening Native Mobile SDK via RazorpayService', tag: 'DthConfirmation');
        final options = {
          'key': razorpayKeyId,
          'amount': payablePaise,
          'name': 'A1 Recharge',
          'description': '${state.selectedOperator!.name} DTH (${state.subscriberId})',
          'order_id': razorpayOrderId,
          'prefill': {
            'contact': state.subscriberId ?? '',
            'email': 'retailer@a1recharge.com',
          },
          'theme': {
            'color': '#1565FF',
          }
        };

        ref.read(razorpayServiceProvider).openCheckout(options);
      }
    } catch (e) {
      AppLogger.error('[Razorpay DTH Exception] $e', tag: 'DthConfirmation');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[DTH_CONFIRMATION_ACTIVE_WIDGET] lib/features/dth/presentation/dth_confirmation_screen.dart -> DthConfirmationScreen');

    ref.listen<PaymentSessionState>(paymentSessionProvider, (previous, next) {
      if (next.type != PaymentSessionType.recharge) return;

      if (next.status == PaymentSessionStatus.verifying) {
        if (mounted) setState(() => _isLoading = true);
      } else if (next.status == PaymentSessionStatus.completed) {
        if (mounted) setState(() => _isLoading = false);
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(earningsSummaryProvider);

        final receipt = next.receipt;
        final extra = next.extraData ?? {};
        ref.read(paymentSessionProvider.notifier).clearSession();

        if (mounted && receipt != null) {
          context.pushReplacement(
            RouteNames.rechargeProcessing,
            extra: {
              'orderId': next.internalTransactionId,
              'receipt': receipt,
              'paymentMode': 'upi',
              'phoneNumber': extra['phoneNumber'],
              'operatorId': extra['operatorId'],
              'operatorCode': extra['operatorCode'],
              'operatorName': extra['operatorName'],
              'amountPaise': extra['amountPaise'],
              'circle': extra['circle'],
            },
          );
        }
      } else if (next.status == PaymentSessionStatus.failed) {
        if (mounted) setState(() => _isLoading = false);
        final err = next.errorMessage ?? 'Payment verification failed.';
        ref.read(paymentSessionProvider.notifier).clearSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.error),
          );
        }
      } else if (next.status == PaymentSessionStatus.cancelled) {
        if (mounted) setState(() => _isLoading = false);
        ref.read(paymentSessionProvider.notifier).clearSession();
      }
    });

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

    final rechargeAmountPaise = state.customAmountPaise!;
    final commissionAmountPaiseInt = commissionEarnedPaise.round();
    final walletDeductionPaise = rechargeAmountPaise - commissionAmountPaiseInt;

    int availableWalletPaise = 0;
    walletBalanceAsync.whenData((balance) {
      availableWalletPaise = balance.availablePaise;
    });

    final bool isWalletInsufficient = availableWalletPaise < walletDeductionPaise;
    final int shortfallPaise = walletDeductionPaise - availableWalletPaise;
    final int balanceAfterPaise = (availableWalletPaise - walletDeductionPaise).clamp(0, 999999999);

    final PaymentMethod activeMethod = _selectedPaymentMethod ?? (isWalletInsufficient ? PaymentMethod.upi : PaymentMethod.wallet);

    debugPrint('[DTH_PAYMENT_CALC] grossAmountPaise=$rechargeAmountPaise, commissionAmountPaise=$commissionAmountPaiseInt, netDebitPaise=$walletDeductionPaise, walletBalancePaise=$availableWalletPaise, upiPaymentAmountPaise=$walletDeductionPaise');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Confirm DTH Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.dthRecharge),
        ),
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
                        Text(CurrencyFormatter.fromPaise(rechargeAmountPaise), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        Text(state.selectedPack?.resolution ?? 'DTH Pack', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),

              // ── WALLET PAYMENT OPTION CARD ──
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
                          const Text('Wallet Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                        _PaymentBreakdownRow(label: 'Available Balance', amount: availableWalletPaise),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'Recharge Amount', amount: rechargeAmountPaise),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'Commission ($commissionDisplay)', amount: commissionAmountPaiseInt, isCredit: true),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'Wallet Debit', amount: walletDeductionPaise, isHighlight: true),
                        const SizedBox(height: 6),
                        _PaymentBreakdownRow(label: 'Balance After Recharge', amount: balanceAfterPaise),
                        const SizedBox(height: 12),
                        const Text('Commission is adjusted instantly.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── UPI PAYMENT OPTION CARD ──
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
                          const Text('UPI / Cards / NetBanking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (activeMethod == PaymentMethod.upi) ...[
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            _UpiAppIcon(name: 'Google Pay', color: Colors.blue),
                            _UpiAppIcon(name: 'PhonePe', color: Colors.purple),
                            _UpiAppIcon(name: 'Paytm', color: Colors.lightBlue),
                            _UpiAppIcon(name: 'BHIM', color: Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _PaymentBreakdownRow(label: 'Recharge Amount', amount: rechargeAmountPaise),
                        const SizedBox(height: 6),
                        if (commissionAmountPaiseInt > 0) ...[
                          _PaymentBreakdownRow(label: 'Commission', amount: commissionAmountPaiseInt, isCredit: true),
                          const SizedBox(height: 6),
                        ],
                        _PaymentBreakdownRow(label: 'Amount Payable', amount: walletDeductionPaise, isHighlight: true),
                        const SizedBox(height: 12),
                        Text(
                          'Secure payment powered by Razorpay. Payment of ${CurrencyFormatter.fromPaise(walletDeductionPaise)} will be requested.',
                          style: const TextStyle(color: AppColors.textHint, fontSize: 12, height: 1.3),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── ACTION SECTION / INSUFFICIENT WALLET / MPIN ENTRY ──
              if (activeMethod == PaymentMethod.wallet && isWalletInsufficient) ...[
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
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 24),
                          SizedBox(width: 8),
                          Text('Wallet balance is low', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 16)),
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
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await context.push(
                              RouteNames.walletTopup,
                              extra: {'suggestedAmountPaise': shortfallPaise},
                            );
                            if (mounted) {
                              ref.invalidate(walletBalanceProvider);
                              await ref.read(walletBalanceProvider.future);
                              setState(() {});
                            }
                          },
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
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => setState(() => _selectedPaymentMethod = PaymentMethod.upi),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF57C00),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Pay ${CurrencyFormatter.fromPaise(walletDeductionPaise)} via UPI', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (activeMethod == PaymentMethod.wallet) ...[
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Pay ${CurrencyFormatter.fromPaise(walletDeductionPaise)} via Wallet',
                        style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter 6-digit MPIN to authorize payment',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
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
              ] else if (activeMethod == PaymentMethod.upi) ...[
                const SizedBox(height: AppSpacing.md),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processUpiPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: Text(
                        'Pay ${CurrencyFormatter.fromPaise(walletDeductionPaise)} via UPI',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
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
  final bool isHighlight;

  const _PaymentBreakdownRow({
    required this.label,
    required this.amount,
    this.isCredit = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isHighlight ? 15 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        Text(
          '${isCredit ? "+" : ""}${CurrencyFormatter.fromPaise(amount)}',
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w800,
            fontSize: isHighlight ? 17 : 15,
            color: isCredit ? AppColors.success : (isHighlight ? AppColors.primaryBlue : AppColors.textPrimary),
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
          child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}
