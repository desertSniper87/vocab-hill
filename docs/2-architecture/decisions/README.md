# Architectural Decisions

This index tracks the Architecture Decision Records for the project.

## ADRs

- [ADR-001: Use Flutter As The First App Framework](ADR-001-flutter-single-codebase.md)

## Decision Map

```mermaid
flowchart TD
    A["Project Goal: web now, mobile later"] --> B["ADR-001"]
    B --> C["Single Flutter codebase"]
    C --> D["Asset-backed starter app"]
    D --> E["SQLite persistence later"]
```
