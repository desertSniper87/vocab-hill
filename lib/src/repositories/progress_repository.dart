import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/progress_snapshot.dart';
import '../models/sync_settings.dart';
import '../models/word_status.dart';
import 'progress_sync_client.dart';

abstract class ProgressRepository {
  Future<ProgressSnapshot> loadProgress();

  Future<void> saveSelectedDay(int selectedDay);

  Future<void> saveWordStatus(int day, String word, WordStatus status);

  Future<SyncSettings> loadSyncSettings();

  Future<void> saveSyncSettings(SyncSettings settings);

  Future<ProgressSnapshot> syncNow();
}

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository({ProgressSyncClient? syncClient})
    : _syncClient = syncClient ?? ProgressSyncClient();

  static const _databaseName = 'vocab_hill_progress.db';
  static const _selectedDayKey = 'selected_day';
  static const _syncServerUrlKey = 'sync_server_url';
  static const _syncKeyKey = 'sync_key';
  static const _migrationFlagKey = 'legacy_shared_prefs_migrated';
  static const _legacySelectedDayKey = 'progress.selected_day';
  static const _legacyStatusPrefix = 'progress.word_status.';

  final ProgressSyncClient _syncClient;
  late final Future<Database> _databaseFuture = _openDatabase();
  Future<void> _syncQueue = Future<void>.value();

  @override
  Future<ProgressSnapshot> loadProgress() async {
    final database = await _databaseFuture;
    await _synchronizeIfConfigured(database, throwOnError: false);
    return _readProgressSnapshot(database);
  }

  @override
  Future<void> saveSelectedDay(int selectedDay) async {
    final database = await _databaseFuture;
    await _upsertAppStateValue(
      database,
      key: _selectedDayKey,
      value: '$selectedDay',
      updatedAt: _nowIso8601(),
    );
    unawaited(_enqueueBestEffortSync(database));
  }

  @override
  Future<void> saveWordStatus(int day, String word, WordStatus status) async {
    final database = await _databaseFuture;
    await database.insert('word_progress', <String, Object?>{
      'day': day,
      'word': word,
      'status': status.storageValue,
      'updated_at': _nowIso8601(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    unawaited(_enqueueBestEffortSync(database));
  }

  @override
  Future<SyncSettings> loadSyncSettings() async {
    final database = await _databaseFuture;
    return _readSyncSettings(database);
  }

  @override
  Future<void> saveSyncSettings(SyncSettings settings) async {
    final database = await _databaseFuture;
    final normalizedServerUrl = settings.serverUrl.trim().isEmpty
        ? SyncSettings.defaultServerUrl
        : settings.serverUrl.trim();
    await _setAppStateValue(
      database,
      key: _syncServerUrlKey,
      value: normalizedServerUrl,
    );
    await _setAppStateValue(
      database,
      key: _syncKeyKey,
      value: settings.syncKey.trim(),
    );
  }

  @override
  Future<ProgressSnapshot> syncNow() async {
    final database = await _databaseFuture;
    await _synchronizeIfConfigured(database, throwOnError: true);
    return _readProgressSnapshot(database);
  }

  Future<Database> _openDatabase() async {
    final factory = _databaseFactory();
    final databasePath = await _databasePath(factory);
    final database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE app_state(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at TEXT
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
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await database.execute(
              'ALTER TABLE app_state ADD COLUMN updated_at TEXT',
            );
            await database.update('app_state', <String, Object?>{
              'updated_at': _nowIso8601(),
            });
          }
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
        'updated_at': _nowIso8601(),
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
          'updated_at': _nowIso8601(),
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
        'updated_at': _nowIso8601(),
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

  Future<ProgressSnapshot> _readProgressSnapshot(Database database) async {
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

  Future<SyncSettings> _readSyncSettings(Database database) async {
    final rows = await database.query(
      'app_state',
      columns: <String>['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: <Object>[_syncServerUrlKey, _syncKeyKey],
    );

    String serverUrl = SyncSettings.defaultServerUrl;
    var syncKey = '';
    for (final row in rows) {
      if (row['key'] == _syncServerUrlKey) {
        final value = row['value'] as String;
        if (value.trim().isNotEmpty) {
          serverUrl = value;
        }
      } else if (row['key'] == _syncKeyKey) {
        syncKey = row['value'] as String;
      }
    }

    return SyncSettings(serverUrl: serverUrl, syncKey: syncKey);
  }

  Future<void> _setAppStateValue(
    Database database, {
    required String key,
    required String value,
  }) async {
    if (value.isEmpty) {
      await database.delete(
        'app_state',
        where: 'key = ?',
        whereArgs: <Object>[key],
      );
      return;
    }

    await database.insert('app_state', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertAppStateValue(
    Database database, {
    required String key,
    required String value,
    required String updatedAt,
  }) async {
    await database.insert('app_state', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _synchronizeIfConfigured(
    Database database, {
    required bool throwOnError,
  }) async {
    final settings = await _readSyncSettings(database);
    if (!settings.isConfigured) {
      return;
    }

    Future<void> run() async {
      final localPayload = await _readSyncPayload(database);
      final merged = await _syncClient.mergeSnapshot(settings, localPayload);
      await _replaceLocalSnapshot(database, merged);
    }

    _syncQueue = _syncQueue.catchError((Object _) {}).then((_) => run());

    if (throwOnError) {
      await _syncQueue;
      return;
    }

    await _syncQueue.catchError((Object _) {});
  }

  Future<void> _enqueueBestEffortSync(Database database) async {
    await _synchronizeIfConfigured(database, throwOnError: false);
  }

  Future<SyncSnapshotPayload> _readSyncPayload(Database database) async {
    final selectedDayRows = await database.query(
      'app_state',
      columns: <String>['value', 'updated_at'],
      where: 'key = ?',
      whereArgs: <Object>[_selectedDayKey],
      limit: 1,
    );
    final progressRows = await database.query(
      'word_progress',
      columns: <String>['day', 'word', 'status', 'updated_at'],
      orderBy: 'day ASC, word ASC',
    );

    return SyncSnapshotPayload(
      selectedDay: selectedDayRows.isEmpty
          ? null
          : int.tryParse(selectedDayRows.first['value'] as String),
      selectedDayUpdatedAt: selectedDayRows.isEmpty
          ? null
          : selectedDayRows.first['updated_at'] as String?,
      statuses: progressRows
          .map(
            (row) => SyncWordProgressRecord(
              day: row['day'] as int,
              word: row['word'] as String,
              status: WordStatus.fromStorageValue(row['status'] as String?),
              updatedAt: row['updated_at'] as String,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _replaceLocalSnapshot(
    Database database,
    SyncSnapshotPayload payload,
  ) async {
    await database.transaction((transaction) async {
      await transaction.delete('word_progress');
      if (payload.selectedDay == null || payload.selectedDayUpdatedAt == null) {
        await transaction.delete(
          'app_state',
          where: 'key = ?',
          whereArgs: <Object>[_selectedDayKey],
        );
      } else {
        await transaction.insert('app_state', <String, Object?>{
          'key': _selectedDayKey,
          'value': '${payload.selectedDay}',
          'updated_at': payload.selectedDayUpdatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final batch = transaction.batch();
      for (final record in payload.statuses) {
        batch.insert('word_progress', <String, Object?>{
          'day': record.day,
          'word': record.word,
          'status': record.status.storageValue,
          'updated_at': record.updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  String _nowIso8601() => DateTime.now().toUtc().toIso8601String();
}
