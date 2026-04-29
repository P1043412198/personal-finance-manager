import '../models/recurring.dart';

/// Last day-of-month for the given year/month (handles Feb 28/29).
int lastDayOfMonth(int year, int month) {
  final firstNext = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return firstNext.subtract(const Duration(days: 1)).day;
}

DateTime _date(int y, int m, int d) {
  final last = lastDayOfMonth(y, m);
  return DateTime(y, m, d > last ? last : d);
}

/// Compute the next due date strictly AFTER `from` for the given rule.
/// Returns null if the rule has ended or has no further occurrences.
DateTime? nextDue(RecurringRule r, DateTime from) {
  if (!r.active) return null;
  // Normalise to date-only.
  final start = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
  final end = r.endDate == null
      ? null
      : DateTime(r.endDate!.year, r.endDate!.month, r.endDate!.day);
  final f = DateTime(from.year, from.month, from.day);

  DateTime candidate;
  switch (r.freq) {
    case RecurFreq.daily:
      candidate = f.isBefore(start) ? start : f.add(const Duration(days: 1));
      break;
    case RecurFreq.weekly:
      final dow = (r.dayOfWeek ?? start.weekday).clamp(1, 7);
      // walk forward day-by-day from max(start, f+1)
      var c = f.isBefore(start) ? start : f.add(const Duration(days: 1));
      while (c.weekday != dow) {
        c = c.add(const Duration(days: 1));
      }
      candidate = c;
      break;
    case RecurFreq.monthly:
      final dom = (r.dayOfMonth ?? start.day).clamp(1, 31);
      var y = f.year;
      var m = f.month;
      var c = _date(y, m, dom);
      // If c <= f or before start, advance.
      while (!c.isAfter(f) || c.isBefore(start)) {
        m += 1;
        if (m > 12) {
          m = 1;
          y += 1;
        }
        c = _date(y, m, dom);
      }
      candidate = c;
      break;
    case RecurFreq.yearly:
      final mo = (r.monthOfYear ?? start.month).clamp(1, 12);
      final dom = (r.dayOfMonth ?? start.day).clamp(1, 31);
      var y = f.year;
      var c = _date(y, mo, dom);
      while (!c.isAfter(f) || c.isBefore(start)) {
        y += 1;
        c = _date(y, mo, dom);
      }
      candidate = c;
      break;
  }

  if (end != null && candidate.isAfter(end)) return null;
  return candidate;
}

/// All due dates strictly AFTER `from` and on/before `until` (inclusive).
/// Used both for auto-applying past-due rules at startup and for projecting
/// upcoming recurring transactions in the EOM forecast.
List<DateTime> dueDatesBetween(RecurringRule r, DateTime from, DateTime until) {
  final out = <DateTime>[];
  var cursor = from;
  for (var i = 0; i < 1000; i++) {
    final n = nextDue(r, cursor);
    if (n == null) break;
    if (n.isAfter(until)) break;
    out.add(n);
    cursor = n;
  }
  return out;
}
