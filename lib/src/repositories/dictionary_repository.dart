import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dictionary_entry.dart';

abstract class DictionaryRepository {
  Future<DictionaryEntry?> lookupWord(String word);
}

class ApiDictionaryRepository implements DictionaryRepository {
  ApiDictionaryRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, Future<DictionaryEntry?>> _cache =
      <String, Future<DictionaryEntry?>>{};

  @override
  Future<DictionaryEntry?> lookupWord(String word) {
    final normalizedWord = word.trim().toLowerCase();
    return _cache.putIfAbsent(normalizedWord, () => _fetchWord(normalizedWord));
  }

  Future<DictionaryEntry?> _fetchWord(String word) async {
    final uri = Uri.parse(
      'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Dictionary lookup failed with ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body);
    if (payload is! List<dynamic> || payload.isEmpty) {
      return null;
    }

    String? phonetic;
    final meanings = <DictionaryMeaning>[];
    final sourceUrls = <String>{};

    for (final entry in payload) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      phonetic ??= _readPhonetic(entry);
      sourceUrls.addAll(_stringList(entry['sourceUrls']));

      final meaningItems = entry['meanings'];
      if (meaningItems is! List<dynamic>) {
        continue;
      }
      for (final meaningItem in meaningItems) {
        if (meaningItem is! Map<String, dynamic>) {
          continue;
        }

        final definitionItems = meaningItem['definitions'];
        if (definitionItems is! List<dynamic>) {
          continue;
        }

        final definitions = <DictionaryDefinition>[];
        for (final definitionItem in definitionItems) {
          if (definitionItem is! Map<String, dynamic>) {
            continue;
          }
          final text = definitionItem['definition'] as String?;
          if (text == null || text.trim().isEmpty) {
            continue;
          }
          definitions.add(
            DictionaryDefinition(
              text: text.trim(),
              example: (definitionItem['example'] as String?)?.trim(),
              synonyms: _stringList(definitionItem['synonyms']),
              antonyms: _stringList(definitionItem['antonyms']),
            ),
          );
          if (definitions.length >= 3) {
            break;
          }
        }

        if (definitions.isEmpty) {
          continue;
        }

        meanings.add(
          DictionaryMeaning(
            partOfSpeech: (meaningItem['partOfSpeech'] as String?)?.trim(),
            definitions: definitions,
            synonyms: _stringList(meaningItem['synonyms']),
            antonyms: _stringList(meaningItem['antonyms']),
          ),
        );
        if (meanings.length >= 4) {
          break;
        }
      }
    }

    if (meanings.isEmpty) {
      return null;
    }

    return DictionaryEntry(
      word: word,
      phonetic: phonetic,
      meanings: meanings,
      sourceUrls: sourceUrls.toList(growable: false),
    );
  }

  String? _readPhonetic(Map<String, dynamic> entry) {
    final primary = entry['phonetic'] as String?;
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }

    final phonetics = entry['phonetics'];
    if (phonetics is! List<dynamic>) {
      return null;
    }
    for (final item in phonetics) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final text = item['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value is! List<dynamic>) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
