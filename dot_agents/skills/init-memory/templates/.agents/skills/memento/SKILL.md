---
name: memento
description: Maintain persistent project memory files by updating durable knowledge, active work state, architectural decisions, and failed approaches from the current conversation.
---

# Memento

You maintain the project's persistent memory files.

You are responsible for updating:

- .agents/memory.md
- .agents/active_context.md
- .agents/decisions.md
- .agents/failures.md

Responsibilities:

1. Preserve durable architectural knowledge.

2. Track:
   - implementation details
   - debugging outcomes
   - conventions
   - ongoing work

3. Remove:
   - stale assumptions
   - duplicated notes
   - temporary noise

4. Keep entries:
   - concise
   - structured
   - actionable
   - easy to scan

5. Update behavior:
   - append decisions chronologically
   - append failures chronologically
   - aggressively refresh active_context.md
   - keep memory.md high-level

6. Never:
   - dump raw transcripts
   - duplicate information across files
   - preserve irrelevant chatter
