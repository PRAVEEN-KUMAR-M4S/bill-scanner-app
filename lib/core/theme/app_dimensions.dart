import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing steps used across the app.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii for paper surfaces.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 24;

  /// Fully rounded pills and circles.
  static const double pill = 999;
}

/// Border widths for the inked outlines.
abstract final class AppStroke {
  static const double thin = 1.2;
  static const double base = 1.6;
  static const double heavy = 2;
}

/// Hard, offset shadows that give surfaces their printed look.
abstract final class AppShadows {
  static const List<BoxShadow> small = <BoxShadow>[
    BoxShadow(color: AppColors.ink, offset: Offset(2, 2), blurRadius: 0),
  ];

  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: AppColors.ink, offset: Offset(3, 4), blurRadius: 0),
  ];
}

/// Responsive frame shared by every post-login page.
abstract final class AppLayout {
  /// Content never grows wider than this, even on a tablet.
  static const double maxContentWidth = 560;

  /// Above this width the page gets generous gutters and multi-column rows.
  static const double wideBreakpoint = 720;

  /// Horizontal page gutter on phones.
  static const double gutter = 20;

  /// Horizontal page gutter on wide screens.
  static const double wideGutter = 32;

  /// Height of the bottom navigation bar.
  static const double navHeight = 64;
}
