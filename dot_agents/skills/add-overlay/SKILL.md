---
name: add-overlay
description: Add or update a project Nushell overlay using a manual workflow in chezmoi-managed user/overlays.nu, with optional starship overlay-count indicator and optional script-to-binary wrappers with mise path guidance.
---

# Add Project Overlay

Use this skill when the user wants to add or update a repository-specific Nushell overlay in the current manual model, or expose repo scripts as convenient commands/aliases/binary-style shortcuts.

## Current model (important)

This setup is **manual activation**, not automatic synchronization:

- Overlay helper/introspection logic lives in:
    - `chezmoi/private_Library/private_Application Support/nushell/user/overlays.nu`
- It is sourced from:
    - `chezmoi/private_Library/private_Application Support/nushell/config.nu`
      via `source user/overlays.nu`
- Activation is done by user command/alias (for example `o`), not by PWD hooks.
- There is no `project_overlays` registry and no `sync_project_overlays` hook logic.

## Procedure

1. Gather required values:

    - Repository path (prefer under `$nu.home-dir`).
    - Overlay module path (default is usually repo-local `overlay.nu`; sometimes `scripts/commands.nu`).
    - Whether user wants:
        - aliases only,
        - exported defs/externs,
        - wrappers in `.local/bin`.

2. Inspect repo state before editing:

    - Check overlay file exists (for example `overlay.nu` or `scripts/commands.nu`).
    - Check `.local/bin` and `mise.toml` only if wrappers/shortcuts are requested.
    - Do not create wrappers or unrelated aliases unless requested.

3. Update `user/overlays.nu` for introspection UX (`i`) as needed:

    - Keep helpers small and readable.
    - Keep custom errors as `error make --unspanned { msg: "..." }`.
    - Prefer parsing from file content for export listing when needed.

4. Ensure import wiring exists in `config.nu`:

    - Confirm:

        ```nu
        source user/overlays.nu
        ```

    - Add it under the external user config section only if missing.

5. If creating/updating overlay module content, prefer top-level exports:

    - For this setup, prefer top-level `export alias` / `export def` / `export extern` declarations.
    - Example:

        ```nu
        export alias mcpc = cargo run -q -p mcpc
        export alias mcpd = cargo run -q -p mcpd
        export alias quizz = cargo run -q -p quizz
        ```

6. If user asks for alias-only overlays:

    - Add `export alias <short> = <command>` entries only.
    - Do not require `mise.toml` or `.local/bin` for alias-only overlays.

7. If user asks for binary wrappers/shortcuts:

    - Prefer `.local/bin/<name>` wrappers.
    - Suggest/update `mise.toml` PATH:

        ```toml
        [env]
        _.path = ["./.local/bin"]
        ```

    - Add `[tools]` entries only when justified.
    - For Nushell scripts, use portable shebang:

        ```nu
        #!/usr/bin/env nu
        ```

    - Make wrapper files executable.

8. If starship overlay count indicator is enabled:

    - Keep it file-based and lightweight (parse `overlay.nu` exports and render count).
    - Do not rely on shell overlay active-state detection from starship custom modules.

## Pitfalls, problems, and compromises

1. Nushell overlay scope behavior:

    - `overlay use/hide` executed inside closures/hooks (`do { ... }`) can fail to persist overlay state in the parent interactive scope.
    - This breaks naive auto-sync-on-PWD-change approaches.

2. Parse-time constraints on `overlay use`:

    - `overlay use` arguments are parse-time sensitive; dynamic variables/paths can fail.
    - Relative module paths can fail in non-interactive contexts before expected `cd` logic applies.

3. Starship process boundary:

    - Starship custom modules run in separate `nu -c` processes.
    - They cannot reliably inspect/reflect the live overlay stack of the interactive shell.
    - Therefore, “overlay active/inactive” indicators in starship are misleading and should be avoided.

4. Practical compromise in this setup:

    - Use manual activation (`o`) for correctness.
    - Use `i` for explicit introspection/warnings in the interactive shell.
    - If starship is used, show only static/file-derived signal (for example exported count like `₃`), not runtime active-state.

5. Top-level exports preference:

    - Nested `module ... { export ... }` in `overlay.nu` can make activation semantics less obvious for this workflow.
    - Prefer top-level exports for predictable activation and introspection.

## Validation

After edits, validate startup load:

```shell
cat <<'NU' | /opt/homebrew/bin/nu -n /dev/stdin
source '/Users/gobbi/Library/Application Support/nushell/config.nu'
source '/Users/gobbi/.local/share/chezmoi/private_Library/private_Application Support/nushell/config.nu'
print 'config loaded'
NU
```

If starship overlay count module is changed, validate directly:

```shell
STARSHIP_CONFIG='/Users/gobbi/.local/share/chezmoi/dot_config/starship.toml' \
starship module custom.overlay_commands_indicator --path '/Users/gobbi/projects/opensockets/mcpd'
```

For changed repo overlay modules/wrappers, run focused checks (non-destructive):

- `mise exec -- nu --check overlay.nu`
- `mise exec -- nu --check scripts/commands.nu`
- Small smoke test inside target repo (only if safe and does not require secrets)
