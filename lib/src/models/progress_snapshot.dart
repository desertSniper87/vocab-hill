import 'word_status.dart';

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.selectedDay,
    required this.wordStatusesByDay,
  });

  final int? selectedDay;
  final Map<int, Map<String, WordStatus>> wordStatusesByDay;
}
