import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../../core/widgets/page_scaffold.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/paper_chip.dart';
import '../../../../core/widgets/paper_icon_button.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../scan/presentation/pages/add_bill_page.dart';
import '../../domain/entities/bill_category.dart';
import '../../domain/entities/bill_summary.dart';
import '../bloc/bills_bloc.dart';
import '../bloc/bills_event.dart';
import '../bloc/bills_state.dart';
import '../widgets/bill_tile.dart';
import '../widgets/sync_status_banner.dart';

/// Every saved bill, with a search field and category filters.
class BillsPage extends StatelessWidget {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    return BlocBuilder<BillsBloc, BillsState>(
      builder: (BuildContext context, BillsState state) {
        return PageScaffold(
          children: <Widget>[
            _BillsHeader(
              onAdd: () =>
                  Navigator.of(context).pushNamed(AddBillPage.routeName),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state is BillsLoaded) ...<Widget>[
              if (state.needsSyncNotice) ...<Widget>[
                SyncStatusBanner(
                  isOffline: state.isOffline,
                  pendingCount: state.pendingCount,
                  onRetry: () =>
                      context.read<BillsBloc>().add(const BillsReloaded()),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _MonthCard(
                summary: BillSummary.fromBills(state.bills, now),
                now: now,
              ),
              const SizedBox(height: AppSpacing.lg),
              _BillSearchField(
                onChanged: (String value) =>
                    context.read<BillsBloc>().add(BillsSearchChanged(value)),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategoryFilters(selected: state.category),
              const SizedBox(height: AppSpacing.lg + 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    'All bills',
                    style: AppFonts.display(
                      size: 21,
                      weight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${state.visibleBills.length}',
                    style: AppFonts.display(
                      size: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.visibleBills.isEmpty)
                _EmptyBills(filtered: state.hasActiveFilter)
              else
                for (int i = 0; i < state.visibleBills.length; i++) ...<Widget>[
                  BillTile(bill: state.visibleBills[i]),
                  if (i != state.visibleBills.length - 1)
                    const SizedBox(height: AppSpacing.sm + 2),
                ],
            ] else if (state is BillsFailure)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    state.message,
                    style: AppFonts.display(
                      size: 12.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PaperButton(
                    label: 'Try again',
                    variant: PaperButtonVariant.secondary,
                    onPressed: () => context.read<BillsBloc>().add(
                      const BillsRetryRequested(),
                    ),
                  ),
                ],
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
}

class _BillsHeader extends StatelessWidget {
  const _BillsHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SectionLabel(
                'Your records',
                size: 9.5,
                letterSpacing: 1.7,
                color: AppColors.inkMuted,
              ),
              const SizedBox(height: AppSpacing.sm - 2),
              Text(
                'Bills',
                style: AppFonts.display(
                  size: 33,
                  weight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        PaperIconButton(
          icon: Icons.add,
          semanticLabel: 'Add a bill',
          onPressed: onAdd,
          size: 44,
          iconSize: 22,
          color: AppColors.accent,
        ),
      ],
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary, required this.now});

  final BillSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final int count = summary.billCountThisMonth;

    return PaperCard(
      color: AppColors.accent,
      shadow: AppShadows.medium,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SectionLabel(
                  DateFormats.monthYear(now),
                  size: 9,
                  letterSpacing: 1.4,
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: AppColors.ink,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            count == 1
                ? '1 bill saved this month'
                : '$count bills saved this month',
            style: AppFonts.display(size: 11.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _BillSearchField extends StatefulWidget {
  const _BillSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_BillSearchField> createState() => _BillSearchFieldState();
}

class _BillSearchFieldState extends State<_BillSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.ink, width: AppStroke.thin),
    );

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: AppFonts.display(size: 14),
      cursorColor: AppColors.ink,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        hintText: 'Find a shop or item',
        hintStyle: AppFonts.display(size: 13.5, color: AppColors.inkFaint),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.inkMuted,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(
            color: AppColors.ink,
            width: AppStroke.base,
          ),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.selected});

  final BillCategory? selected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          PaperChip(
            label: 'All',
            selected: selected == null,
            onTap: () =>
                context.read<BillsBloc>().add(const BillsCategoryChanged(null)),
          ),
          for (final BillCategory category in BillCategory.values) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            PaperChip(
              label: category.label,
              selected: selected == category,
              onTap: () =>
                  context.read<BillsBloc>().add(BillsCategoryChanged(category)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      color: AppColors.surface,
      shadow: const <BoxShadow>[],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Text(
        filtered
            ? 'No bills match that search.'
            : 'No bills yet. Add your first one.',
        textAlign: TextAlign.center,
        style: AppFonts.display(size: 12.5, color: AppColors.inkMuted),
      ),
    );
  }
}
