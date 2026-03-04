enum WordStatus {
  learned('learned'),
  forgotten('forgotten'),
  untouched('untouched');

  const WordStatus(this.storageValue);

  final String storageValue;

  static WordStatus fromStorageValue(String? value) {
    return WordStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => WordStatus.untouched,
    );
  }
}
