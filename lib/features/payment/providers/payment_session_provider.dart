import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/logger.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../../recharge/presentation/recharge_providers.dart';

enum PaymentSessionStatus { idle, razorpayOpen, verifying, completed, failed, cancelled }

enum PaymentSessionType { recharge, walletTopup }

class PaymentSessionState {
  final PaymentSessionStatus status;
  final PaymentSessionType? type;
  final String? internalTransactionId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final Map<String, dynamic>? extraData;
  final DateTime? startedAt;
  final String? errorMessage;
  final RechargeReceipt? receipt;
  final Map<String, dynamic>? walletTopupResult;

  const PaymentSessionState({
    this.status = PaymentSessionStatus.idle,
    this.type,
    this.internalTransactionId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.extraData,
    this.startedAt,
    this.errorMessage,
    this.receipt,
    this.walletTopupResult,
  });

  bool get isPaymentInProgress =>
      status == PaymentSessionStatus.razorpayOpen || status == PaymentSessionStatus.verifying;

  PaymentSessionState copyWith({
    PaymentSessionStatus? status,
    PaymentSessionType? type,
    String? internalTransactionId,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    Map<String, dynamic>? extraData,
    DateTime? startedAt,
    String? errorMessage,
    RechargeReceipt? receipt,
    Map<String, dynamic>? walletTopupResult,
  }) {
    return PaymentSessionState(
      status: status ?? this.status,
      type: type ?? this.type,
      internalTransactionId: internalTransactionId ?? this.internalTransactionId,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      extraData: extraData ?? this.extraData,
      startedAt: startedAt ?? this.startedAt,
      errorMessage: errorMessage,
      receipt: receipt ?? this.receipt,
      walletTopupResult: walletTopupResult ?? this.walletTopupResult,
    );
  }
}

class PaymentSessionNotifier extends StateNotifier<PaymentSessionState> {
  final Ref _ref;

  PaymentSessionNotifier(this._ref) : super(const PaymentSessionState());

  void startSession({
    required String internalTransactionId,
    required String razorpayOrderId,
    required PaymentSessionType type,
    Map<String, dynamic>? extraData,
  }) {
    AppLogger.info(
      '[PAYMENT_SESSION] Starting payment session. Type: $type, InternalTx: $internalTransactionId, RzpOrderId: $razorpayOrderId',
      tag: 'PAYMENT_SESSION',
    );

    state = PaymentSessionState(
      status: PaymentSessionStatus.razorpayOpen,
      type: type,
      internalTransactionId: internalTransactionId,
      razorpayOrderId: razorpayOrderId,
      extraData: extraData,
      startedAt: DateTime.now(),
    );
  }

  void onRazorpaySuccess({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    AppLogger.info(
      '[PAYMENT_SESSION] Razorpay Success received globally. PaymentID: $paymentId, OrderID: $orderId',
      tag: 'PAYMENT_SESSION',
    );

    final currentOrderId = orderId.isNotEmpty ? orderId : (state.razorpayOrderId ?? '');

    state = state.copyWith(
      status: PaymentSessionStatus.verifying,
      razorpayPaymentId: paymentId,
      razorpayOrderId: currentOrderId,
      razorpaySignature: signature,
    );

    verifyPayment();
  }

  void onRazorpayError({required int code, String? message}) {
    AppLogger.error(
      '[PAYMENT_SESSION] Razorpay Error received globally. Code: $code, Message: $message',
      tag: 'PAYMENT_SESSION',
    );

    final isCancelled = code == 2 ||
        (message != null &&
            (message.toLowerCase().contains('cancel') || message.toLowerCase().contains('dismiss')));

    if (isCancelled) {
      state = state.copyWith(
        status: PaymentSessionStatus.cancelled,
        errorMessage: 'Payment was cancelled.',
      );
    } else {
      state = state.copyWith(
        status: PaymentSessionStatus.failed,
        errorMessage: message ?? 'Payment failed.',
      );
    }
  }

  void onExternalWallet(String walletName) {
    AppLogger.info(
      '[PAYMENT_SESSION] External wallet selected: $walletName',
      tag: 'PAYMENT_SESSION',
    );
  }

  Future<void> verifyPayment() async {
    final internalTxId = state.internalTransactionId;
    final rzpOrderId = state.razorpayOrderId;
    final rzpPaymentId = state.razorpayPaymentId;
    final rzpSignature = state.razorpaySignature;

    if (internalTxId == null || rzpOrderId == null || rzpPaymentId == null) {
      AppLogger.error('[PAYMENT_SESSION] Missing required parameters for verification', tag: 'PAYMENT_SESSION');
      state = state.copyWith(
        status: PaymentSessionStatus.failed,
        errorMessage: 'Missing required payment verification details.',
      );
      return;
    }

    try {
      AppLogger.info(
        '[PAYMENT_SESSION] Executing backend payment verification for $internalTxId...',
        tag: 'PAYMENT_SESSION',
      );

      if (state.type == PaymentSessionType.recharge) {
        final repo = _ref.read(rechargeRepositoryProvider);
        final verifyResult = await repo.verifyRazorpayRechargePayment(
          internalTransactionId: internalTxId,
          razorpayOrderId: rzpOrderId,
          razorpayPaymentId: rzpPaymentId,
          razorpaySignature: rzpSignature ?? '',
        );

        final receipt = verifyResult.valueOrNull;
        if (receipt != null) {
          AppLogger.info('[PAYMENT_SESSION] Recharge Payment Verified Successfully!', tag: 'PAYMENT_SESSION');
          state = state.copyWith(
            status: PaymentSessionStatus.completed,
            receipt: receipt,
          );
        } else {
          final err = verifyResult.errorOrNull?.message ?? 'Payment verification failed.';
          AppLogger.error('[PAYMENT_SESSION] Recharge Verification Error: $err', tag: 'PAYMENT_SESSION');
          state = state.copyWith(
            status: PaymentSessionStatus.failed,
            errorMessage: err,
          );
        }
      } else if (state.type == PaymentSessionType.walletTopup) {
        final apiClient = _ref.read(apiClientProvider);
        final response = await apiClient.post<Map<String, dynamic>>(
          '/wallet/verify-payment',
          data: {
            'internalTransactionId': internalTxId,
            'razorpayOrderId': rzpOrderId,
            'razorpayPaymentId': rzpPaymentId,
            'razorpaySignature': rzpSignature ?? '',
          },
          fromJson: (json) => json as Map<String, dynamic>,
        );

        final isSuccess = response.success || (response.data?['walletCredited'] == true);
        if (isSuccess) {
          AppLogger.info('[PAYMENT_SESSION] Wallet Topup Verified Successfully!', tag: 'PAYMENT_SESSION');
          state = state.copyWith(
            status: PaymentSessionStatus.completed,
            walletTopupResult: response.data,
          );
        } else {
          final err = response.message.isNotEmpty ? response.message : 'Wallet topup verification failed.';
          AppLogger.error('[PAYMENT_SESSION] Wallet Topup Verification Error: $err', tag: 'PAYMENT_SESSION');
          state = state.copyWith(
            status: PaymentSessionStatus.failed,
            errorMessage: err,
          );
        }
      }
    } catch (e) {
      AppLogger.error('[PAYMENT_SESSION] Verification Exception: $e', tag: 'PAYMENT_SESSION');
      state = state.copyWith(
        status: PaymentSessionStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  void onAppResumed() {
    if (!state.isPaymentInProgress) return;

    AppLogger.info(
      '[PAYMENT_SESSION] App resumed while payment is in progress (Status: ${state.status}). Checking session recovery...',
      tag: 'PAYMENT_SESSION',
    );

    // If Razorpay success credentials were captured but verification hasn't completed yet
    if (state.razorpayPaymentId != null && state.status == PaymentSessionStatus.verifying) {
      verifyPayment();
    }
  }

  void clearSession() {
    AppLogger.info('[PAYMENT_SESSION] Clearing payment session.', tag: 'PAYMENT_SESSION');
    state = const PaymentSessionState();
  }
}

final paymentSessionProvider =
    StateNotifierProvider<PaymentSessionNotifier, PaymentSessionState>((ref) {
  return PaymentSessionNotifier(ref);
});
