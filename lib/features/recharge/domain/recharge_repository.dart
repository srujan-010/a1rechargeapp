import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import 'models/operator.dart';
import 'models/circle.dart';
import '../domain/models/recharge_plan.dart';
import '../domain/models/recharge_result.dart';
import 'models/recent_contact.dart';

class OperatorResolveResult {
  final Operator operator;
  final Circle circle;
  OperatorResolveResult({required this.operator, required this.circle});
}

abstract class RechargeRepository {
  /// Fetches the list of available operators for a specific service type (e.g., 'mobile', 'dth')
  Future<Result<List<Operator>, AppException>> getOperators({required String serviceType});

  /// Fetches the list of available circles
  Future<Result<List<Circle>, AppException>> getCircles();

  /// Automatically resolves the operator and circle for a given phone number
  Future<Result<OperatorResolveResult, AppException>> resolveOperator(String phoneNumber);

  /// Fetches available recharge plans for a specific operator and circle
  Future<Result<List<RechargePlan>, AppException>> getPlans({
    required String operatorId,
    required String circle,
  });

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
  });

  /// Fetches recent recharge contacts
  Future<List<RecentContact>> getRecentContacts();

  /// Saves a recent recharge contact
  Future<void> saveRecentContact(RecentContact contact);

  /// Removes a recent recharge contact
  Future<void> removeRecentContact(String phone);
}
