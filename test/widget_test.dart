import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_hill/src/app.dart';
import 'package:vocab_hill/src/models/vocab_word.dart';
import 'package:vocab_hill/src/repositories/vocab_repository.dart';

void main() {
  testWidgets('renders Group 1 and moves to Group 2', (tester) async {
    await tester.pumpWidget(VocabHillApp(repository: FakeVocabRepository()));

    await tester.pumpAndSettle();

    expect(find.text('Group 1'), findsWidgets);
    await tester.scrollUntilVisible(find.text('abound'), 400);
    expect(find.text('abound'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Group 2'), -400);
    await tester.tap(find.text('Group 2'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('adulterate'), 400);
    expect(find.text('adulterate'), findsOneWidget);
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
    ];
  }
}
