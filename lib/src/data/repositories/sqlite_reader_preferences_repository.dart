/// Production SQLite database implementation for IReaderPreferencesRepository with offline sync logging.
///
/// One row per publication_id: every book remembers its own appearance settings.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/reader_preferences.dart';
import '../../domain/repositories/i_reader_preferences_repository.dart';
import '../database/app_database.dart';
import '../database/sync_journal.dart';

class SqliteReaderPreferencesRepository implements IReaderPreferencesRepository {
  final AppDatabase _db;
  final SyncJournalManager _journal;
  final ReaderPreferences Function() _defaults;

  /// [defaults] supplies the appearance for a book with no saved row (the
  /// user's "reading defaults" setting); falls back to ReaderPreferences().
  SqliteReaderPreferencesRepository({
    AppDatabase? db,
    SyncJournalManager? journal,
    ReaderPreferences Function()? defaults,
  })  : _db = db ?? AppDatabase.instance,
        _journal = journal ?? SyncJournalManager(),
        _defaults = defaults ?? (() => const ReaderPreferences());

  @override
  Future<ReaderPreferences> getPreferences(String publicationId) async {
    final database = await _db.database;
    final rows = await database.query(
      'reader_preferences',
      where: 'publication_id = ?',
      whereArgs: [publicationId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return _defaults();
    }
    return ReaderPreferences.fromJson(jsonDecode(rows.first['preferences_json'] as String));
  }

  /// Whether this book has its own saved appearance (changed in the reader).
  /// Books without one use the current defaults, which follow the app theme.
  Future<bool> hasSavedPreferences(String publicationId) async {
    final database = await _db.database;
    final rows = await database.query(
      'reader_preferences',
      columns: ['publication_id'],
      where: 'publication_id = ?',
      whereArgs: [publicationId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> savePreferences(String publicationId, ReaderPreferences preferences) async {
    final database = await _db.database;
    await database.insert(
      'reader_preferences',
      {
        'publication_id': publicationId,
        'preferences_json': jsonEncode(preferences.toJson()),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    _db.notifyChange('reader_preferences');

    await _journal.recordMutation(
      entityType: 'preferences',
      entityId: publicationId,
      operation: SyncOperation.update,
      payload: preferences.toJson(),
    );
  }
}
