import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/action_tile.dart';
import '../../../../core/widgets/page_scaffold.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../review/presentation/pages/review_page.dart';
import '../../domain/entities/scan_source.dart';
import 'scan_page.dart';
import '../widgets/scanner_illustration.dart';

/// Entry point of the capture flow: photo, library, manual entry or a sample.
class AddBillPage extends StatelessWidget {
  const AddBillPage({super.key, required this.sampleBill});

  static const String routeName = '/add-bill';

  /// Bundled demo bill supplied by the injector.
  final Bill sampleBill;

  void _openScan(BuildContext context, ScanSource source) {
    Navigator.of(context).pushNamed(ScanPage.routeName, arguments: source);
  }

  void _openReview(BuildContext context, Bill bill) {
    Navigator.of(context).pushNamed(ReviewPage.routeName, arguments: bill);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: PageScaffold(
        children: <Widget>[
          ScreenHeader(
            title: 'Add a bill',
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.xl + 4),
          const Center(child: ScannerIllustration()),
          const SizedBox(height: AppSpacing.xl),
          Text(
            "Let's get this\nbill in order.",
            textAlign: TextAlign.center,
            style: AppFonts.display(
              size: 33,
              weight: FontWeight.w800,
              height: 1.06,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Add a clear photo, then check the details before anything is '
              'saved.',
              textAlign: TextAlign.center,
              style: AppFonts.display(
                size: 12.8,
                color: AppColors.inkMuted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PaperButton(
            label: 'Take a photo',
            icon: Icons.photo_camera_outlined,
            trailingIcon: Icons.arrow_outward,
            alignStart: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg - 2,
            ),
            onPressed: () => _openScan(context, ScanSource.camera),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          PaperButton(
            label: 'Choose from library',
            icon: Icons.image_outlined,
            trailingIcon: Icons.chevron_right,
            variant: PaperButtonVariant.secondary,
            alignStart: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg - 2,
            ),
            onPressed: () => _openScan(context, ScanSource.gallery),
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          const _OrDivider(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Semantics(
              button: true,
              label: 'Enter details manually',
              child: InkWell(
                onTap: () =>
                    _openReview(context, Bill.empty(date: DateTime.now())),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Enter details manually',
                          textAlign: TextAlign.center,
                          style: AppFonts.display(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl + 2),
          ActionTile(
            icon: Icons.visibility_outlined,
            title: 'Just looking around?',
            subtitle: 'Open a sample bill to preview the review form.',
            onTap: () => _openReview(context, sampleBill),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                size: 13,
                color: AppColors.inkFaint,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Your bills stay on this device.',
                  textAlign: TextAlign.center,
                  style: AppFonts.display(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.inkFaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Divider(
            color: AppColors.ink,
            thickness: AppStroke.thin,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SectionLabel(
            'OR',
            color: AppColors.inkMuted,
            size: 9,
            letterSpacing: 1.8,
          ),
        ),
        const Expanded(
          child: Divider(
            color: AppColors.ink,
            thickness: AppStroke.thin,
            height: 1,
          ),
        ),
      ],
    );
  }
}
