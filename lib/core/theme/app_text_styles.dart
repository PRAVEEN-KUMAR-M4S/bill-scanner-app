import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography for the paper-based interface.
///
/// [display] is the chunky rounded face used for headings and copy,
/// [label] is the monospace face used for uppercase technical labels and
/// [hand] is the handwritten face used inside the quote bubble.
abstract final class AppFonts {
  static TextStyle display({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = 1.25,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.baloo2(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle label({
    double size = 11,
    Color color = AppColors.ink,
    double letterSpacing = 1.4,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.spaceMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle hand({double size = 12, Color color = AppColors.ink}) {
    return GoogleFonts.caveat(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.05,
    );
  }
}
