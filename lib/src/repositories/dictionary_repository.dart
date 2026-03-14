import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dictionary_entry.dart';
import '../models/thesaurus_entry.dart';

abstract class DictionaryRepository {
  Future<DictionaryEntry?> lookupWord(String word);

  Future<DictionaryEntry?> lookupMerriamDictionary(String word, String apiKey);

  Future<ThesaurusEntry?> lookupMerriamThesaurus(String word, String apiKey);
}

class ApiDictionaryRepository implements DictionaryRepository {
  ApiDictionaryRepository({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, Future<DictionaryEntry?>> _cache =
      <String, Future<DictionaryEntry?>>{};
  final Map<String, Future<DictionaryEntry?>> _merriamDictionaryCache =
      <String, Future<DictionaryEntry?>>{};
  final Map<String, Future<ThesaurusEntry?>> _merriamThesaurusCache =
      <String, Future<ThesaurusEntry?>>{};

  @override
  Future<DictionaryEntry?> lookupWord(String word) {
    final normalizedWord = word.trim().toLowerCase();
    return _cache.putIfAbsent(normalizedWord, () => _fetchWord(normalizedWord));
  }

  @override
  Future<DictionaryEntry?> lookupMerriamDictionary(String word, String apiKey) {
    final normalizedWord = word.trim().toLowerCase();
    final normalizedKey = apiKey.trim();
    return _merriamDictionaryCache.putIfAbsent(
      '$normalizedWord|$normalizedKey',
      () => _fetchMerriamDictionary(normalizedWord, normalizedKey),
    );
  }

  @override
  Future<ThesaurusEntry?> lookupMerriamThesaurus(String word, String apiKey) {
    final normalizedWord = word.trim().toLowerCase();
    final normalizedKey = apiKey.trim();
    return _merriamThesaurusCache.putIfAbsent(
      '$normalizedWord|$normalizedKey',
      () => _fetchMerriamThesaurus(normalizedWord, normalizedKey),
    );
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

  Future<DictionaryEntry?> _fetchMerriamDictionary(
    String word,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://dictionaryapi.com/api/v3/references/collegiate/json/${Uri.encodeComponent(word)}?key=${Uri.encodeQueryComponent(apiKey)}',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Merriam-Webster dictionary lookup failed with ${response.statusCode}.',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! List<dynamic> || payload.isEmpty) {
      return null;
    }
    if (payload.every((item) => item is String)) {
      return DictionaryEntry(
        word: word,
        phonetic: null,
        meanings: const <DictionaryMeaning>[],
        sourceUrls: <String>[_merriamDictionaryUrl(word)],
        suggestions: payload.whereType<String>().toList(growable: false),
      );
    }

    String? phonetic;
    final meanings = <DictionaryMeaning>[];
    for (final item in payload) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      phonetic ??= _readMerriamPhonetic(item);
      final shortDefs = _stringList(item['shortdef']);
      if (shortDefs.isEmpty) {
        continue;
      }
      meanings.add(
        DictionaryMeaning(
          partOfSpeech: (item['fl'] as String?)?.trim(),
          definitions: shortDefs
              .map(
                (definition) => DictionaryDefinition(
                  text: definition,
                  example: null,
                  synonyms: const <String>[],
                  antonyms: const <String>[],
                ),
              )
              .take(3)
              .toList(growable: false),
          synonyms: const <String>[],
          antonyms: const <String>[],
        ),
      );
      if (meanings.length >= 4) {
        break;
      }
    }

    if (meanings.isEmpty) {
      return null;
    }

    return DictionaryEntry(
      word: word,
      phonetic: phonetic,
      meanings: meanings,
      sourceUrls: <String>[_merriamDictionaryUrl(word)],
    );
  }

  Future<ThesaurusEntry?> _fetchMerriamThesaurus(
    String word,
    String apiKey,
  ) async {
    if (apiKey.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      'https://dictionaryapi.com/api/v3/references/thesaurus/json/${Uri.encodeComponent(word)}?key=${Uri.encodeQueryComponent(apiKey)}',
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Merriam-Webster thesaurus lookup failed with ${response.statusCode}.',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! List<dynamic> || payload.isEmpty) {
      return null;
    }
    if (payload.every((item) => item is String)) {
      return ThesaurusEntry(
        word: word,
        partOfSpeech: null,
        senses: const <String>[],
        synonyms: const <String>[],
        antonyms: const <String>[],
        sourceUrls: <String>[_merriamThesaurusUrl(word)],
        suggestions: payload.whereType<String>().toList(growable: false),
      );
    }

    final senses = <String>[];
    final synonyms = <String>{};
    final antonyms = <String>{};
    String? partOfSpeech;

    for (final item in payload) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      partOfSpeech ??= (item['fl'] as String?)?.trim();
      senses.addAll(_stringList(item['shortdef']));
      final meta = item['meta'];
      if (meta is! Map<String, dynamic>) {
        continue;
      }
      synonyms.addAll(_flattenNestedStringLists(meta['syns']));
      antonyms.addAll(_flattenNestedStringLists(meta['ants']));
    }

    if (senses.isEmpty && synonyms.isEmpty && antonyms.isEmpty) {
      return null;
    }

    return ThesaurusEntry(
      word: word,
      partOfSpeech: partOfSpeech,
      senses: senses.take(4).toList(growable: false),
      synonyms: synonyms.take(12).toList(growable: false),
      antonyms: antonyms.take(12).toList(growable: false),
      sourceUrls: <String>[_merriamThesaurusUrl(word)],
    );
  }

  String? _readMerriamPhonetic(Map<String, dynamic> entry) {
    final hwi = entry['hwi'];
    if (hwi is! Map<String, dynamic>) {
      return null;
    }
    final pronunciations = hwi['prs'];
    if (pronunciations is! List<dynamic>) {
      return null;
    }
    for (final item in pronunciations) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final phonetic = item['mw'] as String?;
      if (phonetic != null && phonetic.trim().isNotEmpty) {
        return phonetic.trim();
      }
    }
    return null;
  }

  List<String> _flattenNestedStringLists(Object? value) {
    if (value is! List<dynamic>) {
      return const <String>[];
    }
    final flattened = <String>{};
    for (final group in value) {
      if (group is! List<dynamic>) {
        continue;
      }
      for (final item in group.whereType<String>()) {
        final normalized = item.trim();
        if (normalized.isNotEmpty) {
          flattened.add(normalized);
        }
      }
    }
    return flattened.toList(growable: false);
  }

  String _merriamDictionaryUrl(String word) =>
      'https://www.merriam-webster.com/dictionary/${Uri.encodeComponent(word)}';

  String _merriamThesaurusUrl(String word) =>
      'https://www.merriam-webster.com/thesaurus/${Uri.encodeComponent(word)}';
}
