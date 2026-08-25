import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/operator.dart';
import 'models/circle.dart';
import '../domain/models/recharge_result.dart';
import 'models/recent_contact.dart';

abstract class RechargeRepository {
  /// Fetches the list of available operators for a specific service type (e.g., 'mobile', 'dth')
  Future<Result<List<Operator>, AppException>> getOperators({required String serviceType});

  /// Fetches the list of available circles
  Future<Result<List<Circle>, AppException>> getCircles();

  /// Initiates a recharge transaction
  Future<Result<RechargeReceipt, AppException>> processRecharge({
    required String phoneNumber,
    required String operatorId,
    required String operatorName,
    required String circleId,
    required String serviceType,
    required int amountPaise,
    String? mpin,
    String? paymentMode,
    String? planId,
    String? planName,
    String? planType,
    String? selectedCategory,
    String? providerOperatorCode,
  });

  /// Fetches recent recharge contacts
  Future<List<RecentContact>> getRecentContacts();

  /// Saves a recent recharge contact
  Future<void> saveRecentContact(RecentContact contact);

  /// Removes a recent recharge contact
  Future<void> removeRecentContact(String phone);

  /// Checks the status of an existing recharge order
  Future<Result<RechargeReceipt, AppException>> checkRechargeStatus(String orderId);

  /// Calculates server-side commission & net payable amount for a recharge
  Future<Result<Map<String, dynamic>, AppException>> calculatePayableAmount({
    required String phoneNumber,
    required String operatorId,
    required String operatorName,
    required String circleId,
    required String serviceType,
    required int amountPaise,
    String? planType,
  });

  /// Creates a Razorpay order for recharge with server-side payable amount
  Future<Result<Map<String, dynamic>, AppException>> createRazorpayRechargeOrder({
    required String phoneNumber,
    required String operatorId,
    required String operatorName,
    required String circleId,
    required String serviceType,
    required int amountPaise,
    String? planId,
    String? planName,
    String? planType,
    String? selectedCategory,
    String? providerOperatorCode,
  });

  /// Verifies Razorpay payment signature and executes recharge
  Future<Result<RechargeReceipt, AppException>> verifyRazorpayRechargePayment({
    required String internalTransactionId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
}
