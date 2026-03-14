class ThesaurusEntry {
  const ThesaurusEntry({
    required this.word,
    required this.partOfSpeech,
    required this.senses,
    required this.synonyms,
    required this.antonyms,
    required this.sourceUrls,
    this.suggestions = const <String>[],
  });

  final String word;
  final String? partOfSpeech;
  final List<String> senses;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> sourceUrls;
  final List<String> suggestions;
}
