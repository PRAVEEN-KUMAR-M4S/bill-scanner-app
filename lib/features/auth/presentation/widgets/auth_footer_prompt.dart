import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/text_link.dart';

/// The "New here? / Create account" style prompt that closes each auth form.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          prompt,
          style: AppFonts.display(size: 14, color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextLink(action, onTap: onTap),
      ],
    );
  }
}
