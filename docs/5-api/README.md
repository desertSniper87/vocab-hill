# API

There is no network API yet.

## Current Boundary

- `AssetVocabRepository` is the current data boundary inside the app.
- A future SQLite layer or remote sync layer should replace or sit behind that repository contract instead of being called directly from widgets.
