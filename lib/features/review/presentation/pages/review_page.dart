import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/page_scaffold.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/paper_chip.dart';
import '../../../../core/widgets/paper_text_field.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../bills/domain/entities/bill_category.dart';
import '../../../bills/domain/entities/bill_problem.dart';
import '../../../bills/presentation/bloc/bills_bloc.dart';
import '../../../bills/presentation/bloc/bills_event.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';

/// Second half of the scan flow: every field the scanner read can be checked
/// and corrected before the bill is saved.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  static const String routeName = '/add-bill/review';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReviewBloc, ReviewState>(
      listenWhen: (ReviewState previous, ReviewState current) {
        if (current is ReviewSaved) return true;
        if (current is ReviewEditing && current.failureMessage != null) {
          return previous is! ReviewEditing ||
              previous.failureMessage != current.failureMessage;
        }
        return false;
      },
      listener: (BuildContext context, ReviewState state) {
        if (state is ReviewSaved) {
          context.read<BillsBloc>().add(const BillsReloaded());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.bill.isPendingSync
                    ? 'Saved on this phone. It will sync when you are back online.'
                    : 'Bill saved',
              ),
            ),
          );
          Navigator.of(context).popUntil(ModalRoute.withName(AppRoutes.shell));
        } else if (state is ReviewEditing && state.failureMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.failureMessage!)));
        }
      },
      builder: (BuildContext context, ReviewState state) {
        if (state is ReviewSaved) {
          return const Scaffold(
            backgroundColor: AppColors.paper,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.ink),
            ),
          );
        }

        final ReviewEditing editing = state as ReviewEditing;

        return Scaffold(
          backgroundColor: AppColors.paper,
          body: PageScaffold(
            children: <Widget>[
              ScreenHeader(
                title: 'Review bill',
                subtitle: 'Check every detail before saving',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: const _InrPill(),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (editing.isSample) ...<Widget>[
                const _SampleBanner(),
                const SizedBox(height: AppSpacing.md),
              ],
              if (editing.problems.isNotEmpty) ...<Widget>[
                _ProblemsBanner(problems: editing.problems),
                const SizedBox(height: AppSpacing.md),
              ],
              _BillDetailsCard(editing: editing),
              const SizedBox(height: AppSpacing.xl),
              SectionHeading(
                title: 'Items',
                subtitle:
                    'Amount is the printed total for each line, not a unit price.',
                titleSize: 26,
                trailing: const _AddItemAction(),
              ),
              const SizedBox(height: AppSpacing.md),
              if (editing.items.isEmpty)
                const _EmptyItems()
              else
                for (int i = 0; i < editing.items.length; i++) ...<Widget>[
                  _ItemCard(index: i, item: editing.items[i]),
                  if (i != editing.items.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              if (editing.submitted && !editing.itemsValid) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Each item needs a name and a line amount.',
                  style: AppFonts.display(size: 11.5, color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _TotalsCard(editing: editing),
              const SizedBox(height: AppSpacing.xl),
              if (editing.submitted && !editing.isValid) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Check the highlighted fields before saving.',
                    textAlign: TextAlign.center,
                    style: AppFonts.display(
                      size: 11.5,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              PaperButton(
                label: 'Save bill',
                icon: Icons.check,
                isLoading: editing.isSaving,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                onPressed: () =>
                    context.read<ReviewBloc>().add(const ReviewSubmitted()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InrPill extends StatelessWidget {
  const _InrPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const SectionLabel(
        'INR',
        color: AppColors.inkMuted,
        size: 9,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _ProblemsBanner extends StatelessWidget {
  const _ProblemsBanner({required this.problems});

  final List<BillProblem> problems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger, width: AppStroke.thin),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            problems.length == 1
                ? '1 field needs a check'
                : '${problems.length} fields need a check',
            style: AppFonts.display(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final BillProblem problem in problems)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• ${problem.message}',
                style: AppFonts.display(
                  size: 11,
                  color: AppColors.inkMuted,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SampleBanner extends StatelessWidget {
  const _SampleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sample bill - edit any field before saving',
              style: AppFonts.display(
                size: 11.5,
                color: AppColors.inkMuted,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillDetailsCard extends StatelessWidget {
  const _BillDetailsCard({required this.editing});

  final ReviewEditing editing;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppFonts.label(
      size: 9,
      color: AppColors.inkMuted,
      letterSpacing: 1.2,
    );

    return PaperCard(
      color: AppColors.accentSoft,
      shadow: AppShadows.small,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 22,
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
                      'Bill details',
                      style: AppFonts.display(
                        size: 22,
                        weight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check each field against your receipt.',
                      style: AppFonts.display(
                        size: 10.5,
                        color: AppColors.inkMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppStroke.thin,
                  ),
                ),
                child: Text(
                  '${editing.readyCount} / 3',
                  style: AppFonts.display(size: 11.5, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatusCheck(
                  label: 'Shop',
                  ready: editing.merchantValid,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatusCheck(label: 'Date', ready: editing.dateValid),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatusCheck(label: 'Total', ready: editing.totalValid),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PaperTextField(
            key: const ValueKey<String>('review-merchant'),
            label: 'SHOP OR MERCHANT',
            labelStyle: labelStyle,
            initialValue: editing.merchant,
            hint: 'Shop or merchant',
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.text,
            errorText: editing.submitted && !editing.merchantValid
                ? 'Add the shop or merchant'
                : null,
            onChanged: (String value) =>
                context.read<ReviewBloc>().add(ReviewMerchantChanged(value)),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget dateField = PaperTextField(
                key: const ValueKey<String>('review-date'),
                label: 'DATE · ISO FORMAT',
                labelStyle: labelStyle,
                initialValue: editing.dateText,
                hint: '2026-10-01',
                keyboardType: TextInputType.datetime,
                errorText: editing.submitted && !editing.dateValid
                    ? 'Use YYYY-MM-DD'
                    : null,
                onChanged: (String value) =>
                    context.read<ReviewBloc>().add(ReviewDateChanged(value)),
              );
              final Widget totalField = PaperTextField(
                key: const ValueKey<String>('review-total'),
                label: 'TOTAL · INR',
                labelStyle: labelStyle,
                initialValue: editing.totalText,
                prefixText: '₹',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                errorText: editing.submitted && !editing.totalValid
                    ? 'Add the total'
                    : null,
                onChanged: (String value) =>
                    context.read<ReviewBloc>().add(ReviewTotalChanged(value)),
              );

              // Only very narrow phones stack; 390px still shows the designed
              // two-column date/total row.
              if (constraints.maxWidth < 300) {
                return Column(
                  children: <Widget>[
                    dateField,
                    const SizedBox(height: AppSpacing.md + 2),
                    totalField,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: dateField),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: totalField),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(
            'CATEGORY',
            size: 9,
            letterSpacing: 1.2,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final BillCategory category in BillCategory.values)
                PaperChip(
                  label: category.label,
                  selected: editing.category == category,
                  onTap: () => context.read<ReviewBloc>().add(
                    ReviewCategoryChanged(category),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCheck extends StatelessWidget {
  const _StatusCheck({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppStroke.thin),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            ready ? Icons.check_circle_outline : Icons.error_outline,
            size: 15,
            color: ready ? AppColors.success : AppColors.inkFaint,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SectionLabel(
                    label,
                    size: 7.5,
                    letterSpacing: 1,
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  ready ? 'Ready' : 'Check',
                  style: AppFonts.display(
                    size: 10.5,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddItemAction extends StatelessWidget {
  const _AddItemAction();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add item',
      child: InkWell(
        onTap: () => context.read<ReviewBloc>().add(const ReviewItemAdded()),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.add, size: 15, color: AppColors.ink),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Add item',
                style: AppFonts.display(size: 12, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      shadow: const <BoxShadow>[],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Text(
        'No items yet. Add the first line of this bill.',
        textAlign: TextAlign.center,
        style: AppFonts.display(size: 12, color: AppColors.inkMuted),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.index, required this.item});

  final int index;
  final ReviewItemInput item;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = AppFonts.label(
      size: 9,
      color: AppColors.inkMuted,
      letterSpacing: 1.2,
    );
    final String number = '${index + 1}'.padLeft(2, '0');

    return PaperCard(
      shadow: const <BoxShadow>[],
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              SectionLabel(
                'ITEM $number',
                size: 9,
                letterSpacing: 1.2,
                color: AppColors.inkMuted,
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Remove item $number',
                child: InkWell(
                  onTap: () =>
                      context.read<ReviewBloc>().add(ReviewItemRemoved(index)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: const SizedBox(
                    width: 28,
                    height: 24,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PaperTextField(
            key: ValueKey<String>('item-${item.id}-name'),
            label: null,
            hint: 'Item name',
            initialValue: item.name,
            textInputAction: TextInputAction.next,
            onChanged: (String value) => context.read<ReviewBloc>().add(
              ReviewItemNameChanged(index: index, value: value),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget quantity = PaperTextField(
                key: ValueKey<String>('item-${item.id}-qty'),
                label: 'QTY',
                labelStyle: labelStyle,
                initialValue: item.quantityText,
                keyboardType: TextInputType.number,
                onChanged: (String value) => context.read<ReviewBloc>().add(
                  ReviewItemQuantityChanged(index: index, value: value),
                ),
              );
              final Widget amount = PaperTextField(
                key: ValueKey<String>('item-${item.id}-amount'),
                label: 'LINE AMOUNT · ₹',
                labelStyle: labelStyle,
                initialValue: item.amountText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (String value) => context.read<ReviewBloc>().add(
                  ReviewItemAmountChanged(index: index, value: value),
                ),
              );

              if (constraints.maxWidth < 270) {
                return Column(
                  children: <Widget>[
                    quantity,
                    const SizedBox(height: AppSpacing.md),
                    amount,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 92, child: quantity),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: amount),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.editing});

  final ReviewEditing editing;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SectionLabel(
                'Items · ${editing.items.length}',
                size: 9,
                letterSpacing: 1.2,
                color: AppColors.inkMuted,
              ),
              const Spacer(),
              Text(
                Currency.inr(editing.itemsTotal),
                style: AppFonts.display(size: 13.5, weight: FontWeight.w700),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
            child: Divider(
              color: AppColors.inkFaint,
              thickness: AppStroke.thin,
              height: 1,
            ),
          ),
          Row(
            children: <Widget>[
              Text(
                'Total',
                style: AppFonts.display(size: 16, weight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                Currency.inr(editing.total ?? 0),
                style: AppFonts.display(size: 20, weight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
