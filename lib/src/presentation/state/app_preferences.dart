/// App-wide user preferences (not per book), persisted in app_settings.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/database/app_settings_repository.dart';
import '../../core/constants/ui_constants.dart';
import '../../domain/entities/reader_preferences.dart';
import '../theme/app_theme_controller.dart';

enum LibrarySort { recentlyAdded, title, author, progress }

enum HapticStrength { light, medium, heavy }

class AppPreferences extends ChangeNotifier {
  AppPreferences._();
  static final AppPreferences instance = AppPreferences._();

  static const keyLibrarySort = 'library_sort';
  static const keySwipeHaptics = 'chapter_swipe_haptics';
  static const keyReaderDefaults = 'reader_defaults';
  static const keyHapticsEnabled = 'haptics_enabled';
  static const keyHapticStrength = 'haptic_strength';
  static const keyBreakMinutes = 'break_reminder_minutes';
  static const keyDailyReminder = 'daily_reminder_minutes'; // minutes after midnight, -1 = off
  static const keyNotificationSound = 'notification_sound'; // 'default' | 'silent' | content:// URI
  static const keyNotificationSoundName = 'notification_sound_name';
  static const keyLanguage = 'language';
  static const keyReaderPadding = 'reader_padding';
  static const keyReaderThemeChosen = 'reader_theme_chosen';
  static const keyDynamicBookBackground = 'dynamic_book_background';

  /// Range of the Settings "Page margins" slider, in logical pixels per side.
  static const double minReaderPadding = 0;
  static const double maxReaderPadding = 48;

  final AppSettingsRepository _repo = AppSettingsRepository();

  LibrarySort _librarySort = LibrarySort.recentlyAdded;
  bool _swipeHaptics = true;
  ReaderPreferences _readerDefaults = const ReaderPreferences();
  // Whether the user picked a book theme in Settings. Until they do, books
  // follow the app theme (see readerDefaults).
  bool _readerThemeChosen = false;
  bool _dynamicBookBackground = false;
  double _readerPadding = UIConstants.readerTextPadding;
  bool _loaded = false;
  bool _hapticsEnabled = true;
  HapticStrength _hapticStrength = HapticStrength.medium;
  int _breakMinutes = 30;
  int _dailyReminder = -1;
  String _notificationSound = 'default';
  String? _notificationSoundName;
  String _language = 'en';

  /// Master switch for vibration feedback across the app.
  bool get hapticsEnabled => _hapticsEnabled;
  HapticStrength get hapticStrength => _hapticStrength;

  /// Remind to take a break after this many minutes of continuous reading
  /// (0 = off).
  int get breakMinutes => _breakMinutes;

  /// Daily "continue reading" notification time, minutes after midnight
  /// (-1 = off).
  int get dailyReminder => _dailyReminder;
  String get notificationSound => _notificationSound;
  String? get notificationSoundName => _notificationSoundName;

  /// UI language code (only 'en' ships today).
  String get language => _language;

  LibrarySort get librarySort => _librarySort;
  bool get swipeHaptics => _swipeHaptics;

  /// Appearance a book starts with until it has its own saved settings.
  /// The page theme matches the app theme (light app: sepia, dark app:
  /// night) unless a book theme was picked in Settings.
  ReaderPreferences get readerDefaults => _readerThemeChosen
      ? _readerDefaults
      : _readerDefaults.copyWith(theme: themeForApp());

  /// Book theme that goes with the current app theme.
  static ReaderTheme themeForApp() =>
      AppThemeController.instance.isLight ? ReaderTheme.sepia : ReaderTheme.dark;

  /// "Dynamic book background": every book's page follows the app theme (sepia when the app is
  /// light, dark when it is dark), whatever theme the book was set to.
  bool get dynamicBookBackground => _dynamicBookBackground;

  /// The theme a book is actually shown in.
  ReaderTheme effectiveReaderTheme(ReaderTheme bookTheme) => _dynamicBookBackground ? themeForApp() : bookTheme;

  Future<void> setDynamicBookBackground(bool value) async {
    _dynamicBookBackground = value;
    notifyListeners();
    await _save(() => _repo.setBool(keyDynamicBookBackground, value));
  }

  /// Left and right padding around the book text, for every book.
  double get readerPadding => _readerPadding;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final sort = await _repo.getString(keyLibrarySort);
      _librarySort = LibrarySort.values.firstWhere((s) => s.name == sort, orElse: () => LibrarySort.recentlyAdded);
      _swipeHaptics = await _repo.getBool(keySwipeHaptics, defaultValue: true);
      _hapticsEnabled = await _repo.getBool(keyHapticsEnabled, defaultValue: true);
      final strength = await _repo.getString(keyHapticStrength);
      _hapticStrength = HapticStrength.values.firstWhere((s) => s.name == strength, orElse: () => HapticStrength.medium);
      _breakMinutes = int.tryParse(await _repo.getString(keyBreakMinutes) ?? '') ?? 30;
      _dailyReminder = int.tryParse(await _repo.getString(keyDailyReminder) ?? '') ?? -1;
      _notificationSound = await _repo.getString(keyNotificationSound) ?? 'default';
      _notificationSoundName = await _repo.getString(keyNotificationSoundName);
      _language = await _repo.getString(keyLanguage) ?? 'en';
      _readerThemeChosen = await _repo.getBool(keyReaderThemeChosen, defaultValue: false);
      _dynamicBookBackground = await _repo.getBool(keyDynamicBookBackground, defaultValue: false);
      _readerPadding = (double.tryParse(await _repo.getString(keyReaderPadding) ?? '') ?? _readerPadding)
          .clamp(minReaderPadding, maxReaderPadding);
      final json = await _repo.getString(keyReaderDefaults);
      if (json != null && json.isNotEmpty) {
        _readerDefaults = ReaderPreferences.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('AppPreferences: load failed: $e');
    }
    notifyListeners();
  }

  Future<void> setLibrarySort(LibrarySort value) async {
    _librarySort = value;
    notifyListeners();
    await _save(() => _repo.setString(keyLibrarySort, value.name));
  }

  Future<void> setSwipeHaptics(bool value) async {
    _swipeHaptics = value;
    notifyListeners();
    await _save(() => _repo.setBool(keySwipeHaptics, value));
  }

  Future<void> setReaderDefaults(ReaderPreferences value) async {
    final themeChosen = _readerThemeChosen || value.theme != readerDefaults.theme;
    _readerDefaults = value;
    _readerThemeChosen = themeChosen;
    notifyListeners();
    await _save(() async {
      await _repo.setString(keyReaderDefaults, jsonEncode(value.toJson()));
      await _repo.setBool(keyReaderThemeChosen, themeChosen);
    });
  }

  Future<void> setReaderPadding(double value) async {
    _readerPadding = value.clamp(minReaderPadding, maxReaderPadding).roundToDouble();
    notifyListeners();
    await _save(() => _repo.setString(keyReaderPadding, '$_readerPadding'));
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    notifyListeners();
    await _save(() => _repo.setBool(keyHapticsEnabled, value));
  }

  Future<void> setHapticStrength(HapticStrength value) async {
    _hapticStrength = value;
    notifyListeners();
    await _save(() => _repo.setString(keyHapticStrength, value.name));
  }

  Future<void> setBreakMinutes(int value) async {
    _breakMinutes = value;
    notifyListeners();
    await _save(() => _repo.setString(keyBreakMinutes, '$value'));
  }

  Future<void> setDailyReminder(int minutesAfterMidnight) async {
    _dailyReminder = minutesAfterMidnight;
    notifyListeners();
    await _save(() => _repo.setString(keyDailyReminder, '$minutesAfterMidnight'));
  }

  Future<void> setNotificationSound(String value, {String? name}) async {
    _notificationSound = value;
    _notificationSoundName = name;
    notifyListeners();
    await _save(() async {
      await _repo.setString(keyNotificationSound, value);
      await _repo.setString(keyNotificationSoundName, name ?? '');
    });
  }

  Future<void> setLanguage(String code) async {
    _language = code;
    notifyListeners();
    await _save(() => _repo.setString(keyLanguage, code));
  }

  Future<void> _save(Future<void> Function() write) async {
    try {
      await write();
    } catch (e) {
      debugPrint('AppPreferences: save failed: $e');
    }
  }
}
