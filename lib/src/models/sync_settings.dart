class SyncSettings {
  const SyncSettings({required this.serverUrl, required this.syncKey});

  static const defaultServerUrl = 'http://localhost:8080';

  static const empty = SyncSettings(serverUrl: defaultServerUrl, syncKey: '');

  final String serverUrl;
  final String syncKey;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty && syncKey.trim().isNotEmpty;

  SyncSettings copyWith({String? serverUrl, String? syncKey}) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      syncKey: syncKey ?? this.syncKey,
    );
  }
}
