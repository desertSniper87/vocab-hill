# AGENTS.md

This document governs how any agent (e.g., Jules, Claude) working on this repository must handle documentation. Treat it as a hard contract, not a style guide.

---

## 1. The `docs/` Folder Is the Source of Truth

All architectural, algorithmic, and structural decisions live in `docs/`. Code without corresponding documentation is considered incomplete. Any PR that modifies logic or structure **must** update the relevant docs in the same commit — not after, not in a follow-up.

---

## 2. Folder Structure

`docs/` must use numbered, hyphenated folder prefixes. Each folder contains a `README.md` and any supporting files.

```
docs/
├── README.md                  ← Table of Contents (auto-updated)
├── GOAL.md                    ← Project goals (human-maintained, agent-readable)
├── TODO.md                    ← Running task list (human-maintained, agent-appendable)
├── 1-overview/
├── 2-architecture/
│   └── decisions/             ← ADRs live here
├── 3-agents/
├── 4-algorithms/
├── 5-api/
└── 6-deployment/
```

Rules:

- Folder names: `{number}-{kebab-case-topic}` (e.g., `2-architecture`, not `2. Architecture`)
- Every folder must have a `README.md`
- New top-level sections get the next available number; do not renumber existing sections

---

## 3. Content Standards

### 3.1 Table of Contents (`docs/README.md`)

Must be updated whenever a document is added, removed, or renamed. It must link to every section README and every ADR.

### 3.2 Mermaid Diagrams

Every architectural decision must include a Mermaid diagram. Diagrams must reflect the _current_ state of the system — a diagram that contradicts the code is a bug.

Use diagrams for: system topology, data flow, component relationships, state machines, class hierarchies.

### 3.3 Code Line References

Algorithmic decisions must reference specific source lines with enough context to survive a refactor. Use this format:

```
`path/to/file.py:L42-L60` — `ClassName.method_name` — brief description of what this does
```

Examples:

```
`agents/executor.py:L44-L58`  — `ExecutorAgent.execute`      — main subtask dispatch loop
`memory/store.py:L60-L95`     — `MemoryStore.retrieve`        — hybrid recency + cosine scoring
`tools/registry.py:L80-L115`  — `ToolRegistry.invoke`         — tool resolution and arg validation
```

All three parts are required:

- **Line range** — exact location in the file
- **Qualified name** — `ClassName.method` or `module.function`; use `module.function` for top-level functions, `ClassName` alone for class-level decisions
- **Description** — one clause explaining the _why_, not just the what

If the referenced lines move, update the line range in the same PR. If the function is renamed, update the qualified name. Stale references are documentation bugs.

### 3.4 Architecture Decision Records (ADRs)

Significant decisions (why a pattern was chosen, why an alternative was rejected) must be recorded as ADRs in `docs/2-architecture/decisions/`.

Filename format: `ADR-{000}-{kebab-case-title}.md`

Each ADR must contain: **Status**, **Context**, **Decision**, **Consequences**.

### 3.5 `docs/GOAL.md` — Project Goals

This file is the long-horizon north star for the project. It is primarily maintained by the human. Agents must:

- **Read it** at the start of any non-trivial task — understand how the work fits the bigger picture
- **Never rewrite or restructure it** without being explicitly asked
- **Append to it** only when the human states something clearly goal-oriented in a prompt (e.g., "ultimately I want this to support X") — add it as a bullet under the relevant section and note it came from a prompt

### 3.6 `docs/TODO.md` — Task List

This file tracks known issues, follow-ups, and technical debt. It is primarily maintained by the human. Agents must:

- **Never remove or reorder items** — only append
- **Append new items** when code work surfaces a clear code smell, bug, or missing piece that falls outside the current task's scope — prefix appended items with `<!-- agent -->` so the human can review
- **Never block a task** on TODO items — note them and move on

---

## 4. Task Scoping

The default mode is small, atomic changes. If a prompt describes something large or vague, do not start coding immediately.

**If the scope is large:** formulate a step-by-step plan and present it for approval before doing any work. Each step should be independently reviewable and committable.

**If the prompt is vague:** ask clarifying questions first. Prefer a few targeted questions over making assumptions. Do not ask about things that can be reasonably inferred from context.

When in doubt: ask, don't assume.

---

## 5. Pre-Submission Checklist

Before marking any task complete, verify each item. A failed item blocks submission.

- [ ] New docs are placed in the correct numbered folder
- [ ] `docs/README.md` is updated with any new or renamed documents
- [ ] All Mermaid diagrams render correctly and reflect current code
- [ ] All code line references (`file.py:L{n}`) point to current lines
- [ ] All internal doc links resolve without 404
- [ ] Any structural or algorithmic change has a corresponding ADR if it represents a new decision
- [ ] Any code smells or issues noticed during the task are appended to `docs/TODO.md`
