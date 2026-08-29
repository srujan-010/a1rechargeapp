import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/core/utils/operator_formatter.dart';

void main() {
  group('OperatorFormatter Unit Tests', () {
    test('Airtel aliases resolve to Airtel', () {
      expect(OperatorFormatter.getDisplayOperatorName('AT'), equals('Airtel'));
      expect(OperatorFormatter.getDisplayOperatorName('AIRTEL'), equals('Airtel'));
      expect(OperatorFormatter.getDisplayOperatorName('2'), equals('Airtel'));
      expect(OperatorFormatter.getDisplayOperatorName('13'), equals('Airtel'));
      expect(OperatorFormatter.getDisplayOperatorName('DA'), equals('Airtel'));
    });

    test('Reliance Jio aliases resolve to Jio', () {
      expect(OperatorFormatter.getDisplayOperatorName('JO'), equals('Jio'));
      expect(OperatorFormatter.getDisplayOperatorName('JIO'), equals('Jio'));
      expect(OperatorFormatter.getDisplayOperatorName('RJIO'), equals('Jio'));
      expect(OperatorFormatter.getDisplayOperatorName('RELIANCE JIO'), equals('Jio'));
      expect(OperatorFormatter.getDisplayOperatorName('11'), equals('Jio'));
    });

    test('Vodafone Idea / Vi aliases resolve to Vi', () {
      expect(OperatorFormatter.getDisplayOperatorName('VI'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('VF'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('VODAFONE'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('IDEA'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('VODAFONE IDEA'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('23'), equals('Vi'));
      expect(OperatorFormatter.getDisplayOperatorName('6'), equals('Vi'));
    });

    test('BSNL aliases resolve to distinct BSNL TOPUP and BSNL SPECIAL labels', () {
      expect(OperatorFormatter.getDisplayOperatorName('BT'), equals('BSNL TOPUP'));
      expect(OperatorFormatter.getDisplayOperatorName('BR'), equals('BSNL SPECIAL'));
      expect(OperatorFormatter.getDisplayOperatorName('BSNL'), equals('BSNL'));
      expect(OperatorFormatter.getDisplayOperatorName('BSNL TOPUP'), equals('BSNL TOPUP'));
      expect(OperatorFormatter.getDisplayOperatorName('BSNL STV'), equals('BSNL SPECIAL'));
      expect(OperatorFormatter.getDisplayOperatorName('BSNL SPECIAL'), equals('BSNL SPECIAL'));
      expect(OperatorFormatter.getDisplayOperatorName('4'), equals('BSNL TOPUP'));
      expect(OperatorFormatter.getDisplayOperatorName('5'), equals('BSNL SPECIAL'));
    });

    test('DTH operators resolve cleanly', () {
      expect(OperatorFormatter.getDisplayOperatorName('DT'), equals('Tata Play'));
      expect(OperatorFormatter.getDisplayOperatorName('TATA PLAY'), equals('Tata Play'));
      expect(OperatorFormatter.getDisplayOperatorName('DD'), equals('Dish TV'));
      expect(OperatorFormatter.getDisplayOperatorName('DISH TV'), equals('Dish TV'));
      expect(OperatorFormatter.getDisplayOperatorName('DS'), equals('Sun Direct'));
      expect(OperatorFormatter.getDisplayOperatorName('DV'), equals('d2h'));
    });

    test('Empty or null input returns default', () {
      expect(OperatorFormatter.getDisplayOperatorName(null), equals('Mobile Operator'));
      expect(OperatorFormatter.getDisplayOperatorName(''), equals('Mobile Operator'));
    });
  });
}
