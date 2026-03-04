import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/progress_snapshot.dart';
import '../models/vocab_word.dart';
import '../models/word_status.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.progressRepository,
  });

  final VocabRepository repository;
  final ProgressRepository progressRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<_BoardData> _boardDataFuture;
  final Map<String, WordStatus> _wordStatuses = <String, WordStatus>{};
  int? _selectedDay;
  bool _restoredProgress = false;

  @override
  void initState() {
    super.initState();
    _boardDataFuture = _loadBoardData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BoardData>(
      future: _boardDataFuture,
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

        final boardData = snapshot.data;
        if (boardData == null || boardData.words.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No words found in the dataset.')),
          );
        }

        final words = boardData.words;
        final groupNames = _sortedGroupNames(words);
        if (!_restoredProgress) {
          _wordStatuses
            ..clear()
            ..addAll(boardData.progress.wordStatuses);
          _selectedDay = boardData.progress.selectedDay;
          _restoredProgress = true;
        }

        final totalDays = groupNames.length;
        final selectedDay = math.min(
          math.max(_selectedDay ?? math.min(6, totalDays), 1),
          totalDays,
        );
        final visibleGroups = groupNames
            .take(selectedDay)
            .toList(growable: false);
        final groupedWords = <String, List<VocabWord>>{
          for (final group in visibleGroups)
            group: words
                .where((word) => word.group == group)
                .toList(growable: false),
        };
        final maxRows = groupedWords.values.fold<int>(
          0,
          (current, groupWords) => math.max(current, groupWords.length),
        );

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                children: <Widget>[
                  _DayHeader(
                    currentDay: selectedDay,
                    totalDays: totalDays,
                    onPrevious: selectedDay > 1
                        ? () => _setSelectedDay(selectedDay - 1)
                        : null,
                    onNext: selectedDay < totalDays
                        ? () => _setSelectedDay(selectedDay + 1)
                        : null,
                    onChanged: (value) {
                      _setSelectedDay(value.round().clamp(1, totalDays));
                    },
                  ),
                  const SizedBox(height: 28),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: visibleGroups
                          .map((group) {
                            final groupWords =
                                groupedWords[group] ?? const <VocabWord>[];
                            return Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: _GroupColumn(
                                title: group,
                                words: groupWords,
                                maxRows: maxRows,
                                statusFor: (word) =>
                                    _wordStatuses[word.word] ??
                                    WordStatus.untouched,
                                onWordTap: _showWordDetails,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_BoardData> _loadBoardData() async {
    final results = await Future.wait<Object>(<Future<Object>>[
      widget.repository.loadWords(),
      widget.progressRepository.loadProgress(),
    ]);
    return _BoardData(
      words: results[0] as List<VocabWord>,
      progress: results[1] as ProgressSnapshot,
    );
  }

  List<String> _sortedGroupNames(List<VocabWord> words) {
    final groups = <String>{for (final word in words) word.group}.toList();
    groups.sort(
      (left, right) => _groupNumber(left).compareTo(_groupNumber(right)),
    );
    return groups;
  }

  int _groupNumber(String groupName) {
    return int.tryParse(groupName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  void _setSelectedDay(int day) {
    setState(() => _selectedDay = day);
    unawaited(widget.progressRepository.saveSelectedDay(day));
  }

  void _setWordStatus(String word, WordStatus status) {
    setState(() {
      if (status == WordStatus.untouched) {
        _wordStatuses.remove(word);
      } else {
        _wordStatuses[word] = status;
      }
    });
    unawaited(widget.progressRepository.saveWordStatus(word, status));
  }

  void _showWordDetails(VocabWord word) {
    final currentStatus = _wordStatuses[word.word] ?? WordStatus.untouched;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F2ED),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  word.word,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _StatusControls(
                  status: currentStatus,
                  onSelected: (status) {
                    _setWordStatus(word.word, status);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 18),
                _DetailSection(
                  title: 'Definition',
                  body: word.definition ?? 'Definition not added yet.',
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  title: 'Bangla',
                  body: word.bangla ?? 'Bangla meaning not added yet.',
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  title: 'Mnemonic',
                  body: word.mnemonic ?? 'Mnemonic not added yet.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardData {
  const _BoardData({required this.words, required this.progress});

  final List<VocabWord> words;
  final ProgressSnapshot progress;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.currentDay,
    required this.totalDays,
    required this.onPrevious,
    required this.onNext,
    required this.onChanged,
  });

  final int currentDay;
  final int totalDays;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            TextButton(onPressed: onPrevious, child: const Text('Previous')),
            Expanded(
              child: Center(
                child: Text(
                  'Day $currentDay of $totalDays',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1F24),
                  ),
                ),
              ),
            ),
            TextButton(onPressed: onNext, child: const Text('Next')),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: const Color(0xFFD3D5DB),
            inactiveTrackColor: const Color(0xFFD3D5DB),
            thumbColor: const Color(0xFF1A73E8),
          ),
          child: Slider(
            value: currentDay.toDouble(),
            min: 1,
            max: totalDays.toDouble(),
            divisions: totalDays - 1,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _GroupColumn extends StatelessWidget {
  const _GroupColumn({
    required this.title,
    required this.words,
    required this.maxRows,
    required this.statusFor,
    required this.onWordTap,
  });

  final String title;
  final List<VocabWord> words;
  final int maxRows;
  final WordStatus Function(VocabWord word) statusFor;
  final void Function(VocabWord word) onWordTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2330),
              ),
            ),
          ),
          for (var index = 0; index < maxRows; index++)
            _WordCell(
              word: index < words.length ? words[index] : null,
              status: index < words.length
                  ? statusFor(words[index])
                  : WordStatus.untouched,
              onTap: index < words.length
                  ? () => onWordTap(words[index])
                  : null,
            ),
        ],
      ),
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({
    required this.word,
    required this.status,
    required this.onTap,
  });

  final VocabWord? word;
  final WordStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = switch (status) {
      WordStatus.learned => const Color(0xFFB8E8C2),
      WordStatus.forgotten => const Color(0xFFF0C5C5),
      WordStatus.untouched => const Color(0xFFF1EEEC),
    };

    final child = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: word == null ? Colors.transparent : background,
        border: Border.all(color: const Color(0xFFDAD4CF), width: 0.6),
      ),
      alignment: Alignment.centerLeft,
      child: word == null
          ? null
          : Text(
              word!.word,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: const Color(0xFF31343D),
              ),
            ),
    );

    if (word == null || onTap == null) {
      return child;
    }

    return InkWell(onTap: onTap, child: child);
  }
}

class _StatusControls extends StatelessWidget {
  const _StatusControls({required this.status, required this.onSelected});

  final WordStatus status;
  final ValueChanged<WordStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Learned'),
          selected: status == WordStatus.learned,
          onSelected: (_) => onSelected(
            status == WordStatus.learned
                ? WordStatus.untouched
                : WordStatus.learned,
          ),
          selectedColor: const Color(0xFFB8E8C2),
        ),
        ChoiceChip(
          label: const Text('Forgotten'),
          selected: status == WordStatus.forgotten,
          onSelected: (_) => onSelected(
            status == WordStatus.forgotten
                ? WordStatus.untouched
                : WordStatus.forgotten,
          ),
          selectedColor: const Color(0xFFF0C5C5),
        ),
        ChoiceChip(
          label: const Text('Clear'),
          selected: status == WordStatus.untouched,
          onSelected: (_) => onSelected(WordStatus.untouched),
        ),
      ],
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
