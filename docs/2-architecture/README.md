# Architecture

This folder contains the current runtime structure and the records for major design choices.

## Contents

- [Architectural Decisions](decisions/README.md)

## Current Topology

```mermaid
flowchart TD
    A["data/final.json"] --> B["AssetVocabRepository"]
    P["Local SQLite progress DB"] --> Q["SqliteProgressRepository"]
    R["Manual sync settings"] --> Q
    S["Python sync server"] --> T["Server-side SQLite sync DB"]
    V["Dart sync server"] --> T
    Q --> U["ProgressSyncClient"]
    U --> S
    U --> V
    B --> C["VocabHillApp"]
    Q --> C
    C --> D["HomePage"]
    D --> E["Day Header + Slider"]
    D --> F["Visible Group Columns"]
    F --> G["Word Cells"]
    G --> H["Inline Word Detail Panel"]
```

The current scaffold is deliberately simple:

- assets are the source of vocabulary content
- repositories isolate vocab loading, local persistence, and optional remote sync from UI rendering
- the page state restores persisted day selection and day-specific word marks from local SQLite before rendering the board
- cross-browser sync is optional and currently uses a manual sync key plus either a Python or Dart backend that shares the same API and SQLite schema
