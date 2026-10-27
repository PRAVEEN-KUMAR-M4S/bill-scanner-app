import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_formats.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_category.dart';
import '../../domain/entities/bill_item.dart';
import '../../domain/entities/bill_sync_state.dart';

/// Database row ⇄ domain mapping for the offline cache.
///
/// Column names live here and in `AppDatabase` only, so everything above the
/// data layer keeps speaking [Bill]. Changing a column is this file, the
/// schema constant and one migration — not a search for `row['total']`.
///
/// `owner_id`, `created_at` and `updated_at` are not here on purpose:
/// `AppDatabase` adds them when it writes, because they are storage
/// bookkeeping rather than part of the bill.
abstract final class BillRowMapper {
  /// A [Bill] as the `bills` row expects it, plus its `bill_items` rows.
  static BillRows toRows(Bill bill) {
    return (
      bill: <String, Object?>{
        'id': bill.id,
        'merchant': bill.merchant,
        'bill_date': DateFormats.iso(bill.date),
        'total': bill.total,
        'currency': bill.currency,
        'category': bill.category.slug,
        'icon': bill.icon,
        'notes': bill.notes,
        'round_off': bill.roundOff,
        'sync_status': bill.syncState.name,
      },
      items: <Map<String, Object?>>[
        for (int position = 0; position < bill.items.length; position++)
          itemToRow(
            billId: bill.id,
            position: position,
            item: bill.items[position],
          ),
      ],
    );
  }

  /// A bill row back into the entity, with its items already loaded.
  static Bill fromRows(
    Map<String, Object?> row, {
    List<BillItem> items = const <BillItem>[],
  }) {
    return Bill(
      id: row['id'] as String? ?? '',
      merchant: row['merchant'] as String? ?? '',
      date:
          DateFormats.parseIso(row['bill_date'] as String? ?? '') ??
          DateTime.now(),
      total: (row['total'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'INR',
      category: BillCategory.fromSlug(row['category'] as String?),
      icon: _text(row['icon']),
      notes: _text(row['notes']),
      roundOff: (row['round_off'] as num?)?.toDouble(),
      items: List<BillItem>.unmodifiable(items),
      syncState: row['sync_status'] == BillSyncState.pending.name
          ? BillSyncState.pending
          : BillSyncState.synced,
    );
  }

  /// One `bill_items` row. The printed order is kept in `position`.
  static Map<String, Object?> itemToRow({
    required String billId,
    required int position,
    required BillItem item,
  }) {
    return <String, Object?>{
      'bill_id': billId,
      'position': position,
      'name': item.name,
      'amount': item.amount,
      'quantity': item.quantity,
    };
  }

  static BillItem itemFromRow(Map<String, Object?> row) {
    return BillItem(
      name: row['name'] as String? ?? '',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      quantity: (row['quantity'] as num?)?.toInt(),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
