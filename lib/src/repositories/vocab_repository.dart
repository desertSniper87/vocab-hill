import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/vocab_word.dart';

abstract class VocabRepository {
  Future<List<VocabWord>> loadWords();
}

class AssetVocabRepository implements VocabRepository {
  const AssetVocabRepository();

  @override
  Future<List<VocabWord>> loadWords() async {
    final rawJson = await rootBundle.loadString('data/final.json');
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final words = decoded['words'] as List<dynamic>;
    return words
        .cast<Map<String, dynamic>>()
        .map(VocabWord.fromJson)
        .toList(growable: false);
  }
}
