# .agents Workspace Guide

This file documents skills, memory artifacts, and state files under `.agents`.

## Skills

- `start-session/SKILL.md`: session bootstrap skill that loads persistent memory artifacts.
- `end-session/SKILL.md`: session close-out skill that persists new learnings into memory artifacts and refreshes workspace docs.
- `memento/SKILL.md`: maintains session-to-session memory continuity (`memory.md`, `active_context.md`, `decisions.md`, `failures.md`).
- `theory-of-mind/SKILL.md`: compresses historical discussions into coherent project memory.
- `ai-janitor/SKILL.md`: keeps this README synchronized whenever `.agents` artifacts change.
- `tests/SKILL.md`: updates and runs existing unit tests when behavior-affecting code changes occur, without creating new tests.
- `docs/SKILL.md`: updates root `README.md` only when non-`.agents` files changed in the session.

## Other Markdown Files

- `memory.md`: durable project overview, architecture, constraints, and conventions.
- `active_context.md`: current focus, immediate issues, and next actions.
- `decisions.md`: chronological log of key technical/product decisions.
- `failures.md`: chronological log of failed approaches and lessons learned.
- `README.md`: canonical `.agents` workspace index and dependency map.

## Dependency Graph

### Start-session flow

```mermaid
graph LR
  start["start-session/SKILL.md"] --> memento["memento/SKILL.md"]
  memento --> memory["memory.md"]
  memento --> active["active_context.md"]
  memento --> decisions["decisions.md"]
  memento --> failures["failures.md"]
```

### End-session flow

```mermaid
graph LR
  endSession["end-session/SKILL.md"] --> memento["memento/SKILL.md"]
  endSession --> janitor["ai-janitor/SKILL.md"]
  endSession --> tests["tests/SKILL.md"]
  endSession --> docs["docs/SKILL.md"]

  memento --> memory["memory.md"]
  memento --> active["active_context.md"]
  memento --> decisions["decisions.md"]
  memento --> failures["failures.md"]

  janitor --> readme["README.md"]
  docs --> projectReadme["../README.md"]
```
