# Custom overlay management, https://www.nushell.sh/book/overlays.html#overlays

# Parse-time bootstrap for overlay names used in `overlay hide`,
# duplication necessary due to nushell's overlay module resolution behavior.
overlay use ~/projects/emails/scripts/commands.nu as cf_commands
overlay use ~/projects/opensockets/mcpd/overlay.nu as mcpd_commands

# Project overlays (add more entries here as needed)
let project_overlays = [
  {
    repo: $"($nu.home-dir)/projects/emails"
    module_path: $"($nu.home-dir)/projects/emails/scripts/commands.nu"
    enable: {|| overlay use ~/projects/emails/scripts/commands.nu as cf_commands }
    disable: {|| overlay hide "cf_commands" }
  }
  {
    repo: $"($nu.home-dir)/projects/opensockets/mcpd"
    module_path: $"($nu.home-dir)/projects/opensockets/mcpd/overlay.nu"
    enable: {|| overlay use ~/projects/opensockets/mcpd/overlay.nu as mcpd_commands }
    disable: {|| overlay hide "mcpd_commands" }
  }
]

# ------------------ Querying the overlay file ------------------

# Parse an overlay module file and extract exported commands, aliases, and externs.
# Used by `i` to show quick, human-readable overlay introspection.
let overlay_exports = {|module_path: string|
  if not ($module_path | path exists) {
    error make --unspanned { msg: $"Overlay module not found: ($module_path)" }
  }

  let src_lines = (^cat $module_path | lines)

  let commands = (
    $src_lines
    | parse -r '^\s*export\s+def(?:\s+--[A-Za-z0-9_-]+)*\s+(?<name>"[^"]+"|[A-Za-z0-9_-]+)'
    | get name
    | each {|name| $name | str replace -a '"' '' }
  )

  let aliases = (
    $src_lines
    | parse -r '^\s*export\s+alias\s+(?<name>[A-Za-z0-9_-]+)\s*=\s*(?<target>.+?)\s*$'
  )

  let externs = (
    $src_lines
    | parse -r '^\s*export\s+extern\s+(?<name>"[^"]+"|[A-Za-z0-9_-]+)'
    | get name
    | each {|name| $name | str replace -a '"' '' }
  )

  {
    module_path: $module_path
    exported: {
      commands: $commands
      aliases: $aliases
      externs: $externs
    }
  }
}

let format_inline_list = {|items: list<string>|
  if ($items | is-empty) {
    "[]"
  } else {
    $"[($items | str join ', ')]"
  }
}

let in_overlay_repo = {|cwd: string, repo: string|
  ($cwd == $repo) or ($cwd | str starts-with $"($repo)/")
}

let current_project_overlay = {|cwd: string|
  $project_overlays
  | where {|overlay_def| do $in_overlay_repo $cwd $overlay_def.repo }
  | first
}

# Inspect overlay exports for the current repo (or a provided module path).
# Prints exported commands, aliases, and externs for fast discovery/help.
def "i" [
  cwd?: string # Optional directory to inspect. Defaults to the current $env.PWD.
  --module-path(-m): string # Inspect this overlay module file directly instead of resolving from project_overlays.
] {
  let effective_cwd = if $cwd == null { ($env.PWD | default "") } else { $cwd }

  let resolved = if $module_path == null {
    let overlay_def = (do $current_project_overlay $effective_cwd)

    if $overlay_def == null {
      error make --unspanned { msg: "No project overlay configured for current directory." }
    }

    {
      repo: ($overlay_def | get repo)
      module_path: ($overlay_def | get module_path)
    }
  } else {
    {
      repo: $effective_cwd
      module_path: $module_path
    }
  }

  let repo = ($resolved | get repo)
  let resolved_module_path = ($resolved | get module_path)

  let module_path_display = if ($resolved_module_path | str starts-with $"($effective_cwd)/") {
    $"./($resolved_module_path | path relative-to $effective_cwd)"
  } else if ($resolved_module_path | str starts-with $"($repo)/") {
    $"./($resolved_module_path | path relative-to $repo)"
  } else {
    $resolved_module_path
  }

  let exports = (do $overlay_exports $resolved_module_path)

  print $"(ansi cyan)Overlay commands for this repo, from(ansi reset) (ansi green_bold)($module_path_display)(ansi reset)"
  print ""
  if ($exports.exported.commands | is-empty) {
    print $"(ansi yellow)commands:(ansi reset) (ansi green)[](ansi reset)"
  } else {
    print $"(ansi yellow)commands:(ansi reset)"

    for command_name in $exports.exported.commands {
      print $"  (ansi green)($command_name)(ansi reset)"
    }
  }

  if ($exports.exported.aliases | is-empty) {
    print $"(ansi yellow)aliases:(ansi reset) (ansi green)[](ansi reset)"
  } else {
    print $"(ansi yellow)aliases:(ansi reset)"

    for alias_def in $exports.exported.aliases {
      print $"  (ansi cyan)($alias_def.name)(ansi reset): (ansi green)($alias_def.target)(ansi reset)"
    }
  }

  print $"(ansi yellow)externs:(ansi reset) (ansi green)(do $format_inline_list $exports.exported.externs)(ansi reset)"
  print ""
  print $"(ansi steelblue1a)  Type help <command | alias | extern> for more info.(ansi reset)"
}

# ------------------ Overlays' synchronization ------------------

# Overlays are not loaded from a directory automatically,
# so we need to sync them manually when the PWD changes.
# Only the overlays for the current directory are enabled at a time, so we disable all others first.
let sync_project_overlays = {|cwd: string|
  for overlay_def in $project_overlays {
    if (do $in_overlay_repo $cwd $overlay_def.repo) {
      do $overlay_def.enable
    } else {
      do $overlay_def.disable
    }
  }
}

# Directory change hook to sync project overlays
$env.config = ($env.config | upsert hooks.env_change.PWD (
  ($env.config | get -o hooks.env_change.PWD | default [])
  | append { |before, after|
      do $sync_project_overlays ($after | default "")
    }
))

# On shell startup, load correct overlays for the current directory
do $sync_project_overlays ($env.PWD | default "")
