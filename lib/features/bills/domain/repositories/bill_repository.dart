import '../entities/bill.dart';
import '../entities/bill_extraction.dart';
import '../entities/bills_snapshot.dart';

/// Storage and extraction contract for bills.
///
/// The app is offline-first, so the contract describes behaviour, not
/// transport:
/// - [fetchBills] returns the newest view it can get. On a device with a
///   server account that means syncing queued bills, fetching the list, and
///   falling back to the cache with [BillsSource.cache] when the network is
///   down.
/// - [save] returns a bill whose [Bill.syncState] says whether the server
///   accepted it. A pending bill is already saved on this device and will be
///   sent on the next successful sync.
/// - [extract] needs the scanner, so it fails with [BillFailure.isOffline]
///   when the connection is down; a photo cannot be read on-device.
///
/// The implementation is `BillRepositoryImpl`, which routes each call between
/// the API, the SQLite cache and the guest's device store.
abstract interface class BillRepository {
  /// The bill list plus where it came from, newest first.
  Future<BillsSnapshot> fetchBills();

  /// Persists [bill], either on the server or in the device queue.
  Future<Bill> save(Bill bill);

  /// Sends one JPG/PNG photo to the scanner and returns the draft plus the
  /// fields the checks flagged. Nothing is stored by this call.
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });
}
