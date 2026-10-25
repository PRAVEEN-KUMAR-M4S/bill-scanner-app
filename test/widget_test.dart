import 'dart:convert';

import 'package:bill_scanner/app.dart';
import 'package:bill_scanner/core/di/injector.dart';
import 'package:bill_scanner/core/navigation/app_shell.dart';
import 'package:bill_scanner/core/network/api_service.dart';
import 'package:bill_scanner/core/widgets/paper_checkbox.dart';
import 'package:bill_scanner/features/auth/data/datasources/auth_api.dart';
import 'package:bill_scanner/features/auth/data/repositories/api_auth_repository.dart';
import 'package:bill_scanner/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:bill_scanner/features/auth/data/session/auth_token_store.dart';
import 'package:bill_scanner/features/auth/domain/entities/app_user.dart';
import 'package:bill_scanner/features/auth/presentation/pages/register_page.dart';
import 'package:bill_scanner/features/auth/presentation/pages/sign_in_page.dart';
import 'package:bill_scanner/features/auth/presentation/pages/welcome_page.dart';
import 'package:bill_scanner/features/bills/data/repositories/in_memory_bill_repository.dart';
import 'package:bill_scanner/features/bills/presentation/pages/bills_page.dart';
import 'package:bill_scanner/features/home/presentation/pages/home_page.dart';
import 'package:bill_scanner/features/review/presentation/pages/review_page.dart';
import 'package:bill_scanner/features/scan/data/repositories/simulated_scan_repository.dart';
import 'package:bill_scanner/features/scan/presentation/camera/camera_driver.dart';
import 'package:bill_scanner/features/scan/presentation/camera/simulated_camera_driver.dart';
import 'package:bill_scanner/features/scan/presentation/pages/add_bill_page.dart';
import 'package:bill_scanner/features/scan/presentation/pages/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget buildApp({
  AppUser? restoredUser,
  CameraDriver Function()? createCamera,
}) {
  return BillScannerApp(
    dependencies: AppDependencies(
      authRepository: InMemoryAuthRepository(latency: Duration.zero),
      billRepository: InMemoryBillRepository(latency: Duration.zero),
      scanRepository: SimulatedScanRepository(
        latency: const Duration(milliseconds: 120),
      ),
      createCamera: createCamera,
      restoredUser: restoredUser,
    ),
  );
}

/// Scopes a finder to a single page so the inactive tabs of the shell's
/// [IndexedStack] don't match.
Finder inPage(Type page, Finder matching) {
  return find.descendant(of: find.byType(page), matching: matching);
}

/// The bottom navigation tab with [label].
Finder navTab(String label) {
  return find.descendant(
    of: find.byType(AppBottomNav),
    matching: find.text(label),
  );
}

Future<void> pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  AppUser? restoredUser,
  CameraDriver Function()? createCamera,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    buildApp(restoredUser: restoredUser, createCamera: createCamera),
  );
  await tester.pumpAndSettle();
}

Future<void> continueAsGuest(WidgetTester tester) async {
  final Finder guest = find.textContaining('CONTINUE AS GUEST');
  await tester.ensureVisible(guest);
  await tester.pumpAndSettle();
  await tester.tap(guest);
  await tester.pumpAndSettle();
}

Future<void> openAddBill(WidgetTester tester) async {
  final Finder addBill = inPage(HomePage, find.text('Add a bill'));
  await tester.ensureVisible(addBill);
  await tester.pumpAndSettle();
  await tester.tap(addBill);
  await tester.pumpAndSettle();
}

Future<void> openSampleReview(WidgetTester tester) async {
  await openAddBill(tester);
  await tester.ensureVisible(find.text('Just looking around?'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Just looking around?'));
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save bill'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save bill'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // Tests must not reach the network for fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('welcome screen shows the brand and entry points', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(inPage(WelcomePage, find.text('Billscan AI')), findsOneWidget);
    expect(inPage(WelcomePage, find.text('Sign In')), findsOneWidget);
    expect(inPage(WelcomePage, find.text('Join the Fold')), findsOneWidget);
    expect(find.textContaining('CONTINUE AS GUEST'), findsOneWidget);
  });

  testWidgets('guest entry lands on the spending dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await continueAsGuest(tester);

    expect(
      inPage(HomePage, find.text('Your spending,\nat a glance.')),
      findsOneWidget,
    );
    expect(inPage(HomePage, find.text('billo')), findsOneWidget);
    expect(inPage(HomePage, find.text('₹680.00')), findsNWidgets(2));
    expect(inPage(HomePage, find.text('Recent bills')), findsOneWidget);
    expect(inPage(HomePage, find.text('Asha Tiffins')), findsOneWidget);
    expect(navTab('Home'), findsOneWidget);
  });

  testWidgets('a restored session opens the dashboard directly', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      restoredUser: const AppUser(
        id: '7',
        name: 'Asha Tiffins',
        email: 'asha@billo.app',
      ),
    );

    expect(
      inPage(HomePage, find.text('Your spending,\nat a glance.')),
      findsOneWidget,
    );
    expect(find.byType(WelcomePage), findsNothing);
  });

  testWidgets('sign in rejects a malformed email', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(inPage(WelcomePage, find.text('Sign In')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);

    final Finder fields = inPage(SignInPage, find.byType(TextFormField));
    await tester.enterText(fields.first, 'not-an-email');
    await tester.enterText(fields.last, 'secret123');
    await tester.tap(inPage(SignInPage, find.text('Sign In')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  testWidgets('successful sign in reaches the dashboard', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(inPage(WelcomePage, find.text('Sign In')));
    await tester.pumpAndSettle();

    final Finder fields = inPage(SignInPage, find.byType(TextFormField));
    await tester.enterText(fields.first, 'asha@billo.app');
    await tester.enterText(fields.last, 'secret123');
    await tester.tap(inPage(SignInPage, find.text('Sign In')));
    await tester.pumpAndSettle();

    expect(
      inPage(HomePage, find.text('Your spending,\nat a glance.')),
      findsOneWidget,
    );
  });

  testWidgets('sign in through the API reaches the dashboard', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final AuthTokenStore tokens = AuthTokenStore();
    final ApiAuthRepository repository = ApiAuthRepository(
      authApi: AuthApi(
        ApiService(
          baseUrl: Uri.parse('http://api.test'),
          accessToken: () async => tokens.accessToken,
          client: MockClient((http.Request request) async {
            switch (request.url.path) {
              case '/auth/login':
                return http.Response(
                  jsonEncode(<String, String>{
                    'access_token': 'access-1',
                    'refresh_token': 'refresh-1',
                  }),
                  200,
                );
              case '/auth/me':
                expect(request.headers['authorization'], 'Bearer access-1');
                return http.Response(
                  jsonEncode(<String, Object>{
                    'id': 7,
                    'email': 'asha@billo.app',
                  }),
                  200,
                );
              default:
                return http.Response('{"detail":"not found"}', 404);
            }
          }),
        ),
      ),
      tokens: tokens,
    );

    await tester.pumpWidget(
      BillScannerApp(dependencies: AppDependencies(authRepository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(inPage(WelcomePage, find.text('Sign In')));
    await tester.pumpAndSettle();

    final Finder fields = inPage(SignInPage, find.byType(TextFormField));
    await tester.enterText(fields.first, 'asha@billo.app');
    await tester.enterText(fields.last, 'secret123');
    await tester.tap(inPage(SignInPage, find.text('Sign In')));
    await tester.pumpAndSettle();

    expect(
      inPage(HomePage, find.text('Your spending,\nat a glance.')),
      findsOneWidget,
    );
    expect(tokens.hasSession, isTrue);
  });

  testWidgets('register requires terms and a strong password', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(inPage(WelcomePage, find.text('Join the Fold')));
    await tester.pumpAndSettle();

    final Finder fields = inPage(RegisterPage, find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Asha Tiffins');
    await tester.enterText(fields.at(1), 'asha@billo.app');
    await tester.enterText(fields.at(2), '123');
    await tester.ensureVisible(inPage(RegisterPage, find.text('Register')));
    await tester.tap(inPage(RegisterPage, find.text('Register')));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(find.text('Please accept the terms to continue'), findsOneWidget);
  });

  testWidgets('bills tab lists saved bills and filters by search', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await continueAsGuest(tester);

    await tester.tap(navTab('Bills'));
    await tester.pumpAndSettle();

    expect(inPage(BillsPage, find.text('YOUR RECORDS')), findsOneWidget);
    expect(inPage(BillsPage, find.text('₹680.00')), findsNWidgets(2));
    expect(
      inPage(BillsPage, find.text('1 bill saved this month')),
      findsOneWidget,
    );
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsOneWidget);

    final Finder search = inPage(BillsPage, find.byType(TextField));
    await tester.enterText(search, 'masala');
    await tester.pumpAndSettle();
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsOneWidget);

    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsNothing);
    expect(find.text('No bills match that search.'), findsOneWidget);

    // Clear the search, then filter by a category that is scrolled off-screen.
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsOneWidget);

    final Finder travel = inPage(BillsPage, find.text('Travel'));
    await tester.ensureVisible(travel);
    await tester.pumpAndSettle();
    await tester.tap(travel);
    await tester.pumpAndSettle();
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsNothing);
    expect(find.text('No bills match that search.'), findsOneWidget);

    final Finder all = inPage(BillsPage, find.text('All'));
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(inPage(BillsPage, find.text('Asha Tiffins')), findsOneWidget);
  });

  testWidgets('camera flow scans, reviews and saves a bill', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await continueAsGuest(tester);
    await openAddBill(tester);

    expect(find.text("Let's get this\nbill in order."), findsOneWidget);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.text('Turn on your camera.'), findsOneWidget);
    expect(find.text('01 / 02'), findsOneWidget);

    // Access was granted on open: the preview fills the frame and the
    // capture button is live.
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.text('CAPTURE'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Reading your bill…'), findsOneWidget);
    expect(find.text('Sending the photo to the scanner.'), findsOneWidget);
    expect(find.text('02 / 02'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ReviewPage), findsOneWidget);
    expect(
      find.text('Sample bill - edit any field before saving'),
      findsOneWidget,
    );
    expect(find.text('3 / 3'), findsOneWidget);

    await tapSave(tester);

    expect(find.byType(ReviewPage), findsNothing);
    expect(find.text('Bill saved'), findsOneWidget);
    expect(inPage(HomePage, find.text('₹1,360.00')), findsOneWidget);
    expect(inPage(HomePage, find.text('2 bills')), findsOneWidget);
  });

  testWidgets('a refused camera explains itself and can be retried', (
    WidgetTester tester,
  ) async {
    final SimulatedCameraDriver camera = SimulatedCameraDriver(
      statusOnOpen: CameraStatus.denied,
    );
    await pumpApp(tester, createCamera: () => camera);
    await continueAsGuest(tester);
    await openAddBill(tester);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(camera.opens, 1);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(
      find.textContaining(
        'Camera access is off. Allow it in your phone settings',
      ),
      findsOneWidget,
    );
    // No preview and no shutter until access is granted.
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    expect(find.text('CAPTURE'), findsNothing);
    expect(find.text('Allow camera'), findsOneWidget);

    final Finder retry = find.text('Allow camera');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(camera.opens, 2);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review blocks saving an empty merchant and adds items', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await continueAsGuest(tester);
    await openSampleReview(tester);

    final Finder merchantField = find.descendant(
      of: find.byKey(const ValueKey<String>('review-merchant')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(merchantField, '');
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(find.byType(ReviewPage), findsOneWidget);
    expect(find.text('Add the shop or merchant'), findsOneWidget);
    expect(
      find.text('Check the highlighted fields before saving.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('ITEM 03'), findsOneWidget);
  });

  testWidgets('profile sheet signs out and returns to welcome', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await continueAsGuest(tester);

    await tester.tap(inPage(HomePage, find.byIcon(Icons.person_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Browsing as a guest'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsNothing);
    expect(inPage(WelcomePage, find.text('Join the Fold')), findsOneWidget);
  });

  testWidgets('registering twice reports the duplicate account', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    Future<void> register(String email) async {
      await tester.tap(inPage(WelcomePage, find.text('Join the Fold')));
      await tester.pumpAndSettle();
      final Finder fields = inPage(RegisterPage, find.byType(TextFormField));
      await tester.enterText(fields.at(0), 'Asha Tiffins');
      await tester.enterText(fields.at(1), email);
      await tester.enterText(fields.at(2), 'secret123');
      await tester.tap(inPage(RegisterPage, find.byType(PaperCheckbox)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(inPage(RegisterPage, find.text('Register')));
      await tester.tap(inPage(RegisterPage, find.text('Register')));
      await tester.pumpAndSettle();
    }

    await register('asha@billo.app');
    expect(
      inPage(HomePage, find.text('Your spending,\nat a glance.')),
      findsOneWidget,
    );

    await tester.tap(inPage(HomePage, find.byIcon(Icons.person_outline)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    await register('asha@billo.app');

    expect(
      find.text('That email is already registered. Try signing in.'),
      findsOneWidget,
    );
  });

  testWidgets('post-login screens fit small, normal and wide viewports', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(800, 1000),
    ]) {
      // Unmount the previous run so the shell and its navigation stack reset.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpApp(tester, size: size);
      await continueAsGuest(tester);
      expect(tester.takeException(), isNull, reason: 'home at $size');

      await tester.tap(navTab('Bills'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'bills at $size');

      await tester.tap(inPage(BillsPage, find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      expect(find.byType(AddBillPage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'add bill at $size');

      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanPage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'camera at $size');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AddBillPage), findsOneWidget);

      final Finder sample = find.text('Just looking around?');
      await tester.ensureVisible(sample);
      await tester.pumpAndSettle();
      await tester.tap(sample);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewPage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'review at $size');
    }
  });

  testWidgets('review page fits the smallest viewport', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(tester, size: const Size(320, 568));
    await continueAsGuest(tester);
    await openSampleReview(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ReviewPage), findsOneWidget);

    await tester.drag(
      find.descendant(
        of: find.byType(ReviewPage),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -280),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Items'), findsOneWidget);
  });
}
