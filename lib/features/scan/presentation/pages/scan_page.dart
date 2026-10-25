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
import '../../domain/entities/scan_source.dart';
import '../bloc/scan_bloc.dart';
import '../bloc/scan_event.dart';
import '../bloc/scan_state.dart';
import '../camera/camera_driver.dart';
import '../widgets/capture_frame.dart';

/// The camera step of the scan flow.
///
/// The screen opens, the bloc asks for camera access, the preview appears in
/// the frame and the shutter goes live. Pressing it sends the photo through the
/// scanner behind a loader, then the draft lands on the review screen.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.source = ScanSource.camera});

  static const String routeName = '/add-bill/camera';

  /// Camera by default; the gallery shortcut opens the same screen with
  /// [ScanSource.gallery] so the copy and picker match.
  final ScanSource source;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  @override
  void initState() {
    super.initState();
    if (widget.source == ScanSource.camera) {
      // Ask for access the way a camera app does: as soon as it opens. The
      // sheet keeps its "Allow camera" button as the retry.
      context.read<ScanBloc>().add(const ScanCameraRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanBloc, ScanState>(
      listenWhen: (ScanState previous, ScanState current) =>
          previous is! ScanCaptured || current is! ScanCaptured,
      listener: (BuildContext context, ScanState state) {
        if (state is ScanCaptured) {
          // Land back on a live preview when the person returns from review.
          context.read<ScanBloc>().add(const ScanResetRequested());
          Navigator.of(
            context,
          ).pushNamed(ReviewPage.routeName, arguments: state.report);
        } else if (state is ScanFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          context.read<ScanBloc>().add(const ScanResetRequested());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Short phones give the preview more of the screen; the sheet
              // scrolls, the frame never shrinks below a usable size.
              final double sheetLimit =
                  constraints.maxHeight *
                  (constraints.maxHeight < 640 ? 0.44 : 0.52);

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
                    child: _CaptureSheet(source: widget.source),
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
    final ScanBloc bloc = context.read<ScanBloc>();
    final ScanState state = context.watch<ScanBloc>().state;
    final CameraDriver camera = bloc.camera;

    // The preview follows the driver, so it stays on - dimmed under the
    // loader - while the photo is being read.
    final Widget? preview = camera.status == CameraStatus.live
        ? camera.buildPreview(context)
        : null;

    final String? status = switch (state) {
      ScanStarting() => 'Starting the camera…',
      ScanBlocked(:final String message) => message,
      _ => null,
    };
    final bool busy = state is ScanStarting;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CaptureFrame(
          preview: preview,
          status: status,
          icon: state is ScanBlocked
              ? Icons.camera_alt_outlined
              : Icons.document_scanner_outlined,
          busy: busy,
        ),
        if (state is ScanScanning) const _ReadingOverlay(),
      ],
    );
  }
}

/// The loader shown while the photo travels through the scanner.
class _ReadingOverlay extends StatelessWidget {
  const _ReadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF01D2433),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reading your bill…',
              textAlign: TextAlign.center,
              style: AppFonts.display(
                size: 15,
                weight: FontWeight.w800,
                color: AppColors.paper,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sending the photo to the scanner.',
              textAlign: TextAlign.center,
              style: AppFonts.display(size: 11.5, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTopBar extends StatelessWidget {
  const _CameraTopBar();

  @override
  Widget build(BuildContext context) {
    final ScanBloc bloc = context.read<ScanBloc>();
    final ScanState state = context.watch<ScanBloc>().state;
    final CameraDriver camera = bloc.camera;
    final bool live = state is ScanLive;
    final bool flashOn = state is ScanLive && state.flashOn;

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
            icon: flashOn ? Icons.flash_on : Icons.flash_off,
            semanticLabel: flashOn ? 'Flash on' : 'Flash off',
            onPressed: live && camera.hasFlash
                ? () => bloc.add(const ScanFlashToggled())
                : null,
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
            const Icon(Icons.open_with, size: 13, color: AppColors.paper),
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
  const _CaptureSheet({required this.source});

  final ScanSource source;

  @override
  Widget build(BuildContext context) {
    final ScanBloc bloc = context.read<ScanBloc>();
    final ScanState state = context.watch<ScanBloc>().state;
    final CameraDriver camera = bloc.camera;
    final bool scanning = state is ScanScanning;
    final bool live = state is ScanLive;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final bool fromGallery = source == ScanSource.gallery;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                  fromGallery ? 'Choose a bill photo.' : 'Turn on your camera.',
                  style: AppFonts.display(
                    size: 26,
                    weight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _helperText(state, fromGallery),
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
                    final double gap = tight
                        ? AppSpacing.sm + 2
                        : AppSpacing.lg;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SheetCircleAction(
                          icon: Icons.photo_outlined,
                          label: 'Photos',
                          size: circleSize,
                          onPressed: scanning
                              ? null
                              : () => bloc.add(
                                  const ScanCaptureRequested(
                                    ScanSource.gallery,
                                  ),
                                ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _PrimaryAction(
                            state: state,
                            fromGallery: fromGallery,
                            tight: tight,
                            onCapture: () =>
                                bloc.add(const ScanShutterPressed()),
                            onAllowCamera: () =>
                                bloc.add(const ScanCameraRequested()),
                            onChoosePhoto: () => bloc.add(
                              const ScanCaptureRequested(ScanSource.gallery),
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        _SheetCircleAction(
                          icon: Icons.flip_camera_ios_outlined,
                          label: 'Flip',
                          size: circleSize,
                          onPressed: scanning || !live || !camera.canFlip
                              ? null
                              : () => bloc.add(const ScanFlipRequested()),
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

  /// The paragraph under the title, which explains whatever state the camera
  /// is actually in.
  static String _helperText(ScanState state, bool fromGallery) {
    if (fromGallery) {
      return 'Pick a clear JPG or PNG of the bill. Nothing is saved until '
          'you confirm it.';
    }
    return switch (state) {
      ScanLive() =>
        'Keep the whole receipt in frame, then tap capture. Nothing is saved '
            'until you confirm it.',
      ScanBlocked(:final String message)
          when message == ScanBloc.deniedMessage =>
        'Camera access is off. Allow it in your phone settings, then tap '
            'Allow camera - or pick a photo instead.',
      ScanBlocked() =>
        'No camera here? Pick a photo from your library instead.',
      _ =>
        'Billo uses the camera only while you take a bill photo. Nothing '
            'is saved until you confirm it.',
    };
  }
}

/// The middle of the action row: the shutter once the preview is running, the
/// access button before that, and the loading button while the API works.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.state,
    required this.fromGallery,
    required this.tight,
    required this.onCapture,
    required this.onAllowCamera,
    required this.onChoosePhoto,
  });

  final ScanState state;
  final bool fromGallery;
  final bool tight;
  final VoidCallback onCapture;
  final VoidCallback onAllowCamera;
  final VoidCallback onChoosePhoto;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: tight ? AppSpacing.md : AppSpacing.lg,
      vertical: AppSpacing.lg,
    );

    if (state is ScanScanning) {
      return PaperButton(
        label: 'Reading your bill…',
        isLoading: true,
        padding: padding,
        onPressed: null,
      );
    }

    if (state is ScanLive) {
      return Center(
        child: _SheetCircleAction(
          icon: Icons.camera_alt,
          label: 'Capture',
          size: tight ? 54 : 64,
          accent: true,
          onPressed: onCapture,
        ),
      );
    }

    if (state is ScanStarting) {
      return PaperButton(
        label: 'Starting camera…',
        isLoading: true,
        padding: padding,
        onPressed: null,
      );
    }

    if (fromGallery) {
      return PaperButton(
        label: 'Choose photo',
        icon: Icons.image_outlined,
        padding: padding,
        onPressed: onChoosePhoto,
      );
    }

    return PaperButton(
      label: 'Allow camera',
      icon: Icons.photo_camera_outlined,
      padding: padding,
      onPressed: onAllowCamera,
    );
  }
}

class _SheetCircleAction extends StatelessWidget {
  const _SheetCircleAction({
    required this.icon,
    required this.label,
    required this.size,
    this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback? onPressed;

  /// Yellow, filled circle: the shutter.
  final bool accent;

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
          iconSize: accent ? 28 : 20,
          circle: true,
          color: accent ? AppColors.accent : AppColors.surface,
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
