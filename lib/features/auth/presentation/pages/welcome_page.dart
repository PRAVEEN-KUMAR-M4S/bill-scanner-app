import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/section_label.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_page.dart';
import 'sign_in_page.dart';

/// Landing screen: brand, value proposition and the entry points into the app.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const String routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Scrolls on short phones; stays vertically centered on tall ones.
            final double minHeight = (constraints.maxHeight - AppSpacing.xxl)
                .clamp(0, double.infinity);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const BrandMark(
                          tileSize: 62,
                          showWordmark: true,
                          showTagline: true,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _QuoteCard(),
                        const SizedBox(height: AppSpacing.xl + 4),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (BuildContext context, AuthState state) {
                            final bool isLoading = state is AuthLoading;
                            return Column(
                              children: <Widget>[
                                PaperButton(
                                  label: 'Sign In',
                                  isLoading: isLoading,
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pushNamed(SignInPage.routeName),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                PaperButton(
                                  label: 'Join the Fold',
                                  variant: PaperButtonVariant.secondary,
                                  onPressed: isLoading
                                      ? null
                                      : () => Navigator.of(
                                          context,
                                        ).pushNamed(RegisterPage.routeName),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (BuildContext context, AuthState state) {
                            return _GuestEntry(isLoading: state is AuthLoading);
                          },
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Center(
                          child: SectionLabel(
                            'Paper-based AI interface • V1.0',
                            color: AppColors.inkFaint,
                            size: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The illustrated card holding the product's one-line pitch.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: <Widget>[
          const _PhoneIllustration(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '"Just snap a photo, and I\'ll do the math for you!"',
            textAlign: TextAlign.center,
            style: AppFonts.hand(size: 17),
          ),
        ],
      ),
    );
  }
}

/// Tilted phone outline with a camera badge - stands in for the exported art.
class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 74,
            height: 100,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.ink, width: AppStroke.base),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _line(0.5),
                _line(0.9),
                _line(0.75),
                _line(0.9),
                _line(0.45),
              ],
            ),
          ),
          Positioned(
            right: -10,
            bottom: -10,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.ink, width: AppStroke.base),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 16,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(double widthFactor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(height: 2, color: AppColors.inkFaint),
      ),
    );
  }
}

/// "Continue as guest" affordance shown under the primary actions.
class _GuestEntry extends StatelessWidget {
  const _GuestEntry({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () =>
                context.read<AuthBloc>().add(const AuthGuestSignInRequested()),
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 13, color: AppColors.inkMuted),
            SizedBox(width: AppSpacing.sm),
            SectionLabel(
              'Continue as guest',
              color: AppColors.inkMuted,
              letterSpacing: 1.8,
            ),
          ],
        ),
      ),
    );
  }
}
