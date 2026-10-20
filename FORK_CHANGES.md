# Fork modification record

Modified by Tony Destin (@limmieo), 2026, with OpenAI Codex assistance.
Original project: https://github.com/localsend/localsend
Base commit: `d01fdb14c978fa8b2b13e29a50cc0feaefe5c1b9`.
All fork modifications use the existing Apache License 2.0.

## Architecture

An opt-in connected-device Android foreground service holds wake and multicast locks while the existing Flutter receiver is running. A quiet availability channel is separate from the alerting incoming-request channel. Tapping a request opens the existing activity and review screen; accept/decline and Quick Save keep their existing roles.

The foreground service is not sticky, stops with its task, and is stopped when the activity destroys its receiver engine. No boot receiver or separate headless engine was added. Saved opt-in is restored only through a running app/server. Turning off availability is independent of the existing transfer-progress service.

The incoming sound button opens Android's channel settings. It preserves the user's channel preferences instead of recreating the channel to override them.

## Changed source files

- `app/android/app/src/main/AndroidManifest.xml`
- `app/android/app/src/main/kotlin/org/localsend/localsend_app/BackgroundReceiveService.kt`
- `app/android/app/src/main/kotlin/org/localsend/localsend_app/MainActivity.kt`
- `app/android/app/src/main/res/drawable/ic_receive_notification.xml`
- `app/assets/i18n/en.json`
- `app/lib/gen/strings.g.dart`
- `app/lib/gen/strings_en.g.dart`
- `app/lib/main.dart`
- `app/lib/pages/tabs/settings_tab.dart`
- `app/lib/provider/background_receive_provider.dart`
- `app/lib/provider/network/server/controller/receive_controller.dart`
- `app/lib/provider/network/server/server_provider.dart`
- `app/lib/provider/persistence_provider.dart`
- `app/lib/util/native/receive_notifications.dart`
- `app/test/unit/provider/background_receive_provider_test.dart`

`README.md` is replaced with fork-specific documentation; the original is retained as `README.upstream.md`. `TESTING.md` and this file document the experiment. Generated English strings and their index reflect the new settings; other locales use the existing English fallback.
