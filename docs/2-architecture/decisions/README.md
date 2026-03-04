# Architectural Decisions

This index tracks the Architecture Decision Records for the project.

## ADRs

- [ADR-001: Use Flutter As The First App Framework](ADR-001-flutter-single-codebase.md)
- [ADR-002: Use SQLite For Local Learner Progress](ADR-002-sqlite-local-progress.md)

## Decision Map

```mermaid
flowchart TD
    A["Project Goal: web now, mobile later"] --> B["ADR-001"]
    A --> E["ADR-002"]
    B --> C["Single Flutter codebase"]
    C --> D["Asset-backed vocab catalog"]
    E --> F["SQLite-backed learner progress"]
```
