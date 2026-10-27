/// Where a saved bill currently lives.
///
/// The app is offline-first: a bill can be accepted by the device before the
/// API has seen it. The review screen still reports "saved"; this value tells
/// the dashboard whether to show a "Waiting to sync" badge.
enum BillSyncState {
  /// The server has stored this bill; the row here is a cache of it.
  synced,

  /// Only this device has it. It is queued for the next successful sync.
  pending,
}
