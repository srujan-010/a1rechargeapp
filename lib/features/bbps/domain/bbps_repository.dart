import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import 'models/bbps_models.dart';

abstract class BbpsRepository {
  /// Fetches billers for a given category (e.g., 'electricity', 'water')
  Future<Result<List<Biller>, AppException>> getBillers({required String category});

  /// Fetches bill details using the biller parameters
  Future<Result<BillDetails, AppException>> fetchBill({
    required String billerId,
    required Map<String, String> parameters,
  });

  /// Pays the bill using MPIN
  Future<Result<RechargeReceipt, AppException>> payBill({
    required BillDetails billDetails,
    required String mpin,
  });
}
