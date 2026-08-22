import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/razorpay_web_helper.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class WalletTopupScreen extends ConsumerStatefulWidget {
  const WalletTopupScreen({super.key});

  @override
  ConsumerState<WalletTopupScreen> createState() => _WalletTopupScreenState();
}

class _WalletTopupScreenState extends ConsumerState<WalletTopupScreen> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _focusNode = FocusNode();
  
  int _amount = 0;
  bool _isLoading = false;
  String? _statusMessage;

  late Razorpay _razorpay;
  String? _pendingInternalTransactionId;
  String? _pendingRazorpayOrderId;
  Timer? _openingTimeoutTimer;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    // Register Razorpay event listeners for native mobile
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccessNative);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentErrorNative);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletNative);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelOpeningTimeout();
    _razorpay.clear();
    _amountController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startOpeningTimeout() {
    _cancelOpeningTimeout();
    _openingTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isLoading && mounted) {
        print('[RAZORPAY] Checkout open timeout');
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Unable to open payment gateway', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            content: const Text(
              'Unable to open Razorpay Checkout. Please check your internet connection and try again.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(RouteNames.wallet);
                },
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _onProceed();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565FF)),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    });
  }

  void _cancelOpeningTimeout() {
    _openingTimeoutTimer?.cancel();
    _openingTimeoutTimer = null;
  }

  void _onAmountChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^\d]'), '');
    final num = int.tryParse(clean) ?? 0;
    
    if (num > 100000) {
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _amount = num;
      if (num > 0) {
        final formatted = NumberFormat('#,##,###').format(num);
        if (_amountController.text != formatted) {
          _amountController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      } else {
        _amountController.text = '';
      }
    });
  }

  void _addQuickAmount(int amountToAdd) {
    final newAmount = _amount + amountToAdd;
    
    if (newAmount > 100000) {
      _shakeController.forward(from: 0);
      return;
    }
    
    _onAmountChanged(newAmount.toString());
  }

  Future<void> _onProceed() async {
    if (_amount < 1 || _amount > 100000) return;

    print('[RAZORPAY] Add Money clicked');
    print('[RAZORPAY] Amount: $_amount');

    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating order...';
    });

    try {
      print('[RAZORPAY] Creating order...');
      final apiClient = ref.read(apiClientProvider);
      final amountPaise = _amount * 100;

      // 1. Create Backend Razorpay Order
      final orderResponse = await apiClient.post<Map<String, dynamic>>(
        '/wallet/create-order',
        data: {'amountPaise': amountPaise},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      print('[RAZORPAY] Create order response received');

      if (!orderResponse.success || orderResponse.data == null) {
        throw Exception(orderResponse.message.isNotEmpty ? orderResponse.message : 'Failed to create payment order');
      }

      final data = orderResponse.data!;
      final internalTransactionId = data['internalTransactionId'] as String?;
      final razorpayOrderId = data['razorpayOrderId'] as String?;
      final razorpayKeyId = data['razorpayKeyId'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (razorpayOrderId == null || razorpayOrderId.isEmpty || razorpayKeyId == null || razorpayKeyId.isEmpty) {
        throw Exception('Invalid order response from backend (missing Order ID or Key ID)');
      }

      _pendingInternalTransactionId = internalTransactionId;
      _pendingRazorpayOrderId = razorpayOrderId;

      print('[RAZORPAY] Create order success');
      print('[RAZORPAY] Order ID present: YES');
      print('[RAZORPAY] Amount present: YES');
      print('[RAZORPAY] Key ID present: YES');
      print('[RAZORPAY] Razorpay Order ID: $razorpayOrderId');
      print('[RAZORPAY] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      print('[RAZORPAY] Preparing Checkout');
      print('[RAZORPAY] Opening Checkout');

      setState(() {
        _statusMessage = 'Opening Razorpay Checkout...';
      });

      _startOpeningTimeout();

      // 2. Platform-specific Checkout Opening
      if (kIsWeb) {
        // Flutter Web: Open Razorpay Web Checkout JS via conditional helper
        openRazorpayWebCheckout(
          key: razorpayKeyId,
          amount: amountPaise,
          orderId: razorpayOrderId,
          contact: userData?['phone'] ?? '',
          email: userData?['email'] ?? '',
          onSuccess: (paymentId, orderId, signature) {
            _cancelOpeningTimeout();
            _executePaymentVerification(
              paymentId: paymentId,
              orderId: orderId,
              signature: signature,
            );
          },
          onError: (errorPayload) {
            _cancelOpeningTimeout();
            _handleStructuredPaymentError(errorPayload);
          },
          onDismiss: () {
            _cancelOpeningTimeout();
            print('[RAZORPAY] Checkout dismissed by user');
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment cancelled'),
                  backgroundColor: Color(0xFF64748B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
        print('[RAZORPAY] Checkout open call completed');
      } else {
        // Native Mobile: Open Razorpay Native SDK
        final options = {
          'key': razorpayKeyId,
          'amount': amountPaise,
          'name': 'A1 Recharge',
          'description': 'Wallet Top-up (₹${_amount.toString()})',
          'order_id': razorpayOrderId,
          'prefill': {
            'contact': userData?['phone'] ?? '',
            'email': userData?['email'] ?? '',
          },
          'theme': {
            'color': '#1565FF',
          }
        };

        _razorpay.open(options);
        print('[RAZORPAY] Checkout open call completed');
      }
    } catch (e) {
      _cancelOpeningTimeout();
      if (!mounted) return;
      setState(() => _isLoading = false);

      print('[RAZORPAY] Create Order Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start payment: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePaymentSuccessNative(PaymentSuccessResponse response) {
    _cancelOpeningTimeout();
    print('[RAZORPAY] Checkout success callback');
    print('[RAZORPAY] Payment ID: ${response.paymentId}');
    print('[RAZORPAY] Order ID: ${response.orderId}');
    print('[RAZORPAY] Signature Received: ${response.signature != null ? "YES" : "NO"}');

    _executePaymentVerification(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? _pendingRazorpayOrderId ?? '',
      signature: response.signature ?? '',
    );
  }

  void _handlePaymentErrorNative(PaymentFailureResponse response) {
    _cancelOpeningTimeout();
    final errorPayload = jsonEncode({
      'code': response.code?.toString() ?? 'PAYMENT_ERROR',
      'description': response.message ?? 'Payment cancelled or failed',
      'source': 'gateway',
      'step': 'checkout',
      'reason': 'payment_failed',
      'order_id': _pendingRazorpayOrderId ?? '',
      'payment_id': '',
    });
    _handleStructuredPaymentError(errorPayload);
  }

  void _handleExternalWalletNative(ExternalWalletResponse response) {
    print('[RAZORPAY] External Wallet Selected: ${response.walletName}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected wallet: ${response.walletName}'),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleStructuredPaymentError(String errorPayloadStr) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    String code = 'PAYMENT_FAILED';
    String description = 'Payment could not be completed.';
    String source = 'gateway';
    String step = 'checkout';
    String reason = 'payment_failed';
    String orderId = _pendingRazorpayOrderId ?? '';
    String paymentId = '';

    try {
      final decoded = jsonDecode(errorPayloadStr);
      if (decoded is Map<String, dynamic>) {
        code = decoded['code']?.toString() ?? code;
        description = decoded['description']?.toString() ?? description;
        source = decoded['source']?.toString() ?? source;
        step = decoded['step']?.toString() ?? step;
        reason = decoded['reason']?.toString() ?? reason;
        orderId = decoded['order_id']?.toString() ?? orderId;
        paymentId = decoded['payment_id']?.toString() ?? paymentId;
      }
    } catch (_) {
      description = errorPayloadStr;
    }

    print('[RAZORPAY] PAYMENT FAILURE');
    print('[RAZORPAY] code: $code');
    print('[RAZORPAY] description: $description');
    print('[RAZORPAY] source: $source');
    print('[RAZORPAY] step: $step');
    print('[RAZORPAY] reason: $reason');
    print('[RAZORPAY] order_id: $orderId');
    print('[RAZORPAY] payment_id: $paymentId');

    // Asynchronously report failure to backend database
    try {
      final apiClient = ref.read(apiClientProvider);
      apiClient.post('/wallet/payment-failed', data: {
        'internalTransactionId': _pendingInternalTransactionId,
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'failureCode': code,
        'failureDescription': description,
        'failureSource': source,
        'failureStep': step,
        'failureReason': reason,
      });
    } catch (_) {}

    final userMessage = _mapRazorpayErrorToUserMessage(code, description, reason);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Payment Failed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF1E293B))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${_amount.toString()}.00', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            const Text('Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(
              userMessage,
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(RouteNames.wallet);
            },
            child: const Text('Back to Wallet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onProceed();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565FF)),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _mapRazorpayErrorToUserMessage(String code, String description, String reason) {
    if (reason == 'payment_cancelled' || code == 'PAYMENT_CANCELLED') {
      return 'Payment was cancelled.';
    }
    if (code == 'BAD_REQUEST_ERROR') {
      return 'We could not process this payment request. Please try again.';
    }
    if (reason == 'payment_authentication' || code == 'PAYMENT_AUTHENTICATION_FAILED') {
      return 'Payment authentication failed. Please try again.';
    }
    if (description.toLowerCase().contains('network') || description.toLowerCase().contains('internet')) {
      return 'Please check your internet connection and try again.';
    }
    if (description.isNotEmpty &&
        !description.contains('Exception') &&
        !description.contains('Error:') &&
        !description.contains('NoSuchMethod') &&
        !description.contains('Dio') &&
        !description.contains('http') &&
        !description.contains('{') &&
        !description.contains('JSON')) {
      return description;
    }
    return 'Your payment could not be completed. Please try again.';
  }

  Future<void> _executePaymentVerification({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid payment signature received from Razorpay.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Verifying payment with backend...';
    });

    try {
      print('[RAZORPAY] Sending Verification');
      final apiClient = ref.read(apiClientProvider);

      final verifyResponse = await apiClient.post<Map<String, dynamic>>(
        '/wallet/verify-payment',
        data: {
          'internalTransactionId': _pendingInternalTransactionId,
          'razorpayOrderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': signature,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (!mounted) return;

      final isWalletCredited = verifyResponse.data?['walletCredited'] == true || verifyResponse.success;
      final paymentStatus = verifyResponse.data?['paymentStatus'] ?? (verifyResponse.success ? 'SUCCESS' : 'FAILED');

      if (isWalletCredited && paymentStatus == 'SUCCESS') {
        print('[RAZORPAY] Backend Verification: SUCCESS');
        print('[WALLET] Credit Authorized');
        print('[WALLET] Credit Completed');

        final newBalRupees = verifyResponse.data?['data']?['newBalanceRupees'] ?? verifyResponse.data?['newBalanceRupees'];

        ref.invalidate(walletBalanceProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(earningsSummaryProvider);

        context.go(RouteNames.wallet);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet credited with ₹${_amount.toString()}! New balance: ₹${newBalRupees ?? ""}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        print('[RAZORPAY] Backend Verification FAILED');
        throw Exception(verifyResponse.message.isNotEmpty ? verifyResponse.message : 'Payment verification failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      print('[RAZORPAY] Verification Error: $e');
      final errText = e.toString();
      if (errText.contains('timeout') || errText.contains('SocketException') || errText.contains('NetworkException')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.hourglass_top, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Text('Verification In Progress', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            content: const Text(
              'Payment verification is in progress. Your wallet balance will update automatically once verified by backend.',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(RouteNames.wallet);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      } else {
        _handleStructuredPaymentError(errText);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _amount >= 1 && _amount <= 100000;
    final balanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Add Money', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF1E293B))),
            Text('Top up your wallet securely via Razorpay.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottomOpacity: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Balance Pill ──
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Wallet Balance',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            balanceAsync.when(
                              data: (b) => Text(
                                CurrencyFormatter.fromPaise(b.availablePaise),
                                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              loading: () => Container(width: 60, height: 16, color: const Color(0xFFE2E8F0)),
                              error: (_, __) => const Text('Error', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Amount Input ──
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final shake = 4.0 * math.sin(_shakeController.value * 4 * math.pi);
                          return Transform.translate(
                            offset: Offset(shake, 0),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            const Text(
                              'Amount',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 240,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '₹',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: _amount > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IntrinsicWidth(
                                    child: TextField(
                                      controller: _amountController,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(color: const Color(0xFFCBD5E1).withValues(alpha: 0.5)),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: _onAmountChanged,
                                      cursorColor: const Color(0xFF1565FF),
                                      cursorWidth: 2,
                                      cursorHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Quick Amounts ──
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          _QuickAmountTile(amount: 500, selectedAmount: _amount, onTap: () => _addQuickAmount(500)),
                          _QuickAmountTile(amount: 1000, selectedAmount: _amount, onTap: () => _addQuickAmount(1000)),
                          _QuickAmountTile(amount: 2000, selectedAmount: _amount, onTap: () => _addQuickAmount(2000)),
                          _QuickAmountTile(amount: 5000, selectedAmount: _amount, onTap: () => _addQuickAmount(5000)),
                          _QuickAmountTile(amount: 10000, selectedAmount: _amount, onTap: () => _addQuickAmount(10000)),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── Payment Method ──
                      Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'UPI • Cards • Net Banking',
                                    style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B), fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Powered by Razorpay',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      // ── Security Badges ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_outline, size: 14, color: Color(0xFF94A3B8)),
                          SizedBox(width: 4),
                          Text(
                            'Secure Payments',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          ),
                          Text(
                            'PCI DSS Compliant',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // ── Sticky Proceed Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isValid ? 1.0 : 0.6,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isValid && !_isLoading ? _onProceed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565FF),
                      disabledBackgroundColor: const Color(0xFF1565FF).withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                              ),
                              const SizedBox(width: 12),
                              Text(_statusMessage ?? 'Processing...', style: const TextStyle(fontSize: 14, color: Colors.white)),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('Proceed to Pay via Razorpay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountTile extends StatelessWidget {
  final int amount;
  final int selectedAmount;
  final VoidCallback onTap;

  const _QuickAmountTile({required this.amount, required this.selectedAmount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAmount == amount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1565FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1565FF) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(amount)}',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}