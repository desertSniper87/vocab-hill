# AGENTS.md

This document governs how any agent (e.g., Jules, Claude, Codex, Kilo) working on this repository must handle documentation. Treat it as a hard contract, not a style guide.

---

## 1. The `docs/` Folder Is the Source of Truth

All architectural, algorithmic, and structural decisions live in `docs/`. Code without corresponding documentation is considered incomplete. Any PR that modifies logic or structure **must** update the relevant docs in the same commit — not after, not in a follow-up.

---

## 2. Folder Structure

`docs/` must use numbered, hyphenated folder prefixes. Each folder contains a `README.md` and any supporting files.

```
docs/
├── README.md                  ← Table of Contents (auto-updated)
├── 1-overview/
├── 2-architecture/
│   └── decisions/             ← ADRs live here
├── 3-agents/
├── 4-algorithms/
├── 5-api/
└── 6-deployment/
```

Rules:
- Folder names: `{number}-{kebab-case-topic}` (e.g., `2-architecture`, not `2. Architecture`)
- Every folder must have a `README.md`
- New top-level sections get the next available number; do not renumber existing sections

---

## 3. Content Standards

### 3.1 Table of Contents (`docs/README.md`)
Must be updated whenever a document is added, removed, or renamed. It must link to every section README and every ADR.

### 3.2 Mermaid Diagrams
Every architectural decision must include a Mermaid diagram. Diagrams must reflect the *current* state of the system — a diagram that contradicts the code is a bug.

Use diagrams for: system topology, data flow, component relationships, state machines, class hierarchies.

### 3.3 Code Line References
Algorithmic decisions must reference specific source lines using this format:

```
`path/to/file.py:L42-L60`
```

If the referenced lines move, the doc must be updated in the same PR. Stale line references are documentation bugs.

### 3.4 Architecture Decision Records (ADRs)
Significant decisions (why a pattern was chosen, why an alternative was rejected) must be recorded as ADRs in `docs/2-architecture/decisions/`.

Filename format: `ADR-{000}-{kebab-case-title}.md`

Each ADR must contain: **Status**, **Context**, **Decision**, **Consequences**.

---

## 4. Pre-Submission Checklist

Before marking any task complete, verify each item. A failed item blocks submission.

- [ ] New docs are placed in the correct numbered folder
- [ ] `docs/README.md` is updated with any new or renamed documents
- [ ] All Mermaid diagrams render correctly and reflect current code
- [ ] All code line references (`file.py:L{n}`) point to current lines
- [ ] All internal doc links resolve without 404
- [ ] Any structural or algorithmic change has a corresponding ADR if it represents a new decision
