import 'package:intl/intl.dart';

class Fmt {
  static String currency(double amount, {String symbol = '₽', int decimals = 0}) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: symbol,
      decimalDigits: decimals,
    );
    return formatter.format(amount).replaceAll('\u00A0', ' ');
  }

  static String number(double v, {int decimals = 0}) {
    return NumberFormat.decimalPattern('ru_RU').format(
      decimals == 0 ? v.round() : double.parse(v.toStringAsFixed(decimals)),
    );
  }

  static String date(DateTime d, {String pattern = 'd MMMM', String locale = 'ru'}) {
    return DateFormat(pattern, locale).format(d);
  }

  static String shortDate(DateTime d, {String locale = 'ru'}) {
    return DateFormat('d MMM', locale).format(d);
  }

  static String time(DateTime d) => DateFormat('HH:mm').format(d);

  static String monthName(DateTime d, {String locale = 'ru'}) =>
      DateFormat('LLLL', locale).format(d);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isYesterday(DateTime a, DateTime now) {
    final y = now.subtract(const Duration(days: 1));
    return isSameDay(a, y);
  }
}
