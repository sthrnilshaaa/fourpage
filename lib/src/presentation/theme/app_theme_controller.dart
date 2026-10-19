/// App-wide light/dark mode, persisted in app_settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database/app_settings_repository.dart';

enum AppThemePreference { system, light, dark }

class AppThemeController extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeController._();
  static final AppThemeController instance = AppThemeController._();

  static const _settingKey = 'app_theme';

  AppThemePreference _preference = AppThemePreference.dark;
  AppThemePreference get preference => _preference;

  bool get isLight => switch (_preference) {
        AppThemePreference.light => true,
        AppThemePreference.dark => false,
        AppThemePreference.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.light,
      };

  /// Loads the saved choice. Safe to call before runApp (after
  /// WidgetsFlutterBinding.ensureInitialized). Defaults to dark - the
  /// original look - when nothing is saved or storage fails.
  Future<void> load() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final saved = await AppSettingsRepository().getString(_settingKey);
      _preference = AppThemePreference.values.firstWhere(
        (p) => p.name == saved,
        orElse: () => AppThemePreference.dark,
      );
    } catch (_) {}
    _applySystemChrome();
  }

  Future<void> setPreference(AppThemePreference value) async {
    if (value == _preference) return;
    _preference = value;
    _applySystemChrome();
    notifyListeners();
    try {
      await AppSettingsRepository().setString(_settingKey, value.name);
    } catch (_) {}
  }

  @override
  void didChangePlatformBrightness() {
    if (_preference == AppThemePreference.system) {
      _applySystemChrome();
      notifyListeners();
    }
  }

  void _applySystemChrome() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      ),
    );
  }
}
