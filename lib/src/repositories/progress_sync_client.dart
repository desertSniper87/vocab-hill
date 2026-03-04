import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_settings.dart';
import '../models/word_status.dart';

class SyncWordProgressRecord {
  const SyncWordProgressRecord({
    required this.day,
    required this.word,
    required this.status,
    required this.updatedAt,
  });

  final int day;
  final String word;
  final WordStatus status;
  final String updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'day': day,
      'word': word,
      'status': status.storageValue,
      'updatedAt': updatedAt,
    };
  }

  factory SyncWordProgressRecord.fromJson(Map<String, dynamic> json) {
    return SyncWordProgressRecord(
      day: json['day'] as int,
      word: json['word'] as String,
      status: WordStatus.fromStorageValue(json['status'] as String?),
      updatedAt: json['updatedAt'] as String,
    );
  }
}

class SyncSnapshotPayload {
  const SyncSnapshotPayload({
    required this.selectedDay,
    required this.selectedDayUpdatedAt,
    required this.statuses,
  });

  final int? selectedDay;
  final String? selectedDayUpdatedAt;
  final List<SyncWordProgressRecord> statuses;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'selectedDay': selectedDay,
      'selectedDayUpdatedAt': selectedDayUpdatedAt,
      'statuses': statuses
          .map((record) => record.toJson())
          .toList(growable: false),
    };
  }

  factory SyncSnapshotPayload.fromJson(Map<String, dynamic> json) {
    final statuses = (json['statuses'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(SyncWordProgressRecord.fromJson)
        .toList(growable: false);

    return SyncSnapshotPayload(
      selectedDay: json['selectedDay'] as int?,
      selectedDayUpdatedAt: json['selectedDayUpdatedAt'] as String?,
      statuses: statuses,
    );
  }
}

class ProgressSyncClient {
  ProgressSyncClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<SyncSnapshotPayload> mergeSnapshot(
    SyncSettings settings,
    SyncSnapshotPayload payload,
  ) async {
    final uri = _baseUri(
      settings.serverUrl,
    ).resolve('/api/progress/${Uri.encodeComponent(settings.syncKey)}/merge');
    final response = await _httpClient.post(
      uri,
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(payload.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Sync failed with ${response.statusCode}: ${response.body}',
      );
    }

    return SyncSnapshotPayload.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Uri _baseUri(String serverUrl) {
    final normalized = serverUrl.endsWith('/') ? serverUrl : '$serverUrl/';
    return Uri.parse(normalized);
  }
}
