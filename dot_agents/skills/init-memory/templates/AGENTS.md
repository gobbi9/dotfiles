# AGENTS.md

Guidance for agents and contributors working in this repository.

## Tooling and runtime

- Use `mise` to run project tooling from the repository root when available.
- Prefer `mise exec -- <tool> <args>` over assuming globally installed runtimes.
- If a tool is not available on PATH, retry through `mise exec -- ...` before reporting failure.

## Scope and safety

- Keep changes focused on the user request.
- Do not refactor unrelated code or add dependencies unless required.
- Preserve existing style and project conventions.

## Validation before finishing

- Run the smallest relevant checks first for files you changed.
- Expand to broader project checks when needed.
- Report the exact command(s) run and result.

## Project memory workflow

- Persistent project context lives in `.agents/`.
- Keep these files current when durable context changes:
  - `.agents/memory.md`
  - `.agents/active_context.md`
  - `.agents/decisions.md`
  - `.agents/failures.md`
- Use `.agents/skills/start-session/SKILL.md` at the beginning of a session and `.agents/skills/end-session/SKILL.md` before finishing.
