/// Rupee presentation for the app. Amounts are always shown to two decimals.
abstract final class Currency {
  /// `₹1,360.00` - the display form used on cards and bill rows.
  static String inr(double value) => '₹${amount(value)}';

  /// `1,360.00` - the form used inside inputs, where the symbol is separate.
  static String amount(double value) {
    final String fixed = value.abs().toStringAsFixed(2);
    final int dot = fixed.indexOf('.');
    final String whole = fixed.substring(0, dot);
    final String decimals = fixed.substring(dot);

    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final int remaining = whole.length - i;
      grouped.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) grouped.write(',');
    }

    return '${value < 0 ? '-' : ''}$grouped$decimals';
  }

  /// Parses a user-entered amount, tolerating spaces, commas and a `₹` prefix.
  static double? parse(String value) {
    final String cleaned = value.replaceAll('₹', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
