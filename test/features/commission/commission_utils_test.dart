// test/features/commission/commission_utils_test.dart
// Unit tests for commission formatting utility.

import 'package:flutter_test/flutter_test.dart';
import 'package:a1_recharge/features/commission/domain/commission_utils.dart';

void main() {
  group('formatCommission', () {
    group('percentage type', () {
      test('formats whole percentage with one decimal', () {
        expect(formatCommission('percentage', 2.0), '2.0%');
      });

      test('formats fractional percentage', () {
        expect(formatCommission('percentage', 1.5), '1.5%');
      });

      test('formats 4% correctly', () {
        expect(formatCommission('percentage', 4.0), '4.0%');
      });

      test('formats 2.5% correctly', () {
        expect(formatCommission('percentage', 2.5), '2.5%');
      });

      test('formats 3% correctly', () {
        expect(formatCommission('percentage', 3.0), '3.0%');
      });
    });

    group('flat type', () {
      test('formats whole rupee amount as flat', () {
        expect(formatCommission('flat', 5.0), contains('flat'));
        expect(formatCommission('flat', 5.0), contains('5'));
      });

      test('formats fractional rupee amount as flat', () {
        expect(formatCommission('flat', 10.5), contains('flat'));
        expect(formatCommission('flat', 10.5), contains('10'));
      });

      test('flat result does not contain percent sign', () {
        expect(formatCommission('flat', 5.0), isNot(contains('%')));
      });
    });

    group('edge cases', () {
      test('percentage result does not contain flat', () {
        expect(formatCommission('percentage', 2.0), isNot(contains('flat')));
      });

      test('percentage result contains percent sign', () {
        expect(formatCommission('percentage', 1.5), contains('%'));
      });
    });
  });
}
