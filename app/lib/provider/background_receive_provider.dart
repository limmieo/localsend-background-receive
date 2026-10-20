// Modified by Tony Destin (limmieo), 2026: Android background receiving and incoming notification controls; AI-assisted implementation.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/native/receive_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:refena_flutter/refena_flutter.dart';

final backgroundReceiveProvider = NotifierProvider<BackgroundReceiveController, bool>((ref) => BackgroundReceiveController());

/// A separate preference from Quick Save: being reachable never grants file acceptance.
class BackgroundReceiveController extends Notifier<bool> {
  Future<void> _pending = Future.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.catchError((Object _) {});
    return next;
  }

  @override
  bool init() => false;

  Future<void> restore() async {
    if (ref.read(persistenceProvider).isBackgroundReceive()) {
      await setEnabled(true);
    }
  }

  /// Server restarts preserve the user's preference, but no stopped server is advertised.
  Future<void> suspend() => _serialize(() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await ReceiveNotifications.setEnabled(false);
      state = false;
    }
  });

  Future<void> setEnabled(bool enabled) => _serialize(() async {
    if (defaultTargetPlatform != TargetPlatform.android || (enabled && state)) {
      return;
    }
    if (enabled) {
      // Permission prompts and foreground-service starts require a visible activity.
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        throw StateError(t.backgroundReceive.openApp);
      }
      if (!await Permission.notification.request().isGranted) {
        throw StateError(t.backgroundReceive.permissionRequired);
      }
    }
    await ReceiveNotifications.setEnabled(enabled);
    await ref.read(persistenceProvider).setBackgroundReceive(enabled);
    state = enabled;
  });
}
