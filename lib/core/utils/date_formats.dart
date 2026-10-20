/// Date presentation used by the bills screens.
///
/// The app only shows two shapes: the "OCTOBER 2026" month heading, the
/// "1 Oct" stamp on a bill row, plus the ISO value edited on the review form.
abstract final class DateFormats {
  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _longMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// `OCTOBER 2026` - the uppercase eyebrow above the dashboard total.
  static String monthYear(DateTime date) {
    return '${_longMonths[date.month - 1].toUpperCase()} ${date.year}';
  }

  /// `1 Oct` - the compact stamp on a bill row.
  static String shortDay(DateTime date) {
    return '${date.day} ${_shortMonths[date.month - 1]}';
  }

  /// `2026-10-01` - the editable ISO value on the review form.
  static String iso(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Parses an ISO `yyyy-MM-dd` value, returning null when it is not a date.
  static DateTime? parseIso(String value) {
    final Match? match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(
      value.trim(),
    );
    if (match == null) return null;

    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final DateTime parsed = DateTime(year, month, day);
    // Reject rolled-over dates such as 2026-02-31.
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  /// Single-letter weekday used by the seven-day strip.
  static String weekdayInitial(DateTime date) {
    const List<String> initials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return initials[date.weekday - 1];
  }
}
