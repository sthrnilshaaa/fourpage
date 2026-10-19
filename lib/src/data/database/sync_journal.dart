/// Model and manager for offline mutation tracking and real-time sync audit logging.
library;

import 'dart:convert';
import 'app_database.dart';

enum SyncOperation { insert, update, delete }

class SyncJournalEntry {
  final String id;
  final String entityType; // 'publication', 'annotation', 'bookmark', 'progress', 'preferences'
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final DateTime? syncedAt;

  const SyncJournalEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.timestamp,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation.name,
        'payload_json': jsonEncode(payload),
        'timestamp': timestamp.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
      };

  factory SyncJournalEntry.fromMap(Map<String, dynamic> map) => SyncJournalEntry(
        id: map['id'] as String,
        entityType: map['entity_type'] as String,
        entityId: map['entity_id'] as String,
        operation: SyncOperation.values.firstWhere(
          (e) => e.name == map['operation'],
          orElse: () => SyncOperation.insert,
        ),
        payload: jsonDecode(map['payload_json'] as String) as Map<String, dynamic>,
        timestamp: DateTime.parse(map['timestamp'] as String),
        syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
      );
}

class SyncJournalManager {
  final AppDatabase _db;

  SyncJournalManager([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Records an offline mutation in the journal log.
  Future<void> recordMutation({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final database = await _db.database;
    final entry = SyncJournalEntry(
      id: 'sync-${DateTime.now().microsecondsSinceEpoch}',
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      timestamp: DateTime.now(),
    );

    await database.insert('sync_journal', entry.toMap());
    _db.notifyChange('sync_journal');
  }

  /// Fetches all unsynced mutations from the journal.
  Future<List<SyncJournalEntry>> getPendingMutations() async {
    final database = await _db.database;
    final rows = await database.query(
      'sync_journal',
      where: 'synced_at IS NULL',
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => SyncJournalEntry.fromMap(r)).toList();
  }

  /// Marks a batch of journal entries as successfully synchronized.
  Future<void> markSynced(List<String> entryIds) async {
    if (entryIds.isEmpty) return;
    final database = await _db.database;
    final nowIso = DateTime.now().toIso8601String();

    await database.transaction((txn) async {
      for (final id in entryIds) {
        await txn.update(
          'sync_journal',
          {'synced_at': nowIso},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });

    _db.notifyChange('sync_journal');
  }
}
