# Verification of the Android receiving experiment

This is an experimental source release. Results below describe local testing on 2026-10-20, not a guarantee across Android devices.

## Automated and build checks

- Flutter 3.41.9 / Dart 3.11.5, matching upstream's pinned SDK.
- `flutter test --no-pub --reporter expanded`: 95 app tests passed, including seven new tests covering opt-in and persistence, suspend/restore, notification permission denial, native failure/retry, background-start restrictions, notification dispatch/clearing, and non-Android behavior.
- `flutter analyze --no-pub`: no issues found, including after adding sound settings.
- Android Kotlin compilation and ARM64 debug APK build: passed with Java 17.
- APK verification: Flutter engine, Rust native library, and debug Dart kernel were present. Android signature verification passed and the preview installed alongside the official app.

The automated tests mock Android method channels. They cannot establish native lifecycle, battery behavior, or notification delivery by themselves. No hosted CI result is claimed.

## Device checks

One Samsung Galaxy S24 FE (SM-S721U), Android 16, on Wi-Fi and connected by USB:

- Enabled background receiving from Settings and granted notification permission. Low-importance availability notification appeared.
- Background requests registered with HTTP 200 and produced high-importance incoming alerts identifying the test sender and item count.
- Tapped an incoming notification, observed the existing Accept/Decline screen, explicitly accepted, and received a fixture with HTTP 200. SHA-256 of the saved file matched the sender.
- Explicit decline returned HTTP 403. The request alert cleared while availability remained.
- Sender cancellation cleared the alert while availability remained. A canceled request was correctly identified on returning to the app.
- Choose sound opened the incoming-request channel settings. Sound opened Samsung's picker, including its Custom section. A custom audio import, selection persistence across restart, and audible playback of a newly selected tone have not yet been tested.
- A request started during the screen-off transition remained pending as keyguard entered its asleep state. This does not establish extended idle delivery or initiation after a settled lock.
- Force-stopping the preview removed both availability/request alerts, left no app service running, and closed the receiver port.

## Remaining checks

- Requests initiated after a settled lock and after extended screen-off idle/Doze.
- Battery consumption, Android/vendor power restrictions, Wi-Fi disconnect/reconnect, and more device/Android versions.
- Remove the app from Recents and verify the receiver and notifications stop, independently of force-stop.
- Deny notification permission on a real device and verify the setting stays disabled with a useful explanation.
- Switch off availability during an accepted transfer and confirm the separate transfer service protects completion.
- Select a custom tone, verify audible playback, restart, and verify that the choice persists.

## Reproduce the basic manual check

1. Keep the official app closed and open the debug preview. Keep Quick Save off.
2. Enable Receive in background and allow notifications.
3. Press Home, send a small file from another LocalSend device, tap the alert, and accept.
4. Compare the received file's SHA-256 with the original. Repeat with decline and sender cancellation.
5. Use Choose sound to open incoming-request settings and select a tone through Sound.
6. Close/force-stop the app; verify availability disappears and it is no longer reachable. Reopen it to restore the saved opt-in.
