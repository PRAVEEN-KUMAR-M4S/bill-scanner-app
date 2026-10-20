import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Small outlined chip; the selected one fills with the accent.
///
/// Shared by the bills filter row and the review form's category picker.
class PaperChip extends StatelessWidget {
  const PaperChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            border: Border.all(
              color: AppColors.ink,
              width: selected ? AppStroke.base : AppStroke.thin,
            ),
          ),
          child: Text(
            label,
            style: AppFonts.display(
              size: 12.5,
              weight: FontWeight.w600,
              color: selected ? AppColors.ink : AppColors.inkMuted,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
