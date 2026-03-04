# API

There is no network API yet.

## Current Boundary

- `AssetVocabRepository` is the current data boundary inside the app.
- `ProgressRepository` is the current learner-state boundary inside the app.
- A future SQLite layer or remote sync layer should replace or sit behind these repository contracts instead of being called directly from widgets.
