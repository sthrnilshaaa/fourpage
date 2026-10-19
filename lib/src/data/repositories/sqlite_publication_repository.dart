/// Production SQLite database implementation for IPublicationRepository with offline sync logging.
library;

import 'dart:convert';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../domain/entities/manifest_resource.dart';
import '../../domain/entities/publication.dart';
import '../../domain/entities/publication_metadata.dart';
import '../../domain/entities/spine_item.dart';
import '../../domain/entities/table_of_contents.dart';
import '../../domain/repositories/i_publication_repository.dart';
import '../database/app_database.dart';
import '../database/sync_journal.dart';

class SqlitePublicationRepository implements IPublicationRepository {
  final AppDatabase _db;
  final SyncJournalManager _journal;

  SqlitePublicationRepository({AppDatabase? db, SyncJournalManager? journal})
      : _db = db ?? AppDatabase.instance,
        _journal = journal ?? SyncJournalManager();

  @override
  Future<List<Publication>> getAllPublications() async {
    final database = await _db.database;
    final rows = await database.query('publications', orderBy: 'created_at DESC');
    return rows.map((r) => _fromDatabaseMap(r)).toList();
  }

  @override
  Future<Publication?> getPublicationById(String id) async {
    final database = await _db.database;
    final rows = await database.query(
      'publications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromDatabaseMap(rows.first);
  }

  @override
  Future<Publication?> getPublicationByFingerprint(String fingerprint) async {
    final database = await _db.database;
    final rows = await database.query(
      'publications',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromDatabaseMap(rows.first);
  }

  @override
  Future<void> savePublication(Publication publication) async {
    final database = await _db.database;
    final map = _toDatabaseMap(publication);

    await database.insert(
      'publications',
      map,
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    _db.notifyChange('publications');

    await _journal.recordMutation(
      entityType: 'publication',
      entityId: publication.id,
      operation: SyncOperation.insert,
      payload: publication.toJson(),
    );
  }

  @override
  Future<void> deletePublication(String id) async {
    final database = await _db.database;
    await database.delete('publications', where: 'id = ?', whereArgs: [id]);
    _db.notifyChange('publications');

    await _journal.recordMutation(
      entityType: 'publication',
      entityId: id,
      operation: SyncOperation.delete,
      payload: {'id': id},
    );
  }

  Map<String, dynamic> _toDatabaseMap(Publication pub) => {
        'id': pub.id,
        'fingerprint': pub.fingerprint,
        'title': pub.metadata.title,
        'authors_json': jsonEncode(pub.metadata.authors),
        'publisher': pub.metadata.publisher,
        'language': pub.metadata.language,
        'identifier': pub.metadata.identifier,
        'cover_href': pub.metadata.coverHref,
        'package_path': pub.packagePath,
        'content_protection_scheme': pub.contentProtectionScheme,
        'metadata_json': jsonEncode(pub.metadata.toJson()),
        'resources_json': jsonEncode(pub.resources.map((r) => r.toJson()).toList()),
        'spine_json': jsonEncode(pub.spine.map((s) => s.toJson()).toList()),
        'toc_json': jsonEncode(pub.tableOfContents.toJson()),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': 'synced',
      };

  Publication _fromDatabaseMap(Map<String, dynamic> map) => Publication(
        id: map['id'] as String,
        fingerprint: map['fingerprint'] as String,
        metadata: PublicationMetadata.fromJson(jsonDecode(map['metadata_json'] as String)),
        resources: (jsonDecode(map['resources_json'] as String) as List)
            .map((r) => ManifestResource.fromJson(r))
            .toList(),
        spine: (jsonDecode(map['spine_json'] as String) as List)
            .map((s) => SpineItem.fromJson(s))
            .toList(),
        tableOfContents: TableOfContents.fromJson(jsonDecode(map['toc_json'] as String)),
        packagePath: map['package_path'] as String,
        contentProtectionScheme: map['content_protection_scheme'] as String?,
      );
}
