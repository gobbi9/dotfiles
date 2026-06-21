# Custom overlay management, https://www.nushell.sh/book/overlays.html#overlays

# Manual overlay workflow:
# - Activate from repo root with: `o` (alias in aliases.nu)
# - Introspect exports with: `i`

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

let print_overlay_exports = {|module_path_display: string, exports: record|
  print $"Overlay commands for this repo, from (ansi green_bold)($module_path_display)(ansi reset)"
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

let print_overlay_inactive_hint = {||
  print $"(ansi orangered1)  Overlay not active  (ansi reset) Activate it from repo root with (ansi green_bold)o(ansi reset)."
  print ""
}

# Inspect overlay exports for the current repo (or a provided module path).
# Prints exported commands, aliases, and externs for fast discovery/help.
def "i" [
  cwd?: string # Optional directory to inspect. Defaults to the current $env.PWD.
  --module-path(-m): string = "overlay.nu" # Overlay module file path, relative to `cwd` by default.
] {
  let effective_cwd = if $cwd == null { ($env.PWD | default ".") } else { $cwd }

  let resolved_module_path = if ($module_path | str starts-with "/") {
    $module_path
  } else {
    $effective_cwd | path join $module_path
  }

  let module_path_display = if ($resolved_module_path | str starts-with $"($effective_cwd)/") {
    $"./($resolved_module_path | path relative-to $effective_cwd)"
  } else {
    $resolved_module_path
  }

  if not ($resolved_module_path | path exists) {
    error make --unspanned { msg: $"Overlay module not found: ($resolved_module_path)" }
  }

  let exports = (do $overlay_exports $resolved_module_path)

  let exported_names = (
    ($exports.exported.commands | default [])
    | append (($exports.exported.aliases | default []) | get -o name)
    | append ($exports.exported.externs | default [])
    | uniq
  )

  let is_active = (
    $exported_names
    | any {|name|
        let resolved = (which $name)
        if ($resolved | is-empty) {
          false
        } else {
          $resolved
          | any {|entry| (($entry.path? | default "") == $resolved_module_path) }
        }
      }
  )

  if not $is_active {
    do $print_overlay_inactive_hint
  }

  do $print_overlay_exports $module_path_display $exports

  if not $is_active {
    print ""
    do $print_overlay_inactive_hint
  }
}
