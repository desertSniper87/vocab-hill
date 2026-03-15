import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:vocab_hill/src/app.dart';
import 'package:vocab_hill/src/models/dictionary_entry.dart';
import 'package:vocab_hill/src/models/progress_snapshot.dart';
import 'package:vocab_hill/src/models/reference_api_settings.dart';
import 'package:vocab_hill/src/models/sync_settings.dart';
import 'package:vocab_hill/src/models/thesaurus_entry.dart';
import 'package:vocab_hill/src/models/vocab_word.dart';
import 'package:vocab_hill/src/models/word_status.dart';
import 'package:vocab_hill/src/repositories/dictionary_repository.dart';
import 'package:vocab_hill/src/repositories/progress_repository.dart';
import 'package:vocab_hill/src/repositories/vocab_repository.dart';

void main() {
  testWidgets('renders a day board without take test labels', (tester) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 3,
        wordStatusesByDay: <int, Map<String, WordStatus>>{
          2: <String, WordStatus>{'abound': WordStatus.learned},
          3: <String, WordStatus>{'abound': WordStatus.learned},
        },
      ),
    );
    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Day 3 of 3'), findsOneWidget);
    expect(find.text('Group 1'), findsWidgets);
    expect(find.text('Group 2'), findsOneWidget);
    expect(find.text('Group 3'), findsOneWidget);
    expect(find.textContaining('Take Test'), findsNothing);
    expect(find.text('abound'), findsOneWidget);
    await tester.tap(find.text('abound'));
    await tester.pumpAndSettle();

    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('To exist in large quantities.'), findsOneWidget);
    expect(find.text('Previous Days: Learned'), findsOneWidget);
    expect(find.text('Dictionary API'), findsOneWidget);
    expect(find.byKey(const Key('previous-status-abound')), findsOneWidget);

    expect(progressRepository.savedSelectedDays, isEmpty);
  });

  testWidgets('persists status changes', (tester) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 2,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('abound'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learned'));
    await tester.pumpAndSettle();

    expect(progressRepository.savedStatuses[2]?['abound'], WordStatus.learned);
  });

  testWidgets('copies the word when the details title is tapped', (
    tester,
  ) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText =
                (methodCall.arguments as Map<dynamic, dynamic>)['text']
                    as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 1,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('abound'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-word-title')));
    await tester.pump();

    expect(clipboardText, 'abound');
    expect(find.text('Copied "abound".'), findsOneWidget);
  });

  testWidgets('supports keyboard navigation and shortcuts', (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText =
                (methodCall.arguments as Map<dynamic, dynamic>)['text']
                    as String?;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 3,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );
    progressRepository.referenceApiSettings = const ReferenceApiSettings(
      merriamDictionaryKey: 'dict-key',
      merriamThesaurusKey: 'thes-key',
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(clipboardText, 'abound');
    expect(find.text('Copied "abound".'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();

    expect(progressRepository.savedStatuses[3]?['abound'], WordStatus.learned);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('To exist in large quantities.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();

    expect(find.text('Phonetic'), findsOneWidget);
    expect(find.text('/əˈbaʊnd/'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.pumpAndSettle();

    expect(find.text('Pronunciation'), findsOneWidget);
    expect(find.text('əbau̇nd'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Senses: to be present in large numbers'),
      findsOneWidget,
    );
    expect(find.textContaining('Synonyms: teem, overflow'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Senses: to be present in large numbers'),
      findsOneWidget,
    );
    expect(find.textContaining('Synonyms: teem, overflow'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pumpAndSettle();
    expect(
      find.text('No Merriam-Webster thesaurus details found for this word.'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(
      progressRepository.savedStatuses[3]?['adulterate'],
      WordStatus.forgotten,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(
      find.text('No Merriam-Webster thesaurus details found for this word.'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(
      find.text('No Merriam-Webster thesaurus details found for this word.'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Senses: to be present in large numbers'),
      findsNothing,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(
      find.text('No Merriam-Webster thesaurus details found for this word.'),
      findsOneWidget,
    );
  });

  testWidgets('stores sync settings from the header dialog', (tester) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 1,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Sync'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sync-server-field')),
      'http://localhost:8080',
    );
    await tester.enterText(find.byKey(const Key('sync-key-field')), 'demo-key');
    await tester.enterText(
      find.byKey(const Key('merriam-dictionary-key-field')),
      'dict-key',
    );
    await tester.enterText(
      find.byKey(const Key('merriam-thesaurus-key-field')),
      'thes-key',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      progressRepository.savedSyncSettings?.serverUrl,
      'http://localhost:8080',
    );
    expect(progressRepository.savedSyncSettings?.syncKey, 'demo-key');
    expect(
      progressRepository.savedReferenceApiSettings?.merriamDictionaryKey,
      'dict-key',
    );
    expect(
      progressRepository.savedReferenceApiSettings?.merriamThesaurusKey,
      'thes-key',
    );
  });

  testWidgets('exports latest forgotten words as a comma-separated list', (
    tester,
  ) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 3,
        wordStatusesByDay: <int, Map<String, WordStatus>>{
          1: <String, WordStatus>{'abound': WordStatus.forgotten},
          2: <String, WordStatus>{
            'abound': WordStatus.learned,
            'adulterate': WordStatus.forgotten,
          },
          3: <String, WordStatus>{'abate': WordStatus.forgotten},
        },
      ),
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgotten List'));
    await tester.pumpAndSettle();

    expect(find.text('Forgotten Words'), findsOneWidget);
    expect(find.text('abate, adulterate'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('switches to dictionary panel with synonyms and antonyms', (
    tester,
  ) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 1,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );
    progressRepository.referenceApiSettings = const ReferenceApiSettings(
      merriamDictionaryKey: 'dict-key',
      merriamThesaurusKey: 'thes-key',
    );

    await tester.pumpWidget(
      VocabHillApp(
        dictionaryRepository: FakeDictionaryRepository(),
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('abound'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictionary API'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectionArea), findsWidgets);
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.text('Phonetic'), findsOneWidget);
    expect(find.text('/əˈbaʊnd/'), findsOneWidget);
    expect(find.text('Meaning (verb)'), findsOneWidget);
    expect(find.textContaining('to exist in great quantities'), findsOneWidget);
    expect(find.textContaining('Synonyms: teem, overflow'), findsOneWidget);
    expect(find.textContaining('Antonyms: lack'), findsOneWidget);
    expect(find.textContaining('Example: Fish abound'), findsOneWidget);
    expect(find.text('https://example.test/abound'), findsOneWidget);

    await tester.tap(find.text('M-W Dictionary'));
    await tester.pumpAndSettle();

    expect(find.text('Pronunciation'), findsOneWidget);
    expect(find.text('əbau̇nd'), findsOneWidget);
    expect(find.textContaining('Meaning (verb)'), findsOneWidget);
    expect(
      find.textContaining('to be present in large numbers'),
      findsOneWidget,
    );
    expect(
      find.text('https://www.merriam-webster.com/dictionary/abound'),
      findsOneWidget,
    );

    await tester.tap(find.text('M-W Thesaurus'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Senses: to be present in large numbers'),
      findsOneWidget,
    );
    expect(find.textContaining('Synonyms: teem, overflow'), findsOneWidget);
    expect(find.textContaining('Antonyms: lack'), findsOneWidget);
    expect(
      find.text('https://www.merriam-webster.com/thesaurus/abound'),
      findsOneWidget,
    );
  });
}

class FakeVocabRepository implements VocabRepository {
  @override
  Future<List<VocabWord>> loadWords() async {
    return const <VocabWord>[
      VocabWord(
        group: 'Group 1',
        word: 'abound',
        definition: 'To exist in large quantities.',
        bangla: null,
        mnemonic: null,
      ),
      VocabWord(
        group: 'Group 2',
        word: 'adulterate',
        definition: 'To make impure.',
        bangla: null,
        mnemonic: null,
      ),
      VocabWord(
        group: 'Group 3',
        word: 'abate',
        definition: 'To diminish.',
        bangla: null,
        mnemonic: null,
      ),
    ];
  }
}

class FakeDictionaryRepository implements DictionaryRepository {
  @override
  Future<DictionaryEntry?> lookupWord(String word) async {
    if (word == 'abound') {
      return const DictionaryEntry(
        word: 'abound',
        phonetic: '/əˈbaʊnd/',
        meanings: <DictionaryMeaning>[
          DictionaryMeaning(
            partOfSpeech: 'verb',
            definitions: <DictionaryDefinition>[
              DictionaryDefinition(
                text: 'to exist in great quantities',
                example: 'Fish abound in the lake.',
                synonyms: <String>['teem', 'overflow'],
                antonyms: <String>['lack'],
              ),
            ],
            synonyms: <String>['teem', 'overflow'],
            antonyms: <String>['lack'],
          ),
        ],
        sourceUrls: <String>['https://example.test/abound'],
      );
    }
    if (word == 'adulterate') {
      return const DictionaryEntry(
        word: 'adulterate',
        phonetic: '/əˈdʌltəreɪt/',
        meanings: <DictionaryMeaning>[
          DictionaryMeaning(
            partOfSpeech: 'verb',
            definitions: <DictionaryDefinition>[
              DictionaryDefinition(
                text: 'to make impure by adding foreign matter',
                example: null,
                synonyms: <String>['contaminate'],
                antonyms: <String>['purify'],
              ),
            ],
            synonyms: <String>['contaminate'],
            antonyms: <String>['purify'],
          ),
        ],
        sourceUrls: <String>['https://example.test/adulterate'],
      );
    }
    return null;
  }

  @override
  Future<DictionaryEntry?> lookupMerriamDictionary(
    String word,
    String apiKey,
  ) async {
    if (word != 'abound' || apiKey.isEmpty) {
      return null;
    }
    return const DictionaryEntry(
      word: 'abound',
      phonetic: 'əbau̇nd',
      meanings: <DictionaryMeaning>[
        DictionaryMeaning(
          partOfSpeech: 'verb',
          definitions: <DictionaryDefinition>[
            DictionaryDefinition(
              text: 'to be present in large numbers or in great quantity',
              example: null,
              synonyms: <String>[],
              antonyms: <String>[],
            ),
          ],
          synonyms: <String>[],
          antonyms: <String>[],
        ),
      ],
      sourceUrls: <String>['https://www.merriam-webster.com/dictionary/abound'],
    );
  }

  @override
  Future<ThesaurusEntry?> lookupMerriamThesaurus(
    String word,
    String apiKey,
  ) async {
    if (word != 'abound' || apiKey.isEmpty) {
      return null;
    }
    return const ThesaurusEntry(
      word: 'abound',
      partOfSpeech: 'verb',
      senses: <String>['to be present in large numbers'],
      synonyms: <String>['teem', 'overflow'],
      antonyms: <String>['lack'],
      sourceUrls: <String>['https://www.merriam-webster.com/thesaurus/abound'],
    );
  }
}

class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({required this.snapshot});

  final ProgressSnapshot snapshot;
  SyncSettings syncSettings = SyncSettings.empty;
  ReferenceApiSettings referenceApiSettings = ReferenceApiSettings.empty;
  final Map<int, Map<String, WordStatus>> savedStatuses =
      <int, Map<String, WordStatus>>{};
  final List<int> savedSelectedDays = <int>[];
  SyncSettings? savedSyncSettings;
  ReferenceApiSettings? savedReferenceApiSettings;

  @override
  Future<ProgressSnapshot> loadProgress() async => snapshot;

  @override
  Future<void> saveSelectedDay(int selectedDay) async {
    savedSelectedDays.add(selectedDay);
  }

  @override
  Future<void> saveWordStatus(int day, String word, WordStatus status) async {
    final dayStatuses = savedStatuses.putIfAbsent(
      day,
      () => <String, WordStatus>{},
    );
    dayStatuses[word] = status;
  }

  @override
  Future<SyncSettings> loadSyncSettings() async => syncSettings;

  @override
  Future<void> saveSyncSettings(SyncSettings settings) async {
    syncSettings = settings;
    savedSyncSettings = settings;
  }

  @override
  Future<ReferenceApiSettings> loadReferenceApiSettings() async =>
      referenceApiSettings;

  @override
  Future<void> saveReferenceApiSettings(ReferenceApiSettings settings) async {
    referenceApiSettings = settings;
    savedReferenceApiSettings = settings;
  }

  @override
  Future<ProgressSnapshot> syncNow() async => snapshot;
}
