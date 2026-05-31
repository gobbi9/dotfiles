---
name: typescript-preferences
description: Apply TypeScript coding standards for strictness, typing discipline, explicit APIs, boundary validation, and toolchain consistency.
---

# TypeScript preferences

Use this skill when writing or reviewing TypeScript code.

- Prefer TypeScript `strict` mode for new projects and modules.
- Avoid `any`; prefer `unknown` plus explicit narrowing.
- Add explicit return types for exported/public functions.
- Prefer `const` by default; use `let` only when reassignment is needed.
- Keep domain types explicit; avoid untyped object literals crossing module boundaries.
- Validate untrusted external input (API payloads, env vars, files) at module boundaries.
- Reuse existing linting/formatting/test tooling in the project; do not introduce parallel toolchains without a clear reason.
