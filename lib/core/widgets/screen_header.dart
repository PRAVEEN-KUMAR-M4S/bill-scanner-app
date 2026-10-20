import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Back arrow, title, optional caption and a trailing control.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.titleSize = 21,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (onBack != null) ...<Widget>[
          Semantics(
            button: true,
            label: 'Back',
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: const SizedBox(
                width: 32,
                height: 28,
                child: Icon(
                  Icons.arrow_back,
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: AppFonts.display(
                  size: titleSize,
                  weight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppFonts.display(
                    size: 11.5,
                    color: AppColors.inkMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}
