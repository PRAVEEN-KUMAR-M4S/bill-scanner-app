import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/action_tile.dart';
import '../../../../core/widgets/page_scaffold.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/paper_icon_button.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_summary.dart';
import '../../../bills/presentation/bloc/bills_bloc.dart';
import '../../../bills/presentation/bloc/bills_event.dart';
import '../../../bills/presentation/bloc/bills_state.dart';
import '../../../bills/presentation/widgets/bill_tile.dart';
import '../../../scan/presentation/pages/add_bill_page.dart';

/// Signed-in dashboard: this month's spend, the seven-day strip, a shortcut
/// into the capture flow and the latest bills.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSeeAllBills});

  final VoidCallback onSeeAllBills;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    return BlocBuilder<BillsBloc, BillsState>(
      builder: (BuildContext context, BillsState state) {
        return PageScaffold(
          children: <Widget>[
            _HomeTopBar(onProfile: () => _showProfile(context)),
            const SizedBox(height: AppSpacing.xl + 4),
            Text(
              'Your spending,\nat a glance.',
              style: AppFonts.display(
                size: 33,
                weight: FontWeight.w800,
                height: 1.08,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            SectionLabel(
              DateFormats.monthYear(now),
              size: 9.5,
              letterSpacing: 1.7,
              color: AppColors.inkMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state is BillsLoaded)
              ..._loaded(context, state, now)
            else if (state is BillsFailure)
              _DashboardFailure(
                message: state.message,
                onRetry: () =>
                    context.read<BillsBloc>().add(const BillsStarted()),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl + 8),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.ink),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _loaded(
    BuildContext context,
    BillsLoaded state,
    DateTime now,
  ) {
    final BillSummary summary = BillSummary.fromBills(state.bills, now);
    final List<Bill> recent = state.recent();

    return <Widget>[
      _SpendingCard(summary: summary),
      const SizedBox(height: AppSpacing.md + 2),
      ActionTile(
        icon: Icons.photo_camera_outlined,
        title: 'Add a bill',
        subtitle: 'Snap a photo or enter it yourself',
        onTap: () =>
            Navigator.of(context).pushNamed(AddBillPage.routeName),
      ),
      const SizedBox(height: AppSpacing.xl),
      SectionHeading(
        title: 'Recent bills',
        subtitle: 'The details that add up',
        trailing: _SeeAllAction(onTap: onSeeAllBills),
      ),
      const SizedBox(height: AppSpacing.md),
      if (recent.isEmpty)
        Text(
          'No bills yet. Add your first one.',
          style: AppFonts.display(size: 12.5, color: AppColors.inkMuted),
        )
      else
        for (int i = 0; i < recent.length; i++) ...<Widget>[
          BillTile(bill: recent[i]),
          if (i != recent.length - 1) const SizedBox(height: AppSpacing.sm + 2),
        ],
    ];
  }

  Future<void> _showProfile(BuildContext context) async {
    final AuthState authState = context.read<AuthBloc>().state;
    final AppUser? user = authState is AuthAuthenticated ? authState.user : null;

    final bool? signOut = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppStroke.base,
                        ),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        size: 24,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            user?.name ?? 'Guest',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.display(
                              size: 20,
                              weight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user == null || user.isGuest
                                ? 'Browsing as a guest'
                                : user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.display(
                              size: 11.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PaperButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  variant: PaperButtonVariant.secondary,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (signOut != true || !context.mounted) return;
    context.read<AuthBloc>().add(const AuthSignOutRequested());
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            border: Border.all(color: AppColors.ink, width: AppStroke.heavy),
            boxShadow: AppShadows.small,
          ),
          child: const Icon(
            Icons.description_outlined,
            size: 24,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: AppSpacing.md - 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'billo',
                style: AppFonts.display(
                  size: 22,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              const SectionLabel(
                'Bills, without the mess',
                size: 8,
                letterSpacing: 1.5,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
        PaperIconButton(
          icon: Icons.person_outline,
          semanticLabel: 'Profile',
          onPressed: onProfile,
          size: 42,
          iconSize: 21,
          color: AppColors.lavender,
          borderColor: null,
          elevated: false,
          circle: true,
        ),
      ],
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.summary});

  final BillSummary summary;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.accent,
      shadow: AppShadows.medium,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: SectionLabel(
                  'Spent this month',
                  size: 9,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 1,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppStroke.thin,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 12,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: AppSpacing.xs + 1),
                    Text(
                      _billCountLabel(summary.billCountThisMonth),
                      style: AppFonts.display(
                        size: 11,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Currency.inr(summary.spentThisMonth),
              style: AppFonts.display(
                size: 40,
                weight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Container(height: AppStroke.thin, color: AppColors.ink),
          const SizedBox(height: AppSpacing.md + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'A little more clarity',
                      style: AppFonts.display(
                        size: 12.5,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your last 7 days',
                      style: AppFonts.display(
                        size: 10.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _SevenDayStrip(
                days: summary.lastSevenDays,
                peak: summary.peakDaySpend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _billCountLabel(int count) {
    return count == 1 ? '1 bill' : '$count bills';
  }
}

class _SevenDayStrip extends StatelessWidget {
  const _SevenDayStrip({required this.days, required this.peak});

  final List<DaySpend> days;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final double ceiling = peak <= 0 ? 1 : peak;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < days.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 5,
                height: 4 + (days[i].amount / ceiling) * 22,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                days[i].label,
                style: AppFonts.label(
                  size: 7.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SeeAllAction extends StatelessWidget {
  const _SeeAllAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'See all bills',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'See all',
                style: AppFonts.display(size: 12, weight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.xs + 1),
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardFailure extends StatelessWidget {
  const _DashboardFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          message,
          style: AppFonts.display(
            size: 12.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PaperButton(
          label: 'Try again',
          variant: PaperButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
