import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Small icon button used for back navigation, header actions and camera
/// controls.
///
/// The default square, bordered, shadowed chip matches the auth screens; pass
/// [circle] and [elevated] for the round controls in the header and camera.
class PaperIconButton extends StatelessWidget {
  const PaperIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 20,
    this.color = AppColors.surface,
    this.iconColor,
    this.borderColor,
    this.circle = false,
    this.elevated = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color color;

  /// Defaults to [AppColors.ink], or to the faint ink when disabled.
  final Color? iconColor;

  /// `null` draws no outline.
  final Color? borderColor;
  final bool circle;
  final bool elevated;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final double radius = circle ? AppRadius.pill : AppRadius.sm;
    final Color resolvedBorder = borderColor ?? AppColors.ink;
    final Color resolvedIcon =
        iconColor ?? (_enabled ? AppColors.ink : AppColors.inkFaint);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor == null
                ? null
                : Border.all(
                    color: _enabled ? resolvedBorder : AppColors.inkFaint,
                    width: AppStroke.base,
                  ),
            boxShadow: elevated ? AppShadows.small : null,
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: _enabled ? resolvedIcon : AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}
