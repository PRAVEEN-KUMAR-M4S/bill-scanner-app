import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/paper_icon_button.dart';

/// Explains that the list is cached or that saves are queued, with a retry.
///
/// Shared by Home and Bills so both screens say the same thing; it renders
/// nothing when the list is fresh and the queue is empty.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.isOffline,
    required this.pendingCount,
    required this.onRetry,
  });

  final bool isOffline;
  final int pendingCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!isOffline && pendingCount == 0) return const SizedBox.shrink();

    final String title = switch ((isOffline, pendingCount)) {
      (true, > 0) => 'Offline · ${_bills(pendingCount)} waiting to sync',
      (true, _) => 'Offline · showing saved bills',
      (false, _) => '${_bills(pendingCount)} waiting to sync',
    };

    final String detail = isOffline
        ? 'These rows come from this phone. New saves wait here until you reconnect.'
        : 'The server has not accepted them yet. Try again in a moment.';

    return PaperCard(
      color: AppColors.lavender,
      radius: AppRadius.md + 2,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: const <BoxShadow>[],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isOffline ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
            size: 20,
            color: AppColors.ink,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppFonts.display(
                    size: 12.5,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: AppFonts.display(
                    size: 10.5,
                    color: AppColors.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PaperIconButton(
            icon: Icons.refresh,
            semanticLabel: isOffline ? 'Retry connection' : 'Retry sync',
            onPressed: onRetry,
            size: 34,
            iconSize: 17,
            circle: true,
            elevated: false,
            color: AppColors.surface,
          ),
        ],
      ),
    );
  }

  static String _bills(int count) => count == 1 ? '1 bill' : '$count bills';
}
