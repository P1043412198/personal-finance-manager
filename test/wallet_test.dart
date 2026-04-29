import 'package:flutter_test/flutter_test.dart';

import 'package:personal_finance/models/transaction.dart';
import 'package:personal_finance/models/wallet.dart';

void main() {
  group('WalletModel JSON round-trip', () {
    test('preserves all fields', () {
      final w = WalletModel(
        id: 'w1',
        name: 'Alfa Card',
        kind: WalletKind.card,
        currency: 'BYN',
        initialBalance: 250.5,
        iconKey: 'card',
        colorValue: 0xFF1976D2,
        archived: false,
        sortIndex: 3,
        createdAt: DateTime.utc(2024, 6, 1),
      );
      final j = w.toJson();
      final back = WalletModel.fromJson(j);
      expect(back.id, w.id);
      expect(back.name, w.name);
      expect(back.kind, w.kind);
      expect(back.currency, w.currency);
      expect(back.initialBalance, w.initialBalance);
      expect(back.iconKey, w.iconKey);
      expect(back.colorValue, w.colorValue);
      expect(back.archived, w.archived);
      expect(back.sortIndex, w.sortIndex);
      expect(back.createdAt, w.createdAt);
    });

    test('legacy wallet missing fields gets defaults', () {
      final j = {
        'id': 'w0',
        'name': 'Old',
        'createdAt': DateTime.utc(2020).toIso8601String(),
      };
      final w = WalletModel.fromJson(j);
      expect(w.kind, WalletKind.card);
      expect(w.currency, '₽');
      expect(w.initialBalance, 0);
      expect(w.sortIndex, 0);
      expect(w.archived, false);
    });
  });

  group('TransactionModel walletId round-trip', () {
    test('walletId persists when set', () {
      final t = TransactionModel(
        id: 't1',
        type: TxType.expense,
        amount: 12.5,
        date: DateTime.utc(2025, 3, 14),
        walletId: 'w42',
      );
      final back = TransactionModel.fromJson(t.toJson());
      expect(back.walletId, 'w42');
    });

    test('walletId null on legacy transactions', () {
      final j = {
        'id': 't0',
        'type': 'expense',
        'amount': 10,
        'date': DateTime.utc(2024).toIso8601String(),
        'method': 'card',
      };
      final back = TransactionModel.fromJson(j);
      expect(back.walletId, isNull);
    });
  });
}
