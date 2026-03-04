# API

There is no network API yet.

## Current Boundary

- `AssetVocabRepository` is the current data boundary inside the app.
- `ProgressRepository` is the current learner-state boundary inside the app and is backed by SQLite.
- A future remote sync layer should sit behind these repository contracts instead of being called directly from widgets.
