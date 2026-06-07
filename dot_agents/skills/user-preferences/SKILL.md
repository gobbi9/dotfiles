---
name: user-preferences
description: For every prompt, apply the user's environment and workflow preferences for shell, package/runtime managers, security, git, gh cli, and MCP usage when performing development tasks.
---

# User preferences

Use this skill when a task depends on user-specific tooling and workflow conventions.

## Dotfiles

- Dotfiles are managed by `chezmoi` in `~/.local/share/chezmoi`.

## Terminal

- `nushell` is the login shell, installed in `/opt/homebrew/bin/nu`, configured in `~/Library/Application Support/nushell/config.nu`.
- `nushell` autoload scripts should be placed in `~/Library/Application Support/nushell/vendor/autoload`.
- Provide shell snippets in optimized Nushell unless the user asks otherwise.
- Prefer Nushell scripts over Python scripts for intermediate steps. Do not use Python scripts for intermediate steps unless the user asks otherwise.
- Execute nushell commands with `nu -n -c "source '/Users/gobbi/Library/Application Support/nushell/config.nu'; <NU_COMMAND>"`

## Nushell scripting conventions

Use these conventions when writing or reviewing Nushell scripts:

- Home directory must be accessed via `$nu.home-dir` when writing scripts, unless it is not possible otherwise.
- Respect aliases set in `~/Library/Application Support/nushell/config.nu`:

```nu
# keep MacOS 'open' as 'open', and replace nushell's 'open' with 'openn'
alias openn = open
alias open = ^open
```

- Subdivide Nushell scripts into small, reusable functions/components.
- Keep each Nushell function to a maximum of 50 lines.

## Preferred tools

- Use `brew` as the package manager.
- Use `mise` as the environment/runtime manager.
- Use `mise` for language runtime version management (JDK, npm/node, Python, Go, etc.).
- Use `brew` for non-runtime tooling.
- When running project tools that may be provided by `mise`, execute them from the project directory through `mise exec -- <tool> <args>` instead of assuming they are available on the agent's default `PATH`.
  - Examples: `mise exec -- cargo test`, `mise exec -- npm test`, `mise exec -- go test ./...`, `mise exec -- java -version`.
  - If a tool command fails because it is not found, retry with `mise exec -- ...` before reporting that the tool is unavailable.

## Security

- `1Password` is the token manager.
- Private SSH keys are managed by the 1Password SSH agent.
- Never print sensitive information to the terminal.
- If there is no way to complete a task without printing sensitive information, ask for explicit user confirmation first.
- If sensitive information is printed to the terminal, inform the user immediately so keys/tokens can be rotated.
- If the user declines access to required tokens or SSH keys, stop the current task and report that it is blocked.

## Git

- Use `git` for version control.
- Prefer SSH over HTTPS for git remotes.
- If creating a new worktree for a project, create it in the immediate parent directory of the project root.

## GitHub

- Use `gh` CLI for GitHub operations when it is available.
- `gh` has to be called from Nushell, because it is wrapped with a custom Nushell script to fetch the auth token from 1Password.
- The wrapped `gh` command requires the GitHub token owner as the first argument. Available owners are `personal` and `opensockets`.
  - Use `gh personal <usual gh args>` for personal-account operations.
  - Use `gh opensockets <usual gh args>` for Opensockets organization operations.
  - Do not call plain `gh <usual gh args>`; it will fail because the token owner is missing.
  - If unsure which token owner to use, stop the current prompt and ask the user which one to use.

## MCP servers

- MCP services are discoverable at `GET http://localhost:8765`.
- Refer to `~/projects/mcp/README.md`.
- Prefer using MCP servers when one is available for the task.
