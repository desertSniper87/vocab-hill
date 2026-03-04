import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_hill/src/app.dart';
import 'package:vocab_hill/src/models/vocab_word.dart';
import 'package:vocab_hill/src/repositories/vocab_repository.dart';

void main() {
  testWidgets('renders a day board without take test labels', (tester) async {
    await tester.pumpWidget(VocabHillApp(repository: FakeVocabRepository()));

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
