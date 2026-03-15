import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dictionary_entry.dart';
import '../models/progress_snapshot.dart';
import '../models/reference_api_settings.dart';
import '../models/sync_settings.dart';
import '../models/thesaurus_entry.dart';
import '../models/vocab_word.dart';
import '../models/word_status.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.repository,
    required this.dictionaryRepository,
    required this.progressRepository,
  });

  final VocabRepository repository;
  final DictionaryRepository dictionaryRepository;
  final ProgressRepository progressRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<_BoardData> _boardDataFuture;
  final Map<int, Map<String, WordStatus>> _wordStatusesByDay =
      <int, Map<String, WordStatus>>{};
  final FocusNode _boardFocusNode = FocusNode(debugLabel: 'boardFocus');
  int? _selectedDay;
  SyncSettings _syncSettings = SyncSettings.empty;
  int _selectedColumnIndex = 0;
  int _selectedRowIndex = 0;
  bool _detailsOpen = false;
  _DetailsView _selectedDetailsView = _DetailsView.studyInfo;
  bool _restoredProgress = false;
  ReferenceApiSettings _referenceApiSettings = ReferenceApiSettings.empty;

  @override
  void initState() {
    super.initState();
    _boardDataFuture = _loadBoardData();
  }

  @override
  void dispose() {
    _boardFocusNode.dispose();
    super.dispose();
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
          _wordStatusesByDay
            ..clear()
            ..addAll(boardData.progress.wordStatusesByDay);
          _selectedDay = boardData.progress.selectedDay;
          _syncSettings = boardData.syncSettings;
          _referenceApiSettings = boardData.referenceApiSettings;
          _restoredProgress = true;
        }

        final totalDays = groupNames.length;
        final selectedDay = math.min(
          math.max(_selectedDay ?? math.min(6, totalDays), 1),
          totalDays,
        );
        final currentDayStatuses =
            _wordStatusesByDay[selectedDay] ?? const <String, WordStatus>{};
        final visibleGroups = groupNames
            .take(selectedDay)
            .toList(growable: false);
        final groupedWords = <String, List<VocabWord>>{
          for (final group in visibleGroups)
            group: words
                .where((word) => word.group == group)
                .toList(growable: false),
        };
        _clampSelection(visibleGroups, groupedWords);
        final selectedWord = _selectedWord(visibleGroups, groupedWords);
        final maxRows = groupedWords.values.fold<int>(
          0,
          (current, groupWords) => math.max(current, groupWords.length),
        );

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
            child: SafeArea(
              child: Focus(
                autofocus: true,
                focusNode: _boardFocusNode,
                onKeyEvent: (node, event) =>
                    _handleBoardKeyEvent(event, visibleGroups, groupedWords),
                child: Stack(
                  children: <Widget>[
                    ListView(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        28,
                        28,
                        _detailsOpen && selectedWord != null ? 340 : 40,
                      ),
                      children: <Widget>[
                        _DayHeader(
                          currentDay: selectedDay,
                          totalDays: totalDays,
                          syncSettings: _syncSettings,
                          onForgottenPressed: _openForgottenWordsDialog,
                          onPrevious: selectedDay > 1
                              ? () => _setSelectedDay(selectedDay - 1)
                              : null,
                          onNext: selectedDay < totalDays
                              ? () => _setSelectedDay(selectedDay + 1)
                              : null,
                          onChanged: (value) {
                            _setSelectedDay(value.round().clamp(1, totalDays));
                          },
                          onSyncPressed: _openSyncSettingsDialog,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: visibleGroups
                                .asMap()
                                .entries
                                .map((entry) {
                                  final groupIndex = entry.key;
                                  final group = entry.value;
                                  final groupWords =
                                      groupedWords[group] ??
                                      const <VocabWord>[];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: _GroupColumn(
                                      title: group,
                                      words: groupWords,
                                      maxRows: maxRows,
                                      selectedRowIndex:
                                          _selectedColumnIndex == groupIndex
                                          ? _selectedRowIndex
                                          : null,
                                      statusFor: (word) =>
                                          currentDayStatuses[word.word] ??
                                          WordStatus.untouched,
                                      previousStatusFor: (word) =>
                                          _latestPreviousStatus(
                                            selectedDay,
                                            word.word,
                                          ),
                                      onWordTap: (word, rowIndex) {
                                        setState(() {
                                          _selectedColumnIndex = groupIndex;
                                          _selectedRowIndex = rowIndex;
                                          _detailsOpen = true;
                                          _selectedDetailsView =
                                              _DetailsView.studyInfo;
                                        });
                                        _boardFocusNode.requestFocus();
                                      },
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ),
                      ],
                    ),
                    if (_detailsOpen && selectedWord != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(
                                0xCC1C1D22,
                              ).withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                    if (_detailsOpen && selectedWord != null)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _DetailsPanel(
                            word: selectedWord,
                            dictionaryRepository: widget.dictionaryRepository,
                            status:
                                currentDayStatuses[selectedWord.word] ??
                                WordStatus.untouched,
                            previousStatus: _latestPreviousStatus(
                              selectedDay,
                              selectedWord.word,
                            ),
                            referenceApiSettings: _referenceApiSettings,
                            selectedView: _selectedDetailsView,
                            onClose: () {
                              setState(() => _detailsOpen = false);
                              _boardFocusNode.requestFocus();
                            },
                            onSelected: (status) {
                              _setWordStatus(
                                selectedDay,
                                selectedWord.word,
                                status,
                              );
                              _boardFocusNode.requestFocus();
                            },
                            onViewSelected: (view) {
                              setState(() => _selectedDetailsView = view);
                              _boardFocusNode.requestFocus();
                            },
                          ),
                        ),
                      ),
                  ],
                ),
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
      widget.progressRepository.loadSyncSettings(),
      widget.progressRepository.loadReferenceApiSettings(),
    ]);
    return _BoardData(
      words: results[0] as List<VocabWord>,
      progress: results[1] as ProgressSnapshot,
      syncSettings: results[2] as SyncSettings,
      referenceApiSettings: results[3] as ReferenceApiSettings,
    );
  }

  Future<void> _openSyncSettingsDialog() async {
    final settings = await showDialog<_SettingsDialogResult>(
      context: context,
      builder: (context) => _SyncSettingsDialog(
        initialSyncSettings: _syncSettings,
        initialReferenceApiSettings: _referenceApiSettings,
      ),
    );
    if (settings == null || !mounted) {
      return;
    }

    await widget.progressRepository.saveSyncSettings(settings.syncSettings);
    await widget.progressRepository.saveReferenceApiSettings(
      settings.referenceApiSettings,
    );
    setState(() {
      _syncSettings = settings.syncSettings;
      _referenceApiSettings = settings.referenceApiSettings;
    });
    if (!settings.syncSettings.isConfigured) {
      return;
    }

    try {
      final progress = await widget.progressRepository.syncNow();
      if (!mounted) {
        return;
      }
      setState(() {
        _wordStatusesByDay
          ..clear()
          ..addAll(progress.wordStatusesByDay);
        _selectedDay = progress.selectedDay ?? _selectedDay;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync completed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    }
  }

  Future<void> _openForgottenWordsDialog() async {
    final forgottenWords = _latestForgottenWords();
    final exportText = forgottenWords.join(', ');

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgotten Words'),
          content: SizedBox(
            width: 540,
            child: forgottenWords.isEmpty
                ? const Text('No forgotten words in your progress yet.')
                : SelectableText(exportText),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (forgottenWords.isNotEmpty)
              FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: exportText));
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Forgotten words copied to clipboard.'),
                    ),
                  );
                },
                child: const Text('Copy'),
              ),
          ],
        );
      },
    );
  }

  List<String> _latestForgottenWords() {
    final latestByWord = <String, ({int day, WordStatus status})>{};
    for (final entry in _wordStatusesByDay.entries) {
      final day = entry.key;
      for (final statusEntry in entry.value.entries) {
        final current = latestByWord[statusEntry.key];
        if (current == null || day > current.day) {
          latestByWord[statusEntry.key] = (day: day, status: statusEntry.value);
        }
      }
    }

    final forgottenWords = latestByWord.entries
        .where((entry) => entry.value.status == WordStatus.forgotten)
        .map((entry) => entry.key)
        .toList(growable: false);
    forgottenWords.sort();
    return forgottenWords;
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

  void _clampSelection(
    List<String> visibleGroups,
    Map<String, List<VocabWord>> groupedWords,
  ) {
    if (visibleGroups.isEmpty) {
      _selectedColumnIndex = 0;
      _selectedRowIndex = 0;
      return;
    }

    _selectedColumnIndex = _selectedColumnIndex.clamp(
      0,
      visibleGroups.length - 1,
    );
    final currentWords =
        groupedWords[visibleGroups[_selectedColumnIndex]] ??
        const <VocabWord>[];
    if (currentWords.isEmpty) {
      _selectedRowIndex = 0;
      return;
    }

    _selectedRowIndex = _selectedRowIndex.clamp(0, currentWords.length - 1);
  }

  void _setSelectedDay(int day) {
    setState(() => _selectedDay = day);
    unawaited(widget.progressRepository.saveSelectedDay(day));
  }

  void _setWordStatus(int day, String word, WordStatus status) {
    setState(() {
      final dayStatuses = _wordStatusesByDay.putIfAbsent(
        day,
        () => <String, WordStatus>{},
      );
      if (status == WordStatus.untouched) {
        dayStatuses.remove(word);
        if (dayStatuses.isEmpty) {
          _wordStatusesByDay.remove(day);
        }
      } else {
        dayStatuses[word] = status;
      }
    });
    unawaited(widget.progressRepository.saveWordStatus(day, word, status));
  }

  WordStatus? _latestPreviousStatus(int selectedDay, String word) {
    for (var day = selectedDay - 1; day >= 1; day--) {
      final dayStatuses = _wordStatusesByDay[day];
      final status = dayStatuses?[word];
      if (status != null && status != WordStatus.untouched) {
        return status;
      }
    }
    return null;
  }

  KeyEventResult _handleBoardKeyEvent(
    KeyEvent event,
    List<String> visibleGroups,
    Map<String, List<VocabWord>> groupedWords,
  ) {
    if (event is! KeyDownEvent || visibleGroups.isEmpty) {
      return KeyEventResult.ignored;
    }

    final selectedWord = _selectedWord(visibleGroups, groupedWords);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyH) {
      setState(() {
        _selectedColumnIndex = math.max(0, _selectedColumnIndex - 1);
        _clampSelection(visibleGroups, groupedWords);
        if (_detailsOpen) {
          _selectedDetailsView = _DetailsView.studyInfo;
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyL) {
      setState(() {
        _selectedColumnIndex = math.min(
          visibleGroups.length - 1,
          _selectedColumnIndex + 1,
        );
        _clampSelection(visibleGroups, groupedWords);
        if (_detailsOpen) {
          _selectedDetailsView = _DetailsView.studyInfo;
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      setState(() {
        _selectedRowIndex = math.max(0, _selectedRowIndex - 1);
        _clampSelection(visibleGroups, groupedWords);
        if (_detailsOpen) {
          _selectedDetailsView = _DetailsView.studyInfo;
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      final currentWords =
          groupedWords[visibleGroups[_selectedColumnIndex]] ??
          const <VocabWord>[];
      setState(() {
        _selectedRowIndex = math.min(
          math.max(currentWords.length - 1, 0),
          _selectedRowIndex + 1,
        );
        _clampSelection(visibleGroups, groupedWords);
        if (_detailsOpen) {
          _selectedDetailsView = _DetailsView.studyInfo;
        }
      });
      return KeyEventResult.handled;
    }
    if (selectedWord == null) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyD) {
      setState(() {
        _detailsOpen = !_detailsOpen;
        if (_detailsOpen) {
          _selectedDetailsView = _DetailsView.studyInfo;
        }
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyT) {
      setState(() {
        _detailsOpen = true;
        _selectedDetailsView = _DetailsView.dictionaryApi;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyY) {
      setState(() {
        _detailsOpen = true;
        _selectedDetailsView = _DetailsView.merriamDictionary;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyU) {
      setState(() {
        _detailsOpen = true;
        _selectedDetailsView = _DetailsView.merriamThesaurus;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyG) {
      _setWordStatus(
        _selectedDay ?? visibleGroups.length,
        selectedWord.word,
        WordStatus.learned,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _setWordStatus(
        _selectedDay ?? visibleGroups.length,
        selectedWord.word,
        WordStatus.forgotten,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  VocabWord? _selectedWord(
    List<String> visibleGroups,
    Map<String, List<VocabWord>> groupedWords,
  ) {
    if (visibleGroups.isEmpty) {
      return null;
    }

    final currentWords =
        groupedWords[visibleGroups[_selectedColumnIndex]] ??
        const <VocabWord>[];
    if (currentWords.isEmpty) {
      return null;
    }

    return currentWords[_selectedRowIndex];
  }
}

class _BoardData {
  const _BoardData({
    required this.words,
    required this.progress,
    required this.syncSettings,
    required this.referenceApiSettings,
  });

  final List<VocabWord> words;
  final ProgressSnapshot progress;
  final SyncSettings syncSettings;
  final ReferenceApiSettings referenceApiSettings;
}

class _SettingsDialogResult {
  const _SettingsDialogResult({
    required this.syncSettings,
    required this.referenceApiSettings,
  });

  final SyncSettings syncSettings;
  final ReferenceApiSettings referenceApiSettings;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.currentDay,
    required this.totalDays,
    required this.syncSettings,
    required this.onForgottenPressed,
    required this.onPrevious,
    required this.onNext,
    required this.onChanged,
    required this.onSyncPressed,
  });

  final int currentDay;
  final int totalDays;
  final SyncSettings syncSettings;
  final VoidCallback onForgottenPressed;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<double> onChanged;
  final VoidCallback onSyncPressed;

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onForgottenPressed,
                  child: const Text('Forgotten List'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSyncPressed,
                  icon: Icon(
                    syncSettings.isConfigured ? Icons.cloud_done : Icons.cloud,
                    size: 18,
                  ),
                  label: Text(
                    syncSettings.isConfigured ? 'Sync Ready' : 'Set Sync',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onNext, child: const Text('Next')),
              ],
            ),
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

class _SyncSettingsDialog extends StatefulWidget {
  const _SyncSettingsDialog({
    required this.initialSyncSettings,
    required this.initialReferenceApiSettings,
  });

  final SyncSettings initialSyncSettings;
  final ReferenceApiSettings initialReferenceApiSettings;

  @override
  State<_SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends State<_SyncSettingsDialog> {
  late final TextEditingController _serverController = TextEditingController(
    text: widget.initialSyncSettings.serverUrl,
  );
  late final TextEditingController _keyController = TextEditingController(
    text: widget.initialSyncSettings.syncKey,
  );
  late final TextEditingController _merriamDictionaryController =
      TextEditingController(
        text: widget.initialReferenceApiSettings.merriamDictionaryKey,
      );
  late final TextEditingController _merriamThesaurusController =
      TextEditingController(
        text: widget.initialReferenceApiSettings.merriamThesaurusKey,
      );

  @override
  void dispose() {
    _serverController.dispose();
    _keyController.dispose();
    _merriamDictionaryController.dispose();
    _merriamThesaurusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Settings'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Use the same sync key in multiple browsers to share progress.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('sync-server-field'),
                controller: _serverController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://localhost:8080',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sync-key-field'),
                controller: _keyController,
                decoration: const InputDecoration(
                  labelText: 'Sync key',
                  hintText: 'your-shared-progress-key',
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Merriam-Webster API keys stay in local SQLite settings and are not embedded into the web bundle.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('merriam-dictionary-key-field'),
                controller: _merriamDictionaryController,
                decoration: const InputDecoration(
                  labelText: 'Merriam Dictionary key',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('merriam-thesaurus-key-field'),
                controller: _merriamThesaurusController,
                decoration: const InputDecoration(
                  labelText: 'Merriam Thesaurus key',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _SettingsDialogResult(
                syncSettings: SyncSettings(
                  serverUrl: _serverController.text.trim().isEmpty
                      ? SyncSettings.defaultServerUrl
                      : _serverController.text.trim(),
                  syncKey: _keyController.text.trim(),
                ),
                referenceApiSettings: ReferenceApiSettings(
                  merriamDictionaryKey: _merriamDictionaryController.text
                      .trim(),
                  merriamThesaurusKey: _merriamThesaurusController.text.trim(),
                ),
              ),
            );
          },
          child: const Text('Save'),
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
    required this.selectedRowIndex,
    required this.statusFor,
    required this.previousStatusFor,
    required this.onWordTap,
  });

  final String title;
  final List<VocabWord> words;
  final int maxRows;
  final int? selectedRowIndex;
  final WordStatus Function(VocabWord word) statusFor;
  final WordStatus? Function(VocabWord word) previousStatusFor;
  final void Function(VocabWord word, int rowIndex) onWordTap;

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
              isSelected: selectedRowIndex == index,
              previousStatus: index < words.length
                  ? previousStatusFor(words[index])
                  : null,
              status: index < words.length
                  ? statusFor(words[index])
                  : WordStatus.untouched,
              onTap: index < words.length
                  ? () => onWordTap(words[index], index)
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
    required this.isSelected,
    required this.previousStatus,
    required this.status,
    required this.onTap,
  });

  final VocabWord? word;
  final bool isSelected;
  final WordStatus? previousStatus;
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
        border: Border.all(
          color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFDAD4CF),
          width: isSelected ? 2 : 0.6,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: word == null
          ? null
          : Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    word!.word,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      color: const Color(0xFF31343D),
                    ),
                  ),
                ),
                if (previousStatus != null)
                  Container(
                    key: Key('previous-status-${word!.word}'),
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: previousStatus == WordStatus.learned
                          ? const Color(0xFF2E8B57)
                          : const Color(0xFFC24B43),
                    ),
                  ),
              ],
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

class _DetailsPanel extends StatefulWidget {
  const _DetailsPanel({
    required this.word,
    required this.dictionaryRepository,
    required this.status,
    required this.previousStatus,
    required this.referenceApiSettings,
    required this.selectedView,
    required this.onClose,
    required this.onSelected,
    required this.onViewSelected,
  });

  final VocabWord word;
  final DictionaryRepository dictionaryRepository;
  final WordStatus status;
  final WordStatus? previousStatus;
  final ReferenceApiSettings referenceApiSettings;
  final _DetailsView selectedView;
  final VoidCallback onClose;
  final ValueChanged<WordStatus> onSelected;
  final ValueChanged<_DetailsView> onViewSelected;

  @override
  State<_DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<_DetailsPanel> {
  @override
  Widget build(BuildContext context) {
    final dictionaryFuture = widget.dictionaryRepository.lookupWord(
      widget.word.word,
    );
    final merriamDictionaryFuture =
        widget.referenceApiSettings.hasMerriamDictionaryKey
        ? widget.dictionaryRepository.lookupMerriamDictionary(
            widget.word.word,
            widget.referenceApiSettings.merriamDictionaryKey,
          )
        : null;
    final merriamThesaurusFuture =
        widget.referenceApiSettings.hasMerriamThesaurusKey
        ? widget.dictionaryRepository.lookupMerriamThesaurus(
            widget.word.word,
            widget.referenceApiSettings.merriamThesaurusKey,
          )
        : null;
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F2ED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1D8CC)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              spreadRadius: 3,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 860,
            minHeight: viewportHeight - 120,
            maxHeight: viewportHeight - 40,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.word.word,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onClose,
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DetailsToolbar(
                    status: widget.status,
                    previousStatus: widget.previousStatus,
                    onSelected: widget.onSelected,
                    selectedView: widget.selectedView,
                    onViewSelected: widget.onViewSelected,
                  ),
                  const SizedBox(height: 18),
                  SelectionArea(
                    child: _DetailsBody(
                      word: widget.word,
                      dictionaryFuture: dictionaryFuture,
                      merriamDictionaryFuture: merriamDictionaryFuture,
                      merriamThesaurusFuture: merriamThesaurusFuture,
                      referenceApiSettings: widget.referenceApiSettings,
                      previousStatus: widget.previousStatus,
                      selectedView: widget.selectedView,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DetailsView {
  studyInfo,
  dictionaryApi,
  merriamDictionary,
  merriamThesaurus,
}

class _DetailsToolbar extends StatelessWidget {
  const _DetailsToolbar({
    required this.status,
    required this.previousStatus,
    required this.onSelected,
    required this.selectedView,
    required this.onViewSelected,
  });

  final WordStatus status;
  final WordStatus? previousStatus;
  final ValueChanged<WordStatus> onSelected;
  final _DetailsView selectedView;
  final ValueChanged<_DetailsView> onViewSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StatusControls(status: status, onSelected: onSelected),
        const SizedBox(height: 10),
        _PreviousDaysBadge(previousStatus: previousStatus),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Study Info'),
              selected: selectedView == _DetailsView.studyInfo,
              onSelected: (_) => onViewSelected(_DetailsView.studyInfo),
            ),
            ChoiceChip(
              label: const Text('Dictionary API'),
              selected: selectedView == _DetailsView.dictionaryApi,
              onSelected: (_) => onViewSelected(_DetailsView.dictionaryApi),
            ),
            ChoiceChip(
              label: const Text('M-W Dictionary'),
              selected: selectedView == _DetailsView.merriamDictionary,
              onSelected: (_) => onViewSelected(_DetailsView.merriamDictionary),
            ),
            ChoiceChip(
              label: const Text('M-W Thesaurus'),
              selected: selectedView == _DetailsView.merriamThesaurus,
              onSelected: (_) => onViewSelected(_DetailsView.merriamThesaurus),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.word,
    required this.dictionaryFuture,
    required this.merriamDictionaryFuture,
    required this.merriamThesaurusFuture,
    required this.referenceApiSettings,
    required this.previousStatus,
    this.selectedView = _DetailsView.studyInfo,
  });

  final VocabWord word;
  final Future<DictionaryEntry?> dictionaryFuture;
  final Future<DictionaryEntry?>? merriamDictionaryFuture;
  final Future<ThesaurusEntry?>? merriamThesaurusFuture;
  final ReferenceApiSettings referenceApiSettings;
  final WordStatus? previousStatus;
  final _DetailsView selectedView;

  @override
  Widget build(BuildContext context) {
    if (selectedView == _DetailsView.dictionaryApi) {
      return _DictionaryApiPanel(dictionaryFuture: dictionaryFuture);
    }
    if (selectedView == _DetailsView.merriamDictionary) {
      return _MerriamDictionaryPanel(
        dictionaryFuture: merriamDictionaryFuture,
        hasApiKey: referenceApiSettings.hasMerriamDictionaryKey,
      );
    }
    if (selectedView == _DetailsView.merriamThesaurus) {
      return _MerriamThesaurusPanel(
        thesaurusFuture: merriamThesaurusFuture,
        hasApiKey: referenceApiSettings.hasMerriamThesaurusKey,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
    );
  }
}

class _PreviousDaysBadge extends StatelessWidget {
  const _PreviousDaysBadge({required this.previousStatus});

  final WordStatus? previousStatus;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (previousStatus) {
      WordStatus.learned => (
        'Previous Days: Learned',
        const Color(0xFFD9EEDC),
        const Color(0xFF236A3E),
      ),
      WordStatus.forgotten => (
        'Previous Days: Forgotten',
        const Color(0xFFF3D8D8),
        const Color(0xFF9B3E39),
      ),
      WordStatus.untouched || null => (
        'Previous Days: No mark yet',
        const Color(0xFFEAE4DA),
        const Color(0xFF6B6154),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DictionaryApiPanel extends StatelessWidget {
  const _DictionaryApiPanel({required this.dictionaryFuture});

  final Future<DictionaryEntry?> dictionaryFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DictionaryEntry?>(
      future: dictionaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailSection(
            title: 'Dictionary API',
            body: 'Loading dictionaryapi.dev details...',
          );
        }

        if (snapshot.hasError) {
          return const _DetailSection(
            title: 'Dictionary API',
            body: 'Could not load dictionaryapi.dev details.',
          );
        }

        final entry = snapshot.data;
        if (entry == null || entry.meanings.isEmpty) {
          return const _DetailSection(
            title: 'Dictionary API',
            body: 'No dictionaryapi.dev details found for this word.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
              _DetailSection(title: 'Phonetic', body: entry.phonetic!),
            if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
              const SizedBox(height: 14),
            for (
              var index = 0;
              index < entry.meanings.length;
              index++
            ) ...<Widget>[
              _DictionaryMeaningSection(meaning: entry.meanings[index]),
              if (index < entry.meanings.length - 1) const SizedBox(height: 18),
            ],
            if (entry.sourceUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _SourceLinkSection(title: 'Sources', urls: entry.sourceUrls),
            ],
          ],
        );
      },
    );
  }
}

class _MerriamDictionaryPanel extends StatelessWidget {
  const _MerriamDictionaryPanel({
    required this.dictionaryFuture,
    required this.hasApiKey,
  });

  final Future<DictionaryEntry?>? dictionaryFuture;
  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    if (!hasApiKey || dictionaryFuture == null) {
      return const _DetailSection(
        title: 'Merriam-Webster Dictionary',
        body: 'Add your Merriam Dictionary key in Settings to use this tab.',
      );
    }

    return FutureBuilder<DictionaryEntry?>(
      future: dictionaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailSection(
            title: 'Merriam-Webster Dictionary',
            body: 'Loading Merriam-Webster dictionary details...',
          );
        }

        if (snapshot.hasError) {
          return const _DetailSection(
            title: 'Merriam-Webster Dictionary',
            body: 'Could not load Merriam-Webster dictionary details.',
          );
        }

        final entry = snapshot.data;
        if (entry == null) {
          return const _DetailSection(
            title: 'Merriam-Webster Dictionary',
            body: 'No Merriam-Webster dictionary details found for this word.',
          );
        }

        if (entry.suggestions.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _DetailSection(
                title: 'Merriam-Webster Dictionary',
                body: 'No exact entry was found. Try one of these suggestions.',
              ),
              const SizedBox(height: 10),
              _InlineMetadataSection(
                title: 'Suggestions',
                entries: entry.suggestions,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
              _DetailSection(title: 'Pronunciation', body: entry.phonetic!),
            if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
              const SizedBox(height: 14),
            for (
              var index = 0;
              index < entry.meanings.length;
              index++
            ) ...<Widget>[
              _DictionaryMeaningSection(meaning: entry.meanings[index]),
              if (index < entry.meanings.length - 1) const SizedBox(height: 18),
            ],
            if (entry.sourceUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _SourceLinkSection(title: 'Sources', urls: entry.sourceUrls),
            ],
          ],
        );
      },
    );
  }
}

class _MerriamThesaurusPanel extends StatelessWidget {
  const _MerriamThesaurusPanel({
    required this.thesaurusFuture,
    required this.hasApiKey,
  });

  final Future<ThesaurusEntry?>? thesaurusFuture;
  final bool hasApiKey;

  @override
  Widget build(BuildContext context) {
    if (!hasApiKey || thesaurusFuture == null) {
      return const _DetailSection(
        title: 'Merriam-Webster Thesaurus',
        body: 'Add your Merriam Thesaurus key in Settings to use this tab.',
      );
    }

    return FutureBuilder<ThesaurusEntry?>(
      future: thesaurusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DetailSection(
            title: 'Merriam-Webster Thesaurus',
            body: 'Loading Merriam-Webster thesaurus details...',
          );
        }

        if (snapshot.hasError) {
          return const _DetailSection(
            title: 'Merriam-Webster Thesaurus',
            body: 'Could not load Merriam-Webster thesaurus details.',
          );
        }

        final entry = snapshot.data;
        if (entry == null) {
          return const _DetailSection(
            title: 'Merriam-Webster Thesaurus',
            body: 'No Merriam-Webster thesaurus details found for this word.',
          );
        }

        if (entry.suggestions.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _DetailSection(
                title: 'Merriam-Webster Thesaurus',
                body: 'No exact entry was found. Try one of these suggestions.',
              ),
              const SizedBox(height: 10),
              _InlineMetadataSection(
                title: 'Suggestions',
                entries: entry.suggestions,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (entry.partOfSpeech != null && entry.partOfSpeech!.isNotEmpty)
              _DetailSection(
                title: 'Part of speech',
                body: entry.partOfSpeech!,
              ),
            if (entry.partOfSpeech != null && entry.partOfSpeech!.isNotEmpty)
              const SizedBox(height: 14),
            if (entry.senses.isNotEmpty)
              _InlineMetadataSection(title: 'Senses', entries: entry.senses),
            if (entry.senses.isNotEmpty) const SizedBox(height: 14),
            if (entry.synonyms.isNotEmpty)
              _InlineMetadataSection(
                title: 'Synonyms',
                entries: entry.synonyms,
              ),
            if (entry.synonyms.isNotEmpty && entry.antonyms.isNotEmpty)
              const SizedBox(height: 14),
            if (entry.antonyms.isNotEmpty)
              _InlineMetadataSection(
                title: 'Antonyms',
                entries: entry.antonyms,
              ),
            if (entry.sourceUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _SourceLinkSection(title: 'Sources', urls: entry.sourceUrls),
            ],
          ],
        );
      },
    );
  }
}

class _DictionaryMeaningSection extends StatelessWidget {
  const _DictionaryMeaningSection({required this.meaning});

  final DictionaryMeaning meaning;

  @override
  Widget build(BuildContext context) {
    final title = meaning.partOfSpeech == null || meaning.partOfSpeech!.isEmpty
        ? 'Meaning'
        : 'Meaning (${meaning.partOfSpeech})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (
          var index = 0;
          index < meaning.definitions.length;
          index++
        ) ...<Widget>[
          _DictionaryDefinitionSection(
            index: index + 1,
            definition: meaning.definitions[index],
          ),
          if (index < meaning.definitions.length - 1)
            const SizedBox(height: 10),
        ],
        if (meaning.synonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _InlineMetadataSection(title: 'Synonyms', entries: meaning.synonyms),
        ],
        if (meaning.antonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _InlineMetadataSection(title: 'Antonyms', entries: meaning.antonyms),
        ],
      ],
    );
  }
}

class _DictionaryDefinitionSection extends StatelessWidget {
  const _DictionaryDefinitionSection({
    required this.index,
    required this.definition,
  });

  final int index;
  final DictionaryDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$index. ${definition.text}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (definition.example != null &&
            definition.example!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            'Example: ${definition.example!}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (definition.synonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          _InlineMetadataSection(
            title: 'Definition synonyms',
            entries: definition.synonyms,
          ),
        ],
        if (definition.antonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          _InlineMetadataSection(
            title: 'Definition antonyms',
            entries: definition.antonyms,
          ),
        ],
      ],
    );
  }
}

class _InlineMetadataSection extends StatelessWidget {
  const _InlineMetadataSection({required this.title, required this.entries});

  final String title;
  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$title: ${entries.join(', ')}',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _SourceLinkSection extends StatelessWidget {
  const _SourceLinkSection({required this.title, required this.urls});

  final String title;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final url in urls)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SelectableExternalLink(url: url),
          ),
      ],
    );
  }
}

class _SelectableExternalLink extends StatefulWidget {
  const _SelectableExternalLink({required this.url});

  final String url;

  @override
  State<_SelectableExternalLink> createState() =>
      _SelectableExternalLinkState();
}

class _SelectableExternalLinkState extends State<_SelectableExternalLink> {
  late final TapGestureRecognizer _tapRecognizer = TapGestureRecognizer()
    ..onTap = _openLink;

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openLink() async {
    await launchUrl(Uri.parse(widget.url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        text: widget.url,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF1A73E8),
          decoration: TextDecoration.underline,
        ),
        recognizer: _tapRecognizer,
      ),
      cursorColor: const Color(0xFF1A73E8),
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
