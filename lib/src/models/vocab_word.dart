class VocabWord {
  const VocabWord({
    required this.group,
    required this.word,
    required this.definition,
    required this.bangla,
    required this.mnemonic,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    return VocabWord(
      group: json['group'] as String,
      word: json['word'] as String,
      definition: json['definition'] as String?,
      bangla: json['bangla'] as String?,
      mnemonic: json['mnemonic'] as String?,
    );
  }

  final String group;
  final String word;
  final String? definition;
  final String? bangla;
  final String? mnemonic;
}
