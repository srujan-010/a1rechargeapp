import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/features/recharge/domain/models/recharge_result.dart';
import 'package:a1_recharge/core/constants/route_names.dart';

void main() {
  test('RechargeReceipt statuses and routes exist correctly', () {
    expect(RouteNames.rechargeProcessing, '/recharge/processing');
    expect(RouteNames.rechargePending, '/recharge/pending');
    expect(RouteNames.rechargeFailed, '/recharge/failed');

    final pendingReceipt = RechargeReceipt(
      transactionId: 'TXN123',
      referenceId: 'REF123',
      operatorRef: 'Processing...',
      status: RechargeStatus.pending,
      amountPaise: 19900,
      mobileNumber: '9876543210',
      operatorName: 'Jio',
      timestamp: DateTime.now(),
    );

    expect(pendingReceipt.isPending, isTrue);
    expect(pendingReceipt.isSuccess, isFalse);

    final failedReceipt = RechargeReceipt(
      transactionId: 'TXN124',
      referenceId: 'REF124',
      operatorRef: 'N/A',
      status: RechargeStatus.failed,
      amountPaise: 19900,
      mobileNumber: '9876543210',
      operatorName: 'Jio',
      timestamp: DateTime.now(),
      failureReason: 'Operator technical error',
    );

    expect(failedReceipt.status, RechargeStatus.failed);
    expect(failedReceipt.failureReason, 'Operator technical error');
  });
}
