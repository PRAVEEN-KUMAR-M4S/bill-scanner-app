import 'dart:typed_data';

import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/repositories/bill_repository.dart';
import 'package:bill_scanner/features/scan/data/repositories/api_scan_repository.dart';
import 'package:bill_scanner/features/scan/data/repositories/session_scan_repository.dart';
import 'package:bill_scanner/features/scan/domain/entities/captured_photo.dart';
import 'package:bill_scanner/features/scan/domain/entities/scan_source.dart';
import 'package:bill_scanner/features/scan/domain/repositories/scan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _RecordingBillRepository implements BillRepository {
  int extractCalls = 0;
  List<int>? bytes;
  String? filename;
  String? contentType;

  @override
  Future<List<Bill>> fetchBills() async => const <Bill>[];

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

class _FakeScanRepository implements ScanRepository {
  _FakeScanRepository(this.label);

  final String label;
  final List<ScanSource> calls = <ScanSource>[];

  @override
  Future<BillExtraction?> capture(ScanSource source) async {
    calls.add(source);
    return BillExtraction(
      bill: Bill(
        id: label,
        merchant: label,
        date: DateTime(2026, 10, 22),
        total: 1,
        category: BillCategory.other,
        items: const <BillItem>[],
      ),
    );
  }

  @override
  Future<BillExtraction> read(CapturedPhoto photo) async {
    reads.add(photo);
    return BillExtraction(
      bill: Bill(
        id: label,
        merchant: label,
        date: DateTime(2026, 10, 22),
        total: 1,
        category: BillCategory.other,
        items: const <BillItem>[],
      ),
    );
  }

  final List<CapturedPhoto> reads = <CapturedPhoto>[];

  @override
  Bill get sampleBill => Bill(
    id: label,
    merchant: label,
    date: DateTime(2026, 10, 22),
    total: 1,
    category: BillCategory.other,
    items: const <BillItem>[],
  );
}

void main() {
  test(
    'capture picks from the requested source and extracts the bytes',
    () async {
      final _RecordingBillRepository bills = _RecordingBillRepository();
      ImageSource? picked;
      final ApiScanRepository scan = ApiScanRepository(
        billRepository: bills,
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
    final ApiScanRepository scan = ApiScanRepository(
      billRepository: _RecordingBillRepository(),
      pickImage: (ImageSource source) async {
        expect(source, ImageSource.camera);
        return null;
      },
    );

    expect(await scan.capture(ScanSource.camera), isNull);
  });

  test('the session scanner picks the API only when signed in', () async {
    bool signedIn = false;
    final _FakeScanRepository remote = _FakeScanRepository('remote');
    final _FakeScanRepository local = _FakeScanRepository('local');
    final SessionScanRepository scan = SessionScanRepository(
      signedIn: remote,
      guest: local,
      hasSession: () => signedIn,
    );

    expect((await scan.capture(ScanSource.gallery))?.bill.id, 'local');
    expect(scan.sampleBill.id, 'local');

    signedIn = true;
    expect((await scan.capture(ScanSource.camera))?.bill.id, 'remote');
    expect(scan.sampleBill.id, 'remote');
    expect(local.calls, <ScanSource>[ScanSource.gallery]);
    expect(remote.calls, <ScanSource>[ScanSource.camera]);
  });

  test('cancelling the picker sends nothing to the scanner', () async {
    final _RecordingBillRepository bills = _RecordingBillRepository();
    final ApiScanRepository scan = ApiScanRepository(
      billRepository: bills,
      pickImage: (ImageSource source) async => null,
    );

    expect(await scan.capture(ScanSource.gallery), isNull);
    expect(bills.extractCalls, 0);
  });

  test(
    'read sends an already-captured photo straight to the scanner',
    () async {
      final _RecordingBillRepository bills = _RecordingBillRepository();
      final ApiScanRepository scan = ApiScanRepository(billRepository: bills);

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

  test('the session scanner reads through the active repository', () async {
    bool signedIn = false;
    final _FakeScanRepository remote = _FakeScanRepository('remote');
    final _FakeScanRepository local = _FakeScanRepository('local');
    final SessionScanRepository scan = SessionScanRepository(
      signedIn: remote,
      guest: local,
      hasSession: () => signedIn,
    );
    const CapturedPhoto photo = CapturedPhoto(
      bytes: <int>[1],
      filename: 'bill.jpg',
    );

    expect((await scan.read(photo)).bill.id, 'local');

    signedIn = true;
    expect((await scan.read(photo)).bill.id, 'remote');
    expect(local.reads, <CapturedPhoto>[photo]);
    expect(remote.reads, <CapturedPhoto>[photo]);
  });
}
