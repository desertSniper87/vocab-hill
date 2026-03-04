import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/progress_snapshot.dart';
import '../models/word_status.dart';

abstract class ProgressRepository {
  Future<ProgressSnapshot> loadProgress();

  Future<void> saveSelectedDay(int selectedDay);

  Future<void> saveWordStatus(int day, String word, WordStatus status);
}

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository();

  static const _databaseName = 'vocab_hill_progress.db';
  static const _selectedDayKey = 'selected_day';
  static const _migrationFlagKey = 'legacy_shared_prefs_migrated';
  static const _legacySelectedDayKey = 'progress.selected_day';
  static const _legacyStatusPrefix = 'progress.word_status.';

  late final Future<Database> _databaseFuture = _openDatabase();

  @override
  Future<ProgressSnapshot> loadProgress() async {
    final database = await _databaseFuture;
    final appStateRows = await database.query(
      'app_state',
      columns: <String>['key', 'value'],
    );
    final progressRows = await database.query(
      'word_progress',
      columns: <String>['day', 'word', 'status'],
      orderBy: 'day ASC, word ASC',
    );

    int? selectedDay;
    for (final row in appStateRows) {
      if (row['key'] == _selectedDayKey) {
        selectedDay = int.tryParse(row['value'] as String);
      }
    }

    final wordStatusesByDay = <int, Map<String, WordStatus>>{};
    for (final row in progressRows) {
      final day = row['day'] as int;
      final word = row['word'] as String;
      final status = WordStatus.fromStorageValue(row['status'] as String?);
      if (status == WordStatus.untouched) {
        continue;
      }
      final dayStatuses = wordStatusesByDay.putIfAbsent(
        day,
        () => <String, WordStatus>{},
      );
      dayStatuses[word] = status;
    }

    return ProgressSnapshot(
      selectedDay: selectedDay,
      wordStatusesByDay: wordStatusesByDay,
    );
  }

  @override
  Future<void> saveSelectedDay(int selectedDay) async {
    final database = await _databaseFuture;
    await database.insert('app_state', <String, Object?>{
      'key': _selectedDayKey,
      'value': '$selectedDay',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveWordStatus(int day, String word, WordStatus status) async {
    final database = await _databaseFuture;
    if (status == WordStatus.untouched) {
      await database.delete(
        'word_progress',
        where: 'day = ? AND word = ?',
        whereArgs: <Object>[day, word],
      );
      return;
    }

    await database.insert('word_progress', <String, Object?>{
      'day': day,
      'word': word,
      'status': status.storageValue,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Database> _openDatabase() async {
    final factory = _databaseFactory();
    final databasePath = await _databasePath(factory);
    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE app_state(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE word_progress(
              day INTEGER NOT NULL,
              word TEXT NOT NULL,
              status TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY(day, word)
            )
          ''');
        },
      ),
    );
    await _migrateLegacyPreferencesIfNeeded(database);
    return database;
  }

  DatabaseFactory _databaseFactory() {
    if (kIsWeb) {
      return databaseFactoryFfiWeb;
    }
    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return sqflite.databaseFactory;
    }
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  Future<String> _databasePath(DatabaseFactory factory) async {
    if (kIsWeb) {
      return _databaseName;
    }

    final platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      return path.join(await sqflite.getDatabasesPath(), _databaseName);
    }

    return path.join(await factory.getDatabasesPath(), _databaseName);
  }

  Future<void> _migrateLegacyPreferencesIfNeeded(Database database) async {
    final existingMigrationFlag = await database.query(
      'app_state',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object>[_migrationFlagKey],
      limit: 1,
    );
    if (existingMigrationFlag.isNotEmpty) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    final batch = database.batch();

    final legacySelectedDay = preferences.getInt(_legacySelectedDayKey);
    if (legacySelectedDay != null) {
      batch.insert('app_state', <String, Object?>{
        'key': _selectedDayKey,
        'value': '$legacySelectedDay',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final keysToRemove = <String>[];
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_legacyStatusPrefix)) {
        continue;
      }

      final suffix = key.substring(_legacyStatusPrefix.length);
      final separatorIndex = suffix.indexOf('.');
      final storedValue = preferences.getString(key);
      final status = WordStatus.fromStorageValue(storedValue);
      if (status == WordStatus.untouched) {
        keysToRemove.add(key);
        continue;
      }

      if (separatorIndex <= 0 || separatorIndex == suffix.length - 1) {
        batch.insert('word_progress', <String, Object?>{
          'day': legacySelectedDay ?? 1,
          'word': suffix,
          'status': status.storageValue,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        keysToRemove.add(key);
        continue;
      }

      final day = int.tryParse(suffix.substring(0, separatorIndex));
      final word = suffix.substring(separatorIndex + 1);
      if (day == null) {
        continue;
      }

      batch.insert('word_progress', <String, Object?>{
        'day': day,
        'word': word,
        'status': status.storageValue,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      keysToRemove.add(key);
    }

    batch.insert('app_state', <String, Object?>{
      'key': _migrationFlagKey,
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);

    if (legacySelectedDay != null) {
      await preferences.remove(_legacySelectedDayKey);
    }
    for (final key in keysToRemove) {
      await preferences.remove(key);
    }
  }
}
