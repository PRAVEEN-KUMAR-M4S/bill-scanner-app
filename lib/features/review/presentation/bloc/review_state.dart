import 'package:equatable/equatable.dart';

import '../../../../core/utils/currency.dart';
import '../../../../core/utils/date_formats.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_category.dart';
import '../../../bills/domain/entities/bill_item.dart';
import '../../../bills/domain/entities/bill_problem.dart';

/// Raw text for one editable line item, kept as strings so partial input
/// ("34", "34.") does not get rewritten while the user types.
class ReviewItemInput extends Equatable {
  const ReviewItemInput({
    required this.id,
    required this.name,
    required this.quantityText,
    required this.amountText,
  });

  factory ReviewItemInput.fromItem(BillItem item, int id) {
    return ReviewItemInput(
      id: id,
      name: item.name,
      quantityText: item.quantity?.toString() ?? '',
      amountText: Currency.amount(item.amount),
    );
  }

  final int id;
  final String name;
  final String quantityText;

  /// The printed amount for the whole line, not a unit price.
  final String amountText;

  int? get quantity => int.tryParse(quantityText.trim());

  double get amount => Currency.parse(amountText) ?? 0;

  double get lineTotal => amount;

  bool get isValid =>
      name.trim().isNotEmpty && amountText.trim().isNotEmpty && amount >= 0;

  bool get hasAnyValue =>
      name.trim().isNotEmpty ||
      quantityText.trim().isNotEmpty ||
      amountText.trim().isNotEmpty;

  BillItem toItem() {
    return BillItem(name: name.trim(), amount: amount, quantity: quantity);
  }

  ReviewItemInput copyWith({
    String? name,
    String? quantityText,
    String? amountText,
  }) {
    return ReviewItemInput(
      id: id,
      name: name ?? this.name,
      quantityText: quantityText ?? this.quantityText,
      amountText: amountText ?? this.amountText,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, quantityText, amountText];
}

sealed class ReviewState extends Equatable {
  const ReviewState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The bill is being checked and edited.
final class ReviewEditing extends ReviewState {
  const ReviewEditing({
    required this.source,
    required this.merchant,
    required this.dateText,
    required this.totalText,
    required this.category,
    required this.items,
    this.problems = const <BillProblem>[],
    this.isSaving = false,
    this.submitted = false,
    this.failureMessage,
  });

  factory ReviewEditing.fromBill(
    Bill bill, {
    List<BillProblem> problems = const <BillProblem>[],
  }) {
    return ReviewEditing(
      source: bill,
      merchant: bill.merchant,
      dateText: DateFormats.iso(bill.date),
      totalText: bill.total == 0 ? '' : Currency.amount(bill.total),
      category: bill.category,
      items: <ReviewItemInput>[
        for (int i = 0; i < bill.items.length; i++)
          ReviewItemInput.fromItem(bill.items[i], i + 1),
      ],
      problems: problems,
    );
  }

  /// The values the review started from; keeps the id and source metadata.
  final Bill source;
  final String merchant;
  final String dateText;
  final String totalText;
  final BillCategory category;
  final List<ReviewItemInput> items;

  /// Fields the scanner or the server flagged. Empty when the draft is clean.
  final List<BillProblem> problems;
  final bool isSaving;
  final bool submitted;
  final String? failureMessage;

  bool get isSample => source.isSample;

  DateTime? get date => DateFormats.parseIso(dateText);

  double? get total => Currency.parse(totalText);

  bool get merchantValid => merchant.trim().isNotEmpty;

  bool get dateValid => date != null;

  bool get totalValid => (total ?? 0) > 0;

  bool get itemsValid => items.every((ReviewItemInput item) => item.isValid);

  bool get isValid => merchantValid && dateValid && totalValid && itemsValid;

  /// How many of the three headline fields are ready (the "3 / 3" pill).
  int get readyCount =>
      (merchantValid ? 1 : 0) + (dateValid ? 1 : 0) + (totalValid ? 1 : 0);

  double get itemsTotal =>
      items.fold<double>(0, (double sum, ReviewItemInput item) {
        return sum + item.lineTotal;
      });

  Bill toBill() {
    return Bill(
      id: source.id,
      merchant: merchant.trim(),
      date: date!,
      total: total!,
      category: category,
      currency: source.currency,
      roundOff: source.roundOff,
      icon: source.icon,
      notes: source.notes,
      items: <BillItem>[
        for (final ReviewItemInput item in items)
          if (item.hasAnyValue) item.toItem(),
      ],
    );
  }

  ReviewEditing copyWith({
    String? merchant,
    String? dateText,
    String? totalText,
    BillCategory? category,
    List<ReviewItemInput>? items,
    List<BillProblem>? problems,
    bool? isSaving,
    bool? submitted,
    String? failureMessage,
    bool clearFailure = false,
  }) {
    return ReviewEditing(
      source: source,
      merchant: merchant ?? this.merchant,
      dateText: dateText ?? this.dateText,
      totalText: totalText ?? this.totalText,
      category: category ?? this.category,
      items: items ?? this.items,
      problems: problems ?? this.problems,
      isSaving: isSaving ?? this.isSaving,
      submitted: submitted ?? this.submitted,
      failureMessage: clearFailure
          ? null
          : (failureMessage ?? this.failureMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    source,
    merchant,
    dateText,
    totalText,
    category,
    items,
    problems,
    isSaving,
    submitted,
    failureMessage,
  ];
}

/// The bill was persisted; the page reacts by returning to the shell.
final class ReviewSaved extends ReviewState {
  const ReviewSaved(this.bill);

  final Bill bill;

  @override
  List<Object?> get props => <Object?>[bill];
}
