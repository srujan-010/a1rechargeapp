import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/operator.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../../wallet/domain/models/wallet_transaction.dart';

abstract class DthRepository {
  Future<Result<List<Operator>, AppException>> getDthOperators();
  
  Future<Result<List<dynamic>, AppException>> getDthPacks(String operatorId, {String? search});
  
  Future<Result<RechargeReceipt, AppException>> executeDthRecharge({
    required String subscriberId,
    required String operatorId,
    required String operatorName,
    required int amountPaise,
    String? packId,
    String? mpin,
    String? paymentMode,
  });

  Future<Result<RechargeReceipt, AppException>> checkDthStatus(String orderId);

  Future<Result<List<WalletTransaction>, AppException>> getDthHistory();
}
