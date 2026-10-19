/// Tracks screen time and reading time, drives the break reminder, and keeps
/// the "continue reading" widget/notification up to date.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../data/repositories/usage_repository.dart';
import '../platform/system_bridge.dart';
import 'app_preferences.dart';
import 'library_controller.dart';

class UsageTracker with WidgetsBindingObserver {
  UsageTracker._();
  static final UsageTracker instance = UsageTracker._();

  final UsageRepository _repo = UsageRepository();

  DateTime? _foregroundSince;
  bool _started = false;

  // Current reading session (paused while the app is in the background).
  BookItem? _book;
  DateTime? _readingSince;
  int _readingSeconds = 0;
  double _startProgress = 0;
  int _continuousSeconds = 0;
  Timer? _ticker;

  /// True when the reader should suggest a break. Reader screens listen and
  /// show a prompt, then call [acknowledgeBreak].
  final ValueNotifier<bool> breakDue = ValueNotifier(false);

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _foregroundSince = DateTime.now();
    // Flush periodically so a killed app loses at most a minute.
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foregroundSince ??= DateTime.now();
      if (_book != null) _readingSince ??= DateTime.now();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _flushForeground();
      _pauseReading();
      _continuousSeconds = 0; // leaving the app is a break
    }
  }

  void _flushForeground() {
    final since = _foregroundSince;
    if (since == null) return;
    _foregroundSince = null;
    _repo.addAppTime(since, DateTime.now().difference(since).inSeconds);
  }

  void _tick() {
    if (_foregroundSince != null) {
      _flushForeground();
      _foregroundSince = DateTime.now();
    }
    if (_readingSince != null) {
      final now = DateTime.now();
      final delta = now.difference(_readingSince!).inSeconds;
      _readingSeconds += delta;
      _continuousSeconds += delta;
      _readingSince = now;
      final limit = AppPreferences.instance.breakMinutes;
      if (limit > 0 && _continuousSeconds >= limit * 60 && !breakDue.value) breakDue.value = true;
    }
  }

  void _pauseReading() {
    if (_readingSince == null) return;
    final delta = DateTime.now().difference(_readingSince!).inSeconds;
    _readingSeconds += delta;
    _continuousSeconds += delta;
    _readingSince = null;
  }

  /// Call when a reader screen opens.
  void startReading(BookItem book) {
    if (_book != null) stopReading();
    _book = book;
    _readingSince = DateTime.now();
    _readingSeconds = 0;
    _startProgress = book.progress;
  }

  /// Call when the reader closes: records the session and refreshes the
  /// widget/reminder text.
  void stopReading() {
    final book = _book;
    if (book == null) return;
    _pauseReading();
    _book = null;
    final seconds = _readingSeconds;
    final gained = (book.progress - _startProgress).clamp(0.0, 1.0);
    final totalWords = book.session.state.publication?.derivedStatistics.wordCount ?? 0;
    var words = (gained * totalWords).round();
    // Jumps (TOC, search) aren't reading: ignore speeds above 1000 wpm.
    if (seconds <= 0 || words / (seconds / 60) > 1000) words = 0;
    _repo.addReadingSession(ReadingSessionRecord(
      publicationId: book.publication.id,
      startedAt: DateTime.now().subtract(Duration(seconds: seconds)),
      seconds: seconds,
      startProgress: _startProgress,
      endProgress: book.progress,
      wordsRead: words,
    ));
    _updateContinueReading(book);
  }

  void acknowledgeBreak() {
    breakDue.value = false;
    _continuousSeconds = 0;
  }

  Future<UsageSummary> summary() async {
    _tick(); // include the time up to now
    return _repo.summary();
  }

  Future<void> resetHistory() => _repo.clear();

  void _updateContinueReading(BookItem book) {
    final percent = (book.progress * 100).round();
    final title = book.publication.metadata.title;
    final authors = book.publication.metadata.authors;
    SystemBridge.updateContinueReading(
      title: title,
      subtitle: authors.isNotEmpty ? authors.first : l10n.percentRead(percent),
      percent: percent,
      reminderTitle: l10n.reminderContinueTitle,
      reminderBody: l10n.reminderContinueBody(title, percent),
    );
  }

  /// Re-applies the daily reminder from settings (after a change or launch).
  Future<void> applyReminderSettings() async {
    final prefs = AppPreferences.instance;
    if (prefs.dailyReminder < 0) {
      await SystemBridge.cancelDailyReminder();
    } else {
      await SystemBridge.scheduleDailyReminder(
        minutesAfterMidnight: prefs.dailyReminder,
        sound: prefs.notificationSound,
      );
    }
  }

  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
