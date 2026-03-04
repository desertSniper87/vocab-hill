import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

void main(List<String> arguments) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final databasePath =
      Platform.environment['VOCAB_HILL_SYNC_DB'] ??
      path.join(Directory.current.path, '.dart_tool', 'vocab_hill_sync.db');
  Directory(path.dirname(databasePath)).createSync(recursive: true);

  final database = sqlite3.open(databasePath);
  _createSchema(database);

  final router = Router()
    ..get('/health', (Request request) {
      return _json(<String, Object?>{'status': 'ok'});
    })
    ..get('/api/progress/<syncKey>', (Request request, String syncKey) {
      return _json(_readSnapshot(database, syncKey));
    })
    ..post('/api/progress/<syncKey>/merge', (
      Request request,
      String syncKey,
    ) async {
      final body = await request.readAsString();
      final payload = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      final merged = _mergeSnapshot(database, syncKey, payload);
      return _json(merged);
    });

  final handler = const Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
    'Vocab Hill sync server listening on http://${server.address.host}:${server.port}',
  );
}

Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: const <String, String>{
            'access-control-allow-origin': '*',
            'access-control-allow-methods': 'GET, POST, OPTIONS',
            'access-control-allow-headers': 'content-type',
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(
        headers: <String, String>{
          ...response.headers,
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, POST, OPTIONS',
          'access-control-allow-headers': 'content-type',
        },
      );
    };
  };
}

Response _json(Map<String, Object?> body) {
  return Response.ok(
    jsonEncode(body),
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void _createSchema(Database database) {
  database.execute('''
    CREATE TABLE IF NOT EXISTS learners(
      sync_key TEXT PRIMARY KEY,
      created_at TEXT NOT NULL
    )
  ''');
  database.execute('''
    CREATE TABLE IF NOT EXISTS app_state(
      sync_key TEXT PRIMARY KEY,
      selected_day INTEGER,
      updated_at TEXT
    )
  ''');
  database.execute('''
    CREATE TABLE IF NOT EXISTS word_progress(
      sync_key TEXT NOT NULL,
      day INTEGER NOT NULL,
      word TEXT NOT NULL,
      status TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY(sync_key, day, word)
    )
  ''');
}

Map<String, Object?> _readSnapshot(Database database, String syncKey) {
  _ensureLearner(database, syncKey);

  final selectedDayRow = database.select(
    '''
    SELECT selected_day, updated_at
    FROM app_state
    WHERE sync_key = ?
    LIMIT 1
    ''',
    <Object?>[syncKey],
  );
  final statusRows = database.select(
    '''
    SELECT day, word, status, updated_at
    FROM word_progress
    WHERE sync_key = ?
    ORDER BY day ASC, word ASC
    ''',
    <Object?>[syncKey],
  );

  return <String, Object?>{
    'selectedDay': selectedDayRow.isEmpty
        ? null
        : selectedDayRow.first['selected_day'] as int?,
    'selectedDayUpdatedAt': selectedDayRow.isEmpty
        ? null
        : selectedDayRow.first['updated_at'] as String?,
    'statuses': statusRows
        .map(
          (row) => <String, Object?>{
            'day': row['day'] as int,
            'word': row['word'] as String,
            'status': row['status'] as String,
            'updatedAt': row['updated_at'] as String,
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> _mergeSnapshot(
  Database database,
  String syncKey,
  Map<String, dynamic> payload,
) {
  _ensureLearner(database, syncKey);

  final incomingSelectedDay = payload['selectedDay'] as int?;
  final incomingSelectedDayUpdatedAt =
      payload['selectedDayUpdatedAt'] as String?;
  final incomingStatuses =
      (payload['statuses'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

  final transaction = database;
  final existingSelectedDayRow = transaction.select(
    '''
    SELECT selected_day, updated_at
    FROM app_state
    WHERE sync_key = ?
    LIMIT 1
    ''',
    <Object?>[syncKey],
  );
  final existingSelectedDayUpdatedAt = existingSelectedDayRow.isEmpty
      ? null
      : existingSelectedDayRow.first['updated_at'] as String?;

  if (_isIncomingNewer(
    incomingSelectedDayUpdatedAt,
    existingSelectedDayUpdatedAt,
  )) {
    transaction.execute(
      '''
      INSERT INTO app_state(sync_key, selected_day, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(sync_key) DO UPDATE SET
        selected_day = excluded.selected_day,
        updated_at = excluded.updated_at
      ''',
      <Object?>[syncKey, incomingSelectedDay, incomingSelectedDayUpdatedAt],
    );
  }

  for (final record in incomingStatuses) {
    final existingRow = transaction.select(
      '''
      SELECT updated_at
      FROM word_progress
      WHERE sync_key = ? AND day = ? AND word = ?
      LIMIT 1
      ''',
      <Object?>[syncKey, record['day'] as int, record['word'] as String],
    );
    final existingUpdatedAt = existingRow.isEmpty
        ? null
        : existingRow.first['updated_at'] as String?;

    if (!_isIncomingNewer(record['updatedAt'] as String?, existingUpdatedAt)) {
      continue;
    }

    transaction.execute(
      '''
      INSERT INTO word_progress(sync_key, day, word, status, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(sync_key, day, word) DO UPDATE SET
        status = excluded.status,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        syncKey,
        record['day'] as int,
        record['word'] as String,
        record['status'] as String,
        record['updatedAt'] as String,
      ],
    );
  }

  return _readSnapshot(transaction, syncKey);
}

void _ensureLearner(Database database, String syncKey) {
  database.execute(
    '''
    INSERT INTO learners(sync_key, created_at)
    VALUES (?, ?)
    ON CONFLICT(sync_key) DO NOTHING
    ''',
    <Object?>[syncKey, DateTime.now().toUtc().toIso8601String()],
  );
}

bool _isIncomingNewer(String? incoming, String? existing) {
  if (incoming == null || incoming.isEmpty) {
    return false;
  }
  if (existing == null || existing.isEmpty) {
    return true;
  }
  return DateTime.parse(incoming).isAfter(DateTime.parse(existing));
}
