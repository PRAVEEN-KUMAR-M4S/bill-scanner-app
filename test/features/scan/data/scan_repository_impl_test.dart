import 'dart:typed_data';

import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/entities/bills_snapshot.dart';
import 'package:bill_scanner/features/bills/domain/repositories/bill_repository.dart';
import 'package:bill_scanner/features/scan/data/repositories/scan_repository_impl.dart';
import 'package:bill_scanner/features/scan/domain/entities/captured_photo.dart';
import 'package:bill_scanner/features/scan/domain/entities/scan_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// Records what the scanner asked the bills repository to read.
class _RecordingBillRepository implements BillRepository {
  int extractCalls = 0;
  List<int>? bytes;
  String? filename;
  String? contentType;

  @override
  Future<BillsSnapshot> fetchBills() async =>
      const BillsSnapshot(bills: <Bill>[], source: BillsSource.server);

  @override
  Future<Bill> save(Bill bill) async => bill;

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    extractCalls++;
    this.bytes = bytes;
    this.filename = filename;
    this.contentType = contentType;
    return BillExtraction(
      bill: Bill(
        id: '',
        merchant: 'Lulu',
        date: DateTime(2026, 10, 22),
        total: 125,
        category: BillCategory.groceries,
        items: const <BillItem>[BillItem(name: 'Rice', amount: 125)],
      ),
    );
  }
}

void main() {
  test(
    'capture picks from the requested source and extracts the bytes',
    () async {
      final _RecordingBillRepository bills = _RecordingBillRepository();
      ImageSource? picked;
      final ScanRepositoryImpl scan = ScanRepositoryImpl(
        bills: bills,
        hasSession: () => true,
        pickImage: (ImageSource source) async {
          picked = source;
          return XFile.fromData(
            Uint8List.fromList(<int>[1, 2, 3, 4]),
            name: 'bill.png',
            path: 'bill.png',
            mimeType: 'image/png',
          );
        },
      );

      final BillExtraction? report = await scan.capture(ScanSource.gallery);

      expect(picked, ImageSource.gallery);
      expect(bills.extractCalls, 1);
      expect(bills.bytes, <int>[1, 2, 3, 4]);
      expect(bills.filename, 'bill.png');
      expect(bills.contentType, 'image/png');
      expect(report?.bill.merchant, 'Lulu');
    },
  );

  test('camera source reaches the camera picker', () async {
    final ScanRepositoryImpl scan = ScanRepositoryImpl(
      bills: _RecordingBillRepository(),
      hasSession: () => true,
      pickImage: (ImageSource source) async {
        expect(source, ImageSource.camera);
        return null;
      },
    );

    expect(await scan.capture(ScanSource.camera), isNull);
  });

  test('cancelling the picker sends nothing to the scanner', () async {
    final _RecordingBillRepository bills = _RecordingBillRepository();
    final ScanRepositoryImpl scan = ScanRepositoryImpl(
      bills: bills,
      hasSession: () => true,
      pickImage: (ImageSource source) async => null,
    );

    expect(await scan.capture(ScanSource.gallery), isNull);
    expect(bills.extractCalls, 0);
  });

  test(
    'read sends an already-captured photo straight to the scanner',
    () async {
      final _RecordingBillRepository bills = _RecordingBillRepository();
      final ScanRepositoryImpl scan = ScanRepositoryImpl(
        bills: bills,
        hasSession: () => true,
      );

      final BillExtraction report = await scan.read(
        const CapturedPhoto(bytes: <int>[9, 8, 7], filename: 'capture.jpg'),
      );

      expect(bills.extractCalls, 1);
      expect(bills.bytes, <int>[9, 8, 7]);
      expect(bills.filename, 'capture.jpg');
      expect(bills.contentType, 'image/jpeg');
      expect(report.bill.merchant, 'Lulu');
    },
  );

  test('a guest gets the bundled sample without a picker or the API', () async {
    final _RecordingBillRepository bills = _RecordingBillRepository();
    bool picked = false;
    final ScanRepositoryImpl scan = ScanRepositoryImpl(
      bills: bills,
      hasSession: () => false,
      guestLatency: Duration.zero,
      pickImage: (ImageSource source) async {
        picked = true;
        return null;
      },
    );

    final BillExtraction? captured = await scan.capture(ScanSource.camera);

    expect(picked, isFalse);
    expect(captured?.bill.merchant, 'Asha Tiffins');
    expect(scan.sampleBill.merchant, 'Asha Tiffins');

    final BillExtraction read = await scan.read(
      const CapturedPhoto(bytes: <int>[1], filename: 'bill.jpg'),
    );
    expect(read.bill.merchant, 'Asha Tiffins');
    expect(bills.extractCalls, 0);
  });

  test('an image/png photo keeps its content type', () async {
    final _RecordingBillRepository bills = _RecordingBillRepository();
    final ScanRepositoryImpl scan = ScanRepositoryImpl(
      bills: bills,
      hasSession: () => true,
      pickImage: (ImageSource source) async => XFile.fromData(
        Uint8List.fromList(<int>[1]),
        name: 'bill.png',
        path: 'bill.png',
      ),
    );

    await scan.capture(ScanSource.gallery);

    expect(bills.contentType, 'image/png');
  });

  test('the session is read per call, not once at construction', () async {
    bool signedIn = false;
    final _RecordingBillRepository bills = _RecordingBillRepository();
    final ScanRepositoryImpl scan = ScanRepositoryImpl(
      bills: bills,
      hasSession: () => signedIn,
      guestLatency: Duration.zero,
      pickImage: (ImageSource source) async => XFile.fromData(
        Uint8List.fromList(<int>[1]),
        name: 'bill.jpg',
        path: 'bill.jpg',
      ),
    );

    expect(
      (await scan.capture(ScanSource.gallery))?.bill.merchant,
      'Asha Tiffins',
    );
    expect(bills.extractCalls, 0);

    signedIn = true;
    expect((await scan.capture(ScanSource.gallery))?.bill.merchant, 'Lulu');
    expect(bills.extractCalls, 1);
  });
}
