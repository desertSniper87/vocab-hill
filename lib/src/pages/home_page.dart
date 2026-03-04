import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/vocab_word.dart';
import '../repositories/vocab_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final VocabRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List<VocabWord>> _wordsFuture;
  final Set<String> _learnedWords = <String>{};
  final Set<String> _forgottenWords = <String>{};
  int _selectedGroupIndex = 0;

  @override
  void initState() {
    super.initState();
    _wordsFuture = widget.repository.loadWords();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VocabWord>>(
      future: _wordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load vocabulary data.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final words = snapshot.data ?? const <VocabWord>[];
        final groupNames = _sortedGroupNames(words);
        if (groupNames.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No words found in the dataset.')),
          );
        }

        final selectedIndex = math.min(
          _selectedGroupIndex,
          groupNames.length - 1,
        );
        final selectedGroup = groupNames[selectedIndex];
        final groupWords = words
            .where((word) => word.group == selectedGroup)
            .toList();
        final learnedCount = groupWords
            .where((word) => _learnedWords.contains(word.word))
            .length;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final content = _BodyLayout(
                  header: _Header(
                    selectedGroup: selectedGroup,
                    totalGroups: groupNames.length,
                    learnedCount: learnedCount,
                    wordCount: groupWords.length,
                    completedGroups: selectedIndex,
                    onPrevious: selectedIndex == 0
                        ? null
                        : () => setState(
                            () => _selectedGroupIndex = selectedIndex - 1,
                          ),
                    onNext: selectedIndex == groupNames.length - 1
                        ? null
                        : () => setState(
                            () => _selectedGroupIndex = selectedIndex + 1,
                          ),
                  ),
                  selector: _GroupSelector(
                    groupNames: groupNames,
                    selectedGroup: selectedGroup,
                    onSelected: (group) {
                      final index = groupNames.indexOf(group);
                      if (index >= 0) {
                        setState(() => _selectedGroupIndex = index);
                      }
                    },
                  ),
                  column: _WordColumn(
                    groupWords: groupWords,
                    learnedWords: _learnedWords,
                    forgottenWords: _forgottenWords,
                    onStatusChanged: _updateWordStatus,
                    onWordTap: _showWordDetails,
                  ),
                  summary: _SummaryPanel(
                    groupWords: groupWords,
                    learnedWords: _learnedWords,
                    forgottenWords: _forgottenWords,
                  ),
                  isWide: isWide,
                );

                return DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFFFDF7ED), Color(0xFFF0E2C4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: content,
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<String> _sortedGroupNames(List<VocabWord> words) {
    final seen = <String>{};
    final groups = <String>[];
    for (final word in words) {
      if (seen.add(word.group)) {
        groups.add(word.group);
      }
    }

    groups.sort(
      (left, right) => _groupNumber(left).compareTo(_groupNumber(right)),
    );
    return groups;
  }

  int _groupNumber(String groupName) {
    return int.tryParse(groupName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  void _updateWordStatus(String word, WordStatus status) {
    setState(() {
      switch (status) {
        case WordStatus.learned:
          _forgottenWords.remove(word);
          _learnedWords.add(word);
        case WordStatus.forgotten:
          _learnedWords.remove(word);
          _forgottenWords.add(word);
        case WordStatus.clear:
          _learnedWords.remove(word);
          _forgottenWords.remove(word);
      }
    });
  }

  void _showWordDetails(VocabWord word) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFAF1),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: <Widget>[
              Text(word.word, style: Theme.of(context).textTheme.headlineSmall),
              _DetailSection(
                title: 'Definition',
                body: word.definition ?? 'Definition not added yet.',
              ),
              _DetailSection(
                title: 'Bangla',
                body: word.bangla ?? 'Bangla meaning not added yet.',
              ),
              _DetailSection(
                title: 'Mnemonic',
                body: word.mnemonic ?? 'Mnemonic not added yet.',
              ),
            ],
          ),
        );
      },
    );
  }
}

enum WordStatus { learned, forgotten, clear }

class _BodyLayout extends StatelessWidget {
  const _BodyLayout({
    required this.header,
    required this.selector,
    required this.column,
    required this.summary,
    required this.isWide,
  });

  final Widget header;
  final Widget selector;
  final Widget column;
  final Widget summary;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final mainColumn = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: <Widget>[
        header,
        const SizedBox(height: 20),
        selector,
        const SizedBox(height: 20),
        if (!isWide) ...<Widget>[summary, const SizedBox(height: 20)],
        column,
      ],
    );

    if (!isWide) {
      return mainColumn;
    }

    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: mainColumn),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 20, 28),
            child: summary,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedGroup,
    required this.totalGroups,
    required this.learnedCount,
    required this.wordCount,
    required this.completedGroups,
    required this.onPrevious,
    required this.onNext,
  });

  final String selectedGroup;
  final int totalGroups;
  final int learnedCount;
  final int wordCount;
  final int completedGroups;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F3B2C),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Vocab Hill',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: const Color(0xFFF8EED8),
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onPrevious,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFF8EED8,
                  ).withValues(alpha: 0.15),
                ),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB86A42),
                ),
                child: const Text('Next Group'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'A Flutter-first vocab trainer with 30-word columns, quick status tracking, and room for web now and mobile later.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFF3E6CB)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatPill(label: 'Current', value: selectedGroup),
              _StatPill(label: 'Words', value: '$wordCount'),
              _StatPill(label: 'Learned', value: '$learnedCount'),
              _StatPill(
                label: 'Finished groups',
                value: '$completedGroups / $totalGroups',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE9D9BC)),
            ),
            TextSpan(
              text: value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groupNames,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<String> groupNames;
  final String selectedGroup;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Group Map', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: groupNames
              .map(
                (group) => ChoiceChip(
                  label: Text(group),
                  selected: group == selectedGroup,
                  onSelected: (_) => onSelected(group),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _WordColumn extends StatelessWidget {
  const _WordColumn({
    required this.groupWords,
    required this.learnedWords,
    required this.forgottenWords,
    required this.onStatusChanged,
    required this.onWordTap,
  });

  final List<VocabWord> groupWords;
  final Set<String> learnedWords;
  final Set<String> forgottenWords;
  final void Function(String word, WordStatus status) onStatusChanged;
  final void Function(VocabWord word) onWordTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE6D7BA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Word Column', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tap a word for details. Mark it learned or forgotten as you move through the list.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...groupWords.asMap().entries.map((entry) {
            final index = entry.key;
            final word = entry.value;
            final isLearned = learnedWords.contains(word.word);
            final isForgotten = forgottenWords.contains(word.word);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == groupWords.length - 1 ? 0 : 12,
              ),
              child: _WordTile(
                index: index + 1,
                word: word,
                isLearned: isLearned,
                isForgotten: isForgotten,
                onLearned: () => onStatusChanged(
                  word.word,
                  isLearned ? WordStatus.clear : WordStatus.learned,
                ),
                onForgotten: () => onStatusChanged(
                  word.word,
                  isForgotten ? WordStatus.clear : WordStatus.forgotten,
                ),
                onTap: () => onWordTap(word),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.index,
    required this.word,
    required this.isLearned,
    required this.isForgotten,
    required this.onLearned,
    required this.onForgotten,
    required this.onTap,
  });

  final int index;
  final VocabWord word;
  final bool isLearned;
  final bool isForgotten;
  final VoidCallback onLearned;
  final VoidCallback onForgotten;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F2E7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLearned
                ? const Color(0xFF5C8A64)
                : isForgotten
                ? const Color(0xFFB85C4D)
                : const Color(0xFFE1D5C0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFF1F3B2C),
              foregroundColor: Colors.white,
              child: Text('$index'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    word.word,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.definition ?? 'Tap to open the word details.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: isLearned ? 'Clear learned' : 'Mark learned',
              onPressed: onLearned,
              icon: Icon(
                isLearned ? Icons.check_circle : Icons.check_circle_outline,
              ),
              color: const Color(0xFF2F6A3F),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: isForgotten ? 'Clear forgotten' : 'Mark forgotten',
              onPressed: onForgotten,
              icon: Icon(isForgotten ? Icons.refresh : Icons.refresh_outlined),
              color: const Color(0xFF9A433C),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.groupWords,
    required this.learnedWords,
    required this.forgottenWords,
  });

  final List<VocabWord> groupWords;
  final Set<String> learnedWords;
  final Set<String> forgottenWords;

  @override
  Widget build(BuildContext context) {
    final learned = groupWords
        .where((word) => learnedWords.contains(word.word))
        .length;
    final forgotten = groupWords
        .where((word) => forgottenWords.contains(word.word))
        .length;
    final untouched = groupWords.length - learned - forgotten;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFE9D7B1),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Session Summary',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Learned', value: '$learned'),
          _SummaryRow(label: 'Forgotten', value: '$forgotten'),
          _SummaryRow(label: 'Untouched', value: '$untouched'),
          const SizedBox(height: 18),
          Text(
            'This starter project keeps progress in memory only. The next step is persisting learned and forgotten states into SQLite.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
