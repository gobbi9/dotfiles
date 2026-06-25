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

def chezmoi_ext_source_root [] {
  let source_root = (chezmoi_ext_source_root_or_empty)
  if $source_root == "" {
    error make --unspanned {
      msg: "Failed to resolve chezmoi source root."
    }
  }

  $source_root
}

def chezmoi_ext_history_lines [source_root: string] {
  let result = (
    ^git --no-pager -C $source_root log --name-status --diff-filter=DR --pretty=format: --
    | complete
  )

  if $result.exit_code != 0 {
    error make --unspanned {
      msg: "Failed to read chezmoi source git history."
      label: {
        text: ($result.stderr | str trim)
      }
    }
  }

  $result.stdout
  | lines
  | where {|line| ($line | str trim) != "" }
}

def chezmoi_ext_history_event [line: string] {
  let cols = ($line | split row (char tab))
  let status = ($cols | get 0? | default "")

  if (($status | str starts-with "D") and (($cols | length) >= 2)) {
    return {
      event: "deleted"
      old_source_rel: ($cols | get 1)
      new_source_rel: null
    }
  }

  if (($status | str starts-with "R") and (($cols | length) >= 3)) {
    return {
      event: "renamed"
      old_source_rel: ($cols | get 1)
      new_source_rel: ($cols | get 2)
    }
  }

  null
}

def chezmoi_ext_decode_source_component [part: string] {
  mut value = $part

  for prefix in ["private_" "encrypted_" "readonly_" "executable_" "create_" "modify_" "remove_" "exact_" "empty_" "literal_"] {
    if ($value | str starts-with $prefix) {
      let start = ($prefix | str length)
      $value = ($value | str substring $start..)
    }
  }

  let is_dot = ($value | str starts-with "dot_")
  if $is_dot {
    $value = ($value | str substring 4..)
  }

  if ($value | str ends-with ".tmpl") {
    let end = (($value | str length) - 5)
    $value = ($value | str substring ..$end)
  }

  if $is_dot {
    $".($value)"
  } else {
    $value
  }
}

def chezmoi_ext_source_rel_to_target_rel [source_rel: string] {
  $source_rel
  | split row "/"
  | each {|part| chezmoi_ext_decode_source_component $part }
  | str join "/"
}

def chezmoi_ext_current_target_paths [] {
  let source_root = (chezmoi_ext_source_root)

  chezmoi_ext_source_files
  | each {|rel|
      let source_abs = ($source_root | path join $rel)
      let result = (^chezmoi target-path $source_abs | complete)
      if $result.exit_code != 0 {
        null
      } else {
        $result.stdout | str trim
      }
    }
  | where {|path| $path != null and $path != "" }
  | uniq
}

def chezmoi_ext_dangling_rows [] {
  let source_root = (chezmoi_ext_source_root)
  let events = (
    chezmoi_ext_history_lines $source_root
    | each {|line| chezmoi_ext_history_event $line }
    | where {|event| $event != null }
  )

  if ($events | is-empty) {
    return []
  }

  let old_rows = (
    $events
    | group-by old_source_rel
    | transpose old_source_rel matches
    | each {|row|
        let renamed = ((($row.matches | where event == "renamed") | get 0?) | default null)
        let chosen = if $renamed == null { $row.matches | first } else { $renamed }
        let target_rel = (chezmoi_ext_source_rel_to_target_rel $row.old_source_rel)
        let target = [$nu.home-dir $target_rel] | path join
        {
          kind: "file"
          event: $chosen.event
          source_rel: $row.old_source_rel
          source_dir: ($row.old_source_rel | path dirname)
          moved_to: ($chosen.new_source_rel | default "")
          target: $target
          target_dir: ($target | path dirname)
          still_exists_in_home: ($target | path exists)
        }
      }
  )

  let stale_files = ($old_rows | where still_exists_in_home)

  let current_targets = (chezmoi_ext_current_target_paths)

  let stale_dirs = (
    $old_rows
    | group-by target_dir
    | transpose target_dir matches
    | each {|row|
        let has_renamed = ($row.matches | any {|m| $m.event == "renamed" })
        let source_dir = (($row.matches | get 0).source_dir)
        let dir_prefix = $"($row.target_dir)/"
        let has_current_managed = (
          $current_targets
          | any {|t| $t == $row.target_dir or ($t | str starts-with $dir_prefix) }
        )

        {
          kind: "directory"
          event: (if $has_renamed { "renamed-dir" } else { "deleted-dir" })
          source_rel: $source_dir
          moved_to: ""
          target: $row.target_dir
          exists: ($row.target_dir | path exists)
          is_dir: (if ($row.target_dir | path exists) { (($row.target_dir | path type) == "dir") } else { false })
          has_current_managed: $has_current_managed
          is_home_dir: ($row.target_dir == $nu.home-dir)
          has_source_dir: ($source_dir != "" and $source_dir != ".")
        }
      }
    | where {|row| $row.exists and $row.is_dir and (not $row.has_current_managed) and (not $row.is_home_dir) and $row.has_source_dir }
    | select kind event source_rel moved_to target
  )

  $stale_files
  | select kind event source_rel moved_to target
  | append $stale_dirs
  | uniq-by kind target
  | sort-by kind target
}

def chezmoi_ext_prune_rows [rows: table, dry_run: bool] {
  if ($rows | is-empty) {
    return []
  }

  let plan = (chezmoi_ext_prune_plan $rows)
  if ($plan | is-empty) {
    return []
  }

  if $dry_run {
    return (
      $plan
      | each {|step|
          {
            action: "would-delete"
            kind: $step.kind
            target: $step.target
          }
        }
    )
  }

  $plan
  | each {|step|
      if $step.kind == "file" {
        if ($step.target | path exists) and (($step.target | path type) == "file") {
          rm --force $step.target
        }
      } else {
        if ($step.target | path exists) and (($step.target | path type) == "dir") {
          rm --recursive --force $step.target
        }
      }

      {
        action: "deleted"
        kind: $step.kind
        target: $step.target
      }
    }
}

def chezmoi_ext_validate_prune_target [target: string] {
  let normalized = ($target | path expand)
  let home = ($nu.home-dir | path expand)
  let home_prefix = $"($home)/"

  if not ($normalized | str starts-with $home_prefix) {
    error make --unspanned {
      msg: $"Refusing to prune path outside $nu.home-dir: ($normalized)"
    }
  }

  if $normalized == $home {
    error make --unspanned {
      msg: "Refusing to prune $nu.home-dir directly."
    }
  }

  $normalized
}

def chezmoi_ext_prune_plan [rows: table] {
  let files = (
    $rows
    | where kind == "file"
    | each {|row|
        {
          kind: "file"
          target: (chezmoi_ext_validate_prune_target $row.target)
        }
      }
    | uniq-by target
  )

  let directories = (
    $rows
    | where kind == "directory"
    | each {|row|
        let target = (chezmoi_ext_validate_prune_target $row.target)
        {
          kind: "directory"
          target: $target
          depth: (($target | split row "/") | length)
        }
      }
    | uniq-by target
    | sort-by depth -r
    | select kind target
  )

  $files | append $directories
}

# List dangling entries, or prune them.
# - `chezmoi dangling` lists entries.
# - `chezmoi dangling prune` deletes files first, then directories (deepest-first).
# - Use `--dry-run` with `prune` to preview removals.
export def "chezmoi dangling" [action?: string, --dry-run(-n)] {
  let rows = (chezmoi_ext_dangling_rows)

  if $action == null {
    return $rows
  }

  if $action != "prune" {
    error make --unspanned {
      msg: $"Unsupported subcommand: '($action)'. Use `chezmoi dangling` or `chezmoi dangling prune`."
    }
  }

  chezmoi_ext_prune_rows $rows $dry_run
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
