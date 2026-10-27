import 'package:equatable/equatable.dart';

import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';
import '../../domain/entities/bills_snapshot.dart';

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
///
/// [source] is where the list came from. The pages use it to explain stale
/// data: a cache read means the server could not be reached.
final class BillsLoaded extends BillsState {
  const BillsLoaded({
    required this.bills,
    required this.visibleBills,
    required this.source,
    this.query = '',
    this.category,
  });

  final List<Bill> bills;
  final List<Bill> visibleBills;
  final BillsSource source;
  final String query;
  final BillCategory? category;

  bool get hasActiveFilter => query.trim().isNotEmpty || category != null;

  /// True when these rows came from the device cache.
  bool get isOffline => source == BillsSource.cache;

  /// Bills saved on this device that the server has not accepted yet.
  int get pendingCount => bills.where((Bill bill) => bill.isPendingSync).length;

  /// True when the sync banner has something to say.
  bool get needsSyncNotice => isOffline || pendingCount > 0;

  /// The newest bills first, capped for the dashboard's "Recent bills".
  List<Bill> recent([int count = 3]) => bills.take(count).toList();

  @override
  List<Object?> get props => <Object?>[
    bills,
    visibleBills,
    source,
    query,
    category,
  ];
}

final class BillsFailure extends BillsState {
  const BillsFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
