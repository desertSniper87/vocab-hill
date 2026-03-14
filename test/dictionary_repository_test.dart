import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vocab_hill/src/repositories/dictionary_repository.dart';

void main() {
  test('parses Merriam-Webster dictionary entries', () async {
    final repository = ApiDictionaryRepository(
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          contains('/references/collegiate/json/abound'),
        );
        return http.Response('''
[
  {
    "meta": {"id": "abound"},
    "hwi": {"prs": [{"mw": "abaund"}]},
    "fl": "verb",
    "shortdef": [
      "to be present in large numbers or in great quantity",
      "to be copiously supplied"
    ]
  }
]
''', 200);
      }),
    );

    final entry = await repository.lookupMerriamDictionary(
      'abound',
      'dict-key',
    );

    expect(entry, isNotNull);
    expect(entry!.phonetic, 'abaund');
    expect(entry.meanings.single.partOfSpeech, 'verb');
    expect(
      entry.meanings.single.definitions.first.text,
      'to be present in large numbers or in great quantity',
    );
  });

  test('parses Merriam-Webster thesaurus entries', () async {
    final repository = ApiDictionaryRepository(
      httpClient: MockClient((request) async {
        expect(request.url.path, contains('/references/thesaurus/json/abound'));
        return http.Response('''
[
  {
    "meta": {
      "id": "abound",
      "syns": [["teem", "overflow"]],
      "ants": [["lack"]]
    },
    "fl": "verb",
    "shortdef": ["to be present in large numbers"]
  }
]
''', 200);
      }),
    );

    final entry = await repository.lookupMerriamThesaurus('abound', 'thes-key');

    expect(entry, isNotNull);
    expect(entry!.partOfSpeech, 'verb');
    expect(entry.senses, contains('to be present in large numbers'));
    expect(entry.synonyms, containsAll(<String>['teem', 'overflow']));
    expect(entry.antonyms, contains('lack'));
  });

  test('returns Merriam suggestions when no exact entry exists', () async {
    final repository = ApiDictionaryRepository(
      httpClient: MockClient((request) async {
        return http.Response('["abounded","abounding"]', 200);
      }),
    );

    final entry = await repository.lookupMerriamDictionary('abond', 'dict-key');

    expect(entry, isNotNull);
    expect(entry!.suggestions, <String>['abounded', 'abounding']);
  });
}
