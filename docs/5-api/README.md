# API

The project now has two API boundaries: external reference lookups inside the app and a minimal sync API for cross-browser learner progress.

## Current Boundary

- `AssetVocabRepository` remains the vocabulary content boundary inside the app.
- `DictionaryRepository` is the in-app boundary for live lookups against:
  - `https://api.dictionaryapi.dev/api/v2/entries/en/:word`
  - `https://dictionaryapi.com/api/v3/references/collegiate/json/:word?key=...`
  - `https://dictionaryapi.com/api/v3/references/thesaurus/json/:word?key=...`
- `ProgressRepository` remains the learner-state boundary inside the app and now hides both local SQLite and optional remote sync from widgets.
- Merriam-Webster API keys are stored only in local SQLite settings and are read by the app at runtime; they are not compiled into the website bundle.
- The sync transport is intentionally narrow and only handles learner progress, not vocab content.
- The current backend implementations are a standard-library Python HTTP server and a Dart server, both backed by the same SQLite schema and JSON contract.

## External Reference Sources

- `Dictionary API`
  - source: `api.dictionaryapi.dev`
  - no learner key required
  - used for phonetics, meanings, examples, synonyms, antonyms, and clickable source links
- `M-W Dictionary`
  - source: Merriam-Webster Collegiate Dictionary API
  - learner provides the API key in the settings dialog
  - used for short definitions, part of speech, pronunciation, suggestions, and Merriam source links
- `M-W Thesaurus`
  - source: Merriam-Webster Thesaurus API
  - learner provides the API key in the settings dialog
  - used for senses, synonyms, antonyms, suggestions, and Merriam source links

## HTTP Endpoints

- `GET /health`
  - returns a simple health payload for local verification
- `GET /api/progress/:syncKey`
  - returns the canonical remote snapshot for one learner key
- `POST /api/progress/:syncKey/merge`
  - accepts a full local snapshot and returns the merged server snapshot

## Snapshot Shape

```json
{
  "selectedDay": 6,
  "selectedDayUpdatedAt": "2026-03-04T10:15:00.000Z",
  "statuses": [
    {
      "day": 6,
      "word": "abound",
      "status": "learned",
      "updatedAt": "2026-03-04T10:16:00.000Z"
    }
  ]
}
```

The merge contract is timestamp-based:

- `selectedDayUpdatedAt` decides whether the incoming selected day replaces the server value
- each `statuses` record is merged independently by `updatedAt`
- `status: "untouched"` acts as a tombstone so clearing a mark also syncs across browsers
