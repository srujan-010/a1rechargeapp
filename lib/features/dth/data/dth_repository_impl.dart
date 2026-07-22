import '../../../core/models/app_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/operator.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../../wallet/domain/models/wallet_transaction.dart';
import '../domain/dth_repository.dart';

class DthRepositoryImpl implements DthRepository {
  final ApiClient apiClient;

  DthRepositoryImpl({required this.apiClient});

  @override
  Future<Result<List<Operator>, AppException>> getDthOperators() async {
    try {
      final response = await apiClient.get<List<dynamic>>(
        '/dth/operators',
        fromJson: (json) => json is List ? json : [],
      );

      if (response.success && response.data != null) {
        final operators = (response.data as List)
            .map((item) => Operator.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return Success(operators);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      AppLogger.error('Failed to fetch DTH operators', tag: 'DthRepo', error: e);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<dynamic>, AppException>> getDthPacks(String operatorId, {String? search}) async {
    return Success([]);
  }

  @override
  Future<Result<RechargeReceipt, AppException>> executeDthRecharge({
    required String subscriberId,
    required String operatorId,
    required String operatorName,
    required int amountPaise,
    String? packId,
    String? mpin,
    String? paymentMode,
  }) async {
    try {
      final response = await apiClient.post<RechargeReceipt>(
        '/dth/recharge',
        data: {
          'subscriberId': subscriberId,
          'operatorId': operatorId,
          'operatorName': operatorName,
          'amountPaise': amountPaise,
          if (packId != null) 'packId': packId,
          if (mpin != null) 'mpin': mpin,
          if (paymentMode != null) 'paymentMode': paymentMode,
        },
        fromJson: (json) {
          final data = json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
          return RechargeReceipt(
            transactionId: data['transactionId'] as String? ?? data['referenceId'] as String? ?? '',
            referenceId: data['referenceId'] as String? ?? '',
            mobileNumber: data['subscriberNumber'] as String? ?? subscriberId,
            operatorName: data['operatorName'] as String? ?? operatorName,
            amountPaise: (data['amountPaise'] as num?)?.toInt() ?? amountPaise,
            status: _parseStatus(data['status'] as String? ?? data['providerStatus'] as String?),
            timestamp: DateTime.now(),
            operatorRef: data['operatorReference'] as String? ?? data['providerTransactionId'] as String?,
            paymentMode: paymentMode ?? 'Wallet',
          );
        },
      );

      if (response.success && response.data != null) {
        return Success(response.data!);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      AppLogger.error('Failed to execute DTH recharge', tag: 'DthRepo', error: e);
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<RechargeReceipt, AppException>> checkDthStatus(String orderId) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/dth/status/$orderId',
        fromJson: (json) => json is Map ? Map<String, dynamic>.from(json) : {},
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final rawStatus = data['status'] as String? ?? data['providerStatus'] as String?;
        final receipt = RechargeReceipt(
          transactionId: orderId,
          referenceId: orderId,
          mobileNumber: data['subscriberNumber'] as String? ?? '',
          operatorName: data['operatorName'] as String? ?? 'DTH',
          amountPaise: (data['amountPaise'] as num?)?.toInt() ?? 0,
          status: _parseStatus(rawStatus),
          timestamp: data['completedAt'] != null ? DateTime.parse(data['completedAt'] as String) : DateTime.now(),
          operatorRef: data['operatorReference'] as String? ?? data['providerTransactionId'] as String?,
        );
        return Success(receipt);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }

  @override
  Future<Result<List<WalletTransaction>, AppException>> getDthHistory() async {
    try {
      final response = await apiClient.get<List<dynamic>>(
        '/dth/history',
        fromJson: (json) => json is List ? json : [],
      );

      if (response.success && response.data != null) {
        final txns = (response.data as List)
            .map((item) => WalletTransaction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return Success(txns);
      }
      return Failure(ServerException(message: response.message));
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }

  static RechargeStatus _parseStatus(String? raw) => switch (raw?.toLowerCase()) {
        'success' => RechargeStatus.success,
        'failed' => RechargeStatus.failed,
        'processing' => RechargeStatus.processing,
        _ => RechargeStatus.pending,
      };
}
