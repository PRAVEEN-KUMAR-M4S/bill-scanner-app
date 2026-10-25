import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Labelled text input styled as an inked paper field.
class PaperTextField extends StatelessWidget {
  const PaperTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.labelTrailing,
    this.labelStyle,
    this.prefixText,
    this.errorText,
  }) : assert(
         controller == null || initialValue == null,
         'Use either a controller or an initial value, not both.',
       );

  /// Caption above the field. Omit it for inputs that sit under their own
  /// heading (the item name on the review form).
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? labelTrailing;

  /// Overrides the display-font label (the review form uses mono captions).
  final TextStyle? labelStyle;

  /// Small symbol shown inside the field, e.g. `₹`.
  final String? prefixText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: const BorderSide(color: AppColors.ink, width: AppStroke.base),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label!,
                  style:
                      labelStyle ??
                      AppFonts.display(size: 13, weight: FontWeight.w700),
                ),
              ),
              ?labelTrailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          validator: validator,
          onChanged: onChanged,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onFieldSubmitted,
          style: AppFonts.display(size: 15),
          cursorColor: AppColors.ink,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            hintText: hint,
            hintStyle: AppFonts.display(size: 15, color: AppColors.inkFaint),
            prefixText: prefixText,
            prefixStyle: AppFonts.display(size: 15, color: AppColors.ink),
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(
                color: AppColors.ink,
                width: AppStroke.base * 1.5,
              ),
            ),
            errorBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            errorStyle: AppFonts.display(size: 12, color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}
