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
~/.ssh/allowedSigners
~/.ssh/config
~/.ssh/known_hosts
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

# Notes

- chezmoi is NOT a live sync system
- it does NOT automatically watch files
- sync direction is explicit
- source repo is considered canonical state
- runtime/cache/history files should usually be ignored

---

# Repository Location

chezmoi source repo:

```text
~/.local/share/chezmoi
```

This is a normal Git repo and works well with editors like Zed.
