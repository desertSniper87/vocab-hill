# Vocab Hill

Vocab Hill is a Flutter application for studying GregMat-style vocabulary groups in 30-word columns.

The starter project includes:

- a single Flutter codebase positioned for web now and mobile later
- loading vocabulary records from `data/final.json`
- a day-based board that reveals Groups `1..N` for the selected day
- a horizontal multi-column layout modeled on the vocab mountain view
- a right-side green/red marker showing the most recent previous-day mark for that word
- keyboard control: arrows or `h` `j` `k` `l` move, `Cmd+C` / `Ctrl+C` copies the selected word when the board is active, `d` toggles the study-info details view, `t` switches to `Dictionary API`, `y` switches to `M-W Dictionary`, `u` switches to `M-W Thesaurus`, `g` marks remembered, and `r` marks forgotten
- the selected reference tab is remembered for the current session, so moving to another word keeps the same details tab open
- a top-level `Forgotten List` export that produces a comma-separated copyable list based on each word's latest recorded status
- per-word detail sheets with a `Study Info` view for the local definition, a top-level previous-day status badge, Bangla, and mnemonic, plus separate `Dictionary API`, `M-W Dictionary`, and `M-W Thesaurus` views
- reference-panel text is selectable and source URLs open as clickable links in web builds
- persisted per-day `learned` / `forgotten` marks and selected day using SQLite-backed local storage
- local SQLite storage for Merriam-Webster dictionary and thesaurus API keys so they are not shipped in the web bundle
- optional cross-browser sync through matching Python or Dart backends plus a shared sync key

## Why Flutter

The project goal already points to a website first and a mobile app later. Flutter is the cleanest fit for that trajectory because it keeps the UI, state management, and component model in one codebase.

## Run

```bash
flutter pub get
flutter run
```

To run local cross-browser sync:

```bash
python3 bin/sync_server.py
```

Or:

```bash
dart run bin/sync_server.dart
```

## Current Scope

This scaffold is intentionally narrow:

- SQLite persistence is wired for learner progress and selected day
- Merriam-Webster API keys are configured locally in the settings dialog and stay in local SQLite
- sync can work across browsers with a shared sync key, but auth/login is not wired yet
- Flutter web support is configured and the project builds for the browser target
