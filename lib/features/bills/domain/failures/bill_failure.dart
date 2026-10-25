import '../entities/bill_problem.dart';

/// A bill operation that failed in a way the UI can explain.
///
/// [problems] is populated when the server rejected a draft with its cashier
/// checks (HTTP 422), so the review screen can show the exact reason instead of
/// a generic “could not save”.
class BillFailure implements Exception {
  const BillFailure(this.message, {this.problems = const <BillProblem>[]});

  final String message;
  final List<BillProblem> problems;

  @override
  String toString() => 'BillFailure: $message';
}
