import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/models/debt.dart';

void main() {
  DebtPayment payment(double a) => DebtPayment(
        id: 'p$a',
        amount: a,
        date: DateTime.utc(2025, 1, 1),
      );

  group('DebtModel calculations', () {
    test('paid is sum of payments', () {
      final d = DebtModel(
        id: 'd1',
        counterparty: 'Иван',
        direction: DebtDirection.youOwe,
        amount: 500,
        createdAt: DateTime.utc(2025, 1, 1),
        payments: [payment(100), payment(50.5)],
      );
      expect(d.paid, closeTo(150.5, 1e-6));
      expect(d.remaining, closeTo(349.5, 1e-6));
      expect(d.isPaid, false);
    });

    test('isPaid when fully repaid', () {
      final d = DebtModel(
        id: 'd2',
        counterparty: 'Bank',
        direction: DebtDirection.youOwe,
        amount: 200,
        createdAt: DateTime.utc(2025, 1, 1),
        payments: [payment(120), payment(80)],
      );
      expect(d.isPaid, true);
      expect(d.remaining, 0);
    });

    test('overpayment clamps remaining at zero', () {
      final d = DebtModel(
        id: 'd3',
        counterparty: 'X',
        direction: DebtDirection.owesYou,
        amount: 100,
        createdAt: DateTime.utc(2025, 1, 1),
        payments: [payment(150)],
      );
      expect(d.remaining, 0);
      expect(d.isPaid, true);
    });
  });

  group('DebtModel JSON round-trip', () {
    test('preserves all fields including payments', () {
      final d = DebtModel(
        id: 'd1',
        counterparty: 'Анна',
        direction: DebtDirection.owesYou,
        amount: 500.5,
        currency: 'BYN',
        createdAt: DateTime.utc(2025, 3, 1),
        dueDate: DateTime.utc(2025, 4, 1),
        note: 'concert tickets',
        payments: [payment(100), payment(50)],
      );
      final back = DebtModel.fromJson(d.toJson());
      expect(back.counterparty, 'Анна');
      expect(back.direction, DebtDirection.owesYou);
      expect(back.amount, 500.5);
      expect(back.currency, 'BYN');
      expect(back.dueDate, DateTime.utc(2025, 4, 1));
      expect(back.note, 'concert tickets');
      expect(back.payments.length, 2);
      expect(back.paid, 150);
    });

    test('legacy debt without payments field works', () {
      final j = {
        'id': 'd0',
        'counterparty': 'Old',
        'direction': 'youOwe',
        'amount': 100,
        'createdAt': DateTime.utc(2024).toIso8601String(),
      };
      final d = DebtModel.fromJson(j);
      expect(d.payments, isEmpty);
      expect(d.remaining, 100);
    });
  });
}
