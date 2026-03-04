# Vocab Hill

Vocab Hill is a Flutter application for studying GregMat-style vocabulary groups in 30-word columns.

The starter project includes:

- a single Flutter codebase positioned for web now and mobile later
- loading vocabulary records from `data/final.json`
- a day-based board that reveals Groups `1..N` for the selected day
- a horizontal multi-column layout modeled on the vocab mountain view
- a right-side green/red marker showing the most recent previous-day mark for that word
- keyboard control: arrows move, `d` toggles details, `g` marks remembered, `r` marks forgotten
- per-word detail sheets for definition, Bangla meaning, and mnemonic
- persisted per-day `learned` / `forgotten` marks and selected day using SQLite-backed local storage

## Why Flutter

The project goal already points to a website first and a mobile app later. Flutter is the cleanest fit for that trajectory because it keeps the UI, state management, and component model in one codebase.

## Run

```bash
flutter pub get
flutter run
```

## Current Scope

This scaffold is intentionally narrow:

- SQLite persistence is wired for learner progress and selected day
- auth/login is not wired yet
- Flutter web support is configured and the project builds for the browser target
