// Modified by Tony Destin (limmieo), 2026: Android background receiving and incoming notification controls; AI-assisted implementation.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:localsend_app/gen/strings.g.dart';
import 'package:logging/logging.dart';

const _channel = MethodChannel('org.localsend.localsend_app/localsend');
final _logger = Logger('ReceiveNotifications');

/// Availability and incoming requests use separate Android channels so requests can alert
/// without repeatedly sounding the quiet availability notification.
class ReceiveNotifications {
  ReceiveNotifications._();

  static Future<void> openSoundSettings() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _channel.invokeMethod<void>('openReceiveSoundSettings');
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    await _channel
        .invokeMethod<void>('setBackgroundReceive', {
          'enabled': enabled,
          'title': t.appName,
          'text': t.backgroundReceive.ready,
        })
        .timeout(const Duration(seconds: 10));
  }

  static Future<void> showRequest({required String sender, required int count}) async {
    if (defaultTargetPlatform != TargetPlatform.android || WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('showReceiveRequest', {
        'title': t.backgroundReceive.incoming(sender: sender),
        'text': t.backgroundReceive.review(count: count),
      });
    } catch (e, st) {
      _logger.warning('Could not show incoming request', e, st);
    }
  }

  static Future<void> clearRequest() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('clearReceiveRequest');
    } catch (e, st) {
      _logger.warning('Could not clear incoming request', e, st);
    }
  }
}
