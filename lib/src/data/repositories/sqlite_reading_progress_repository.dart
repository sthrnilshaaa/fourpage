/// Production SQLite database implementation for IReadingProgressRepository with offline sync logging.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/locator.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/i_reading_progress_repository.dart';
import '../database/app_database.dart';
import '../database/sync_journal.dart';

class SqliteReadingProgressRepository implements IReadingProgressRepository {
  final AppDatabase _db;
  final SyncJournalManager _journal;

  SqliteReadingProgressRepository({AppDatabase? db, SyncJournalManager? journal})
      : _db = db ?? AppDatabase.instance,
        _journal = journal ?? SyncJournalManager();

  @override
  Future<ReadingProgress?> getProgress(String publicationId) async {
    final database = await _db.database;
    final rows = await database.query(
      'reading_progress',
      where: 'publication_id = ?',
      whereArgs: [publicationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ReadingProgress(
      publicationId: r['publication_id'] as String,
      locator: Locator.fromJson(jsonDecode(r['locator_json'] as String)),
      percentage: (r['percentage'] as num).toDouble(),
      lastReadAt: DateTime.parse(r['last_read_at'] as String),
    );
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    final database = await _db.database;
    await database.insert(
      'reading_progress',
      {
        'publication_id': progress.publicationId,
        'locator_json': jsonEncode(progress.locator.toJson()),
        'percentage': progress.percentage,
        'last_read_at': progress.lastReadAt.toIso8601String(),
        'sync_status': 'synced',
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    _db.notifyChange('reading_progress');

    await _journal.recordMutation(
      entityType: 'progress',
      entityId: progress.publicationId,
      operation: SyncOperation.update,
      payload: progress.toJson(),
    );
  }
}
