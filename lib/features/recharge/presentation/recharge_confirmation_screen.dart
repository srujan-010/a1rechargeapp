import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../domain/models/operator.dart';
import 'recharge_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/razorpay_web_helper.dart';
import '../../../core/utils/logger.dart';

enum PaymentMethod { wallet, upi }
enum PaymentResultStatus { cancelled, failed, pending, unknown, success }

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

  late Razorpay _razorpay;
  String? _pendingInternalTransactionId;
  String? _pendingRazorpayOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccessNative);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentErrorNative);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletNative);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _pinController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccessNative(PaymentSuccessResponse response) {
    AppLogger.info(
      '[Razorpay Mobile Success] Payment ID: ${response.paymentId}, Order ID: ${response.orderId}',
      tag: 'RechargeConfirmation',
    );
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? _pendingRazorpayOrderId ?? '';
    final signature = response.signature ?? '';

    _executePaymentVerification(
      paymentId: paymentId,
      razorpayOrderId: orderId,
      signature: signature,
    );
  }

  void _handlePaymentErrorNative(PaymentFailureResponse response) {
    AppLogger.error(
      '[Razorpay Mobile Error] Code: ${response.code}, Message: ${response.message}',
      tag: 'RechargeConfirmation',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Code 2 is PAYMENT_CANCELLED in Razorpay SDK
    final isCancelled = response.code == 2 ||
        (response.message != null &&
            (response.message!.toLowerCase().contains('cancel') ||
                response.message!.toLowerCase().contains('dismiss')));

    if (isCancelled) {
      AppLogger.info('[Razorpay] User cancelled checkout', tag: 'RechargeConfirmation');
      _showPaymentStatusModal(
        status: PaymentResultStatus.cancelled,
        title: 'Payment Cancelled',
        message: 'No amount was charged.',
      );
    } else {
      AppLogger.error('[Razorpay] Payment failed: ${response.message}', tag: 'RechargeConfirmation');
      _showPaymentStatusModal(
        status: PaymentResultStatus.failed,
        title: 'Payment Failed',
        message: response.message ?? 'Your payment could not be completed.',
      );
    }
  }

  void _handleExternalWalletNative(ExternalWalletResponse response) {
    AppLogger.info('[Razorpay Mobile External Wallet] ${response.walletName}', tag: 'RechargeConfirmation');
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Redirected to external wallet: ${response.walletName}'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  Future<void> _executePaymentVerification({
    required String paymentId,
    required String razorpayOrderId,
    required String signature,
  }) async {
    final internalTxId = _pendingInternalTransactionId;
    if (internalTxId == null || internalTxId.isEmpty) {
      AppLogger.error('[Razorpay Verify] Internal transaction ID missing', tag: 'RechargeConfirmation');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      AppLogger.info('[Razorpay] Sending verification request to backend...', tag: 'RechargeConfirmation');
      final repo = ref.read(rechargeRepositoryProvider);
      final verifyResult = await repo.verifyRazorpayRechargePayment(
        internalTransactionId: internalTxId,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      if (!mounted) return;
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(earningsSummaryProvider);

      final state = ref.read(rechargeFlowProvider);
      final receipt = verifyResult.valueOrNull;

      if (receipt != null) {
        AppLogger.info('[Razorpay] Backend verification: VERIFIED / SUCCESS', tag: 'RechargeConfirmation');
        context.push(
          RouteNames.rechargeProcessing,
          extra: {
            'orderId': internalTxId,
            'receipt': receipt,
            'paymentMode': 'upi',
            'phoneNumber': state.phoneNumber,
            'operatorId': state.operator?.id,
            'operatorCode': state.operator?.shortCode,
            'operatorName': state.operator?.name,
            'amountPaise': state.customAmountPaise,
            'circle': state.circle?.state,
          },
        );
      } else {
        final err = verifyResult.errorOrNull?.message ?? 'Verification failed';
        AppLogger.error('[Razorpay] Backend verification error: $err', tag: 'RechargeConfirmation');
        _showPaymentStatusModal(
          status: PaymentResultStatus.failed,
          title: 'Payment Verification Failed',
          message: err,
        );
      }
    } catch (e) {
      AppLogger.error('[Razorpay Verification Exception] $e', tag: 'RechargeConfirmation');
      if (!mounted) return;
      _showPaymentStatusModal(
        status: PaymentResultStatus.pending,
        title: 'Payment Verification Pending',
        message: 'We are confirming your payment with Razorpay. Please don\'t pay again.',
        orderId: internalTxId,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPaymentStatusModal({
    required PaymentResultStatus status,
    required String title,
    required String message,
    String? orderId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final IconData iconData = switch (status) {
          PaymentResultStatus.cancelled => Icons.cancel_outlined,
          PaymentResultStatus.failed => Icons.error_outline,
          PaymentResultStatus.pending || PaymentResultStatus.unknown => Icons.hourglass_top,
          PaymentResultStatus.success => Icons.check_circle_outline,
        };

        final Color iconColor = switch (status) {
          PaymentResultStatus.cancelled => Colors.orange,
          PaymentResultStatus.failed => AppColors.error,
          PaymentResultStatus.pending || PaymentResultStatus.unknown => Colors.blue,
          PaymentResultStatus.success => AppColors.success,
        };

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 48, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (status == PaymentResultStatus.pending && orderId != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(
                      RouteNames.rechargeProcessing,
                      extra: {
                        'orderId': orderId,
                        'paymentMode': 'upi',
                      },
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Status'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  void _processRecharge(String pin) {
    final state = ref.read(rechargeFlowProvider);
    final isDth = state.operator?.type == OperatorType.dth;

    if (state.phoneNumber == null || state.operator == null || (!isDth && state.circle == null) || state.customAmountPaise == null) {
      setState(() => _errorText = 'Incomplete recharge details.');
      return;
    }

    AppLogger.info(
      '[Payment Screen] Operator passed to request: ${state.operator!.name} (ID: ${state.operator!.id}, Code: ${state.operator!.shortCode}), Number: ${state.phoneNumber}, Amount: ${state.customAmountPaise}',
      tag: 'RechargeConfirmation',
    );

    context.push(
      RouteNames.rechargeProcessing,
      extra: {
        'mpin': pin,
        'paymentMode': 'wallet',
        'phoneNumber': state.phoneNumber,
        'operatorId': state.operator!.id,
        'operatorCode': state.operator!.shortCode,
        'operatorName': state.operator!.name,
        'amountPaise': state.customAmountPaise,
        'circle': state.circle?.state,
      },
    );
  }

  Future<void> _processUpiPayment() async {
    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      final state = ref.read(rechargeFlowProvider);
      final isDth = state.operator?.type == OperatorType.dth;

      if (state.phoneNumber == null || state.operator == null || (!isDth && state.circle == null) || state.customAmountPaise == null) {
        setState(() {
          _errorText = 'Incomplete recharge details.';
          _isLoading = false;
        });
        return;
      }

      AppLogger.info('[Razorpay] Creating order...', tag: 'RechargeConfirmation');
      final repo = ref.read(rechargeRepositoryProvider);
      final serviceType = switch (state.operator!.type) {
        OperatorType.prepaid => 'mobile',
        OperatorType.dth => 'dth',
        OperatorType.postpaid => 'bbps',
      };

      // Step 1: Create Razorpay Order server-side for payable amount
      final orderRes = await repo.createRazorpayRechargeOrder(
        phoneNumber: state.phoneNumber!,
        operatorId: state.operator!.id,
        operatorName: state.operator!.name,
        circleId: state.circle?.id ?? '',
        serviceType: serviceType,
        amountPaise: state.customAmountPaise!,
        planId: state.selectedPlan?.id,
        planName: state.selectedPlan?.desc,
        planType: state.selectedPlanType,
        selectedCategory: state.selectedPlanCategory,
        providerOperatorCode: state.providerOperatorCode,
      );

      final orderData = orderRes.valueOrNull;
      if (orderData == null) {
        final err = orderRes.errorOrNull?.message ?? 'Failed to initialize payment order.';
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

      _pendingInternalTransactionId = internalTxId;
      _pendingRazorpayOrderId = razorpayOrderId;

      AppLogger.info(
        '[Razorpay Order Created] Order ID: $razorpayOrderId, Internal Tx: $internalTxId, Payable: $payablePaise paise',
        tag: 'RechargeConfirmation',
      );

      // Step 2: Open Razorpay Checkout modal (Platform specific)
      if (kIsWeb) {
        AppLogger.info('[Razorpay] Opening Web Checkout JS', tag: 'RechargeConfirmation');
        openRazorpayWebCheckout(
          key: razorpayKeyId,
          amount: payablePaise,
          orderId: razorpayOrderId,
          contact: state.phoneNumber!,
          email: 'retailer@a1recharge.com',
          onSuccess: (paymentId, rzpOrderId, signature) {
            _executePaymentVerification(
              paymentId: paymentId,
              razorpayOrderId: rzpOrderId,
              signature: signature,
            );
          },
          onError: (err) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            final isCancelled = err.toLowerCase().contains('cancel') || err.toLowerCase().contains('dismiss');
            if (isCancelled) {
              _showPaymentStatusModal(
                status: PaymentResultStatus.cancelled,
                title: 'Payment Cancelled',
                message: 'No amount was charged.',
              );
            } else {
              _showPaymentStatusModal(
                status: PaymentResultStatus.failed,
                title: 'Payment Failed',
                message: err.isNotEmpty ? err : 'Your payment could not be completed.',
              );
            }
          },
          onDismiss: () {
            if (!mounted) return;
            setState(() => _isLoading = false);
            _showPaymentStatusModal(
              status: PaymentResultStatus.cancelled,
              title: 'Payment Cancelled',
              message: 'No amount was charged.',
            );
          },
        );
      } else {
        AppLogger.info('[Razorpay] Opening Native Mobile SDK', tag: 'RechargeConfirmation');
        final options = {
          'key': razorpayKeyId,
          'amount': payablePaise,
          'name': 'A1 Recharge',
          'description': '${state.operator!.name} Recharge (${state.phoneNumber})',
          'order_id': razorpayOrderId,
          'prefill': {
            'contact': state.phoneNumber ?? '',
            'email': 'retailer@a1recharge.com',
          },
          'theme': {
            'color': '#1565FF',
          }
        };

        _razorpay.open(options);
      }
    } catch (e) {
      AppLogger.error('[Razorpay Order Creation Exception] $e', tag: 'RechargeConfirmation');
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

    final isDth = state.operator?.type == OperatorType.dth;

    debugPrint('--- RECHARGE PAYMENT VALIDATION ---');
    debugPrint('Service Type: ${state.operator?.type.name}');
    debugPrint('Operator: ${state.operator?.name} (id: ${state.operator?.id})');
    debugPrint('Operator Code: ${state.operator?.shortCode}');
    debugPrint('Subscriber Number: ${state.phoneNumber}');
    debugPrint('Amount: ${state.customAmountPaise} paise');
    debugPrint('Circle: ${state.circle?.state} (id: ${state.circle?.id})');
    debugPrint('Selected Pack: ${state.selectedPlan?.id}');
    debugPrint('operator != null: ${state.operator != null}');
    debugPrint('number != null: ${state.phoneNumber != null}');
    debugPrint('amount > 0: ${state.customAmountPaise != null && state.customAmountPaise! > 0}');
    debugPrint('circle != null: ${state.circle != null} (Required for Mobile, Optional for DTH)');

    if (state.phoneNumber == null || state.operator == null || state.customAmountPaise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Recharge')),
        body: const Center(child: Text('Invalid recharge state.')),
      );
    }

    final subtitleText = isDth 
        ? state.operator!.name 
        : (state.circle != null ? '${state.operator!.name} • ${state.circle!.state}' : state.operator!.name);

    final serviceType = switch (state.operator?.type ?? OperatorType.prepaid) {
      OperatorType.prepaid => 'mobile',
      OperatorType.dth => 'dth',
      OperatorType.postpaid => 'bbps',
    };

    final payableAsync = ref.watch(rechargePayableProvider((
      phoneNumber: state.phoneNumber ?? '',
      operatorId: state.operator?.id ?? '',
      operatorName: state.operator?.name ?? '',
      circleId: state.circle?.id ?? '',
      serviceType: serviceType,
      amountPaise: state.customAmountPaise ?? 0,
      planType: state.selectedPlanType,
    )));

    int rechargeAmountPaise = state.customAmountPaise ?? 0;
    int commissionAmountPaise = 0;
    int payableAmountPaise = rechargeAmountPaise;

    payableAsync.whenData((data) {
      if (data.isNotEmpty) {
        rechargeAmountPaise = (data['rechargeAmountPaise'] as num?)?.toInt() ?? rechargeAmountPaise;
        commissionAmountPaise = (data['commissionAmountPaise'] as num?)?.toInt() ?? 0;
        payableAmountPaise = (data['payableAmountPaise'] as num?)?.toInt() ?? (rechargeAmountPaise - commissionAmountPaise);
      }
    });

    final slabsAsync = ref.watch(activeCommissionSlabsProvider);
    if (commissionAmountPaise == 0) {
      slabsAsync.whenData((slabs) {
        final searchWord = state.operator!.name.toLowerCase().split(' ')[0];
        final slab = slabs.where((s) {
          final opName = s.operatorName.toLowerCase();
          return opName == state.operator!.name.toLowerCase() ||
                 opName == searchWord ||
                 opName.contains(searchWord) ||
                 searchWord.contains(opName);
        }).firstOrNull;
        if (slab != null) {
          if (slab.commissionType == 'percentage') {
            commissionAmountPaise = (rechargeAmountPaise * slab.commissionValue / 100).round();
          } else {
            commissionAmountPaise = (slab.commissionValue * 100).round();
          }
          payableAmountPaise = rechargeAmountPaise - commissionAmountPaise;
        }
      });
    }

    int availableWalletPaise = 0;
    walletBalanceAsync.whenData((balance) {
      availableWalletPaise = balance.availablePaise;
    });

    final bool isWalletInsufficient = availableWalletPaise < payableAmountPaise;
    final int shortfallPaise = payableAmountPaise - availableWalletPaise;

    final userSession = ref.watch(sessionProvider).valueOrNull;
    final isPersonal = userSession?.isPersonal ?? false;

    // For personal accounts, payment is ALWAYS via UPI/Razorpay direct gateway (wallet is not used)
    final PaymentMethod activeMethod = isPersonal 
      ? PaymentMethod.upi 
      : (_selectedPaymentMethod ?? (isWalletInsufficient ? PaymentMethod.upi : PaymentMethod.wallet));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.mobileRecharge),
        ),
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
                          Text(subtitleText, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

              // ── RETAILER ONLY: WALLET OPTION ──
              if (!isPersonal) ...[
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
                          _PaymentBreakdownRow(label: 'Recharge Amount', amount: rechargeAmountPaise),
                          const SizedBox(height: 6),
                          _PaymentBreakdownRow(label: 'Commission', amount: commissionAmountPaise, isDeduction: true),
                          const SizedBox(height: 6),
                          _PaymentBreakdownRow(label: 'You Pay', amount: payableAmountPaise, isHighlight: true),
                          const SizedBox(height: 12),
                          const Text('Commission is adjusted instantly.', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── UPI OPTION ──
              GestureDetector(
                onTap: isPersonal ? null : () => setState(() => _selectedPaymentMethod = PaymentMethod.upi),
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
                          if (!isPersonal)
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
                        if (!isPersonal && commissionAmountPaise > 0) ...[
                          _PaymentBreakdownRow(label: 'Commission', amount: commissionAmountPaise, isDeduction: true),
                          const SizedBox(height: 6),
                        ],
                        _PaymentBreakdownRow(label: 'Amount Payable', amount: payableAmountPaise, isHighlight: true),
                        const SizedBox(height: 12),
                        Text(
                          'Secure payment powered by Razorpay. Payment of ${CurrencyFormatter.fromPaise(payableAmountPaise)} will be requested.',
                          style: const TextStyle(color: AppColors.textHint, fontSize: 12, height: 1.3),
                        ),
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
                          Text(CurrencyFormatter.fromPaise(payableAmountPaise), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      onPressed: _processUpiPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: Text(
                        isPersonal 
                          ? 'Pay ${CurrencyFormatter.fromPaise(payableAmountPaise)} with Razorpay / UPI'
                          : 'Continue to UPI',
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
  final bool isDeduction;
  final bool isHighlight;

  const _PaymentBreakdownRow({
    required this.label,
    required this.amount,
    this.isCredit = false,
    this.isDeduction = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    String prefix = '';
    if (isCredit) prefix = '+';
    if (isDeduction && amount > 0) prefix = '-';

    Color textColor = AppColors.textPrimary;
    if (isCredit) textColor = AppColors.success;
    if (isDeduction) textColor = AppColors.success;
    if (isHighlight) textColor = AppColors.primaryBlue;

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
          '$prefix${CurrencyFormatter.fromPaise(amount)}',
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w800,
            fontSize: isHighlight ? 17 : 15,
            color: textColor,
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
