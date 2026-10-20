import 'package:equatable/equatable.dart';

import '../../domain/entities/bill_category.dart';

sealed class BillsEvent extends Equatable {
  const BillsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The shell is ready to show saved bills.
final class BillsStarted extends BillsEvent {
  const BillsStarted();
}

/// A bill was saved elsewhere; reload without flashing the loading state.
final class BillsReloaded extends BillsEvent {
  const BillsReloaded();
}

final class BillsSearchChanged extends BillsEvent {
  const BillsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

final class BillsCategoryChanged extends BillsEvent {
  const BillsCategoryChanged(this.category);

  /// `null` means the "All" filter.
  final BillCategory? category;

  @override
  List<Object?> get props => <Object?>[category];
}

final class BillsRetryRequested extends BillsEvent {
  const BillsRetryRequested();
}
