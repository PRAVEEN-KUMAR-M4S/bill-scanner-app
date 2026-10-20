import '../domain/entities/bill.dart';
import '../domain/entities/bill_category.dart';
import '../domain/entities/bill_item.dart';

/// The demo bill shipped with the app.
///
/// Its values match the design export: Asha Tiffins, two 340.00 items and a
/// 680.00 total, dated the first of the current month so the dashboard keeps
/// showing the designed month.
Bill buildSampleBill(DateTime now) {
  return Bill(
    id: '',
    merchant: 'Asha Tiffins',
    date: DateTime(now.year, now.month, 1, 12),
    total: 680,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[
      BillItem(name: 'Tiffin special', quantity: 1, priceEach: 340),
      BillItem(name: 'Masala chai', quantity: 1, priceEach: 340),
    ],
    isSample: true,
  );
}
