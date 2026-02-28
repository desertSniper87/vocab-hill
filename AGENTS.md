# AGENTS.md

This document provides instructions for any agent (like Jules) working on this repository.

## Documentation Requirements

The `docs` folder is the source of truth for the project's architecture and design. All changes to the codebase MUST be reflected in the documentation.

### Structure

- The `docs` folder MUST be nicely structured using numbered prefixes (e.g., `1. Architecture`, `2. Data_Structure`).
- Documentation MUST be organized into folders.
- Every major feature or decision MUST have a corresponding Markdown document.

### Content Standards

- **Table of Contents:** The `docs/README.md` MUST serve as a Table of Contents for the entire documentation root.
- **Mermaid Diagrams:** Architectural decisions MUST be accompanied by Mermaid diagrams to visualize system components and data flow.
- **Code Line References:** Algorithmic decisions or complex logic MUST include references to specific code lines where applicable.
- **Sync with Code:** Documentation MUST be kept in sync with the codebase. Any PR or change that modifies logic or structure MUST also update the relevant documentation.

## Verification

Before submitting any changes, ensure that:
1. New documentation files are correctly placed in the structured folders.
2. The `docs/README.md` is updated if new documents are added.
3. Mermaid diagrams correctly render the intended architecture.
4. All links between documentation files are functional.
