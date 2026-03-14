class ReferenceApiSettings {
  const ReferenceApiSettings({
    required this.merriamDictionaryKey,
    required this.merriamThesaurusKey,
  });

  static const empty = ReferenceApiSettings(
    merriamDictionaryKey: '',
    merriamThesaurusKey: '',
  );

  final String merriamDictionaryKey;
  final String merriamThesaurusKey;

  bool get hasMerriamDictionaryKey => merriamDictionaryKey.trim().isNotEmpty;

  bool get hasMerriamThesaurusKey => merriamThesaurusKey.trim().isNotEmpty;

  ReferenceApiSettings copyWith({
    String? merriamDictionaryKey,
    String? merriamThesaurusKey,
  }) {
    return ReferenceApiSettings(
      merriamDictionaryKey: merriamDictionaryKey ?? this.merriamDictionaryKey,
      merriamThesaurusKey: merriamThesaurusKey ?? this.merriamThesaurusKey,
    );
  }
}
