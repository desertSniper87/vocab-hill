# Deployment

The project is still in scaffold stage, but it now has two runnable pieces: the Flutter app and a small sync server. The sync server can run in Python or Dart.

## Current Reality

- The Flutter project has iOS and Android targets generated.
- The Flutter project also has generated web platform files under `web/`.
- `flutter build web` succeeds on this machine, so browser-target output is available under `build/web`.
- The sync backend can be started locally with `python3 bin/sync_server.py` or `dart run bin/sync_server.dart`.
- The sync backend stores its SQLite database under `.dart_tool/vocab_hill_sync.db` by default.
- No production build or deployment pipeline exists yet for either the app or the backend.

## Local Sync Setup

1. Start the backend with `python3 bin/sync_server.py` or `dart run bin/sync_server.dart`.
2. Open the app in each browser you want to share.
3. Use the `Set Sync` button in the header.
4. Enter the same `Server URL` and `Sync key` in each browser.
5. Optionally enter local Merriam-Webster dictionary and thesaurus API keys if you want those tabs enabled in that browser profile.
