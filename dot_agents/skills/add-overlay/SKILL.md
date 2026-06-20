---
name: add-overlay
description: Add or update a project Nushell overlay in chezmoi-managed config.nu, including overlay bootstrap, project_overlays entries, optional aliases, and optional script-to-binary wrappers with mise path guidance.
---

# Add Project Overlay

Use this skill when the user wants to add a repository-specific Nushell overlay to the chezmoi-managed Nushell config, or when they want to expose repo scripts as convenient commands, aliases, or binary-style shortcuts.

The primary target file is:

- `chezmoi/private_Library/private_Application Support/nushell/config.nu`

## Expected overlay model

`config.nu` keeps project overlays data-driven:

1. A parse-time bootstrap line for every overlay name used by `overlay hide`:

    ```nu
    overlay use ~/projects/emails/scripts/commands.nu as cf_commands
    ```

2. One matching record in `project_overlays`:

    ```nu
    {
      repo: $"($nu.home-dir)/projects/emails"
      module_path: $"($nu.home-dir)/projects/emails/scripts/commands.nu"
      enable: {|| overlay use ~/projects/emails/scripts/commands.nu as cf_commands }
      disable: {|| overlay hide "cf_commands" }
    }
    ```

Keep these two locations in sync. The overlay name in `overlay use ... as <name>` must exactly match the string passed to `overlay hide "<name>"`.

## Procedure

1. Gather the required values from the user or the repository:

    - Repository path, preferably under `$nu.home-dir`, e.g. `$"($nu.home-dir)/projects/my-repo"`.
    - Overlay module path, usually `<repo>/scripts/commands.nu`.
    - Overlay name, usually a short repo-specific name ending in `_commands`, e.g. `cf_commands`.

2. Inspect the target repo layout before editing:

    - Check whether `scripts/commands.nu` already exists.
    - Check whether `.local/bin` and `mise.toml` exist if the user wants binary wrappers or command shortcuts for scripts.
    - Do not create wrappers or aliases unless the user asked for them or they are clearly part of the requested overlay setup.

3. Update `config.nu`:

    - Add one parse-time bootstrap line in the `# parse-time bootstrap for overlay names used in \`overlay hide\`` block:

        ```nu
        overlay use ~/projects/my-repo/scripts/commands.nu as my_repo_commands
        ```

    - Add one record to `project_overlays`:

        ```nu
        {
          repo: $"($nu.home-dir)/projects/my-repo"
          module_path: $"($nu.home-dir)/projects/my-repo/scripts/commands.nu"
          enable: {|| overlay use ~/projects/my-repo/scripts/commands.nu as my_repo_commands }
          disable: {|| overlay hide "my_repo_commands" }
        }
        ```

    - Keep the existing data-driven `sync_project_overlays` logic unchanged.
    - Do not duplicate path-toggle logic in hooks.

4. If creating a new overlay module, prefer `scripts/commands.nu` with exported commands and aliases:

    ```nu
    # Repo-local Nushell command overlay for discoverable help.
    # Load with:
    #   overlay use ./scripts/commands.nu

    def repo-root [] {
      let result = (^git rev-parse --show-toplevel | complete)

      if $result.exit_code != 0 {
        error make --unspanned {
          msg: $"Could not determine repository root from current directory '($env.PWD)'. Ensure you are inside this repository."
        }
      }

      $result.stdout | str trim
    }

    export def --wrapped example [...args: string] {
      let command = ((repo-root) | path join ".local" "bin" "example")
      run-external $command ...$args
    }

    export alias ex = example
    ```

5. If the user asks only for aliases:

    - Add `export alias <short> = <command>` entries to the overlay module.
    - Do not require `mise.toml` or `.local/bin` just for aliases.
    - Validate that the aliased command is available in the overlay context or explain any external requirement.

6. If the user asks to convert scripts to binaries, binary wrappers, or shortcuts:

    - Prefer repo-local executable wrappers in `.local/bin/<name>`.
    - Suggest adding or updating `mise.toml` so `.local/bin` is on PATH when the repo is active:

        ```toml
        [env]
        _.path = ["./.local/bin"]
        ```

    - If tools are required by wrappers, add them under `[tools]` only when justified, e.g.:

        ```toml
        [tools]
        terraform = "1.9.8"
        aws = "latest"

        [env]
        _.path = ["./.local/bin"]
        ```

    - Do not require or introduce `mise.toml` for alias-only overlays.
    - For Nushell wrapper scripts, use a direct shebang and forward arguments:

        ```nu
        #!/opt/homebrew/bin/nu

        def repo-root [] {
          let result = (^git rev-parse --show-toplevel | complete)

          if $result.exit_code != 0 {
            error make --unspanned {
              msg: $"Could not determine repository root from current directory '($env.PWD)'. Ensure you are inside this repository."
            }
          }

          $result.stdout | str trim
        }

        def --wrapped main [...args: string] {
          let command = ((repo-root) | path join "scripts" "example.nu")
          run-external $command ...$args
        }
        ```

    - Make wrapper files executable.

7. Follow Nushell conventions:

    - Use `$nu.home-dir` for home-relative paths in scripts and config records where possible.
    - Use `error make --unspanned` for custom errors.
    - Use `openn` instead of `open` when reading/parsing files in Nushell snippets.
    - Keep helper functions small and private unless they are intentionally exported.

## Validation

After edits, validate `config.nu` by sourcing the active config and the chezmoi source config:

```shell
cat <<'NU' | /opt/homebrew/bin/nu -n /dev/stdin
source '/Users/gobbi/Library/Application Support/nushell/config.nu'
source '/Users/gobbi/.local/share/chezmoi/private_Library/private_Application Support/nushell/config.nu'
print 'config loaded'
NU
```

For changed overlay modules or wrapper scripts, run the smallest focused validation available, such as:

- `mise exec -- nu --check scripts/commands.nu`
- `mise exec -- nu --check scripts/<script>.nu`
- A direct command smoke test from inside the target repo, if it does not require secrets or destructive actions.
