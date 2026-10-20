import 'package:flutter/material.dart';

/// Palette for the paper-based "billscan" interface.
///
/// Values are sampled directly from the UX Pilot design exports.
abstract final class AppColors {
  /// Page background - warm paper.
  static const Color paper = Color(0xFFFFFBE4);

  /// Raised surface used by cards, inputs and buttons.
  static const Color surface = Color(0xFFFFFEF8);

  /// Primary ink used for text, borders and hard shadows.
  static const Color ink = Color(0xFF273047);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF6E7689);

  /// Faint text such as footers and hints.
  static const Color inkFaint = Color(0xFFA6ABBA);

  /// Primary accent.
  static const Color accent = Color(0xFFFFD84E);

  /// Tinted yellow used for large information cards.
  static const Color accentSoft = Color(0xFFFFF0A8);

  /// Cool tint behind icons and small pills.
  static const Color lavender = Color(0xFFE9EDFF);

  /// Deeper ink used for pills and controls on the dark camera screen.
  static const Color inkDeep = Color(0xFF1D2433);

  /// Hairline used inside the dark camera screen.
  static const Color nightLine = Color(0xFF4A5168);

  /// Validation success (the "Ready" checks on the review screen).
  static const Color success = Color(0xFF3E8E4E);

  /// Validation failure.
  static const Color danger = Color(0xFFB3261E);
}
