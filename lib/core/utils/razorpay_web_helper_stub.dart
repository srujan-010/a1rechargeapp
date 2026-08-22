// Stub implementation for non-web platforms
void openRazorpayWebCheckoutImpl({
  required String key,
  required int amount,
  required String orderId,
  required String contact,
  required String email,
  required Function(String paymentId, String orderId, String signature) onSuccess,
  required Function(String error) onError,
  required Function() onDismiss,
}) {
  onError('Razorpay Web Checkout is only supported on Web platform.');
}
