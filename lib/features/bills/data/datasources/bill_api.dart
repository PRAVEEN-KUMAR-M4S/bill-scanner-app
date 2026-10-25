import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_extraction.dart';
import '../models/bill_mapper.dart';

/// The three bill endpoints exposed by the Bill Reader API.
///
/// This is the only bills file that knows paths and JSON field names; the
/// repository maps its results and failures into the domain.
class BillApi {
  const BillApi(this._api);

  final ApiService _api;

  /// `GET /bills` — every saved bill for the token's account, newest first.
  Future<List<Bill>> fetchAll() async {
    final Object? json = await _api.get(
      ApiEndpoints.bills,
      authenticated: true,
    );
    if (json is! List) throw const ApiFormatException();

    return <Bill>[
      for (final Object? entry in json)
        if (entry is Map) BillMapper.fromExpense(_asMap(entry)),
    ];
  }

  /// `POST /bills/extract` — one photo in, a draft plus problems out.
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
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
  }

  /// `POST /bills/confirm` — the edited draft, re-checked before it is saved.
  Future<Bill> confirm(Bill bill) async {
    final Object? json = await _api.post(
      ApiEndpoints.billsConfirm,
      body: <String, Object?>{'draft': BillMapper.toConfirmJson(bill)},
      authenticated: true,
    );
    return BillMapper.fromExpense(_asMap(json));
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
