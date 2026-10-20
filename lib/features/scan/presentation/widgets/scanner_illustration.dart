import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// The tinted rounded square on the add-bill screen: a paper receipt with a
/// camera badge, composed from widgets rather than an exported image.
class ScannerIllustration extends StatelessWidget {
  const ScannerIllustration({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
          ),
          Center(
            child: Container(
              width: size * 0.46,
              height: size * 0.56,
              padding: EdgeInsets.symmetric(
                horizontal: size * 0.075,
                vertical: size * 0.07,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(size * 0.055),
                border: Border.all(
                  color: AppColors.ink,
                  width: AppStroke.base,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: size * 0.07,
                    height: size * 0.07,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(height: size * 0.055),
                  _ReceiptLine(width: size * 0.20),
                  SizedBox(height: size * 0.038),
                  _ReceiptLine(width: size * 0.26),
                  SizedBox(height: size * 0.038),
                  _ReceiptLine(width: size * 0.22),
                  SizedBox(height: size * 0.038),
                  _ReceiptLine(width: size * 0.12),
                ],
              ),
            ),
          ),
          Positioned(
            right: size * 0.18,
            bottom: size * 0.19,
            child: Container(
              width: size * 0.30,
              height: size * 0.30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: AppStroke.base),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: size * 0.16,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2.6,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
