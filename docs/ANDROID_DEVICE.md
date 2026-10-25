# Running on a real Android phone

This is the checklist for putting the app on a physical Android device and
talking to the FastAPI backend on your development machine. The emulator is
different: it reaches the host through `10.0.2.2`, while a real phone needs
either USB port forwarding or your machine's LAN address.

## 1. Prepare the machine and the phone

```bash
flutter doctor --android-licenses   # accept the SDK licences once
flutter doctor                       # Android toolchain should be a tick
```

On the phone:

1. Settings → About phone → tap **Build number** seven times.
2. Settings → Developer options → enable **USB debugging**.
3. Connect the USB cable, choose **File transfer / MTP** if prompted, and tap
   **Allow** on the “Allow USB debugging?” dialog.
4. Check that the machine sees it:

```bash
adb devices -l
```

The state must be `device`. `unauthorized` means the phone dialog was not
accepted; `offline` usually means replug the cable or run `adb kill-server`
then `adb start-server`.

```bash
flutter devices
```

## 2. Start the backend

```bash
cd "/d/New folder (2)/fastapi2"
uv run main.py
```

`main.py` already binds `0.0.0.0:8000`, so it accepts both USB-forwarded and
LAN connections. Confirm on the PC first:

```bash
curl http://127.0.0.1:8000/docs
```

Bill extraction also needs `GEMINI_API_KEY` in `fastapi2/.env`. Auth and
`GET /bills` work without it; the scan endpoint will not.

## 3. Connect the phone to the API

### Option A — USB with `adb reverse` (simplest)

Keep the phone connected and forward the port:

```bash
adb reverse tcp:8000 tcp:8000
flutter run -d <device-id>
```

The app's default `http://127.0.0.1:8000` now points at the PC, so **no
`--dart-define` is needed**. The reverse is removed when the phone disconnects;
run `adb reverse` again after reconnecting. This only works while the USB cable
is attached.

### Option B — Wi-Fi / LAN (phone untethered)

1. Find the PC's IPv4 address:

   ```bash
   ipconfig
   ```

   Use the Wi-Fi adapter's address, for example `192.168.1.42`.

2. Allow inbound TCP 8000 through Windows Defender Firewall. Either accept the
   prompt the first time Python listens, or add a rule in an **administrator**
   PowerShell:

   ```powershell
   New-NetFirewallRule -DisplayName "Bill API 8000" -Direction Inbound `
     -Protocol TCP -LocalPort 8000 -Action Allow
   ```

3. Before touching Flutter, open this on the **phone's browser**:

   ```text
   http://192.168.1.42:8000/docs
   ```

   If that page does not load, the app will not work either — fix the network
   or firewall first.

4. Run with the LAN address:

   ```bash
   flutter run -d <device-id> \
     --dart-define=API_BASE_URL=http://192.168.1.42:8000
   ```

Both devices must be on the same network. Guest Wi-Fi and some routers enable
“AP isolation”, which blocks phone-to-PC traffic even when both have internet.
Use the USB path in that case.

## 4. Debug, profile and release builds

The Android project allows plain HTTP in **debug** and **profile** builds only
(`android/app/src/debug/AndroidManifest.xml` and
`android/app/src/profile/AndroidManifest.xml`). A release build deliberately
does not, because a shipped app should use HTTPS.

| Build | Local HTTP API | How to run |
|---|---|---|
| Debug | ✅ | `flutter run -d <device-id>` |
| Profile | ✅ | `flutter run --profile -d <device-id>` |
| Release | ❌ | Needs an HTTPS API, or a deliberate cleartext exception |

If a release build logs `CLEARTEXT communication to … not permitted`, it is
working as configured. Build a release APK only against an HTTPS endpoint:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release build currently uses the debug signing key, which is fine for
sideloading but not for Google Play. Replace the signing config before
publishing.

## 5. First-run checklist on the phone

1. **Welcome → Create account.** Use a password of at least 6 characters.
2. The dashboard should appear and `GET /bills` should return the account's
   bills (empty state on a fresh account).
3. **Bills** tab: search by shop/category/item and filter by category.
4. **Scan a bill** → the scan screen opens an in-app camera preview. The first
   time, Android asks for camera access: allow it and the live preview fills
   the frame with a yellow capture button; refuse it and the frame says "Camera
   access is off" with an "Allow camera" retry and a photo-library shortcut.
   The shutter photo is sent to `/bills/extract` behind a loader, then the
   review screen opens. The gallery path uses Android's photo picker.
5. Edit a field, fix a flagged problem, then **Save**. Confirm returns 201 and
   the bill appears on the dashboard and list.
6. Force a 422 by making the total disagree with the items; the review screen
   should show the server's field problems rather than a generic error.
7. Kill the app from recents and relaunch: the session should restore straight
   to the dashboard (SharedPreferences).
8. **Sign out** returns to the welcome screen and clears the session.
9. Turn on airplane mode and retry: you should get a readable connection error,
   not a crash.
10. Rotate the phone and try a narrow window: pages scroll and do not overflow.

## 6. Known limits on a physical device

- Extraction spends Gemini quota; `GEMINI_API_KEY` must be set and funded.
- If Android kills the app while the camera is open, the picked image can be
  lost. `image_picker`'s `retrieveLostData()` recovery is not implemented.
- A camera permission refused with "don't ask again" can only be turned back on
  from the phone's Settings; the app says so but cannot open Settings for you.
- An expired access token is not refreshed automatically yet; sign in again.
- Tokens live in SharedPreferences, not an encrypted keystore.
- Provider buttons (Google/Apple) have no backend endpoint yet.

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `SocketException: Connection refused` | Backend not running, or `adb reverse` missing | Start `uv run main.py`; run `adb reverse tcp:8000 tcp:8000` |
| Works in the phone browser but not the app | App was built with the wrong `API_BASE_URL` | Rebuild/run with the correct `--dart-define` |
| Phone browser cannot open `:8000` | Firewall or Wi-Fi isolation | Allow TCP 8000; use USB reverse |
| `CLEARTEXT communication … not permitted` | Release build against HTTP | Use HTTPS, or run debug/profile |
| `401 Unauthorized` | Expired access token or cleared backend DB | Sign in again |
| `503` / quota message on scan | Gemini key missing, busy, or out of quota | Check `fastapi2/.env` and the backend log |
| `adb devices` shows `unauthorized` | RSA prompt not accepted | Replug, accept the prompt, `adb kill-server` |
| Flutter does not list the phone | USB mode or driver | Choose File transfer, install OEM USB driver, `adb devices` |
