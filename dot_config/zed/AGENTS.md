# User preferences

Apply these preferences for every prompt when performing development tasks.

## Dotfiles

- Dotfiles are managed by `chezmoi` in `~/.local/share/chezmoi`.

## Instruction packs (lazy load protocol)

Do not read all packs up front.

Load only when task signals match:

- Go signals: `go.mod`, `*.go` -> read `~/.agents/instructions/go-preferences/SKILL.md`
- TS/JS signals: `package.json`, `tsconfig.json`, `*.ts`, `*.tsx`, `*.js` -> read `~/.agents/instructions/typescript-preferences/SKILL.md` and `~/.agents/instructions/javascript-preferences/SKILL.md` as needed
- Kotlin signals: `*.kt`, `build.gradle.kts`, `settings.gradle.kts` -> read `~/.agents/instructions/kotlin-preferences/SKILL.md`
- JVM signals: `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, `*.java` -> read `~/.agents/instructions/jvm-preferences/SKILL.md`
- Gradle signals: `gradle.properties`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, `gradle/libs.versions.toml` -> read `~/.agents/instructions/gradle-preferences/SKILL.md`
- Terraform signals: `*.tf`, `*.tfvars`, `.terraform.lock.hcl`, `terragrunt.hcl` -> read `~/.agents/instructions/terraform-preferences/SKILL.md`

Precedence:
1) user request
2) repo-local `AGENTS.md`
3) loaded instruction pack
4) global defaults

## Terminal

- `nushell` is the login shell, installed in `/opt/homebrew/bin/nu`.
- Nushell config is split: entrypoint at `~/Library/Application Support/nushell/config.nu`, with user modules under `~/Library/Application Support/nushell/user/*.nu`.
- `nushell` autoload scripts should be placed in `~/Library/Application Support/nushell/vendor/autoload`.
- Provide shell snippets in optimized Nushell unless the user asks otherwise.
- Prefer Nushell scripts over Python scripts for intermediate steps. Do not use Python scripts for intermediate steps unless the user asks otherwise.
- For committed or executable Nushell scripts, prefer portable `#!/usr/bin/env nu` shebangs over package-manager-specific absolute paths like `#!/opt/homebrew/bin/nu`.
- Execute Nushell commands by explicitly loading config from `'/Users/gobbi/Library/Application Support/nushell/config.nu'`.
- Write readable, line-separated scripts for **intermediate operations**, by using heredoc piping for multi-line commands:
  ```shell
  cat <<'NU' | /opt/homebrew/bin/nu -n /dev/stdin
  source '/Users/gobbi/Library/Application Support/nushell/config.nu'
  <NU_SCRIPT>
  NU
  ```
  - NEVER write a temporary `.nu` script file to run it with `/opt/homebrew/bin/nu -n <script.nu>`, unless user explicitly requests it.
  - NEVER use `nu -n -c "source '/Users/gobbi/Library/Application Support/nushell/config.nu'; <NU_COMMAND>"`, not even for short single-line commands, unless user explicitly requests it.

## Nushell scripting conventions

Use these conventions when writing or reviewing Nushell scripts:

- Home directory must be accessed via `$nu.home-dir` when writing scripts, unless it is not possible otherwise.
- Interactive Nushell sessions use the aliases in `~/Library/Application Support/nushell/user/aliases.nu`.

- **Interactive commands and snippets:** use `openn` whenever you mean Nushell's built-in `open` command (reading/parsing files, JSON, YAML, text, etc.). Plain `open` intentionally launches macOS `open` (`^open`).
- **Nushell modules and reusable `.nu` files:** do **not** use `openn` or depend on interactive aliases. Modules have their own lexical scope and may be loaded before aliases are sourced. Use Nushell's built-in `open` directly for file loading/parsing.
- Quick examples:
  - ✅ Interactive: `openn ./data.json | get name`
  - ✅ Interactive: `openn ./README.md | lines | first 5`
  - ✅ Interactive: `open https://example.com` (launch in browser)
  - ❌ Interactive: `open ./data.json | get name` (launches macOS `open`)
  - ✅ Module: `open --raw $file_path`
  - ❌ Module: `openn --raw $file_path` (an interactive alias is not available)

- Subdivide Nushell scripts into small, reusable functions/components.
- Keep each Nushell function to a maximum of 50 lines.
- Use `snake_case` for Nushell function names.
- Differentiate visibility with `export`:
  - Use `export def ...` only for intentionally user-facing/public commands.
  - Use plain `def ...` for private/internal helper functions.
- Do **not** use `_` prefixes to indicate private functions; rely on `export` vs non-`export` visibility instead.
- For internal helper logic, prefer private helpers (`def ...`) **or** local closures via `let` (for example `let my_helper = {|...| ... }`) when that is cleaner.
- When refactoring `.nu` scripts, ignore auto-generated scripts (for example, files with a comment header containing the word `generated`).
- Always create custom Nushell error messages with `--unspanned` (for example: `error make --unspanned { msg: "..." }`).
- Validate nushell scripts for deprecation warnings, and fix any deprecated commands.

## Nushell overlays (`user/overlays.nu`)

When adding/updating overlays, use the current **manual activation** model:

- Overlay helper/introspection logic lives in:
    - `~/.local/share/chezmoi/private_Library/private_Application Support/nushell/user/overlays.nu`
- It is sourced from the config entrypoint:
    - `~/.local/share/chezmoi/private_Library/private_Application Support/nushell/config.nu`
    - via `source user/overlays.nu`
- Activation is manual (for example `o`), not automatic via PWD hooks.
- There is no `project_overlays` registry and no `sync-project-overlays` hook flow.
- Prefer top-level exports in repo overlay modules (`overlay.nu` or `scripts/commands.nu`):
    - `export alias ...`
    - `export def ...`
    - `export extern ...`
- Keep Nushell helper functions small/readable and use custom errors with:
    - `error make --unspanned { msg: "..." }`
- If starship overlay indicators are used, prefer static/file-derived indicators (for example exported command count), not live active-overlay state.

After edits, validate by sourcing runtime config and the specific split file you changed:

```shell
cat <<'NU' | /opt/homebrew/bin/nu -n /dev/stdin
source '/Users/gobbi/.local/share/chezmoi/private_Library/private_Application Support/nushell/user/overlays.nu'
print 'config loaded'
NU
```

Inform the user that `chezmoi apply` and `reload` is required to see changes.

## Preferred tools

- Use `brew` as the package manager.
- Use `mise` as the environment/runtime manager.
- Use `mise` for language runtime version management (JDK, npm/node, Python, Go, etc.).
- `mise` must not call `brew install`.
- If a package is only available on Homebrew, do not add it to `mise.toml`; install/manage it via `brew` instead.
- Use `brew` for non-runtime tooling.
- When running project tools that may be provided by `mise`, execute them from the project directory through `mise exec -- <tool> <args>` instead of assuming they are available on the agent's default `PATH`.
    - Examples: `mise exec -- cargo test`, `mise exec -- npm test`, `mise exec -- go test ./...`, `mise exec -- java -version`.
    - If a tool command fails because it is not found, retry with `mise exec -- ...` before reporting that the tool is unavailable.

### Modern CLI preference (installed on this system)

- Prefer these tools over defaults when it makes sense:
    - `rg` over `grep` for recursive text search.
    - `fd` over `find` for interactive/project file discovery.
    - `bat` over `cat` when human-readable output (syntax highlight/paging) is helpful.
    - `fzf` for interactive selection/filtering in terminal workflows.
    - `zoxide` (`z`, `zi`) for interactive directory jumping.
- Keep default tools when behavior must be strictly POSIX/stable for scripts, CI, or machine-parsed output.
- For non-interactive scripted commands, prefer deterministic flags (for example: `rg --no-heading --line-number`, `fd --strip-cwd-prefix`) and avoid relying on interactive UI behavior.

## Security

- `1Password` is the token manager.
- Private SSH keys are managed by the 1Password SSH agent.
- Never print sensitive information to the terminal.
- If there is no way to complete a task without printing sensitive information, ask for explicit user confirmation first.
- If sensitive information is printed to the terminal, inform the user immediately so keys/tokens can be rotated.
- If the user declines access to required tokens or SSH keys, stop the current task and report that it is blocked.

## Directory discovery safety

- Never run broad recursive searches from the home directory (for example: `find ~ ...`, `find /Users/<user> ...`, or equivalent).
- If a needed directory location is unknown, ask the user for the exact base path before searching.
- Prefer scoped searches under the user-provided directory only.
- Example: for most git projects, ask for and use `~/projects/*` (or the user-provided path) instead of scanning `~`.

## Markdown formatting

- Sub-elements from lists (ordered or unordered) should be indented with at least 4 spaces, i.e.:

```markdown
- Item 1
    - Sub-item 1
    - Sub-item 2
```

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

## Project preferences

- If temporary log files or transient scripts were created by the agent for debugging, clean them up before finishing the task.

## Diagrams

- Use Mermaid diagrams in `.md` files unless the user asks otherwise.
- Use `TD` layout by default unless the user asks otherwise.
- Avoid separating lines with semicolons (`;`) in Mermaid diagrams, if not strictly necessary.
- Avoid Mermaid/GitHub renderer keywords as node/identifier names. Reserve these for syntax only, and prefer alternatives like `finish`, `done`, `group`, `go_down`, etc.
  - Examples to avoid as identifiers: `end`, `subgraph`, `graph`, `flowchart`, `direction`, `class`, `classDef`, `style`, `linkStyle`, `click`.

### Mermaid validation runtime (mmdc)

- Validate Mermaid diagrams with `mise exec -- mmdc`.
- `mmdc` needs a Puppeteer browser runtime. On this machine, prefer a Chromium-family executable at:

  - `/Applications/Vivaldi.app/Contents/MacOS/Vivaldi`

- Do **not** assume Chrome is installed.
- Do **not** use Firefox for `mmdc` unless explicitly requested and confirmed working; default flow should use Vivaldi executablePath.

- When validating diagrams, pass a Puppeteer config file to `mmdc` with `-p` containing:

  ```json
  {
    "executablePath": "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi",
    "args": ["--no-sandbox", "--disable-setuid-sandbox"]
  }
