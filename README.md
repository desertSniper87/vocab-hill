# Vocab Hill

Vocab Hill is a Flutter application for studying GregMat-style vocabulary groups in 30-word columns.

The starter project includes:

- a single Flutter codebase positioned for web now and mobile later
- loading vocabulary records from `data/final.json`
- group navigation with `Previous` and `Next Group`
- per-word detail sheets for definition, Bangla meaning, and mnemonic
- in-memory `learned` and `forgotten` tracking for the current session

## Why Flutter

The project goal already points to a website first and a mobile app later. Flutter is the cleanest fit for that trajectory because it keeps the UI, state management, and component model in one codebase.

## Run

```bash
flutter pub get
flutter run
```

## Current Scope

This scaffold is intentionally narrow:

- SQLite persistence is not wired yet
- auth/login is not wired yet
- Flutter web support is configured and the project builds for the browser target
