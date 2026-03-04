import 'word_status.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.selectedDay,
    required this.wordStatuses,
  });

  final int? selectedDay;
  final Map<String, WordStatus> wordStatuses;
}
