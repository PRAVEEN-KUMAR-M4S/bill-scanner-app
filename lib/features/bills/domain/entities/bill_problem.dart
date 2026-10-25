import 'package:equatable/equatable.dart';

/// One field the scanner or the cashier checks want corrected.
///
/// [field] is a path such as `total` or `items[2].amount`, so a form can point
/// at the exact row; [message] is safe to show to the user.
class BillProblem extends Equatable {
  const BillProblem({required this.field, required this.message});

  final String field;
  final String message;

  /// The item index when [field] addresses a line (`items[1].amount`).
  int? get itemIndex {
    final RegExpMatch? match = RegExp(r'^items\[(\d+)\]').firstMatch(field);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  @override
  List<Object?> get props => <Object?>[field, message];
}
