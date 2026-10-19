/// Tiny key/value store for app-wide flags that aren't tied to any one book
/// (e.g. "has the user finished onboarding?"). Backed by SQLite so it
/// actually survives an app restart, unlike a plain in-memory flag.
library;

import 'package:sqflite/sqflite.dart' as sqflite;
import 'app_database.dart';

class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final database = await _db.database;
    final rows = await database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return defaultValue;
    return rows.first['value'] == 'true';
  }

  Future<void> setBool(String key, bool value) async {
    final database = await _db.database;
    await database.insert(
      'app_settings',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<String?> getString(String key) async {
    final database = await _db.database;
    final rows = await database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setString(String key, String value) async {
    final database = await _db.database;
    await database.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String key) async {
    final database = await _db.database;
    await database.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
