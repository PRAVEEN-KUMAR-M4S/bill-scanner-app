import 'package:equatable/equatable.dart';

import 'bill.dart';
import 'bill_problem.dart';

/// What `POST /bills/extract` returns: a draft to review plus everything the
/// cashier checks want corrected. An empty [problems] means the draft is ready
/// to confirm.
class BillExtraction extends Equatable {
  const BillExtraction({
    required this.bill,
    this.problems = const <BillProblem>[],
  });

  final Bill bill;
  final List<BillProblem> problems;

  bool get isClean => problems.isEmpty;

  /// First message for a field, or null when that field was accepted.
  String? messageFor(String field) {
    for (final BillProblem problem in problems) {
      if (problem.field == field) return problem.message;
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[bill, problems];
}
