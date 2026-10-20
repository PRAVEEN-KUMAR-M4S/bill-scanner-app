import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// Responsive frame for a scrolling paper page.
///
/// Content is centered and capped at [AppLayout.maxContentWidth] so the same
/// layout reads correctly on a 320px phone and on a tablet, with gutters that
/// grow on wide screens.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.children,
    this.maxWidth = AppLayout.maxContentWidth,
    this.topPadding = AppSpacing.xl,
    this.bottomPadding = AppSpacing.xxl,
  });

  final List<Widget> children;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= AppLayout.wideBreakpoint;
          final double gutter = wide ? AppLayout.wideGutter : AppLayout.gutter;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              topPadding,
              gutter,
              bottomPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
