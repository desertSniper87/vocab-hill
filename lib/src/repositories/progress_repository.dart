import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_snapshot.dart';
import '../models/word_status.dart';

abstract class ProgressRepository {
  Future<ProgressSnapshot> loadProgress();

  Future<void> saveSelectedDay(int selectedDay);

  Future<void> saveWordStatus(int day, String word, WordStatus status);
}

class SharedPreferencesProgressRepository implements ProgressRepository {
  const SharedPreferencesProgressRepository();

  static const _selectedDayKey = 'progress.selected_day';
  static const _statusPrefix = 'progress.word_status.';

  @override
  Future<ProgressSnapshot> loadProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedDay = preferences.getInt(_selectedDayKey);
    final wordStatusesByDay = <int, Map<String, WordStatus>>{};

    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_statusPrefix)) {
        continue;
      }

      final suffix = key.substring(_statusPrefix.length);
      final separatorIndex = suffix.indexOf('.');
      if (separatorIndex <= 0 || separatorIndex == suffix.length - 1) {
        continue;
      }

      final day = int.tryParse(suffix.substring(0, separatorIndex));
      if (day == null) {
        continue;
      }

      final word = suffix.substring(separatorIndex + 1);
      final storedValue = preferences.getString(key);
      final status = WordStatus.fromStorageValue(storedValue);
      if (status != WordStatus.untouched) {
        final dayStatuses = wordStatusesByDay.putIfAbsent(
          day,
          () => <String, WordStatus>{},
        );
        dayStatuses[word] = status;
      }
    }

    return ProgressSnapshot(
      selectedDay: selectedDay,
      wordStatusesByDay: wordStatusesByDay,
    );
  }

  @override
  Future<void> saveSelectedDay(int selectedDay) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_selectedDayKey, selectedDay);
  }

  @override
  Future<void> saveWordStatus(int day, String word, WordStatus status) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_statusPrefix$day.$word';
    if (status == WordStatus.untouched) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, status.storageValue);
  }
}
