import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/utils/calc.dart';

void main() {
  group('evalAmount', () {
    test('handles bare number', () {
      expect(evalAmount('1234'), 1234);
      expect(evalAmount('12,5'), 12.5);
      expect(evalAmount('12.5'), 12.5);
    });

    test('handles addition and subtraction', () {
      expect(evalAmount('1200+450'), 1650);
      expect(evalAmount('1000-150'), 850);
      expect(evalAmount('100+50-25'), 125);
    });

    test('handles multiplication and division', () {
      expect(evalAmount('3*4'), 12);
      expect(evalAmount('10/4'), 2.5);
      expect(evalAmount('2+3*4'), 14);
    });

    test('handles parentheses and unary minus', () {
      expect(evalAmount('(2+3)*4'), 20);
      expect(evalAmount('-5+10'), 5);
    });

    test('returns null on invalid input', () {
      expect(evalAmount('abc'), isNull);
      expect(evalAmount(''), isNull);
      expect(evalAmount('1/0'), isNull);
      expect(evalAmount('1++2'), isNull);
    });
  });
}
