import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Visual weight of a [PaperButton].
enum PaperButtonVariant {
  /// Yellow, filled and raised - the single primary action on a screen.
  primary,

  /// White surface with an inked outline - secondary actions.
  secondary,

  /// Borderless text action.
  ghost,
}

/// Chunky paper button that presses into its own shadow.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = PaperButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.alignStart = false,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final PaperButtonVariant variant;
  final bool isLoading;
  final bool expand;

  /// Left-aligns the label and pushes [trailingIcon] to the far edge.
  final bool alignStart;
  final EdgeInsetsGeometry padding;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool raised = widget.variant != PaperButtonVariant.ghost;
    final Color background = switch (widget.variant) {
      PaperButtonVariant.primary => AppColors.accent,
      PaperButtonVariant.secondary => AppColors.surface,
      PaperButtonVariant.ghost => Colors.transparent,
    };

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.expand ? double.infinity : null,
          transform: Matrix4.translationValues(
            _pressed ? 3 : 0,
            _pressed ? 4 : 0,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: raised
                ? Border.all(color: AppColors.ink, width: AppStroke.base)
                : null,
            boxShadow: raised && !_pressed ? AppShadows.medium : null,
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: widget.alignStart
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: <Widget>[
              if (widget.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.ink,
                  ),
                )
              else ...<Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 18, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (widget.alignStart)
                  Expanded(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.display(
                        size: 15,
                        weight: FontWeight.w700,
                        color: _enabled ? AppColors.ink : AppColors.inkFaint,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.display(
                        size: 15,
                        weight: FontWeight.w700,
                        color: _enabled ? AppColors.ink : AppColors.inkFaint,
                      ),
                    ),
                  ),
                if (widget.trailingIcon != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    widget.trailingIcon,
                    size: 18,
                    color: _enabled ? AppColors.ink : AppColors.inkFaint,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
