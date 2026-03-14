class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.phonetic,
    required this.meanings,
    required this.sourceUrls,
    this.suggestions = const <String>[],
  });

  final String word;
  final String? phonetic;
  final List<DictionaryMeaning> meanings;
  final List<String> sourceUrls;
  final List<String> suggestions;
}

class DictionaryMeaning {
  const DictionaryMeaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
  });

  final String? partOfSpeech;
  final List<DictionaryDefinition> definitions;
  final List<String> synonyms;
  final List<String> antonyms;
}

class DictionaryDefinition {
  const DictionaryDefinition({
    required this.text,
    required this.example,
    required this.synonyms,
    required this.antonyms,
  });

  final String text;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;
}
