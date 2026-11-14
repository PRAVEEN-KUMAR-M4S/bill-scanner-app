import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/paper_button.dart';
import '../../../../core/widgets/paper_card.dart';
import '../../../../core/widgets/paper_icon_button.dart';
import '../../../../core/widgets/paper_text_field.dart';
import '../../../../core/widgets/section_label.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../domain/entities/balance.dart';

/// The dashboard's "Available balance" card.
///
/// What it shows is the arithmetic, not a second source of truth:
/// `balance.available(bills)` — the figure the user set minus the spending.
/// A signed-in account takes that spending from the API, which counts every
/// stored bill; a guest subtracts the bills on this phone. Either way, when
/// `BillsBloc` emits after a save the card rebuilds and the figure has already
/// moved; no event is needed.
///
/// The "Update" sheet writes the balance with `PUT /account/balance`, which
/// replaces the figure — so the field is prefilled with the current one.
///
/// The eye button is local UI state (masking is a glance-level concern, not
/// application state), so it lives here rather than in the bloc.
class AvailableBalanceCard extends StatefulWidget {
  const AvailableBalanceCard({
    super.key,
    required this.balance,
    required this.bills,
    required this.onUpdate,
  });

  /// The stored entry.
  final Balance balance;

  /// Every bill in the list, pending ones included — they are money spent.
  final List<Bill> bills;

  /// Called with the new entry when the sheet is saved.
  final ValueChanged<double> onUpdate;

  @override
  State<AvailableBalanceCard> createState() => _AvailableBalanceCardState();
}

class _AvailableBalanceCardState extends State<AvailableBalanceCard> {
  /// Masked until the user taps the eye.
  bool _revealed = false;

  double get _available => widget.balance.available(widget.bills);

  /// `₹23,620.00`, or `−₹1,380.00` once spending passes the entry — the minus
  /// sign belongs outside the symbol so it reads before the rupee mark.
  String get _amount {
    final double value = _available;
    return value < 0 ? '−${Currency.inr(-value)}' : Currency.inr(value);
  }

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppShadows.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppStroke.thin,
                  ),
                ),
                child: const Icon(
                  Icons.credit_card_outlined,
                  size: 20,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SectionLabel(
                      'Available balance',
                      size: 9.5,
                      letterSpacing: 1.4,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Manually maintained · not bank-synced',
                      style: AppFonts.display(
                        size: 10,
                        color: AppColors.inkMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PaperIconButton(
                icon: _revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                semanticLabel: _revealed ? 'Hide balance' : 'Show balance',
                onPressed: () => setState(() => _revealed = !_revealed),
                size: 36,
                iconSize: 18,
                color: AppColors.lavender,
                borderColor: null,
                elevated: false,
                circle: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionLabel(
            'INR - personal entry',
            size: 8.5,
            letterSpacing: 1.6,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: _value()),
              const SizedBox(width: AppSpacing.sm),
              _UpdatePill(onPressed: _openSheet),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(height: AppStroke.thin, color: AppColors.ink),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Each bill you save is subtracted. The entry itself only '
                  'changes when you tap Update.',
                  style: AppFonts.display(
                    size: 10.5,
                    color: AppColors.inkMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The masked or revealed figure. `FittedBox` keeps it on one line when the
  /// gutter, the pill and a long number meet on a 320pt phone.
  Widget _value() {
    final Widget content = _revealed
        ? Text(
            _amount,
            maxLines: 1,
            style: AppFonts.display(
              size: 27,
              weight: FontWeight.w800,
              height: 1,
            ),
          )
        : Text(
            '• • • • • •',
            style: AppFonts.label(size: 22, letterSpacing: 3),
          );

    // Screen readers get the real figure only while it is on screen.
    return Semantics(
      label: _revealed ? 'Available balance $_amount' : 'Balance hidden',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: content,
      ),
    );
  }

  /// The sheet behind the "Update" pill: one amount field, one save button.
  Future<void> _openSheet() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String draft = Currency.amount(widget.balance.base);

    final Object? result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
            ),
            child: Form(
              key: formKey,
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
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Update balance',
                    style: AppFonts.display(size: 20, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The amount you start from, before bills are subtracted.',
                    style: AppFonts.display(
                      size: 11.5,
                      color: AppColors.inkMuted,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PaperTextField(
                    label: 'Balance',
                    labelStyle: AppFonts.label(
                      size: 9.5,
                      color: AppColors.inkMuted,
                    ),
                    initialValue: draft,
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (String value) => draft = value,
                    validator: (String? value) =>
                        Currency.parse(value ?? '') == null
                        ? 'Enter an amount, for example 25000'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PaperButton(
                    label: 'Save balance',
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != true || !mounted) return;
    final double? parsed = Currency.parse(draft);
    if (parsed != null) widget.onUpdate(parsed);
  }
}

/// Yellow pencil pill from the export, kept as its own widget only so the
/// card's row stays readable.
class _UpdatePill extends StatelessWidget {
  const _UpdatePill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Update balance',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.ink, width: AppStroke.thin),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.edit_outlined, size: 13, color: AppColors.ink),
              const SizedBox(width: 5),
              Text(
                'Update',
                style: AppFonts.display(size: 11.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
