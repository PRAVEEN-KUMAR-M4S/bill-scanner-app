# BillScan AI — Interview Notes

A revision companion to [`PROJECT_GUIDE.md`](PROJECT_GUIDE.md). Use it the night
before: pitches, trade-offs, likely questions, snippets to know cold, and the
debugging stories that make the project sound like work rather than a tutorial.

---

## 1. The 30-second pitch

> "BillScan AI is a Flutter expense app: you sign in, photograph a bill, check
> the extracted fields, and save it. I built it feature-first with clean
> architecture — domain, data and presentation per feature — one BLoC per
> feature with sealed events and states, and repository contracts. Auth, the
> bill list, photo extraction and confirmation all talk to a FastAPI backend
> through one reusable `ApiService` with multipart support and typed errors; the
> JWT pair is restored from SharedPreferences on launch. The five post-login
> screens come from design exports, with a token-based design system, shared
> paper components, and layouts verified from 320-pixel phones up to tablets.
> Bills are offline-first: SQLite caches the last list, and a save made without
> a connection waits in an upload queue and syncs on the next successful load.
> It has 91 tests — 19 widget paths and 72 unit tests (network, data, SQLite
> schema/queries, the offline queue and the scan bloc) — and the analyzer is
> clean."

---

## 2. The two-minute walkthrough

1. **Auth** — `WelcomePage` offers guest, sign-in and registration. Forms use
   `Form` + validators; `AuthBloc` emits loading/authenticated/error. Email auth
   goes `AuthBloc → ApiAuthRepository → AuthApi → ApiService`, stores the token
   pair and loads `/auth/me`; one listener in `app.dart` moves the stack to the
   shell or shows a snack bar.
2. **Shell** — Home and Bills live in an `IndexedStack` behind a custom bottom
   bar. A single app-level `BillsBloc` feeds both so they never disagree.
3. **Dashboard** — derived month totals and a seven-day strip from
   `BillSummary.fromBills`, an "Add a bill" shortcut, recent bills.
4. **Bills** — search across merchant/category/items and category chips, all
   handled in the bloc; the full list is kept separately so the dashboard total
   is not filtered.
5. **Scan** — Add-a-bill offers capture, library, manual entry and a sample.
   The camera screen uses a custom-painted frame and a cream sheet; a photo is
   picked with `image_picker`, sent to `/bills/extract`, and `ScanCaptured`
   carries the draft plus the server's problems into review.
6. **Review** — a stateful form: raw strings in the state, derived validation
   (`merchantValid`, `dateValid`, `totalValid`, item rules), add/remove items,
   totals, and save. On success `ReviewSaved` triggers a bills reload, a snack
   bar and a pop to the shell.
7. **Quality** — 13 shared design-system widgets, design tokens instead of
   hardcoded values, responsive patterns, 91 tests (19 widget + 72 unit,
   including real SQLite) and zero analyzer issues.

---

## 3. Architecture on a whiteboard

Draw two boxes on the outside and one in the middle:

```
┌──────────────────────┐        ┌──────────────────────┐
│     presentation     │        │        data          │
│ pages · widgets      │        │ repository impls     │
│ blocs · events       │        │ sample data          │
│ states               │        │ latency              │
└──────────┬───────────┘        └──────────┬───────────┘
           │ depends on                     │ implements
           ▼                                ▼
        ┌──────────────────────────────────────────┐
        │                 domain                   │
        │ entities · repository interfaces         │
        │ use cases · failures                     │
        └──────────────────────────────────────────┘
```

Say: *"The arrows point inwards; domain has no Flutter or storage knowledge.
Data implements what domain declares, presentation calls use cases, and a single
composition root wires it. That gives me swappable edges and fast tests."*

Then draw the request path:

```
tap → event → bloc → use case → repository (interface)
                    ← result
     state ← emit ←
     page rebuilds
```

---

## 4. Trade-offs I made (and would defend)

| Decision | Why | Cost / when to revisit |
|---|---|---|
| BLoC over `setState`/Provider | Explicit events, immutable states, easy async/loading/error handling, testable | More files than `setState`; fine for a growing app |
| Sealed events and states | Exhaustive switches and readable transitions | Boilerplate per event; codegen helps at scale |
| Thin use cases | Keep blocs free of repository APIs; rule/analytics seam | Ceremony now; pays off with backend rules |
| Repository interfaces | UI/test substitute without mocking widgets | One extra contract per feature |
| Hand-written `copyWith`/`props` | No build step; small states | Use freezed when states multiply |
| `AppDependencies` instead of `get_it` | One obvious composition root, easy constructor injection | Manual wiring grows; move to get_it when the graph does |
| `http` + a hand-written `ApiService` | Four verbs, JSON, bearer auth and typed errors in one tested file | Revisit Dio when interceptors, retries or uploads stack up |
| Token pair in SharedPreferences | A restart keeps the session without a secure-store dependency yet | Not a vault; swap the storage implementation for Keychain/Keystore before shipping |
| One BillsBloc for two screens | No sync logic; one source of truth | Holds both all/filtered lists; acceptable at this size |
| `IndexedStack` for tabs | Keeps scroll/state per tab | Both pages stay in the tree; tests must scope finders |
| Raw strings in review state | Partial input (`1.`, empty) does not fight the user | Parse/validate in getters; use domain values on submit |
| Demo chart from real data | Honest product behaviour | Does not replicate the export's decorative tall bar |
| API repositories for auth/bills + image_picker | Real end-to-end flow without a bespoke camera preview | In-memory/simulated implementations remain for deterministic tests |

---

## 5. Likely questions and answers

### Clean architecture

**Q: What is clean architecture in one sentence?**
> "Separating what the app knows (domain) from how it stores things (data) and
> how it presents them (presentation), with dependencies pointing inward."

**Q: Where does this project apply it?**
> Every feature is split into `domain`, `data` and `presentation`. For example
> bills: `Bill`/`BillItem`/`BillRepository`/`FetchBills` are domain;
> `InMemoryBillRepository` is data; `BillsBloc`, pages and `BillTile` are
> presentation. Domain imports no Flutter code.

**Q: Why use cases if they only call the repository?**
> They give the bloc a stable API that isn't tied to data methods, and they're
> where rules will go — e.g. "a bill must have at least one item", dedupe, or
> analytics. They also make the bloc testable with a one-method fake instead of a
> multi-method repository.

**Q: Why feature-first folders?**
> A feature is the unit of change. Everything about bills is under
> `features/bills`, so a new developer can find it, and deleting a feature is
> deleting a folder. Layer-first (`models/`, `services/`) spreads one feature
> across the tree.

**Q: Does every feature need all three folders?**
> No. `home` and `review` have no data/domain because they reuse bills' domain
> and the shared bloc. Empty folders would be cargo cult.

### BLoC and state

**Q: Why BLoC instead of Provider/Riverpod/setState?**
> The app has async transitions (auth, fetch, scan, save) and several screens
> sharing state. BLoC's event→state model makes those transitions explicit and
> testable, and it separates business state from widgets. `setState` would leak
> logic into pages; Provider is fine for small apps but doesn't give the same
> event trace. Riverpod would work; BLoC is already established here.

**Q: Why separate events from states?**
> An event is an intention (`ReviewSubmitted`), a state is a snapshot
> (`ReviewEditing(isSaving: true)`). Keeping them apart makes the transition
> graph obvious and lets the UI dispatch intent without knowing the rules.

**Q: Why sealed classes?**
> They are a closed union. `switch` over `AuthState` is exhaustive, so adding a
> state forces every handler to be updated at compile time. No `else` fallbacks.

**Q: What is Equatable for?**
> Value equality. BLoC compares the new state to the old one and skips rebuilds
> when equal; `BlocConsumer.listenWhen` compares previous/current. Without it,
> two `BillsLoaded` objects with the same data would be different by identity.

**Q: How do you handle loading and errors?**
> Loading is emitted before the await; errors are states (or a `failureMessage`
> field) after catching typed failures. Auth errors surface via one app-level
> listener; review errors stay on the review page. Repository exceptions never
> reach widgets.

**Q: Why is AuthBloc app-level but ReviewBloc route-level?**
> Auth identity is needed everywhere and lasts the session; a review draft is
> meaningless after leaving the screen. Scan is the same: the camera session dies
> with its route. Blocs are closed automatically when their provider is disposed;
> the app-level ones are closed in `BillScannerApp.dispose`.

**Q: How do you prevent double submits?**
> The event handler returns early when `isSaving`, and the button is disabled
> while loading. The camera bloc also returns early if it is already scanning.

### Data and DI

**Q: How does saving a bill update the dashboard?**
> `ReviewSaved` triggers `BillsReloaded` on the shared app-level BillsBloc, which
> refetches from the same repository instance and emits an updated list. The
> dashboard and list both rebuild. No manual copying between screens.

**Q: How is the backend wired?**
> Through `ApiService` → `AuthApi`/`BillApi` → `ApiAuthRepository`/`ApiBillRepository`,
> with `MockClient` tests for every status branch. All paths live in
> `ApiEndpoints`; `BillMapper` owns the JSON rules (rupees as strings, ISO
> dates, ten category slugs, whole-line amounts). Swapping a repository is one
> line in `AppDependencies`; pages and blocs stay untouched. That is exactly how
> offline support landed: `OfflineBillRepository` wraps the API repository, so
> no bloc, page or use case changed.

**Q: How does persistence work?**
> Two stores for two jobs. The session (tokens + profile) goes through
> `SessionStorage` to SharedPreferences and is restored before `runApp`; tests
> use the in-memory implementation. Bills go to SQLite through
> `BillLocalStore`: `SqliteBillStore` on mobile, `MemoryBillStore` in tests and
> on web/desktop. Each row is partitioned by `owner_id`, so two accounts on one
> phone never share a cache.

**Q: Walk me through an offline save.**
> Review dispatches `SaveBill` → `OfflineBillRepository.save` →
> `POST /bills/confirm`. A connection or timeout failure becomes
> `BillFailure.offline`; the repository stores the bill with a `local-…` id and
> `sync_status = 'pending'` and returns it as saved. The review screen sees
> `isPendingSync` and says "Saved on this phone. It will sync when you are back
> online." The bills list shows a "Pending sync" badge and a banner. On the next
> successful `fetchBills`, the queue is sent oldest first, each server row
> replaces its local row in one transaction, then `GET /bills` refreshes the
> cache.

**Q: Why not queue every failed save?**
> A 422 is deterministic — the backend will reject the same draft forever. Only
> connection failures are retried automatically; a validation failure stays on
> the review form with the server's problem messages. A queued bill that the
> server later rejects stays queued and visible rather than disappearing.

**Q: How do you test SQL without a device?**
> `sqflite_common_ffi` opens a real in-memory SQLite database in a Dart VM test
> with the production schema (`BillDatabase.open(factory: databaseFactoryFfi)`).
> The ten tests cover create statements/indexes, ordering, owner partitioning,
> the pending filter, refresh-keeps-queue, cascade on promotion, reopening a
> closed file and item replacement. `docs/SQL_GUIDE.md` is the write-up and practice book for those
> queries.

**Q: What is the offline design's weak spot?**
> `POST /bills/confirm` has no idempotency key. If the request reached the server
> but the response was lost, the retry can create a duplicate. The fix is a
> client `request_id` with a unique index on the server; the app already has a
> stable local id it could send. I would also move the flush into a background
> task so it does not wait for the app to open.

**Q: Why keep the sample bill in two repositories?**
> It does not: `buildSampleBill(now)` in `features/bills/data` is the single
> source used by the seed and by the simulated scanner. That avoids drift between
> the dashboard's demo row and the sample review.

**Q: Why is `isSample` on the entity?**
> The review banner needs to know where the values came from. A dedicated draft
> type or a review parameter would also work; the flag is the simplest option
> for a demo. In a production model I would separate "draft source" from the
> persisted bill.

**Q: JSON/serialization?**
> Both features have handwritten mappers in data: `AuthTokens`/`ApiUser` for the
> five auth responses and `BillMapper` for the three bill routes. Domain entities
> never see transport shapes. A row mapper (`BillRowMapper`) does the same for
> SQLite, so a column rename never leaks above the data layer. At this size,
> `json_serializable`/`build_runner` would add a build step without removing
> much code.

### UI, design and responsiveness

**Q: How is the design system structured?**
> Tokens (`AppColors`, `AppSpacing`, `AppRadius`, `AppStroke`, `AppShadows`,
> `AppLayout`, `AppFonts`) plus 13 shared components. Pages never hardcode a
> colour or a font; they compose widgets.

**Q: When do you promote a widget to `core/widgets`?**
> When a second screen needs the same markup. This pass promoted `PageScaffold`,
> `ScreenHeader`, `SectionHeading`, `ActionTile` and `PaperChip`; feature-only
> widgets like `BillTile`, `CaptureFrame` and `AuthPageScaffold` stay in their
> features.

**Q: How did you make it responsive?**
> Scrollable pages, a 560-px content cap with growing gutters, `Expanded`/
> `Flexible` text, wrapping and horizontally scrolling chips, breakpoint-aware
> date/total and item rows, a height-capped camera sheet with responsive
> controls, an aspect-ratio capture frame, `FittedBox` for money, and safe-area
> padding. Verified with tests at 320×568, 390×844 and 800×1000 plus live
> browser checks.

**Q: How do you stop long text from overflowing?**
> Buttons and the camera hint use `Flexible` with ellipsis; copy wraps inside
> `Expanded`; chips scroll or wrap; the amount uses `FittedBox(scaleDown)`;
> pages scroll instead of clipping.

**Q: The design is 412 wide. What happens at 320?**
> Review stacks date/total and item fields, the camera controls shrink, the
> sheet scrolls, the dashboard scrolls (Add-a-bill wraps), and the welcome page
> scrolls. No overflow; the tests assert no layout exceptions.

**Q: How would you support dark mode / text scaling / RTL?**
> Dark mode: add a second token set and pass a theme; components already read
> tokens, so most pages need no changes. Text scaling: test at 2.0, prefer
> wrapping over fixed heights. RTL: Flutter's directional widgets handle most of
> it; check icons (arrows) and mirrored layouts.

### Testing

**Q: What is your testing strategy?**
> Two levels. Widget tests drive the real UI and blocs with instant in-memory
> repositories (and one `ApiAuthRepository` backed by `MockClient`), covering
> auth validation and success, session restore, guest entry, tab switching,
> search/filtering, the scan state progression, review validation, items,
> save/reload, sign-out, duplicate emails and no-overflow at three widths. Unit
> tests call `ApiService`, `AuthApi`/`ApiAuthRepository`, `BillApi`, the token
> store and the scan repository directly: 401/409/413/415/422/429/5xx, timeout,
> offline, malformed JSON, multipart, token attach/restore, refresh rotation,
> best-effort logout, list/extract/confirm mapping and 422 problem propagation.

**Q: How do you test an async scanning state?**
> The scan repository takes 120 ms in tests: the screen asks for access in
> `initState`, so after the shutter press `pump(16ms)` shows "Reading your bill…"
> and `02 / 02`, then `pumpAndSettle()` reaches review. The camera and the
> repository are both injected fakes, so a denied permission, a failed shutter
> and the torch are all testable without a device.

**Q: Why do finders need scoping?**
> The shell's `IndexedStack` keeps Home and Bills in the tree. `find.text` would
> match both, so helpers scope to `HomePage`/`BillsPage` or the bottom nav. This
> is a real consequence of preserving tab state.

**Q: What isn't tested?**
> Goldens, device integration, and an automated run against the live API (the
> network tests use `MockClient`; I exercised real sign-in, listing and
> confirmation manually). The camera and the image picker are only tested
> through their injected replacements — `ScanBloc` does have unit tests. I'd add `bloc_test` for the state
> matrices, golden tests for the paper components, and an integration test for
> a real capture.

**Q: Why disable Google Fonts in tests?**
> Tests must not depend on the network; disabling runtime fetching keeps them
> deterministic. In production the fonts are fetched/cached at runtime.

### Performance and quality

**Q: Any performance concerns?**
> Filtering and summary computation are O(n) over a small list. Builds are
> scoped with `BlocBuilder`/`context.select`; static widgets are `const`;
> `IndexedStack` avoids rebuilding tabs on switch. For large data I'd move
> filtering server-side or memoise the summary.

**Q: Accessibility?**
> Icon-only controls have semantic labels, tappable rows are buttons, and the
> nav reports selected state. Known gaps: some text-bearing controls repeat
> their label ("Bills Bills") because an explicit label wraps visible text, and
> the accent-on-cream active tab is low contrast. The fixes are
> `excludeSemantics` and a stronger active tint.

**Q: Security?**
> Passwords are sent to the API (HTTPS in production), which stores bcrypt
> hashes; the app never stores the password. The access token (30 min JWT) and
> refresh token are persisted in SharedPreferences for the demo, never logged,
> and cleared on sign-out; the refresh token is revoked server-side. A shipping
> build still needs Keychain/Keystore storage, automatic 401 → refresh → retry,
> and rate limiting on the API.

---

## 6. Snippets to know cold

### 6.1 Auth: one async path for every request

```dart
Future<void> _run(
  Emitter<AuthState> emit,
  Future<AppUser> Function() request,
) async {
  emit(const AuthLoading());
  try {
    emit(AuthAuthenticated(await request()));
  } on AuthFailure catch (failure) {
    emit(AuthError(failure.message));
  }
}
```

Why it matters: loading is emitted first; all four entry points share it; only
recoverable `AuthFailure`s become user messages, so unexpected errors are not
masked as user errors.

### 6.2 Bills: filtering in the bloc

```dart
List<Bill> _bills = const [];
String _query = '';
BillCategory? _category;

BillsLoaded _loaded() => BillsLoaded(
  bills: List.unmodifiable(_bills),
  visibleBills: List.unmodifiable(_bills.where(_matches).toList()),
  query: _query,
  category: _category,
);

bool _matches(Bill bill) {
  if (_category != null && bill.category != _category) return false;
  final needle = _query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return bill.merchant.toLowerCase().contains(needle) ||
      bill.category.label.toLowerCase().contains(needle) ||
      bill.items.any((i) => i.name.toLowerCase().contains(needle));
}
```

Talking point: the full list is preserved for the month summary; the filtered
list is a separate immutable snapshot, so the UI never filters.

### 6.3 Review: validate, then save

```dart
Future<void> _onSubmitted(ReviewSubmitted event, Emitter<ReviewState> emit) async {
  final editing = _editing;
  if (editing == null || editing.isSaving) return;

  if (!editing.isValid) {
    emit(editing.copyWith(submitted: true));
    return;
  }

  emit(editing.copyWith(isSaving: true, submitted: true, clearFailure: true));
  try {
    emit(ReviewSaved(await _saveBill(editing.toBill())));
  } on Exception {
    emit(editing.copyWith(
      isSaving: false,
      failureMessage: 'Could not save that bill. Try again.',
    ));
  }
}
```

Talking points: validation never throws; `submitted` reveals inline errors;
`clearFailure` prevents stale error messages; `ReviewSaved` is a one-shot state
the page reacts to once.

### 6.4 Composition root

```dart
final deps = await AppDependencies.create(); // SharedPreferences → session → API
runApp(BillScannerApp(dependencies: deps));

// network test: the real repository, a MockClient instead of the socket
AppDependencies(
  authRepository: ApiAuthRepository(
    authApi: AuthApi(ApiService(baseUrl: ..., client: MockClient(...))),
    tokens: AuthTokenStore(),
  ),
)

// widget tests: instant fakes
AppDependencies(
  authRepository: InMemoryAuthRepository(latency: Duration.zero),
  billRepository: InMemoryBillRepository(latency: Duration.zero),
  scanRepository: SimulatedScanRepository(latency: const Duration(milliseconds: 120)),
)
```

Talking point: the graph is the only thing that changes between live, mocked and
in-memory runs; no global singleton to reset.

### 6.5 Route-scoped blocs with arguments

```dart
case ReviewPage.routeName:
  final bill = settings.arguments! as Bill;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => BlocProvider<ReviewBloc>(
      create: (_) => widget.dependencies.createReviewBloc(bill: bill),
      child: const ReviewPage(),
    ),
  );
```

Talking point: `BlocProvider(create:)` owns the bloc, so it is disposed with the
route; the page itself has no constructor dependencies.

### 6.6 The responsive frame

```dart
SingleChildScrollView(
  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  ),
)
```

Talking point: one widget gives every page scroll safety, a readable measure and
responsive gutters.

### 6.7 One HTTP client, four verbs

```dart
final Object? json = await _api.post(
  '/auth/login',
  body: {'email': email, 'password': password},
);
```

The call site is one line because `ApiService` owns the base URL, JSON
encoding/decoding, `Authorization: Bearer …` when `authenticated: true`, the
timeout, and turning 401/409/422/429/5xx into typed exceptions. `AuthApi` owns
the URLs and field names; `ApiAuthRepository` turns exceptions into
`AuthFailure`s. Blocs never import `package:http`.

Talking point: swapping `get/post/put/delete` for another transport means
rewriting one file and its tests, not every data source.

---

## 7. Feature scripts (90 seconds each)

### Scan flow

> "Add-a-bill has four entry points: camera, library, manual and a sample. The
> camera route creates a route-scoped ScanBloc and receives a ScanSource. Its
> idle state is the permission sheet; the primary action picks a photo with
> image_picker and emits Scanning, ApiScanRepository sends the bytes to
> /bills/extract, and ScanCaptured pushes review with the draft and problems.
> If the scan fails, the page shows a snack bar and resets. The frame is a
> CustomPainter — thin outline, mid guide, four accent brackets — and the sheet
> is height-capped and scrolls on small phones."

### Review state

> "ReviewBloc starts from a Bill and builds a ReviewEditing state that stores
> merchant/date/total as strings plus a list of item inputs. Validation is
> derived, not stored: parse the ISO date, parse the total, trim the merchant,
> check each item. The header shows how many of the three headline fields are
> ready. Submit reveals errors if invalid; otherwise it emits saving, calls the
> SaveBill use case, and on success emits ReviewSaved. The page then reloads the
> bills bloc, shows a snack bar, and pops to the shell, where the new bill is
> already visible."

### Sign-out bug story

> "Sign-out originally used pushNamedAndRemoveUntil with a predicate that
> removed every route. After sign-out, popUntil(isFirst) had no Welcome route to
> return to, so the user was stranded. I changed the auth transition to keep the
> Welcome route as the root via ModalRoute.withName, and added a test that signs
> in, signs out and registers again."

---

## 8. Debugging stories to have ready

1. **Sign-out stranded the user.** Root cause: the navigation predicate removed
   all routes. Fix: keep Welcome as root, remove only the auth stack. Test added.
2. **Welcome overflowed at 320×568.** Root cause: a fixed `Column` with
   `Spacer`s could not scroll. Fix: `LayoutBuilder` + `SingleChildScrollView` +
   min-height `ConstrainedBox` + `Center`, capped at 420 px.
3. **Rows overflowed under narrow constraints.** Root cause: unconstrained text
   in `Row`s (camera hint, manual link, privacy note). Fix: `Flexible` +
   wrapping/ellipsis, verified with a 320-px widget test.
4. **Date/total row stacked on a 390 phone.** Root cause: breakpoint compared
   the card's inner width to 320. Fix: lower to 300 so 390 keeps the designed
   two-column row while 320 still stacks.
5. **Widget tests inflated text widths.** In the test environment the real fonts
   are not available, so glyph widths differ and exposed latent overflow risks.
   Kept the `Flexible` fixes (better for accessibility too) rather than
   weakening assertions.
6. **Tests tapped off-screen chips after horizontal scrolling.** Fix:
   `ensureVisible` before tapping and unmounting the app between viewport
   iterations so the navigator stack resets.
7. **Sign-in passed the tests but failed in Chrome.** The mocked tests never
   send a CORS preflight. `OPTIONS /auth/login` answered 405 with no
   `Access-Control-Allow-Origin`, so the browser refused the POST even though
   the client was correct. I confirmed the data layer through a logging proxy
   and logged the missing backend `CORSMiddleware` as a deployment task. The
   lesson: `MockClient` proves your client, not the deployment.

---

## 9. Numbers to remember

| Thing | Value |
|---|---|
| Post-login screens | 5 |
| Auth screens | 3 |
| Features | 5 (`auth`, `bills`, `home`, `scan`, `review`) |
| Dart files in `lib` | 110 |
| Lines in `lib` | ≈ 10,280 |
| Shared widgets (core) | 13 |
| Widget tests | 19 |
| Unit tests | 72 |
| Total tests | 91 (all passing) |
| SQLite tables / indexes | 2 / 3 |
| Analyzer issues | 0 |
| Integrated API endpoints | 8 (5 auth, 3 bills) |
| Design tokens | 12 colours, 6 spacings, 5 radii, 3 strokes, 2 shadows |
| Responsive widths verified | 320×568, 390×844, 800×1000 |
| Test latencies | bills 0 ms in widget tests, scan 120 ms (production is real HTTP) |

---

## 10. What I would improve next (priority order)

1. **Idempotent sync** — send a `request_id` with `/bills/confirm` and add a
   unique index on the server, so a lost response cannot become a duplicate.
   Then move the flush to a background task (WorkManager / BGTaskScheduler).
2. **Secure sessions** — Keychain/Keystore token storage and automatic
   401 → refresh → retry (the repository already rotates the pair).
3. **Bloc unit tests** with `bloc_test` for the full validation/filtering
   matrices.
4. **Accessibility pass** — fix duplicate semantics labels, raise active-tab
   contrast, test text scaling at 2.0.
5. **Design polish** — measurement against the 412-px exports, tablet
   two-column layouts, exact chart presentation with a demo clock.
6. **Localisation** — `intl`, currency/locale, extracted strings.
7. **CI** — `flutter analyze`, `flutter test`, format check on every push.

---

## 11. Questions to ask the interviewer

- How do you decide between BLoC, Riverpod and plain `ChangeNotifier` on your
  team?
- Do you use code generation (freezed/json_serializable/build_runner) or
  handwritten models?
- How do you test screens that depend on a device camera or permissions?
- What does your CI run for Flutter, and how do you handle golden tests across
  platforms?
- How do you manage design tokens — Figma variables, a theme package, or code?
- What is the team's approach to accessibility and large text scaling?

---

## 12. Ten-minute revision checklist

- [ ] Draw the three layers and the event→bloc→use case→repository path.
- [ ] Say the 30-second pitch out loud.
- [ ] Explain why BillsBloc lives above both tabs.
- [ ] Explain the review validation getters and one-shot `ReviewSaved`.
- [ ] Walk the offline save: queue → pending badge → flush → promote.
- [ ] Explain the two-table schema, why `owner_id` is on every query, and why
      only connection failures are queued.
- [ ] Say what you would fix first: a server-side idempotency key.
- [ ] Explain how a save reaches the dashboard (`BillsReloaded` + shared repo).
- [ ] Name three responsive techniques and the widths you verified.
- [ ] Name the five promoted shared widgets and why.
- [ ] Tell the sign-out navigation bug story.
- [ ] State what is simulated and what you would build next.
- [ ] Ask two questions about the team's Flutter practice.
