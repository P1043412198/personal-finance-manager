import 'package:home_widget/home_widget.dart';

import '../models/transaction.dart';

/// Thin wrapper around `home_widget` that pushes the current month balance
/// to the Android home-screen widget. Calls are no-ops when the platform
/// channel is unavailable (e.g. on the unit-test VM, iOS, etc.).
class HomeWidgetService {
  static const _appGroupId = 'com.vibesight.personal_finance.widget';
  static const _providerName = 'PFMHomeWidgetProvider';

  static String _formatCurrency(double v, String symbol) {
    final negative = v < 0;
    final abs = v.abs();
    final whole = abs.truncate();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${negative ? '-' : ''}$buf $symbol';
  }

  /// Compute month income / expense / balance and push to the widget.
  /// Safe to call on every app-state mutation.
  static Future<void> push(List<TransactionModel> txs, {required String currency}) async {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final t in txs) {
      if (t.date.year != now.year || t.date.month != now.month) continue;
      if (t.type == TxType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final balance = income - expense;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      await HomeWidget.saveWidgetData<String>(
          'balance', _formatCurrency(balance, currency));
      await HomeWidget.saveWidgetData<String>(
          'income', _formatCurrency(income, currency));
      await HomeWidget.saveWidgetData<String>(
          'expense', _formatCurrency(expense, currency));
      await HomeWidget.saveWidgetData<String>('updated', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        name: _providerName,
        androidName: _providerName,
      );
    } catch (_) {
      // Widget plugin not registered (tests, iOS, etc.) — ignore.
    }
  }
}
