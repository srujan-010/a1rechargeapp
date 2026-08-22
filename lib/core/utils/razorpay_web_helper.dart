// Conditional export helper for Razorpay Web Checkout
import 'razorpay_web_helper_stub.dart'
    if (dart.library.js_interop) 'razorpay_web_helper_html.dart'
    if (dart.library.html) 'razorpay_web_helper_html.dart';

void openRazorpayWebCheckout({
  required String key,
  required int amount,
  required String orderId,
  required String contact,
  required String email,
  required Function(String paymentId, String orderId, String signature) onSuccess,
  required Function(String error) onError,
  required Function() onDismiss,
}) {
  openRazorpayWebCheckoutImpl(
    key: key,
    amount: amount,
    orderId: orderId,
    contact: contact,
    email: email,
    onSuccess: onSuccess,
    onError: onError,
    onDismiss: onDismiss,
  );
}
