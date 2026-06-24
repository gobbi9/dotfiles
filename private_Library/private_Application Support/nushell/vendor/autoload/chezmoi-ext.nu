def chezmoi-ext-git-root-or-empty [] {
  let result = (^git rev-parse --show-toplevel | complete)
  if $result.exit_code != 0 {
    return ""
  }

  $result.stdout | str trim
}

def chezmoi-ext-source-root-or-empty [] {
  let result = (^chezmoi source-path | complete)
  if $result.exit_code != 0 {
    return ""
  }

  $result.stdout | str trim
}

def chezmoi-ext-in-source-repo [] {
  let git_root = (chezmoi-ext-git-root-or-empty)
  if $git_root == "" {
    return false
  }

  let source_root = (chezmoi-ext-source-root-or-empty)
  if $source_root == "" {
    return false
  }

  (($git_root | path expand) == ($source_root | path expand))
}

def chezmoi-ext-status-result [] {
  ^chezmoi status --no-pager --path-style relative --exclude templates | complete
}

def chezmoi-ext-status-lines [] {
  let result = (chezmoi-ext-status-result)
  if $result.exit_code != 0 {
    error make --unspanned {
      msg: "Failed to run 'chezmoi status'."
      label: {
        text: ($result.stderr | str trim)
      }
    }
  }

  $result.stdout
  | lines
  | where {|line| ($line | str trim) != "" }
}

def chezmoi-ext-entry [line: string] {
  let parsed = ($line | parse -r '^(?<filesystem>.)(?<source>.)\s+(?<path>.+)$')
  if (($parsed | length) == 0) {
    return null
  }

  let filesystem = ($parsed | get 0.filesystem)
  let source = ($parsed | get 0.source)
  let path = ($parsed | get 0.path)

  if $filesystem != " " {
    return { direction: "down" path: $path filesystem: $filesystem source: $source }
  }

  if $source != " " {
    return { direction: "up" path: $path filesystem: $filesystem source: $source }
  }

  null
}

def chezmoi-ext-entries [] {
  chezmoi-ext-status-lines
  | each {|line| chezmoi-ext-entry $line }
  | where {|entry| $entry != null }
}

def chezmoi-ext-counts [] {
  let entries = (chezmoi-ext-entries)

  {
    down: ($entries | where direction == "down" | length)
    up: ($entries | where direction == "up" | length)
    total: ($entries | length)
  }
}

def chezmoi-ext-target-path [path: string] {
  if ($path | str starts-with "/") {
    return $path
  }

  [$nu.home-dir $path] | path join
}

def chezmoi-ext-paths-by-direction [direction: string] {
  chezmoi-ext-entries
  | where direction == $direction
  | get path
  | each {|path| chezmoi-ext-target-path $path }
}

# Starship guard: succeeds only when the current directory is the chezmoi source repo.
# Intended for use by the custom Starship module `custom.chezmoi_diff`.
export def "chezmoi-ext-starship-when" [] {
  if (chezmoi-ext-in-source-repo) {
    exit 0
  }

  exit 1
}

# Starship renderer for chezmoi summary counts.
# Output format: ` !<total> ⇣<down> ⇡<up>`
# - Uses `chezmoi status --exclude templates` (no template fetches).
# - ⇣ includes any entry whose first status column is set (including `MM`).
# - ⇡ includes entries whose first column is blank and second is set.
export def "chezmoi-ext-starship-command" [] {
  let counts = (chezmoi-ext-counts)
  if $counts.total == 0 {
    exit 1
  }

  $" !($counts.total) ⇣($counts.down) ⇡($counts.up)"
}

# Easy chezmoi diff summary (path list, no line hunks).
# Prints one managed path per line with direction:
# - `⇡ <path>`: apply source to destination (`chezmoi apply <path>`)
# - `⇣ <path>`: re-add destination state to source (`chezmoi re-add <path>`)
# - Uses `chezmoi status --exclude templates` by default.
# `MM` entries are grouped under `⇣` by design.
export def "chezmoi ediff" [] {
  let entries = (chezmoi-ext-entries)
  if ($entries | is-empty) {
    return
  }

  $entries
  | each {|entry|
      if $entry.direction == "down" {
        $"⇣ ($entry.path)"
      } else {
        $"⇡ ($entry.path)"
      }
    }
  | str join (char nl)
}

# Apply all `⇡` entries reported by `chezmoi ediff` in one command.
# Runs: `chezmoi apply -- ...<absolute destination paths>`
export def "chezmoi up" [] {
  let paths = (chezmoi-ext-paths-by-direction "up")
  if ($paths | is-empty) {
    return
  }

  ^chezmoi apply -- ...$paths
}

# Re-add all `⇣` entries reported by `chezmoi ediff` in one command.
# Runs: `chezmoi re-add -- ...<absolute destination paths>`
export def "chezmoi down" [] {
  let paths = (chezmoi-ext-paths-by-direction "down")
  if ($paths | is-empty) {
    return
  }

  ^chezmoi re-add -- ...$paths
}

# Synchronize both directions in a single command.
# Order is intentional:
# 1) run `chezmoi down`
# 2) run `chezmoi up`
export def "chezmoi sync" [] {
  chezmoi down
  chezmoi up
}
