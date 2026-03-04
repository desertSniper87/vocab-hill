import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:vocab_hill/src/app.dart';
import 'package:vocab_hill/src/models/progress_snapshot.dart';
import 'package:vocab_hill/src/models/vocab_word.dart';
import 'package:vocab_hill/src/models/word_status.dart';
import 'package:vocab_hill/src/repositories/progress_repository.dart';
import 'package:vocab_hill/src/repositories/vocab_repository.dart';

void main() {
  testWidgets('renders a day board without take test labels', (tester) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 3,
        wordStatusesByDay: <int, Map<String, WordStatus>>{
          3: <String, WordStatus>{'abound': WordStatus.learned},
        },
      ),
    );
    await tester.pumpWidget(
      VocabHillApp(
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

  testWidgets('supports keyboard navigation and shortcuts', (tester) async {
    final progressRepository = FakeProgressRepository(
      snapshot: const ProgressSnapshot(
        selectedDay: 3,
        wordStatusesByDay: <int, Map<String, WordStatus>>{},
      ),
    );

    await tester.pumpWidget(
      VocabHillApp(
        repository: FakeVocabRepository(),
        progressRepository: progressRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();

    expect(progressRepository.savedStatuses[3]?['abound'], WordStatus.learned);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('To exist in large quantities.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(
      progressRepository.savedStatuses[3]?['adulterate'],
      WordStatus.forgotten,
    );
    expect(find.text('To make impure.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pumpAndSettle();
    expect(find.text('Definition'), findsNothing);
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

class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({required this.snapshot});

  final ProgressSnapshot snapshot;
  final Map<int, Map<String, WordStatus>> savedStatuses =
      <int, Map<String, WordStatus>>{};
  final List<int> savedSelectedDays = <int>[];

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
}
