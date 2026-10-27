# BillScan AI

A Flutter expense app built from a paper-collage UX Pilot design: sign in,
photograph a bill, check what the scanner read, and confirm it. Auth, the bill
list, photo extraction and confirmation all talk to the Bill Reader FastAPI
backend; the session survives an app restart, and bills are cached on the phone
so the dashboard opens offline and saves wait in an upload queue.

| | |
|---|---|
| **Architecture** | Feature-first clean architecture (`domain` / `data` / `presentation`) with one BLoC per feature |
| **State** | `flutter_bloc` 9, sealed events/states, `equatable` |
| **API** | One reusable `ApiService` (GET/POST/PUT/DELETE + multipart, JSON, bearer auth, typed errors) and one central `ApiEndpoints` list |
| **Session** | Access + refresh tokens and the profile persisted in SharedPreferences; restored on launch |
| **Offline** | sqflite cache + write-behind upload queue; cached reads and queued saves survive restart |
| **Design system** | Token-driven colours, spacing, radii, shadows and typography; 13 shared widgets |
| **Responsive** | Verified at 320×568, 390×844 and 800×1000 |
| **Camera** | In-app preview: permission → preview → shutter → API, with a loader; a simulated driver keeps tests off the plugin |
| **Quality** | `flutter analyze` clean, 91 tests passing |

## Screens

| Dashboard | Review bill | Bill camera |
|---|---|---|
| ![Dashboard](screenshots/01-home.png) | ![Review](screenshots/06-review-390.png) | ![Camera](screenshots/04-camera.png) |

## Run

Start the Bill Reader API first (it listens on `http://127.0.0.1:8000`).

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

- The `API_BASE_URL` default is already `http://127.0.0.1:8000`, so the define
  can be omitted when the API is local.
- Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
- The web build needs the API to send CORS headers for the app origin. If the
  backend does not, run the Flutter build on Android/desktop or add
  `CORSMiddleware` to the FastAPI app.
- Guest mode works without the backend. Email sign-in, bills and the scanner
  need it.

### Run on a real Android phone

USB is the quickest path and needs no `--dart-define`, because `adb reverse`
makes the phone's `127.0.0.1:8000` point at the PC:

```bash
adb reverse tcp:8000 tcp:8000
flutter run -d <device-id>
```

Over Wi-Fi, find the PC's IPv4 address, allow TCP 8000 through the firewall,
check `http://<pc-ip>:8000/docs` in the phone browser, then run with
`--dart-define=API_BASE_URL=http://<pc-ip>:8000`. Debug/profile builds permit
local HTTP; release builds require HTTPS.

See **[Running on a real Android phone](docs/ANDROID_DEVICE.md)** for the full
checklist, first-run tests and troubleshooting.

```bash
flutter test      # 91 tests, including real in-memory SQLite
flutter analyze
```

## Documentation

- **[Complete project guide](docs/PROJECT_GUIDE.md)** — product scope, screen
  inventory, architecture, every feature and layer, the network stack, design
  system, flows, responsiveness, testing, limitations and a file-by-file
  reference.
- **[Interview notes](docs/INTERVIEW_NOTES.md)** — pitches, trade-offs, likely
  questions with answers, code snippets, debugging stories and a revision
  checklist.
- **[SQL guide](docs/SQL_GUIDE.md)** — the offline cache explained from first
  principles: schema, every query, indexes, transactions, migrations, practice
  tasks with solutions, and the interview Q&A it prepares.
- **[Android device guide](docs/ANDROID_DEVICE.md)** — USB port forwarding and
  Wi-Fi setup, build types, first-run checks and troubleshooting.

## Structure at a glance

```
lib/
├── main.dart / app.dart        # restores dependencies, app-level blocs, routes
├── core/
│   ├── network/               # ApiConfig, ApiEndpoints, ApiService, exceptions
│   ├── di/ theme/ navigation/ utils/ widgets/
└── features/
    ├── auth/                  # welcome, sign in, register, persisted API session
    ├── bills/                 # entities, BillApi, SQLite cache, offline/queued
    │                          # repositories, list + sync banner
    ├── home/                  # spending dashboard
    ├── scan/                  # camera preview + shutter, extraction, add bill
    └── review/                # editable review form + confirm
```

## Notes

- **URLs** live only in `lib/core/network/api_endpoints.dart`; data sources never
  hard-code a path.
- **Auth** is real HTTP: register → login → `GET /auth/me`, with refresh and
  logout wired into the data layer. The token pair and profile are stored in
  SharedPreferences so a restart reopens the dashboard.
- **Bills** are real HTTP: `GET /bills` feeds the dashboard and list,
  `POST /bills/confirm` saves a reviewed draft, and `POST /bills/extract` is the
  scanner behind the camera/gallery flow.
- **The camera is real.** Opening the scan screen asks for access, renders the
  live preview in the frame, and the shutter hands the bytes to
  `POST /bills/extract` behind a loader. A `CameraDriver` abstraction keeps the
  plugin out of the bloc and lets tests inject a simulated camera.
- **Offline is real.** `GET /bills` is cached in SQLite on Android, iOS and
  macOS (web and desktop previews fall back to an in-memory store); if the
  server is unreachable the dashboard shows the cache with an offline banner. A
  bill confirmed while offline is stored with a `local-…` id and a `Pending
  sync` badge, then pushed to `/bills/confirm` on the next successful load. Only
  connection failures queue — a 422 stays on the review form.
- **Money is the printed line amount.** `items[].amount` is the whole line in
  rupees, never a unit price multiplied by quantity.
- **Categories** are the backend's ten fixed slugs; unknown values fall back to
  "Other" instead of crashing.
- The API has no display-name field, so the name typed during registration is
  kept for that session and later sign-ins derive a name from the email.
- Provider buttons have no backend endpoint yet and fail with a clear message.
- Repository interfaces and a single `AppDependencies` container keep every
  implementation replaceable; widget tests inject zero-latency fakes and mock
  HTTP.
- Fonts are fetched at runtime through `google_fonts`; widget tests disable that
  fetch for deterministic, offline runs.
