import '../../../../core/utils/date_formats.dart';
import 'bill.dart';

/// One day of the dashboard's seven-day strip.
class DaySpend {
  const DaySpend({
    required this.date,
    required this.label,
    required this.amount,
  });

  final DateTime date;

  /// Single-letter weekday initial shown below the bar.
  final String label;
  final double amount;
}

/// Figures derived from the saved bills for the dashboard and bills header.
class BillSummary {
  const BillSummary({
    required this.spentThisMonth,
    required this.billCountThisMonth,
    required this.lastSevenDays,
  });

  factory BillSummary.fromBills(List<Bill> bills, DateTime today) {
    final int year = today.year;
    final int month = today.month;

    double spent = 0;
    int count = 0;
    for (final Bill bill in bills) {
      if (bill.date.year == year && bill.date.month == month) {
        spent += bill.total;
        count++;
      }
    }

    final DateTime start = DateTime(
      year,
      month,
      today.day,
    ).subtract(const Duration(days: 6));
    final List<DaySpend> week = <DaySpend>[];
    for (int offset = 0; offset < 7; offset++) {
      final DateTime day = DateTime(
        start.year,
        start.month,
        start.day + offset,
      );
      double dayTotal = 0;
      for (final Bill bill in bills) {
        if (bill.date.year == day.year &&
            bill.date.month == day.month &&
            bill.date.day == day.day) {
          dayTotal += bill.total;
        }
      }
      week.add(
        DaySpend(
          date: day,
          label: DateFormats.weekdayInitial(day),
          amount: dayTotal,
        ),
      );
    }

    return BillSummary(
      spentThisMonth: spent,
      billCountThisMonth: count,
      lastSevenDays: week,
    );
  }

  final double spentThisMonth;
  final int billCountThisMonth;
  final List<DaySpend> lastSevenDays;

  /// Largest day total in the strip; 0 when nothing was spent this week.
  double get peakDaySpend => lastSevenDays.fold<double>(
    0,
    (double max, DaySpend day) => day.amount > max ? day.amount : max,
  );
}
