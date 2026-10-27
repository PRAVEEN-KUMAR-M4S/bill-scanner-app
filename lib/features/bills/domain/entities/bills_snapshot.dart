import 'package:equatable/equatable.dart';

import 'bill.dart';
import 'bill_sync_state.dart';

/// Where the bills in a [BillsSnapshot] came from.
enum BillsSource {
  /// Fresh from `GET /bills`; the local cache was rewritten from it.
  server,

  /// The local cache, because the server could not be reached.
  cache,

  /// This device only (a guest has no server account).
  device,
}

/// One read of the bill list, with the provenance the UI needs.
///
/// Returning a snapshot instead of a bare list is what lets the dashboard say
/// "Offline — showing bills saved on this phone" without knowing anything
/// about sqflite or HTTP.
class BillsSnapshot extends Equatable {
  const BillsSnapshot({required this.bills, required this.source});

  final List<Bill> bills;
  final BillsSource source;

  /// True when the server was unreachable and these rows are the cache.
  bool get isOffline => source == BillsSource.cache;

  /// Bills saved here that the server has not accepted yet.
  int get pendingCount => bills
      .where((Bill bill) => bill.syncState == BillSyncState.pending)
      .length;

  @override
  List<Object?> get props => <Object?>[bills, source];
}
