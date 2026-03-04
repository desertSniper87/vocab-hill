# Architecture

This folder contains the current runtime structure and the records for major design choices.

## Contents

- [Architectural Decisions](decisions/README.md)

## Current Topology

```mermaid
flowchart TD
    A["data/final.json"] --> B["AssetVocabRepository"]
    P["SharedPreferences"] --> Q["ProgressRepository"]
    B --> C["VocabHillApp"]
    Q --> C
    C --> D["HomePage"]
    D --> E["Day Header + Slider"]
    D --> F["Visible Group Columns"]
    F --> G["Word Cells"]
    G --> H["Word Detail Bottom Sheet"]
```

The current scaffold is deliberately simple:

- assets are the source of vocabulary content
- repositories isolate both vocab loading and progress persistence from UI rendering
- the page state restores persisted day selection and word marks before rendering the board
