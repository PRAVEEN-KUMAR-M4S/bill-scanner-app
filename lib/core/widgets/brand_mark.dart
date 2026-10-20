import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'section_label.dart';

/// The yellow app tile, optionally stacked above the product wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.tileSize = 56,
    this.showWordmark = false,
    this.showTagline = false,
  });

  final double tileSize;
  final bool showWordmark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: AppStroke.base * 1.25),
        boxShadow: AppShadows.medium,
      ),
      child: Icon(
        Icons.document_scanner_outlined,
        size: tileSize * 0.5,
        color: AppColors.ink,
      ),
    );

    if (!showWordmark && !showTagline) return tile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        tile,
        const SizedBox(height: AppSpacing.md),
        if (showWordmark)
          Text(
            'Billscan AI',
            style: AppFonts.display(size: 26, weight: FontWeight.w800),
          ),
        if (showTagline) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          const SectionLabel(
            'Your expenses, handled.',
            color: AppColors.inkMuted,
            letterSpacing: 2,
          ),
        ],
      ],
    );
  }
}
