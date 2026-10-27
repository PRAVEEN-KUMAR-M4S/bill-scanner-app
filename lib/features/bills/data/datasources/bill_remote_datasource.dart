import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_extraction.dart';
import '../../domain/entities/bill_problem.dart';
import '../../domain/failures/bill_failure.dart';
import '../models/bill_mapper.dart';

/// The three bill endpoints of the Bill Reader API.
///
/// The only bills file that knows paths and JSON field names:
/// `GET /bills`, `POST /bills/extract` and `POST /bills/confirm`.
///
/// HTTP stops here. The shared [ApiService] raises [ApiException]s; this class
/// turns each one into a [BillFailure] whose message is already safe to show,
/// so the repository and everything above it speak one error language and never
/// import a status code.
class BillRemoteDataSource {
  const BillRemoteDataSource(this._api);

  final ApiService _api;

  /// Every saved bill for the token's account, newest first.
  Future<List<Bill>> fetchAll() async {
    try {
      final Object? json = await _api.get(
        ApiEndpoints.bills,
        authenticated: true,
      );
      if (json is! List) throw const ApiFormatException();

      return <Bill>[
        for (final Object? entry in json)
          if (entry is Map) BillMapper.fromExpense(_asMap(entry)),
      ];
    } on ApiException catch (exception) {
      throw _failure(exception, action: _Action.loading);
    }
  }

  /// One photo in, a draft plus the fields the cashier checks flagged out.
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final Object? json = await _api.postMultipart(
        ApiEndpoints.billsExtract,
        file: ApiUploadFile(
          field: 'file',
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        ),
        authenticated: true,
      );
      return BillMapper.fromExtractionReport(_asMap(json));
    } on ApiException catch (exception) {
      throw _failure(exception, action: _Action.extracting);
    }
  }

  /// The edited draft, re-checked by the server before it is stored.
  Future<Bill> confirm(Bill bill) async {
    try {
      final Object? json = await _api.post(
        ApiEndpoints.billsConfirm,
        body: <String, Object?>{'draft': BillMapper.toConfirmJson(bill)},
        authenticated: true,
      );
      return BillMapper.fromExpense(_asMap(json));
    } on ApiException catch (exception) {
      throw _failure(exception, action: _Action.saving);
    }
  }

  BillFailure _failure(ApiException exception, {required _Action action}) {
    // A 422 is a rejected draft, not a broken connection: keep the server's
    // per-field messages so the review screen can point at the wrong value.
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
        _Action.extracting => const BillFailure(
          'The scanner is out of quota right now. Try later or enter the bill by hand.',
        ),
        _ => const BillFailure('Too many requests. Try again in a minute.'),
      };
    }

    if (exception is ServerApiException) {
      return switch (action) {
        _Action.extracting => const BillFailure(
          'The scanner is busy right now. Try again in a minute, or enter the bill by hand.',
        ),
        _ => const BillFailure('The server had a problem. Try again.'),
      };
    }

    // The only failure the offline cache is allowed to take over from.
    if (exception is NetworkApiException || exception is TimeoutApiException) {
      return const BillFailure.offline(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (exception is ApiFormatException) {
      return const BillFailure('The server sent an unexpected response.');
    }

    return switch (action) {
      _Action.loading => const BillFailure(
        'Could not load your bills. Try again.',
      ),
      _Action.saving => const BillFailure(
        'Could not save that bill. Try again.',
      ),
      _Action.extracting => const BillFailure(
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

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (Object? key, Object? entry) => MapEntry(key.toString(), entry),
      );
    }
    throw const ApiFormatException();
  }
}

/// What the call was for. Only the wording of a rate limit or a server error
/// depends on it.
enum _Action { loading, saving, extracting }
