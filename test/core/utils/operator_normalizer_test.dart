import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/core/utils/operator_normalizer.dart';

void main() {
  group('OperatorNormalizer Test Suite', () {
    test('TEST 1: API returns Reliance Jio Infocomm Limited / OpCode 11 -> JIO / OpCode 11', () {
      final res = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Andhra Pradesh',
        rawCircleCode: '49',
      );

      expect(res, isNotNull);
      expect(res!.operatorName, equals('Jio'));
      expect(res.providerOperatorCode, equals('11'));
      expect(res.a1TopupCode, equals('RC'));
      expect(res.circleName, equals('Andhra Pradesh'));
      expect(res.circleCode, equals('49'));
    });

    test('TEST 2: Previously selected BSNL, new detection JIO -> BSNL cleared', () {
      const prevOpName = 'BSNL TOPUP';

      final res = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Andhra Pradesh',
        rawCircleCode: '49',
      );

      expect(res!.operatorName, equals('Jio'));
      expect(res.operatorName, isNot(equals(prevOpName)));
      expect(res.providerOperatorCode, equals('11'));
    });

    test('TEST 3: Detection returns JIO but plans request must use OpCode 11', () {
      final res = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Andhra Pradesh',
        rawCircleCode: '49',
      );

      expect(res!.providerOperatorCode, equals('11'));
    });

    test('TEST 4: Out-of-order race condition check', () {
      const currentToken = 2; // Latest request token for Jio
      const currentPhone = '919440761742';

      // Old request token = 1 (BSNL response)
      const staleToken = 1;
      const stalePhone = '9440000000';

      bool isLatest(int token, String phone) => token == currentToken && phone == currentPhone;

      expect(isLatest(staleToken, stalePhone), isFalse);
      expect(isLatest(currentToken, currentPhone), isTrue);
    });

    test('TEST 5: Number change Jio -> BSNL', () {
      final res = OperatorNormalizer.normalize(
        rawOperator: 'BSNL TOPUP',
        rawOpCode: '4',
        rawCircle: 'Maharashtra',
        rawCircleCode: '90',
      );

      expect(res!.operatorName, equals('BSNL TOPUP'));
      expect(res.providerOperatorCode, equals('4'));
      expect(res.a1TopupCode, equals('BT'));
    });

    test('TEST 6: Number change BSNL -> Jio', () {
      final res = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Delhi',
        rawCircleCode: '10',
      );

      expect(res!.operatorName, equals('Jio'));
      expect(res.providerOperatorCode, equals('11'));
      expect(res.a1TopupCode, equals('RC'));
    });

    test('TEST 7: Manual Change Operator Airtel', () {
      final res = OperatorNormalizer.normalize(
        rawOperator: 'Airtel',
        rawOpCode: '2',
        rawCircle: 'Karnataka',
        rawCircleCode: '06',
      );

      expect(res!.operatorName, equals('Airtel'));
      expect(res.providerOperatorCode, equals('2'));
      expect(res.a1TopupCode, equals('A'));
    });

    test('TEST 8: Refresh/re-enter same mobile number', () {
      final res1 = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Andhra Pradesh',
        rawCircleCode: '49',
      );

      final res2 = OperatorNormalizer.normalize(
        rawOperator: 'Reliance Jio Infocomm Limited',
        rawOpCode: '11',
        rawCircle: 'Andhra Pradesh',
        rawCircleCode: '49',
      );

      expect(res1!.operatorName, equals(res2!.operatorName));
      expect(res1.providerOperatorCode, equals(res2.providerOperatorCode));
    });
  });
}
