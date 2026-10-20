// Modified by Tony Destin (limmieo), 2026: Android background receiving and incoming notification controls; AI-assisted implementation.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/background_receive_provider.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:localsend_app/util/native/receive_notifications.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _Persistence extends Fake implements PersistenceService {
  bool enabled = false;

  @override
  bool isBackgroundReceive() => enabled;

  @override
  Future<void> setBackgroundReceive(bool enabled) async => this.enabled = enabled;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.localsend.localsend_app/localsend');
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  late _Persistence persistence;
  late RefenaContainer container;
  late List<MethodCall> calls;
  bool grantPermission = true;
  bool failStart = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    persistence = _Persistence();
    container = RefenaContainer(overrides: [persistenceProvider.overrideWithValue(persistence)]);
    calls = [];
    grantPermission = true;
    failStart = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(permissions, (call) async {
      if (call.method == 'requestPermissions') {
        return {for (final permission in call.arguments as List) permission: grantPermission ? 1 : 0};
      }
      return grantPermission ? 1 : 0;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'setBackgroundReceive' && failStart) throw PlatformException(code: 'start_failed');
      return null;
    });
  });

  tearDown(() {
    container.disposeContainer();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(permissions, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('opt-in persists only after native startup; suspension preserves the preference', () async {
    final controller = container.notifier(backgroundReceiveProvider);
    expect(container.read(backgroundReceiveProvider), false);
    await controller.setEnabled(true);
    expect(container.read(backgroundReceiveProvider), true);
    expect(persistence.enabled, true);
    await controller.suspend();
    expect(container.read(backgroundReceiveProvider), false);
    expect(persistence.enabled, true);
    await controller.restore();
    expect(container.read(backgroundReceiveProvider), true);
    await controller.setEnabled(false);
    expect(container.read(backgroundReceiveProvider), false);
    expect(persistence.enabled, false);
    expect(calls.map((c) => c.arguments['enabled']), [true, false, true, false]);
  });

  test('denied notifications do not enable or persist background receiving', () async {
    grantPermission = false;
    await expectLater(container.notifier(backgroundReceiveProvider).setEnabled(true), throwsStateError);
    expect(container.read(backgroundReceiveProvider), false);
    expect(persistence.enabled, false);
    expect(calls, isEmpty);
  });

  test('native failure leaves preference disabled and a later retry can succeed', () async {
    failStart = true;
    await expectLater(container.notifier(backgroundReceiveProvider).setEnabled(true), throwsA(isA<PlatformException>()));
    expect(container.read(backgroundReceiveProvider), false);
    expect(persistence.enabled, false);
    failStart = false;
    await container.notifier(backgroundReceiveProvider).setEnabled(true);
    expect(container.read(backgroundReceiveProvider), true);
  });

  test('background start is rejected before requesting native startup', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await expectLater(container.notifier(backgroundReceiveProvider).setEnabled(true), throwsStateError);
    expect(calls, isEmpty);
  });

  test('request alerts are only posted while backgrounded and can be cleared', () async {
    await ReceiveNotifications.showRequest(sender: 'Laptop', count: 2);
    expect(calls, isEmpty);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await ReceiveNotifications.showRequest(sender: 'Laptop', count: 2);
    expect(calls.single.method, 'showReceiveRequest');
    expect(calls.single.arguments['title'], contains('Laptop'));
    expect(calls.single.arguments['text'], contains('2'));
    await ReceiveNotifications.clearRequest();
    expect(calls.last.method, 'clearReceiveRequest');
  });

  test('disabling after a suspended receiver also clears the saved preference', () async {
    persistence.enabled = true;
    await container.notifier(backgroundReceiveProvider).setEnabled(false);
    expect(persistence.enabled, false);
  });

  test('non-Android platforms never call the native receiver', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await container.notifier(backgroundReceiveProvider).setEnabled(true);
    await ReceiveNotifications.showRequest(sender: 'Laptop', count: 2);
    await ReceiveNotifications.clearRequest();
    expect(calls, isEmpty);
  });
}
