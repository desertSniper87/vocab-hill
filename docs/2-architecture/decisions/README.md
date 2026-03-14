# Architectural Decisions

This index tracks the Architecture Decision Records for the project.

## ADRs

- [ADR-001: Use Flutter As The First App Framework](ADR-001-flutter-single-codebase.md)
- [ADR-002: Use SQLite For Local Learner Progress](ADR-002-sqlite-local-progress.md)
- [ADR-003: Use A Manual Sync Key With A Small Interchangeable Sync Backend](ADR-003-sync-key-backend.md)
- [ADR-004: Keep Merriam API Keys In Local SQLite And Support Multiple Reference Providers](ADR-004-local-api-keys-and-reference-providers.md)

## Decision Map

```mermaid
flowchart TD
    A["Project Goal: web now, mobile later"] --> B["ADR-001"]
    A --> E["ADR-002"]
    A --> G["ADR-003"]
    A --> I["ADR-004"]
    B --> C["Single Flutter codebase"]
    C --> D["Asset-backed vocab catalog"]
    E --> F["SQLite-backed learner progress"]
    G --> H["Manual sync key + interchangeable Python/Dart backend"]
    I --> J["Local API-key settings + multiple reference providers"]
```
