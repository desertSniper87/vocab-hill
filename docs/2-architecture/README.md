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
    D --> E["Group Selector"]
    D --> F["Word Column"]
    D --> G["Session Summary"]
    F --> H["Word Detail Bottom Sheet"]
```

The current scaffold is deliberately simple:

- assets are the source of vocabulary content
- the repository isolates file loading from UI rendering
- the page state owns group selection and learned/forgotten session state
