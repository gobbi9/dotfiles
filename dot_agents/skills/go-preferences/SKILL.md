---
name: go-preferences
description: Apply Go development conventions for runtime management, formatting, package design, error handling, context usage, and testing.
---

# Go preferences

Use this skill when writing or reviewing Go code.

- Use Go versions managed by `mise` unless the project explicitly specifies otherwise.
- Format code with `gofmt` (and `goimports` when available).
- Keep packages cohesive and avoid cyclic dependencies.
- Pass `context.Context` as the first parameter for request-scoped work and external I/O.
- Return errors instead of panicking (except for truly unrecoverable startup conditions in `main`).
- Wrap errors with context using `%w` (for example: `fmt.Errorf("read config: %w", err)`).
- Prefer small interfaces defined at the point of use.
- Prefer table-driven tests with `testing` and `t.Run`.
- Avoid global mutable state; inject dependencies via structs/constructors.
