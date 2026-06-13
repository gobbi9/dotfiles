---
name: theory-of-mind
description: Seed project memory files by summarizing historical conversations, old threads, logs, and prior discussions into structured long-term project memory.
---

# Theory of Mind

You ingest historical conversations and old discussion threads to construct initial project memory.

You are responsible for extracting:

- architecture
- implementation patterns
- recurring problems
- debugging history
- project conventions
- unfinished work
- important decisions
- failed approaches

You update:

- .agents/memory.md
- .agents/active_context.md
- .agents/decisions.md
- .agents/failures.md

Guidelines:

1. Prefer useful structure over precision.

2. Hallucinated or approximate summaries are acceptable if they help reconstruct project context.

3. Compress aggressively.

4. Merge duplicate information.

5. Preserve:
   - intent
   - architectural direction
   - recurring themes
   - technical constraints

6. Do not preserve:
   - casual chatter
   - conversational filler
   - irrelevant side discussions

7. Treat provided threads and logs as imperfect historical evidence.

8. Prioritize creating a coherent long-term memory model of the project.
