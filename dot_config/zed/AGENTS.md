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

- `nushell` is the login shell, installed in `/opt/homebrew/bin/nu`, configured in `~/Library/Application Support/nushell/config.nu`.
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
- Use aliases set in `~/Library/Application Support/nushell/config.nu` (this is mandatory):

```nu
# keep MacOS 'open' as 'open', and replace Nushell's built-in 'open' with 'openn'
alias openn = open
alias open = ^open
```

- **Critical rule for LLMs:** in Nushell snippets, use `openn` whenever you mean Nushell's built-in `open` command (reading/parsing files, JSON, YAML, text, etc.).
- Do **not** use plain `open` for data loading/parsing; plain `open` is intentionally aliased to macOS `open` (`^open`) and launches apps/files/URLs.
- Quick examples:
  - ✅ `openn ./data.json | get name`
  - ✅ `openn ./README.md | lines | first 5`
  - ✅ `open https://example.com` (launch in browser)
  - ❌ `open ./data.json | get name` (wrong: calls macOS `open`)

- Subdivide Nushell scripts into small, reusable functions/components.
- Keep each Nushell function to a maximum of 50 lines.
- Avoid defining public `def`s for internal helpers.
  - For internal helper logic, prefer private helpers (for example `def "--my-helper" [...] { ... }`) **or** local closures via `let` (for example `let my_helper = {|...| ... }`) when that is cleaner.
  - Only add public `def`s when the command is intentionally user-facing.
- Always create custom Nushell error messages with `--unspanned` (for example: `error make --unspanned { msg: "..." }`).
- Validate nushell scripts for deprecation warnings, and fix any deprecated commands.

## Nushell overlays (`config.nu`)

When updating `~/.local/share/chezmoi/private_Library/private_Application Support/nushell/config.nu` overlays:

- Keep overlays data-driven through `project_overlays`.
- Add new overlays by appending one record with:
    - `repo`: absolute repo path (prefer `$nu.home-dir` interpolation).
    - `enable`: closure with `overlay use <commands.nu> as <overlay_name>`.
    - `disable`: closure with `overlay hide "<overlay_name>"`.
- Do not duplicate path-toggle logic in hooks; keep it centralized in `sync-project-overlays`.
- Maintain parse-time validity for `overlay hide` by ensuring each hidden overlay name is bootstrapped once with `overlay use ... as <name>` before hide usage.
- **Manual maintenance required:** keep the bootstrap `overlay use ... as <name>` lines at the beginning of the overlay block in sync with `project_overlays` (add/remove/rename together).
- After edits, validate by sourcing config with Nushell:

```shell
cat <<'NU' | /opt/homebrew/bin/nu -n /dev/stdin
source '/Users/gobbi/Library/Application Support/nushell/config.nu'
source '/Users/gobbi/.local/share/chezmoi/private_Library/private_Application Support/nushell/config.nu'
print 'config loaded'
NU
```

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
