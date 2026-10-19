/// Reading sessions and app screen time (SQLite, schema v4).
library;

import '../database/app_database.dart';

class ReadingSessionRecord {
  final String publicationId;
  final DateTime startedAt;
  final int seconds;
  final double startProgress;
  final double endProgress;
  final int wordsRead;

  const ReadingSessionRecord({
    required this.publicationId,
    required this.startedAt,
    required this.seconds,
    required this.startProgress,
    required this.endProgress,
    this.wordsRead = 0,
  });
}

/// Per-book reading totals.
class BookUsage {
  final String publicationId;
  final int seconds;
  final int sessions;
  final DateTime lastReadAt;
  const BookUsage(this.publicationId, this.seconds, this.sessions, this.lastReadAt);
}

class UsageSummary {
  final int readingToday;
  final int readingThisWeek;
  final int readingTotal;
  final int appToday;
  final int appTotal;

  /// Average words per minute over sessions where it could be measured.
  final int? wordsPerMinute;

  /// Consecutive days, ending today or yesterday, with any reading.
  final int streakDays;

  /// Average reading seconds per day over days with reading.
  final int averagePerReadingDay;
  final List<BookUsage> books;

  const UsageSummary({
    required this.readingToday,
    required this.readingThisWeek,
    required this.readingTotal,
    required this.appToday,
    required this.appTotal,
    required this.wordsPerMinute,
    required this.streakDays,
    required this.averagePerReadingDay,
    required this.books,
  });
}

class UsageRepository {
  final AppDatabase _db;
  UsageRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<void> addReadingSession(ReadingSessionRecord r) async {
    if (r.seconds <= 0) return;
    final db = await _db.database;
    await db.insert('reading_sessions', {
      'publication_id': r.publicationId,
      'started_at': r.startedAt.toIso8601String(),
      'seconds': r.seconds,
      'start_progress': r.startProgress,
      'end_progress': r.endProgress,
      'words_read': r.wordsRead,
    });
  }

  Future<void> addAppTime(DateTime day, int seconds) async {
    if (seconds <= 0) return;
    final db = await _db.database;
    // Update-then-insert rather than UPSERT: older Android SQLite (< 3.24)
    // doesn't support ON CONFLICT ... DO UPDATE.
    final key = dayKey(day);
    final updated = await db.rawUpdate('UPDATE app_usage SET seconds = seconds + ? WHERE day = ?', [seconds, key]);
    if (updated == 0) await db.insert('app_usage', {'day': key, 'seconds': seconds});
  }

  Future<UsageSummary> summary({DateTime? now}) async {
    final db = await _db.database;
    final today = now ?? DateTime.now();
    final todayKey = dayKey(today);
    final weekStart = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));

    final sessions = await db.query('reading_sessions', orderBy: 'started_at ASC');
    var readingToday = 0, readingWeek = 0, readingTotal = 0;
    var measuredWords = 0, measuredSeconds = 0;
    final perDay = <String, int>{};
    final perBook = <String, (int, int, DateTime)>{};
    for (final row in sessions) {
      final started = DateTime.parse(row['started_at'] as String);
      final seconds = row['seconds'] as int;
      final words = row['words_read'] as int;
      final key = dayKey(started);
      readingTotal += seconds;
      perDay[key] = (perDay[key] ?? 0) + seconds;
      if (key == todayKey) readingToday += seconds;
      if (!started.isBefore(weekStart)) readingWeek += seconds;
      // Only sessions long enough and with forward progress give a speed.
      if (words > 0 && seconds >= 60) {
        measuredWords += words;
        measuredSeconds += seconds;
      }
      final pub = row['publication_id'] as String;
      final prev = perBook[pub];
      perBook[pub] = (
        (prev?.$1 ?? 0) + seconds,
        (prev?.$2 ?? 0) + 1,
        prev == null || started.isAfter(prev.$3) ? started : prev.$3,
      );
    }

    var streak = 0;
    var day = DateTime(today.year, today.month, today.day);
    if (!perDay.containsKey(dayKey(day))) day = day.subtract(const Duration(days: 1));
    while (perDay.containsKey(dayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }

    final appRows = await db.query('app_usage');
    var appToday = 0, appTotal = 0;
    for (final row in appRows) {
      final s = row['seconds'] as int;
      appTotal += s;
      if (row['day'] == todayKey) appToday += s;
    }

    final books = [
      for (final e in perBook.entries) BookUsage(e.key, e.value.$1, e.value.$2, e.value.$3),
    ]..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));

    return UsageSummary(
      readingToday: readingToday,
      readingThisWeek: readingWeek,
      readingTotal: readingTotal,
      appToday: appToday,
      appTotal: appTotal,
      wordsPerMinute: measuredSeconds >= 60 ? (measuredWords / (measuredSeconds / 60)).round() : null,
      streakDays: streak,
      averagePerReadingDay: perDay.isEmpty ? 0 : (readingTotal / perDay.length).round(),
      books: books,
    );
  }

  /// Settings → Reset: forget all usage history.
  Future<void> clear() async {
    final db = await _db.database;
    await db.delete('reading_sessions');
    await db.delete('app_usage');
  }
}
