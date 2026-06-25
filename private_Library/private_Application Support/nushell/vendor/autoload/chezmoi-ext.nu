def chezmoi_ext_git_root_or_empty [] {
  let result = (^git rev-parse --show-toplevel | complete)
  if $result.exit_code != 0 {
    return ""
  }

  $result.stdout | str trim
}

def chezmoi_ext_source_root_or_empty [] {
  let result = (^chezmoi source-path | complete)
  if $result.exit_code != 0 {
    return ""
  }

  $result.stdout | str trim
}

def chezmoi_ext_in_source_repo [] {
  let git_root = (chezmoi_ext_git_root_or_empty)
  if $git_root == "" {
    return false
  }

  let source_root = (chezmoi_ext_source_root_or_empty)
  if $source_root == "" {
    return false
  }

  (($git_root | path expand) == ($source_root | path expand))
}

def chezmoi_ext_status_result [] {
  ^chezmoi status --no-pager --path-style relative --exclude templates | complete
}

def chezmoi_ext_status_lines [] {
  let result = (chezmoi_ext_status_result)
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

def chezmoi_ext_entry [line: string] {
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

def chezmoi_ext_entries [] {
  chezmoi_ext_status_lines
  | each {|line| chezmoi_ext_entry $line }
  | where {|entry| $entry != null }
}

def chezmoi_ext_counts [] {
  let entries = (chezmoi_ext_entries)

  {
    down: ($entries | where direction == "down" | length)
    up: ($entries | where direction == "up" | length)
    total: ($entries | length)
  }
}

def chezmoi_ext_target_path [path: string] {
  if ($path | str starts-with "/") {
    return $path
  }

  [$nu.home-dir $path] | path join
}

def chezmoi_ext_paths_by_direction [direction: string] {
  chezmoi_ext_entries
  | where direction == $direction
  | get path
  | each {|path| chezmoi_ext_target_path $path }
}

# Starship guard: succeeds only when the current directory is the chezmoi source repo.
# Intended for use by the custom Starship module `custom.chezmoi_diff`.
export def "chezmoi_ext_starship_when" [] {
  if (chezmoi_ext_in_source_repo) {
    exit 0
  }

  exit 1
}

# Starship renderer for chezmoi summary counts.
# Output format: ` !<total> ⇣<down> ⇡<up>`
# - Uses `chezmoi status --exclude templates` (no template fetches).
# - ⇣ includes any entry whose first status column is set (including `MM`).
# - ⇡ includes entries whose first column is blank and second is set.
export def "chezmoi_ext_starship_command" [] {
  let counts = (chezmoi_ext_counts)
  if $counts.total == 0 {
    exit 1
  }

  $" !($counts.total) ⇣($counts.down) ⇡($counts.up)"
}

def chezmoi_ext_source_files [] {
  let source_root = (chezmoi_ext_source_root_or_empty)
  if $source_root == "" {
    return []
  }

  let result = (^rg --files --hidden --follow --no-ignore $source_root | complete)
  if $result.exit_code != 0 {
    return []
  }

  $result.stdout
  | lines
  | where {|line| ($line | str trim) != "" }
  | each {|line| $line | path relative-to $source_root }
  | where {|relpath| not ($relpath | str starts-with ".git/") }
}

def chezmoi_ext_find_source_files [query: string] {
  let files = (chezmoi_ext_source_files)
  if ($files | is-empty) {
    return []
  }

  let trimmed_query = ($query | str trim)
  if $trimmed_query == "" {
    return $files
  }

  let result = (
    $files
    | str join (char nl)
    | ^fzf --filter $trimmed_query
    | complete
  )

  if $result.exit_code != 0 {
    return []
  }

  $result.stdout
  | lines
  | where {|line| ($line | str trim) != "" }
}

def chezmoi_ext_completion_last_token [context: string] {
  let parsed = ($context | parse -r '(?s)^(?:.*\s)?(?<partial>\S*)$')
  if (($parsed | length) == 0) {
    return ""
  }

  $parsed | get 0.partial
}



def "nu_complete chezmoi edit_file" [context: string] {
  let partial = (chezmoi_ext_completion_last_token $context)

  let completions = (
    chezmoi_ext_find_source_files $partial
    | each {|relpath|
        {
          value: $relpath
          description: $relpath
        }
      }
    | uniq-by value
  )

  {
    options: {
      case_sensitive: false,
      completion_algorithm: fuzzy,
    },
    completions: $completions
  }
}

# Easy chezmoi diff summary (path list, no line hunks).
# Prints one managed path per line with direction and index:
# - `[N] ⇡ <path>`: apply source to destination (`chezmoi apply <path>`)
# - `[N] ⇣ <path>`: re-add destination state to source (`chezmoi re-add <path>`)
# - Uses `chezmoi status --exclude templates` by default.
# `MM` entries are grouped under `⇣` by design.
#
# Optional index argument:
# - `chezmoi ediff <index>` runs `chezmoi diff` for just that target path.
export def "chezmoi ediff" [index?: int] {
  let entries = (chezmoi_ext_entries)
  if ($entries | is-empty) {
    return
  }

  if $index != null {
    if $index < 0 or $index >= ($entries | length) {
      error make --unspanned {
        msg: $"Invalid index: ($index). Use an index from 0 to (($entries | length) - 1)."
      }
    }

    let entry = ($entries | get $index)
    let target = (chezmoi_ext_target_path $entry.path)
    ^chezmoi diff -- $target
    return
  }

  $entries
  | enumerate
  | each {|row|
      let entry = $row.item
      let arrow = (if $entry.direction == "down" { "⇣" } else { "⇡" })
      $"[($row.index)] ($arrow) ($entry.path)"
    }
  | str join (char nl)
}

def chezmoi_ext_select_source_file [] {
  let files = (chezmoi_ext_source_files)
  if ($files | is-empty) {
    error make --unspanned {
      msg: "No source files found in the chezmoi source repo."
    }
  }

  let result = (
    $files
    | str join (char nl)
    | ^fzf --prompt "chezmoi edit> " --height 45% --layout reverse --border
    | complete
  )

  if $result.exit_code != 0 {
    return null
  }

  let selected = ($result.stdout | str trim)
  if $selected == "" {
    return null
  }

  $selected
}

# Open a source match in the target filesystem with Zed.
# - `chezmoi edit <query>` picks the first filtered source match.
# - `chezmoi edit` opens an interactive fzf picker over source files.
# - Selected source path is mapped with `chezmoi target-path`.
# - Opens target file with `zed_open --new`.
export def "chezmoi edit" [file?: string@"nu_complete chezmoi edit_file"] {
  let source_match = (
    if $file == null or (($file | str trim) == "") {
      chezmoi_ext_select_source_file
    } else {
      let matches = (chezmoi_ext_find_source_files $file)
      if ($matches | is-empty) {
        error make --unspanned {
          msg: $"No target file matched: ($file)"
        }
      }

      $matches | first
    }
  )

  if $source_match == null {
    return
  }

  let target = (^chezmoi target-path $source_match | str trim)
  if $target == "" {
    error make --unspanned {
      msg: $"Failed to resolve target path for source file: ($source_match)"
    }
  }

  zed_open $target --new
}

# Apply all `⇡` entries reported by `chezmoi ediff` in one command.
# Runs: `chezmoi apply -- ...<absolute destination paths>`
export def "chezmoi up" [] {
  let paths = (chezmoi_ext_paths_by_direction "up")
  if ($paths | is-empty) {
    return
  }

  ^chezmoi apply -- ...$paths
}

# Re-add all `⇣` entries reported by `chezmoi ediff` in one command.
# Runs: `chezmoi re-add -- ...<absolute destination paths>`
export def "chezmoi down" [] {
  let paths = (chezmoi_ext_paths_by_direction "down")
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
