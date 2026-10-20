import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// A section title with an optional caption and a trailing action.
///
/// Used by the dashboard ("Recent bills"), the bills list ("All bills") and the
/// review form ("Items").
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleSize = 22,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: AppFonts.display(
                  size: titleSize,
                  weight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: AppFonts.display(
              size: 11.5,
              color: AppColors.inkMuted,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
