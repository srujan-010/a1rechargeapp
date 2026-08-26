import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../utils/logger.dart';
import '../../features/payment/providers/payment_session_provider.dart';

class RazorpayService {
  late final Razorpay _razorpay;
  final Ref _ref;
  bool _isInitialized = false;

  RazorpayService(this._ref) {
    if (!kIsWeb) {
      _initRazorpay();
    }
  }

  void _initRazorpay() {
    if (_isInitialized) return;
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      _isInitialized = true;
      AppLogger.info('[RAZORPAY_SERVICE] Global Razorpay Service initialized', tag: 'RAZORPAY_SERVICE');
    } catch (e) {
      AppLogger.error('[RAZORPAY_SERVICE] Failed to initialize Razorpay: $e', tag: 'RAZORPAY_SERVICE');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    AppLogger.info(
      '[RAZORPAY_SERVICE] Global Payment Success -> PaymentID: ${response.paymentId}, OrderID: ${response.orderId}',
      tag: 'RAZORPAY_SERVICE',
    );
    _ref.read(paymentSessionProvider.notifier).onRazorpaySuccess(
          paymentId: response.paymentId ?? '',
          orderId: response.orderId ?? '',
          signature: response.signature ?? '',
        );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    AppLogger.error(
      '[RAZORPAY_SERVICE] Global Payment Error -> Code: ${response.code}, Message: ${response.message}',
      tag: 'RAZORPAY_SERVICE',
    );
    _ref.read(paymentSessionProvider.notifier).onRazorpayError(
          code: response.code ?? -1,
          message: response.message,
        );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    AppLogger.info(
      '[RAZORPAY_SERVICE] Global External Wallet -> ${response.walletName}',
      tag: 'RAZORPAY_SERVICE',
    );
    _ref.read(paymentSessionProvider.notifier).onExternalWallet(response.walletName ?? '');
  }

  void openCheckout(Map<String, dynamic> options) {
    if (kIsWeb) {
      AppLogger.info('[RAZORPAY_SERVICE] Web Checkout handled via openRazorpayWebCheckout helper', tag: 'RAZORPAY_SERVICE');
      return;
    }
    if (!_isInitialized) {
      _initRazorpay();
    }
    AppLogger.info('[RAZORPAY_SERVICE] Opening Native Razorpay Checkout for order: ${options['order_id']}', tag: 'RAZORPAY_SERVICE');
    _razorpay.open(options);
  }

  void clear() {
    if (_isInitialized && !kIsWeb) {
      try {
        _razorpay.clear();
      } catch (_) {}
    }
  }
}

final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  final service = RazorpayService(ref);
  ref.onDispose(() => service.clear());
  return service;
});
