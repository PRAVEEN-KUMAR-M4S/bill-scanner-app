import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The framed capture area on the dark camera screen.
///
/// Draws the thin outline, the mid guide line and the four accent corner
/// brackets over whatever is behind it - the live preview when the camera is
/// running, nothing before that - and centers the status that tells the person
/// what the camera is doing.
class CaptureFrame extends StatelessWidget {
  const CaptureFrame({
    super.key,
    this.preview,
    this.status,
    this.icon = Icons.document_scanner_outlined,
    this.busy = false,
  });

  /// The live preview, shown under the brackets.
  final Widget? preview;

  /// Centered message; `null` keeps the default prompt.
  final String? status;

  /// Glyph above [status].
  final IconData icon;

  /// Adds the spinner under [status] while the camera starts.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (preview != null) Positioned.fill(child: ClipRect(child: preview!)),
        CustomPaint(painter: _CaptureFramePainter()),
        if (status != null || preview == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _FrameStatus(
                icon: icon,
                text: status ?? 'Your bill will appear here',
                busy: busy,
              ),
            ),
          ),
      ],
    );
  }
}

class _FrameStatus extends StatelessWidget {
  const _FrameStatus({
    required this.icon,
    required this.text,
    required this.busy,
  });

  final IconData icon;
  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.inkDeep,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.accent, width: AppStroke.thin),
          ),
          child: Icon(icon, color: AppColors.accent, size: 26),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppFonts.display(
            size: 12.5,
            weight: FontWeight.w700,
            color: AppColors.paper,
          ),
        ),
        if (busy) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ],
      ],
    );
  }
}

class _CaptureFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);

    final Paint outline = Paint()
      ..color = AppColors.nightLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawRect(frame, outline);

    // Mid guide: the receipt baseline sits on this line.
    canvas.drawLine(
      Offset(frame.left, frame.center.dy),
      Offset(frame.right, frame.center.dy),
      outline,
    );

    final Paint bracket = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;

    const double length = 30;
    final double left = frame.left;
    final double right = frame.right;
    final double top = frame.top;
    final double bottom = frame.bottom;

    canvas.drawLine(Offset(left, top), Offset(left + length, top), bracket);
    canvas.drawLine(Offset(left, top), Offset(left, top + length), bracket);

    canvas.drawLine(Offset(right, top), Offset(right - length, top), bracket);
    canvas.drawLine(Offset(right, top), Offset(right, top + length), bracket);

    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + length, bottom),
      bracket,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - length),
      bracket,
    );

    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - length, bottom),
      bracket,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - length),
      bracket,
    );
  }

  @override
  bool shouldRepaint(covariant _CaptureFramePainter oldDelegate) => false;
}
