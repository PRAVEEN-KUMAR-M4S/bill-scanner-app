import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Uppercase monospace caption used for eyebrow labels and metadata.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color = AppColors.ink,
    this.size = 11,
    this.letterSpacing = 1.4,
  });

  final String text;
  final Color color;
  final double size;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.label(
        size: size,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
