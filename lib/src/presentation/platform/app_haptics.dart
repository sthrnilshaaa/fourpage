/// One place for vibration feedback, honouring Settings → Haptics.
library;

import 'package:flutter/services.dart';

import '../state/app_preferences.dart';

class AppHaptics {
  AppHaptics._();

  static AppPreferences get _prefs => AppPreferences.instance;

  /// A deliberate action completed (e.g. chapter lock-swipe filled).
  static Future<void> confirm() async {
    if (!_prefs.hapticsEnabled) return;
    switch (_prefs.hapticStrength) {
      case HapticStrength.light:
        await HapticFeedback.lightImpact();
      case HapticStrength.medium:
        await HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        await HapticFeedback.heavyImpact();
    }
  }

  /// A small state change (toggle, backing off a gesture).
  static Future<void> tick() async {
    if (_prefs.hapticsEnabled) await HapticFeedback.selectionClick();
  }
}
