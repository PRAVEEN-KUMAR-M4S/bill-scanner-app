import 'package:equatable/equatable.dart';

import 'bill_category.dart';
import 'bill_item.dart';

/// A saved (or in-progress) bill.
///
/// [id] is empty until the bill has been saved; [isSample] marks the bundled
/// demo bill so the review screen can explain where the values came from.
class Bill extends Equatable {
  const Bill({
    required this.id,
    required this.merchant,
    required this.date,
    required this.total,
    required this.category,
    required this.items,
    this.currency = 'INR',
    this.roundOff,
    this.icon,
    this.notes,
    this.isSample = false,
  });

  /// A blank bill for manual entry.
  factory Bill.empty({required DateTime date}) => Bill(
    id: '',
    merchant: '',
    date: date,
    total: 0,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[],
  );

  final String id;
  final String merchant;
  final DateTime date;
  final double total;
  final BillCategory category;
  final List<BillItem> items;

  /// ISO 4217 code. The API currently accepts INR only.
  final String currency;

  /// The printed Round Off / adjustment line, signed, when the bill shows one.
  final double? roundOff;

  /// The HugeIcons name returned by the API; null for a locally entered draft.
  final String? icon;
  final String? notes;
  final bool isSample;

  bool get isSaved => id.isNotEmpty;

  /// The icon to send on confirm: the one the API chose, or the category's
  /// default for a manually entered bill.
  String get iconName => icon ?? category.icon;

  /// Sum of the line items, used to sanity-check [total] on the review form.
  double get itemsTotal => items.fold<double>(
    0,
    (double sum, BillItem item) => sum + item.lineTotal,
  );

  Bill copyWith({
    String? id,
    String? merchant,
    DateTime? date,
    double? total,
    BillCategory? category,
    List<BillItem>? items,
    String? currency,
    double? roundOff,
    String? icon,
    String? notes,
    bool? isSample,
  }) {
    return Bill(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      category: category ?? this.category,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      roundOff: roundOff ?? this.roundOff,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      isSample: isSample ?? this.isSample,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    merchant,
    date,
    total,
    category,
    items,
    currency,
    roundOff,
    icon,
    notes,
    isSample,
  ];
}
