# Architecture

This folder contains the current runtime structure and the records for major design choices.

## Contents

- [Architectural Decisions](decisions/README.md)

## Current Topology

```mermaid
flowchart TD
    A["data/final.json"] --> B["AssetVocabRepository"]
    B --> C["VocabHillApp"]
    C --> D["HomePage"]
    D --> E["Day Header + Slider"]
    D --> F["Visible Group Columns"]
    F --> G["Word Cells"]
    G --> H["Word Detail Bottom Sheet"]
```

The current scaffold is deliberately simple:

- assets are the source of vocabulary content
- the repository isolates file loading from UI rendering
- the page state owns day selection and learned/forgotten session state
