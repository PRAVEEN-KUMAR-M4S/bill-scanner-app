import 'package:bill_scanner/features/balance/domain/entities/balance.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill(
  double total, {
  BillSyncState syncState = BillSyncState.synced,
  String id = 'b',
}) {
  return Bill(
    id: id,
    merchant: 'Asha Tiffins',
    date: DateTime(2026, 10, 1),
    total: total,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[],
    syncState: syncState,
  );
}

void main() {
  group('Balance.available', () {
    test('is the entry itself when nothing has been bought', () {
      const Balance balance = Balance(base: 25000);
      expect(balance.available(const <Bill>[]), 25000);
    });

    test('subtracts every bill, newest and oldest alike', () {
      const Balance balance = Balance(base: 1000);
      final List<Bill> bills = <Bill>[
        _bill(120, id: 'newest'),
        _bill(380, id: 'middle'),
        _bill(500, id: 'oldest'),
      ];
      expect(balance.available(bills), 0);
    });

    test('counts a bill still waiting in the upload queue', () {
      const Balance balance = Balance(base: 1000);
      final List<Bill> bills = <Bill>[
        _bill(600, syncState: BillSyncState.pending),
      ];
      expect(balance.available(bills), 400);
    });

    test('goes negative once spending passes the entry', () {
      const Balance balance = Balance(base: 100);
      expect(balance.available(<Bill>[_bill(250)]), -150);
    });
  });

  group('Balance copyWith', () {
    test('keeps the stored time unless a new figure is written', () {
      final DateTime at = DateTime(2026, 10, 26, 9);
      const Balance balance = Balance(base: 500, updatedAt: null);
      final Balance renamed = balance.copyWith(base: 750, updatedAt: at);

      expect(renamed.base, 750);
      expect(renamed.updatedAt, at);
      expect(renamed, isNot(balance));
    });
  });
}
