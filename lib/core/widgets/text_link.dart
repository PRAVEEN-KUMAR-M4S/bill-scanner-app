import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Inline text action underlined with the accent colour.
class TextLink extends StatelessWidget {
  const TextLink(
    this.label, {
    super.key,
    this.onTap,
    this.size = 14,
    this.color = AppColors.ink,
    this.weight = FontWeight.w600,
  });

  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppFonts.display(size: size, weight: weight, color: color)
            .copyWith(
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
              decorationThickness: 2.5,
            ),
      ),
    );
  }
}
