import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';
import '../../domain/entities/bill_extraction.dart';
import '../../domain/entities/bill_item.dart';
import '../../domain/entities/bill_problem.dart';

/// JSON ⇄ domain mapping for the three bill endpoints.
///
/// The API is the source of truth for shapes:
/// - money leaves as a string such as `"128.00"`, never a float;
/// - `date` is an ISO `YYYY-MM-DD` string;
/// - `items[].amount` is the whole line, not a unit price;
/// - `category` is one of the ten slugs and `icon` a HugeIcons name.
abstract final class BillMapper {
  /// A saved row from `GET /bills` or `POST /bills/confirm`.
  static Bill fromExpense(Map<String, dynamic> json) {
    final BillCategory category = BillCategory.fromSlug(
      _string(json['category']),
    );
    final Object? date = json['date'];
    final DateTime parsedDate = DateFormats.parseIso('$date') ?? DateTime.now();

    return Bill(
      id: json['id']?.toString() ?? '',
      merchant: _string(json['shop']) ?? '',
      date: parsedDate,
      total: _money(json['total']),
      currency: _string(json['currency']) ?? 'INR',
      category: category,
      icon: _string(json['icon']) ?? category.icon,
      notes: _string(json['notes']),
      items: _items(json['items']),
    );
  }

  /// A draft from `POST /bills/extract` (or its `draft` object).
  static Bill fromDraft(Map<String, dynamic> json) {
    final BillCategory category = BillCategory.fromSlug(
      _string(json['category']),
    );
    final String? dateText = _string(json['date']);

    return Bill(
      id: '',
      merchant: _string(json['shop']) ?? '',
      date: DateFormats.parseIso(dateText ?? '') ?? DateTime.now(),
      total: _money(json['total']),
      currency: _string(json['currency']) ?? 'INR',
      category: category,
      roundOff: json['round_off'] == null ? null : _money(json['round_off']),
      icon: _string(json['icon']) ?? category.icon,
      notes: _string(json['notes']),
      items: _items(json['items']),
    );
  }

  static BillExtraction fromExtractionReport(Map<String, dynamic> json) {
    return BillExtraction(
      bill: fromDraft(_asMap(json['draft'], 'draft')),
      problems: problems(json['problems']),
    );
  }

  static List<BillProblem> problems(Object? value) {
    if (value is! List) return const <BillProblem>[];
    final List<BillProblem> result = <BillProblem>[];
    for (final Object? entry in value) {
      if (entry is! Map) continue;
      final String? field = _string(entry['field']);
      final String? message = _string(entry['message']);
      if (field == null || message == null || message.isEmpty) continue;
      result.add(BillProblem(field: field, message: message));
    }
    return List<BillProblem>.unmodifiable(result);
  }

  /// The body `POST /bills/confirm` expects under `draft`.
  static Map<String, Object?> toConfirmJson(Bill bill) {
    return <String, Object?>{
      'shop': bill.merchant,
      'date': DateFormats.iso(bill.date),
      'currency': bill.currency,
      'category': bill.category.slug,
      'icon': bill.iconName,
      'total': _formatMoney(bill.total),
      'round_off': bill.roundOff == null ? null : _formatMoney(bill.roundOff!),
      'items': <Map<String, Object?>>[
        for (final BillItem item in bill.items)
          <String, Object?>{
            'name': item.name,
            'qty': item.quantity,
            'amount': _formatMoney(item.amount),
          },
      ],
      'notes': bill.notes,
    };
  }

  static List<BillItem> _items(Object? value) {
    if (value is! List) return const <BillItem>[];
    return <BillItem>[
      for (final Object? entry in value)
        if (entry is Map)
          BillItem(
            name: _string(entry['name']) ?? '',
            amount: _money(entry['amount']),
            quantity: _int(entry['qty']),
          ),
    ];
  }

  static String _formatMoney(double value) => value.toStringAsFixed(2);

  static double _money(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final String cleaned = value
          .replaceAll(',', '')
          .replaceAll('₹', '')
          .trim();
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _string(Object? value) {
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static Map<String, dynamic> _asMap(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (Object? key, Object? entry) => MapEntry(key.toString(), entry),
      );
    }
    throw ApiFormatException(body: 'Expected "$field" to be an object.');
  }
}
