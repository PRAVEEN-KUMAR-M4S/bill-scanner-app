import '../entities/bill_problem.dart';

/// A bill operation that failed in a way the UI can explain.
///
/// [problems] is populated when the server rejected a draft with its cashier
/// checks (HTTP 422), so the review screen can show the exact reason instead of
/// a generic “could not save”.
///
/// [isOffline] is true only for a connection or timeout failure. That flag is
/// what tells the offline repository to queue a save instead of showing an
/// error: a 422 must never be retried blindly, but an unreachable server is
/// exactly the case the cache exists for.
class BillFailure implements Exception {
  const BillFailure(
    this.message, {
    this.problems = const <BillProblem>[],
    this.isOffline = false,
  });

  /// A connection-level failure the cache can take over from.
  const BillFailure.offline(this.message)
    : problems = const <BillProblem>[],
      isOffline = true;

  final String message;
  final List<BillProblem> problems;
  final bool isOffline;

  @override
  String toString() => 'BillFailure: $message';
}
