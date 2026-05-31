# Dotfiles with chezmoi

This repository manages personal configuration files using
[chezmoi](https://www.chezmoi.io/).

The goal is:

- version configs with Git
- back them up remotely
- keep files in their original locations
- avoid symlinks
- preserve per-app behavior
- support configs spread across multiple directories

---

# Why chezmoi?

Initially considered:

- bare Git repo with `--work-tree`
- symlink-based approaches (`stow`)
- plain Git repos

But each had drawbacks:

## Bare Git repo drawbacks

Although elegant, it has poor editor UX:

- opening the repo in Zed/VSCode does not show tracked files outside repo dir
- Git tooling becomes confusing
- entire `$HOME` becomes a logical Git repo
- requires hiding untracked files
- `.gitignore` handling becomes awkward

## Symlink drawbacks

Personally disliked because:

- hard to remember what is a symlink vs real file
- filesystem truth becomes less obvious

## Why chezmoi won

chezmoi provides:

- normal Git repo structure
- no symlinks required
- files stay in correct target locations
- support for arbitrary filesystem paths
- explicit sync behavior
- better editor UX

---

# Managed Files

## Individual Files

```text
~/.gitconfig
~/.testcontainers.properties
~/dev.sh
~/.config/starship.toml
~/.config/gh/config.yml
~/.ssh/allowedSigners
~/.ssh/config
~/.ssh/known_hosts
~/.config/scans/scans.csv (rendered from 1Password template)
~/.config/scans/all-tags.txt (rendered from 1Password template)
```

## Managed Directories

```text
~/.config/mise
~/Library/Application Support/nushell
```

Ignored inside nushell:

```text
history.txt
```

---

# Zed Configuration & Extensions

Use this repo to fully restore your Zed setup on a new machine.

## Files to Track

Track these global Zed config files:

```text
~/.config/zed/settings.json
~/.config/zed/keymap.json
~/.config/zed/tasks.json
~/.config/zed/snippets/
~/.config/zed/themes/
```

The helper script below syncs these paths into chezmoi automatically (no manual `chezmoi add` needed for Zed files).

Notes:

- `tasks.json`, `snippets/`, and `themes/` are optional (only add if you use them).
- Do **not** track `~/Library/Application Support/Zed/extensions/installed` (runtime artifacts, machine-local).

## Tracking Installed Extensions (Portable Way)

Track extension IDs through `settings.json` using `auto_install_extensions`.

This repo includes a helper script:

```text
sync-zed.nu
```

It reads currently installed Zed extensions and then does everything end-to-end:

```text
1) updates ~/.config/zed/settings.json -> auto_install_extensions
2) runs: chezmoi add ~/.config/zed/settings.json
3) runs: chezmoi add ~/.config/zed/keymap.json   (if present)
4) runs: chezmoi add ~/.config/zed/tasks.json    (if present)
5) runs: chezmoi add ~/.config/zed/snippets      (if present)
6) runs: chezmoi add ~/.config/zed/themes        (if present)
```

### Usage

From repo root:

```bash
cd ~/.local/share/chezmoi
./sync-zed.nu --dry-run
./sync-zed.nu
```

Then commit/push as usual.

The script is idempotent:

- it rewrites `settings.json` only when `auto_install_extensions` actually changed
- it is safe to rerun after every extension install/remove
- it only runs `chezmoi add` for paths that exist (optional paths are skipped when missing)

## New Machine Restore Flow (Zed)

```bash
cd ~/.local/share/chezmoi
chezmoi apply
```

Then open Zed once. Zed reads `auto_install_extensions` and installs listed extensions automatically.

---

# Setup

Install:

```bash
brew install chezmoi
```

Initialize:

```bash
chezmoi init
```

Add ignore rule:

```nu
"private_Library/private_Application Support/nushell/history.txt" | save -f ~/.local/share/chezmoi/.chezmoiignore
```

Add files:

```bash
chezmoi add ~/.gitconfig
chezmoi add ~/.testcontainers.properties
chezmoi add ~/dev.sh
chezmoi add ~/.config/starship.toml
chezmoi add ~/.config/gh/config.yml
chezmoi add ~/.ssh/allowedSigners
chezmoi add ~/.ssh/config
chezmoi add ~/.ssh/known_hosts
```

Add directories:

```bash
chezmoi add ~/.config/mise
chezmoi add "~/Library/Application Support/nushell"
```

Test editing a file directly inside source repo:

```text
~/.local/share/chezmoi
```

Check differences:

```bash
chezmoi diff
```

Apply source repo changes to filesystem:

```bash
chezmoi apply
```

Commit:

```bash
git cm "Setup dotfiles"
```

Create GitHub repo:

```bash
gh repo create gobbi9/dotfiles --private --source=. --remote=origin --push
```

---

# Important Mental Model

chezmoi has TWO SIDES:

```text
REAL FILESYSTEM
        ↕
CHEZMOI SOURCE REPO
```

You explicitly sync between them.

---

# Core Commands

## Pull filesystem changes INTO chezmoi repo

Meaning:

```text
filesystem -> source repo
```

Command:

```bash
chezmoi add <path>
```

Examples:

```bash
chezmoi add ~/.gitconfig
chezmoi add ~/.config/mise
```

For already-managed files:

```bash
chezmoi re-add
```

This is effectively:

> "pull changes into repo"

---

## Push chezmoi repo changes TO filesystem

Meaning:

```text
source repo -> filesystem
```

Command:

```bash
chezmoi apply
```

Examples:

```bash
chezmoi apply
chezmoi apply ~/.gitconfig
```

This is effectively:

> "push repo state to machine"

---

# Very Important Behavior

`chezmoi apply` can overwrite filesystem changes.

⚠️ For files rendered from 1Password templates, `chezmoi diff` resolves secret values (after 1Password authentication/biometric confirmation when required) and can print sensitive plaintext content to your terminal.

Safe workflow:

```bash
chezmoi diff
```

then decide:

## Keep filesystem changes

```bash
chezmoi re-add
```

## Overwrite filesystem with repo version

```bash
chezmoi apply
```

---

# Push Local Files Back to 1Password (for `onepasswordRead` templates)

Templates like:

- `dot_config/scans/scans.csv.tmpl`
- `dot_config/scans/all-tags.txt.tmpl`

use `onepasswordRead "op://..."` references.

Important: `onepasswordRead` is read-only from chezmoi's perspective (1Password -> rendered local file).
If you changed a local rendered file and want that change in 1Password, run the helper script from the repo root:

```bash
cd ~/.local/share/chezmoi
./push-templates-to-1password.nu --dry-run
./push-templates-to-1password.nu
chezmoi apply # for tmpl files choose "overwrite" to update chezmoi state
chezmoi diff # should not output anything
```

What it does:

- scans all `*.tmpl` files in the chezmoi source directory
- extracts every `onepasswordRead` `op://...` reference
- resolves each template's local target via `chezmoi target-path`
- reads the local target file content
- updates standard fields by exact `id`/`label` via item JSON template edits
- if the ref points to a file attachment (for example `all-tags.txt`), updates it via escaped `[file]` assignment so dotted names are handled correctly

Behavior:

- `--dry-run` prints intended updates only
- in apply mode, the script prints each `op://...` ref before any `op` call (before biometric prompt)
- works for new templates automatically (no hardcoded scans paths)
- skips missing local target files with warnings
- exits non-zero if any update fails

---

# Useful Commands

## Show differences

```bash
chezmoi diff
```

## Show managed files with differences

```bash
chezmoi status
```

## Show managed files

```bash
chezmoi managed
```

## Dry run apply

```bash
chezmoi apply --dry-run
```

## Remove file from chezmoi management

```bash
chezmoi forget <path>
```

Example:

```bash
chezmoi forget "~/Library/Application Support/nushell/history.txt"
```

---

# Important Confusions Learned

## Source filenames are NOT target filenames

chezmoi renames files internally:

| Real Path | Source Repo |
|---|---|
| `~/.gitconfig` | `dot_gitconfig` |
| `~/.config` | `dot_config` |
| private files | `private_*` |

These are implementation details.

Commands generally expect REAL TARGET PATHS.

Correct:

```bash
chezmoi apply ~/.gitconfig
```

Wrong:

```bash
chezmoi apply dot_gitconfig
```

---

# About `.chezmoiignore`

Location:

```text
~/.local/share/chezmoi/.chezmoiignore
```

Paths are relative to chezmoi source repo structure,
NOT relative to `~`.

Example:

```gitignore
private_Library/private_Application Support/nushell/history.txt
```

NOT:

```gitignore
~/Library/Application Support/nushell/history.txt
```

---

# Recommended Workflow

## Daily usage

Edit real files normally:

```text
~/.config/mise/config.toml
~/Library/Application Support/nushell/config.nu
```

Then periodically:

```bash
chezmoi diff
chezmoi re-add
git commit
git push
```

## New machine / restore workflow

```bash
git pull
chezmoi apply
```

---

# Homebrew Bundle (`Brewfile`)

The repo includes a `Brewfile` in the repo root (`~/.local/share/chezmoi/Brewfile`).

## Update `Brewfile` from current machine

From the repo root:

```bash
cd ~/.local/share/chezmoi
brew bundle dump --force
```

## Import/install from `Brewfile`

On a new or existing machine:

```bash
cd ~/.local/share/chezmoi
brew bundle
```

Optional check-only mode:

```bash
brew bundle check
```

---

# Notes

- chezmoi is NOT a live sync system
- it does NOT automatically watch files
- sync direction is explicit
- source repo is considered canonical state
- runtime/cache/history files should usually be ignored

---

# Public Repo Safety Notes

This dotfiles repo is designed to be shareable/public.

- Secrets are managed via 1Password at runtime (not committed in this repo).
- `~/.config/scans/scans.csv` and `~/.config/scans/all-tags.txt` are managed via chezmoi templates that call `onepasswordRead`.
- Raw source copies (`dot_config/scans/scans.csv` and `dot_config/scans/all-tags.txt`) are blocked by both `.chezmoiignore` (apply scope) and `.gitignore` (commit scope).
- Sensitive/runtime files are explicitly blocked by both `.chezmoiignore` (apply scope) and `.gitignore` (commit scope).
- Keep `~/.config/gh/config.yml` tracked, but do **not** track `~/.config/gh/hosts.yml` (contains auth tokens).
- Do **not** commit private keys (for example `~/.ssh/id_*`); only public material/config is tracked here.

---

# Repository Location

chezmoi source repo:

```text
~/.local/share/chezmoi
```

This is a normal Git repo and works well with editors like Zed.
