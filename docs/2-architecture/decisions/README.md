# Architectural Decisions

This document outlines the high-level architecture of the vocabulary project.

## Current Data Flow

The project currently consists of several JSON and CSV files representing vocabulary data at different stages of processing.

```mermaid
graph TD
    CSV["Greg Mat Vocab List.csv"] --> Filter["Filtering Process"]
    Filter --> JSON_Filtered["claude-batch-1-gregmat-filtered.json"]
    JSON_Filtered --> Mnemonic_Add["Mnemonic Augmentation"]
    Mnemonic_Add --> JSON_Mnemonics["gregmat-full-from-claude-batch-1-with-mnemonics.json"]
    JSON_Filtered --> Full["gregmat-full-from-claude-batch-1.json"]
```

## Storage Strategy

Data is stored in flat JSON files to ensure maximum compatibility and ease of manual inspection.
