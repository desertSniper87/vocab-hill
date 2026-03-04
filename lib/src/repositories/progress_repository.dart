import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_snapshot.dart';
import '../models/word_status.dart';

abstract class ProgressRepository {
  Future<ProgressSnapshot> loadProgress();

  Future<void> saveSelectedDay(int selectedDay);

  Future<void> saveWordStatus(String word, WordStatus status);
}

class SharedPreferencesProgressRepository implements ProgressRepository {
  const SharedPreferencesProgressRepository();

  static const _selectedDayKey = 'progress.selected_day';
  static const _statusPrefix = 'progress.word_status.';

  @override
  Future<ProgressSnapshot> loadProgress() async {
    final preferences = await SharedPreferences.getInstance();
    final selectedDay = preferences.getInt(_selectedDayKey);
    final wordStatuses = <String, WordStatus>{};

    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_statusPrefix)) {
        continue;
      }

      final word = key.substring(_statusPrefix.length);
      final storedValue = preferences.getString(key);
      final status = WordStatus.fromStorageValue(storedValue);
      if (status != WordStatus.untouched) {
        wordStatuses[word] = status;
      }
    }

    return ProgressSnapshot(
      selectedDay: selectedDay,
      wordStatuses: wordStatuses,
    );
  }

  @override
  Future<void> saveSelectedDay(int selectedDay) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_selectedDayKey, selectedDay);
  }

  @override
  Future<void> saveWordStatus(String word, WordStatus status) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_statusPrefix$word';
    if (status == WordStatus.untouched) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, status.storageValue);
  }
}
