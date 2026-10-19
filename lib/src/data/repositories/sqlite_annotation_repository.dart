/// Production SQLite database implementation for IAnnotationRepository with offline sync logging.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/locator.dart';
import '../../domain/repositories/i_annotation_repository.dart';
import '../database/app_database.dart';
import '../database/sync_journal.dart';

class SqliteAnnotationRepository implements IAnnotationRepository {
  final AppDatabase _db;
  final SyncJournalManager _journal;

  SqliteAnnotationRepository({AppDatabase? db, SyncJournalManager? journal})
      : _db = db ?? AppDatabase.instance,
        _journal = journal ?? SyncJournalManager();

  @override
  Future<List<Annotation>> getAnnotationsForPublication(String publicationId) async {
    final database = await _db.database;
    final rows = await database.query(
      'annotations',
      where: 'publication_id = ?',
      whereArgs: [publicationId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => _fromDatabaseMap(r)).toList();
  }

  @override
  Future<void> saveAnnotation(Annotation annotation) async {
    final database = await _db.database;
    await database.insert(
      'annotations',
      _toDatabaseMap(annotation),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    _db.notifyChange('annotations');

    await _journal.recordMutation(
      entityType: 'annotation',
      entityId: annotation.id,
      operation: SyncOperation.insert,
      payload: annotation.toJson(),
    );
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    final database = await _db.database;
    await database.delete('annotations', where: 'id = ?', whereArgs: [id]);
    _db.notifyChange('annotations');

    await _journal.recordMutation(
      entityType: 'annotation',
      entityId: id,
      operation: SyncOperation.delete,
      payload: {'id': id},
    );
  }

  @override
  Future<List<Bookmark>> getBookmarksForPublication(String publicationId) async {
    final database = await _db.database;
    final rows = await database.query(
      'bookmarks',
      where: 'publication_id = ?',
      whereArgs: [publicationId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => Bookmark(
            id: r['id'] as String,
            publicationId: r['publication_id'] as String,
            locator: Locator.fromJson(jsonDecode(r['locator_json'] as String)),
            title: r['title'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveBookmark(Bookmark bookmark) async {
    final database = await _db.database;
    await database.insert(
      'bookmarks',
      {
        'id': bookmark.id,
        'publication_id': bookmark.publicationId,
        'locator_json': jsonEncode(bookmark.locator.toJson()),
        'title': bookmark.title,
        'created_at': bookmark.createdAt.toIso8601String(),
        'sync_status': 'synced',
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    _db.notifyChange('bookmarks');

    await _journal.recordMutation(
      entityType: 'bookmark',
      entityId: bookmark.id,
      operation: SyncOperation.insert,
      payload: bookmark.toJson(),
    );
  }

  @override
  Future<void> deleteBookmark(String id) async {
    final database = await _db.database;
    await database.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
    _db.notifyChange('bookmarks');

    await _journal.recordMutation(
      entityType: 'bookmark',
      entityId: id,
      operation: SyncOperation.delete,
      payload: {'id': id},
    );
  }

  Map<String, dynamic> _toDatabaseMap(Annotation ann) => {
        'id': ann.id,
        'publication_id': ann.publicationId,
        'locator_json': jsonEncode(ann.locator.toJson()),
        'text_quote': ann.textQuote,
        'text_prefix': ann.textPrefix,
        'text_suffix': ann.textSuffix,
        'note': ann.note,
        'color_hex': ann.colorHex,
        'type': ann.type.name,
        'created_at': ann.createdAt.toIso8601String(),
        'updated_at': ann.updatedAt.toIso8601String(),
        'sync_status': 'synced',
      };

  Annotation _fromDatabaseMap(Map<String, dynamic> map) => Annotation(
        id: map['id'] as String,
        publicationId: map['publication_id'] as String,
        locator: Locator.fromJson(jsonDecode(map['locator_json'] as String)),
        textQuote: map['text_quote'] as String?,
        textPrefix: map['text_prefix'] as String?,
        textSuffix: map['text_suffix'] as String?,
        note: map['note'] as String?,
        colorHex: map['color_hex'] as String,
        type: AnnotationType.values.firstWhere((e) => e.name == map['type']),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
