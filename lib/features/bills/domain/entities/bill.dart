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
  final bool isSample;

  bool get isSaved => id.isNotEmpty;

  /// Sum of the line items, used to sanity-check [total] on the review form.
  double get itemsTotal =>
      items.fold<double>(0, (double sum, BillItem item) => sum + item.lineTotal);

  Bill copyWith({
    String? id,
    String? merchant,
    DateTime? date,
    double? total,
    BillCategory? category,
    List<BillItem>? items,
    bool? isSample,
  }) {
    return Bill(
      id: id ?? this.id,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      total: total ?? this.total,
      category: category ?? this.category,
      items: items ?? this.items,
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
    isSample,
  ];
}
