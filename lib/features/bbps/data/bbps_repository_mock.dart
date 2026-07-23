import 'dart:math';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../recharge/domain/models/recharge_result.dart';
import '../domain/bbps_repository.dart';
import '../domain/models/bbps_models.dart';

class BbpsRepositoryMock implements BbpsRepository {
  final _random = Random();

  BbpsRepositoryMock();

  @override
  Future<Result<RechargeReceipt, AppException>> checkStatus({
    required String category,
    required String orderId,
  }) async {
    await _delay();
    return Success(RechargeReceipt.fake());
  }

  Future<void> _delay() async {
    final ms = AppConfig.mockLatencyMin.inMilliseconds +
        _random.nextInt(AppConfig.mockLatencyMax.inMilliseconds - AppConfig.mockLatencyMin.inMilliseconds);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<Result<List<BillerDistrict>, AppException>> getDistricts({required String operatorCode}) async {
    await _delay();
    
    if (operatorCode == '443') {
      return const Success([
        BillerDistrict(operatorCode: 443, state: 'Uttar Pradesh', districtName: 'Agra', districtCode: 'AGRA'),
        BillerDistrict(operatorCode: 443, state: 'Uttar Pradesh', districtName: 'Aligarh', districtCode: 'ALIGARH'),
      ]);
    }
    
    return const Success([]);
  }

  @override
  Future<Result<List<String>, AppException>> getStates({required String category}) async {
    await _delay();
    return const Success([
      'Andhra Pradesh',
      'Karnataka',
      'Maharashtra',
      'Telangana',
      'Uttar Pradesh'
    ]);
  }

  @override
  Future<Result<List<Biller>, AppException>> getBillers({required String category, String? state}) async {
    await _delay();
    
    // Provide some mock billers based on category
    if (category.toLowerCase() == 'electricity') {
      var allBillers = <Biller>[
        const Biller(
          id: 'elec_msebd',
          name: 'Maharashtra State Electricity Board',
          category: 'Electricity',
          iconUrl: '',
          sampleBillUrl: 'https://via.placeholder.com/400x600/1E3A8A/FFFFFF?text=Sample+MSEB+Bill',
          parameters: [
            BillerParameter(
              name: 'consumer_number',
              displayName: 'Consumer Number',
              regex: r'^[0-9]{12}$',
              minLength: 12,
              maxLength: 12,
              helperText: 'Please enter your 12 digit consumer number as printed on your bill.',
            ),
            BillerParameter(
              name: 'billing_unit',
              displayName: 'Billing Unit (BU)',
              regex: r'^[0-9]{4}$',
              minLength: 4,
              maxLength: 4,
              helperText: '4 digit BU code available on top right of your bill.',
            ),
            BillerParameter(
              name: 'mobile_number',
              displayName: 'Mobile Number',
              regex: r'^[0-9]{10}$',
              minLength: 10,
              maxLength: 10,
              isOptional: true,
              helperText: 'For receiving payment alerts.',
            ),
          ],
        ),
        const Biller(
          id: 'elec_bescom',
          name: 'BESCOM (Bangalore)',
          category: 'Electricity',
          iconUrl: '',
          parameters: [
            BillerParameter(
              name: 'account_id',
              displayName: 'Account ID',
              regex: r'^[0-9]{10}$',
              minLength: 10,
              maxLength: 10,
            ),
          ],
        ),
        const Biller(
          id: 'elec_torrent',
          name: 'Torrent Power',
          category: 'Electricity',
          iconUrl: '',
          parameters: [
            BillerParameter(
              name: 'service_number',
              displayName: 'Service Number',
              regex: r'^[0-9]+$',
              minLength: 8,
              maxLength: 12,
            ),
          ],
        ),
      ];

      if (state != null && state.isNotEmpty) {
        // mock filter
        allBillers = allBillers.where((b) => b.name.contains(state) || b.name.contains('MSEB')).toList();
      }
      return Success(allBillers);
    } else if (category.toLowerCase() == 'fastag') {
      return const Success([
        Biller(
          id: 'ft_hdfc',
          name: 'HDFC Bank FASTag',
          category: 'FASTag',
          iconUrl: '',
          parameters: [
            BillerParameter(
              name: 'vehicle_number',
              displayName: 'Vehicle Registration Number',
              regex: r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$',
              minLength: 9,
              maxLength: 10,
            ),
          ],
        ),
        Biller(
          id: 'ft_icici',
          name: 'ICICI Bank FASTag',
          category: 'FASTag',
          iconUrl: '',
          parameters: [
            BillerParameter(
              name: 'vehicle_number',
              displayName: 'Vehicle Registration Number',
              regex: r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$',
              minLength: 9,
              maxLength: 10,
            ),
          ],
        ),
      ]);
    }
    
    // Default empty list for unhandled categories
    return const Success([]);
  }

  @override
  Future<Result<BillDetails, AppException>> fetchBill({
    required String category,
    required String billerId,
    required Map<String, String> parameters,
  }) async {
    await _delay();
    
    // Simulate invalid parameter error
    if (parameters.values.any((v) => v.isEmpty || v == '0000000000')) {
      return const Failure(ValidationException(
        message: 'Invalid details. No bill found for these parameters.',
        code: 'BILL_NOT_FOUND',
      ));
    }
    
    final operatorName = 'Demo Provider';
    final amount = (100 + _random.nextInt(4900)) * 100;
    
    final billDetails = BillDetails(
      billerId: billerId,
      billerName: operatorName,
      category: category,
      customerName: 'Test User',
      billAmountPaise: amount,
      rawBillDate: DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 5))),
      rawDueDate: DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 10))),
      parsedBillDate: DateTime.now().subtract(const Duration(days: 5)),
      parsedDueDate: DateTime.now().add(const Duration(days: 10)),
      billNumber: 'BILL${DateTime.now().millisecondsSinceEpoch}',
    );
    
    return Success(billDetails);
  }

  @override
  Future<Result<RechargeReceipt, AppException>> payBill({
    required BillDetails billDetails,
    required String mpin,
  }) async {
    await _delay();
    
    if (mpin == '000000') {
      return const Failure(AuthException.invalidMpin);
    }
    
    final receipt = RechargeReceipt(
      transactionId: 'TXN${_random.nextInt(999999999).toString().padLeft(9, '0')}',
      referenceId: 'BBPS${_random.nextInt(9999999).toString().padLeft(7, '0')}',
      mobileNumber: 'N/A', // Bill payments usually track customer via bill details, not phone
      amountPaise: billDetails.billAmountPaise,
      timestamp: DateTime.now(),
      status: RechargeStatus.success,
      operatorName: billDetails.billerName,
      operatorRef: billDetails.billNumber,
    );
    
    return Success(receipt);
  }
}
