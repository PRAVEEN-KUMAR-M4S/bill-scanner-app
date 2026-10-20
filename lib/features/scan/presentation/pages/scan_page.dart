import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_icon_button.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../review/presentation/pages/review_page.dart';
import '../bloc/scan_bloc.dart';
import '../bloc/scan_event.dart';
import '../bloc/scan_state.dart';
import '../widgets/capture_frame.dart';

/// The camera step of the scan flow.
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  static const String routeName = '/add-bill/camera';

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanBloc, ScanState>(
      listenWhen: (ScanState previous, ScanState current) =>
          previous is! ScanCaptured || current is! ScanCaptured,
      listener: (BuildContext context, ScanState state) {
        if (state is ScanCaptured) {
          Navigator.of(context).pushNamed(
            ReviewPage.routeName,
            arguments: state.bill,
          );
        } else if (state is ScanFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          context.read<ScanBloc>().add(const ScanResetRequested());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double sheetLimit = constraints.maxHeight * 0.52;

              return Column(
                children: <Widget>[
                  const _CameraTopBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.gutter,
                        vertical: AppSpacing.sm,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: const AspectRatio(
                            aspectRatio: 0.78,
                            child: _CaptureArea(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _EdgeHint(),
                  const SizedBox(height: AppSpacing.lg),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: sheetLimit),
                    child: const _CaptureSheet(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CaptureArea extends StatelessWidget {
  const _CaptureArea();

  @override
  Widget build(BuildContext context) {
    final bool scanning = context.select<ScanBloc, bool>(
      (ScanBloc bloc) => bloc.state is ScanScanning,
    );
    return CaptureFrame(isScanning: scanning);
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          PaperIconButton(
            icon: Icons.close,
            semanticLabel: 'Close camera',
            onPressed: () => Navigator.of(context).pop(),
            size: 44,
            circle: true,
            color: Colors.transparent,
            borderColor: AppColors.inkMuted,
            iconColor: AppColors.paper,
            elevated: false,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.inkDeep,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const SectionLabel(
                  'Bill camera',
                  color: AppColors.paper,
                  size: 9.5,
                  letterSpacing: 1.6,
                ),
              ],
            ),
          ),
          const Spacer(),
          PaperIconButton(
            icon: Icons.flash_off,
            semanticLabel: 'Flash off',
            onPressed: null,
            size: 44,
            circle: true,
            color: Colors.transparent,
            borderColor: AppColors.inkMuted,
            iconColor: AppColors.paper,
            elevated: false,
          ),
        ],
      ),
    );
  }
}

class _EdgeHint extends StatelessWidget {
  const _EdgeHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.inkDeep,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.open_with,
              size: 13,
              color: AppColors.paper,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                'Keep all four bill edges in frame',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.display(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureSheet extends StatelessWidget {
  const _CaptureSheet();

  @override
  Widget build(BuildContext context) {
    final ScanState state = context.watch<ScanBloc>().state;
    final bool scanning = state is ScanScanning;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    void allowCamera() {
      context.read<ScanBloc>().add(const ScanCameraAllowed());
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppLayout.gutter,
          10,
          AppLayout.gutter,
          AppSpacing.lg + bottomInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    const SectionLabel(
                      'Receipt scan',
                      color: AppColors.inkMuted,
                      size: 9.5,
                      letterSpacing: 1.6,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: SectionLabel(
                        scanning ? '02 / 02' : '01 / 02',
                        color: AppColors.inkMuted,
                        size: 9.5,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Turn on your camera.',
                  style: AppFonts.display(
                    size: 26,
                    weight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Billo uses the camera only while you take a bill photo. '
                  'Nothing is saved until you confirm it.',
                  style: AppFonts.display(
                    size: 12.5,
                    color: AppColors.inkMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool tight = constraints.maxWidth < 330;
                    final double circleSize = tight ? 46 : 52;
                    final double gap = tight ? AppSpacing.sm + 2 : AppSpacing.lg;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SheetCircleAction(
                          icon: Icons.photo_outlined,
                          label: 'Photos',
                          size: circleSize,
                          onPressed: scanning ? null : allowCamera,
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: PaperButton(
                              label: 'Allow camera',
                              icon: Icons.photo_camera_outlined,
                              isLoading: scanning,
                              padding: EdgeInsets.symmetric(
                                horizontal: tight
                                    ? AppSpacing.md
                                    : AppSpacing.lg,
                                vertical: AppSpacing.lg,
                              ),
                              onPressed: scanning ? null : allowCamera,
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        _SheetCircleAction(
                          icon: Icons.flip_camera_ios_outlined,
                          label: 'Flip',
                          size: circleSize,
                          onPressed: null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg - 2),
                Center(
                  child: InkWell(
                    onTap: scanning
                        ? null
                        : () => Navigator.of(context).pushNamed(
                            ReviewPage.routeName,
                            arguments: Bill.empty(date: DateTime.now()),
                          ),
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
                            size: 15,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              'Enter bill details without a photo',
                              textAlign: TextAlign.center,
                              style: AppFonts.display(
                                size: 12.5,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetCircleAction extends StatelessWidget {
  const _SheetCircleAction({
    required this.icon,
    required this.label,
    required this.size,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PaperIconButton(
          icon: icon,
          semanticLabel: label,
          onPressed: onPressed,
          size: size,
          iconSize: 20,
          circle: true,
          color: AppColors.surface,
          elevated: false,
        ),
        const SizedBox(height: 6),
        SectionLabel(
          label,
          size: 8,
          letterSpacing: 1.2,
          color: onPressed == null ? AppColors.inkFaint : AppColors.inkMuted,
        ),
      ],
    );
  }
}
