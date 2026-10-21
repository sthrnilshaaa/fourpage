/// Native Android services (MainActivity's `fourpages/system` channel):
/// notifications and the daily reminder, the notification-sound picker, the
/// home-screen widget, and opening links. Calls are no-ops elsewhere, so
/// Linux/macOS builds keep working unchanged.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SystemBridge {
  SystemBridge._();

  static const _channel = MethodChannel('fourpages/system');

  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('SystemBridge.$method failed: $e');
      return null;
    }
  }

  /// Android 13+ needs runtime permission to post notifications.
  static Future<bool> ensureNotificationPermission() async =>
      (await _call<bool>('requestNotificationPermission')) ?? !isSupported;

  /// Schedules (or replaces) the daily "continue reading" reminder.
  static Future<void> scheduleDailyReminder({required int minutesAfterMidnight, required String sound}) =>
      _call('scheduleDailyReminder', {'minutes': minutesAfterMidnight, 'sound': sound});

  static Future<void> cancelDailyReminder() => _call('cancelDailyReminder');

  /// Text the reminder and widget show; refreshed whenever reading stops.
  static Future<void> updateContinueReading({
    required String title,
    required String subtitle,
    required int percent,
    required String reminderTitle,
    required String reminderBody,
  }) =>
      _call('updateContinueReading', {
        'title': title,
        'subtitle': subtitle,
        'percent': percent,
        'reminderTitle': reminderTitle,
        'reminderBody': reminderBody,
      });

  /// Posts a notification immediately (break reminder / sound preview).
  static Future<void> notifyNow({required String title, required String body, required String sound}) =>
      _call('notifyNow', {'title': title, 'body': body, 'sound': sound});

  /// Posts the "update available" notification; tapping it opens the app with
  /// the "update" launch action. False when notifications are off.
  static Future<bool> notifyUpdate({required String title, required String body, required String channelName}) async =>
      (await _call<bool>('notifyUpdate', {'title': title, 'body': body, 'channelName': channelName})) ?? false;

  static Future<void> cancelUpdateNotification() => _call('cancelUpdateNotification');

  /// What opened the app, once: "update" after tapping the update
  /// notification, else null.
  static Future<String?> takeLaunchAction() => _call<String>('takeLaunchAction');

  /// System sound picker. Returns (uri, display name), or null if cancelled.
  static Future<(String, String)?> pickNotificationSound(String current) async {
    final result = await _call<Map<dynamic, dynamic>>('pickNotificationSound', {'current': current});
    if (result == null) return null;
    return (result['uri'] as String, result['name'] as String);
  }

  static Future<bool> openUrl(String url) async => (await _call<bool>('openUrl', {'url': url})) ?? false;
}
