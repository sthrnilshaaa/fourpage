/// Production-ready SQLite Database singleton with offline persistence and cross-platform support.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/constants/app_constants.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  sqflite.Database? _db;
  final _changeController = StreamController<String>.broadcast();

  /// Stream emitting table names whenever a real-time database mutation occurs.
  Stream<String> get changeStream => _changeController.stream;

  Future<sqflite.Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<sqflite.Database> _initDatabase() async {
    // Initialize FFI for desktop (Linux, Windows, macOS)
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      sqflite.databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = 'aread_offline.db';
    } else {
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        dbPath = p.join(documentsDir.path, AppConstants.databaseName);
      } catch (_) {
        // Headless tests (no path_provider): one database per test process in
        // the temp dir. Test files run in parallel processes, and a shared
        // file in the project root made them flaky ("database is locked").
        dbPath = p.join(Directory.systemTemp.path, 'fourpages_test_$pid.db');
      }
    }

    return await sqflite.openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }


  /// v4: usage tracking (Settings → Reading stats).
  static const _usageTables = [
    '''
      CREATE TABLE IF NOT EXISTS reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publication_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        seconds INTEGER NOT NULL,
        start_progress REAL NOT NULL,
        end_progress REAL NOT NULL,
        words_read INTEGER NOT NULL DEFAULT 0
      )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_reading_sessions_pub ON reading_sessions (publication_id)',
    '''
      CREATE TABLE IF NOT EXISTS app_usage (
        day TEXT PRIMARY KEY,
        seconds INTEGER NOT NULL
      )
    ''',
  ];

  Future<void> _onCreate(sqflite.Database db, int version) async {
    // 1. Publications Table
    await db.execute('''
      CREATE TABLE publications (
        id TEXT PRIMARY KEY,
        fingerprint TEXT NOT NULL,
        title TEXT NOT NULL,
        authors_json TEXT NOT NULL,
        publisher TEXT,
        language TEXT,
        identifier TEXT NOT NULL,
        cover_href TEXT,
        package_path TEXT NOT NULL,
        content_protection_scheme TEXT,
        metadata_json TEXT NOT NULL,
        resources_json TEXT NOT NULL,
        spine_json TEXT NOT NULL,
        toc_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    // 2. Reading Progress Table
    await db.execute('''
      CREATE TABLE reading_progress (
        publication_id TEXT PRIMARY KEY,
        locator_json TEXT NOT NULL,
        percentage REAL NOT NULL,
        last_read_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (publication_id) REFERENCES publications (id) ON DELETE CASCADE
      )
    ''');

    // 3. Annotations Table (Highlights & Notes)
    await db.execute('''
      CREATE TABLE annotations (
        id TEXT PRIMARY KEY,
        publication_id TEXT NOT NULL,
        locator_json TEXT NOT NULL,
        text_quote TEXT,
        text_prefix TEXT,
        text_suffix TEXT,
        note TEXT,
        color_hex TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (publication_id) REFERENCES publications (id) ON DELETE CASCADE
      )
    ''');

    // 4. Bookmarks Table
    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        publication_id TEXT NOT NULL,
        locator_json TEXT NOT NULL,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (publication_id) REFERENCES publications (id) ON DELETE CASCADE
      )
    ''');

    // 5. Reader Preferences Table (one row per book: font/theme/layout are per-publication)
    await db.execute('''
      CREATE TABLE reader_preferences (
        publication_id TEXT PRIMARY KEY,
        preferences_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        FOREIGN KEY (publication_id) REFERENCES publications (id) ON DELETE CASCADE
      )
    ''');

    // 6. Offline Synchronization Journal Table
    await db.execute('''
      CREATE TABLE sync_journal (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // 8-9. Usage tracking
    for (final sql in _usageTables) {
      await db.execute(sql);
    }

    // 7. App Settings Table (small app-wide key/value flags, e.g. onboarding-seen)
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Migrates the schema forward. v1 -> v2 re-keys reader_preferences from a
  /// single global row (id = 1) to one row per publication_id, so appearance
  /// settings can be remembered per book. There is no meaningful way to map
  /// the old global row onto a specific book, so it is dropped; every book
  /// simply falls back to default preferences once, then persists normally.
  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS reader_preferences');
      await db.execute('''
        CREATE TABLE reader_preferences (
          publication_id TEXT PRIMARY KEY,
          preferences_json TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'synced',
          FOREIGN KEY (publication_id) REFERENCES publications (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      for (final sql in _usageTables) {
        await db.execute(sql);
      }
    }
  }

  /// Removes what is recorded about one book (progress, highlights,
  /// bookmarks, its settings). Foreign keys are off, so ON DELETE CASCADE
  /// never runs. Usage history is kept so stats stay complete.
  Future<void> clearBookData(String publicationId) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const ['annotations', 'bookmarks', 'reading_progress', 'reader_preferences']) {
        await txn.delete(table, where: 'publication_id = ?', whereArgs: [publicationId]);
      }
    });
    notifyChange('annotations');
  }

  /// Settings → Reset: removes every book and everything recorded about them
  /// (progress, highlights, bookmarks, per-book settings, usage history).
  /// App-wide settings (theme, language, reminders) are kept.
  Future<void> clearLibraryData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const [
        'annotations', 'bookmarks', 'reading_progress', 'reader_preferences',
        'sync_journal', 'reading_sessions', 'app_usage', 'publications',
      ]) {
        await txn.delete(table);
      }
      await txn.delete('app_settings', where: 'key IN (?, ?, ?)', whereArgs: ['scanned_folders', 'book_folder_map', 'shelves']);
    });
  }

  /// Emits a real-time change event to notify subscribers.
  void notifyChange(String tableName) {
    _changeController.add(tableName);
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _changeController.close();
  }
}
