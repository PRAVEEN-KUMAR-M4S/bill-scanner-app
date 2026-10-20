import 'package:equatable/equatable.dart';

import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';

sealed class BillsState extends Equatable {
  const BillsState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class BillsLoading extends BillsState {
  const BillsLoading();
}

/// Bills were loaded. [bills] is the full set; [visibleBills] applies the
/// current search and category filter.
final class BillsLoaded extends BillsState {
  const BillsLoaded({
    required this.bills,
    required this.visibleBills,
    this.query = '',
    this.category,
  });

  final List<Bill> bills;
  final List<Bill> visibleBills;
  final String query;
  final BillCategory? category;

  bool get hasActiveFilter => query.trim().isNotEmpty || category != null;

  /// The newest bills first, capped for the dashboard's "Recent bills".
  List<Bill> recent([int count = 3]) => bills.take(count).toList();

  @override
  List<Object?> get props => <Object?>[bills, visibleBills, query, category];
}

final class BillsFailure extends BillsState {
  const BillsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
