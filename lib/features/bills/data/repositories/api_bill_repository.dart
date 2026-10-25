import '../../../../core/network/api_exception.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_extraction.dart';
import '../../domain/entities/bill_problem.dart';
import '../../domain/failures/bill_failure.dart';
import '../../domain/repositories/bill_repository.dart';
import '../datasources/bill_api.dart';

/// Bills backed by the Bill Reader API.
///
/// Every network failure is translated into a [BillFailure] whose message is
/// safe to show. A 422 from confirm keeps the server's list of [BillProblem]s,
/// so the review screen can point at the field that failed the cashier check.
class ApiBillRepository implements BillRepository {
  const ApiBillRepository({required BillApi billApi}) : _billApi = billApi;

  final BillApi _billApi;

  @override
  Future<List<Bill>> fetchBills() async {
    try {
      return await _billApi.fetchAll();
    } on ApiException catch (exception) {
      throw _failure(exception, action: _BillAction.loading);
    }
  }

  @override
  Future<Bill> save(Bill bill) async {
    try {
      return await _billApi.confirm(bill);
    } on ApiException catch (exception) {
      throw _failure(exception, action: _BillAction.saving);
    }
  }

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      return await _billApi.extract(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
    } on ApiException catch (exception) {
      throw _failure(exception, action: _BillAction.extracting);
    }
  }

  BillFailure _failure(ApiException exception, {required _BillAction action}) {
    if (exception is ValidationApiException) {
      final List<BillProblem> problems = _problems(exception);
      return BillFailure(
        problems.isEmpty
            ? exception.message
            : 'Fix the highlighted fields before saving.',
        problems: problems,
      );
    }

    if (exception is UnauthorizedApiException) {
      return const BillFailure('Your session expired. Please sign in again.');
    }

    if (exception is PayloadTooLargeApiException) {
      return const BillFailure('That photo is too large. Use one under 5 MB.');
    }

    if (exception is UnsupportedMediaTypeApiException) {
      return const BillFailure('Upload a JPG or PNG photo.');
    }

    if (exception is RateLimitedApiException) {
      return switch (action) {
        _BillAction.extracting => const BillFailure(
          'The scanner is out of quota right now. Try later or enter the bill by hand.',
        ),
        _ => const BillFailure('Too many requests. Try again in a minute.'),
      };
    }

    if (exception is ServerApiException) {
      return switch (action) {
        _BillAction.extracting => const BillFailure(
          'The scanner is busy right now. Try again in a minute, or enter the bill by hand.',
        ),
        _ => const BillFailure('The server had a problem. Try again.'),
      };
    }

    if (exception is NetworkApiException || exception is TimeoutApiException) {
      return const BillFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (exception is ApiFormatException) {
      return const BillFailure('The server sent an unexpected response.');
    }

    return switch (action) {
      _BillAction.loading => const BillFailure(
        'Could not load your bills. Try again.',
      ),
      _BillAction.saving => const BillFailure(
        'Could not save that bill. Try again.',
      ),
      _BillAction.extracting => const BillFailure(
        'Could not read that bill. Try once more.',
      ),
    };
  }

  List<BillProblem> _problems(ValidationApiException exception) {
    if (exception.problems.isNotEmpty) {
      return <BillProblem>[
        for (final ApiProblem problem in exception.problems)
          BillProblem(field: problem.field, message: problem.message),
      ];
    }

    return <BillProblem>[
      for (final MapEntry<String, String> entry in exception.fields.entries)
        BillProblem(field: entry.key, message: entry.value),
    ];
  }
}

enum _BillAction { loading, saving, extracting }
