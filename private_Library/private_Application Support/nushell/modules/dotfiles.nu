# Dotfiles command hub for discovery and quick commandline insertion.
#
# Behavior:
# - `dotfiles` prints shortcuts and exported module commands.
# - `dotfiles <...>` does not execute anything; it replaces the current
#   commandline with the mapped real command (or prints it in non-interactive mode).

def dotfiles_module_for_command [name: string] {
  if ($name | str starts-with "edit ") or $name == "zed_open" {
    return "edit"
  }

  if ($name | str starts-with "macos icons ") {
    return "app-icons"
  }

  if ($name | str starts-with "pdf ") {
    return "pdf"
  }

  if $name == "macos touchid sudo" {
    return "touchid-sudo"
  }

  if $name == "op push" {
    return "op-push"
  }

  if $name == "zed sync" {
    return "zed-sync"
  }

  if $name == "macos settings sync" {
    return "macos-settings-sync"
  }

  if $name == "loop" {
    return "loop"
  }

  if $name == "gh" {
    return "gh-cli"
  }

  if $name == "i" {
    return "overlays"
  }

  if $name == "dotfiles" {
    return "dotfiles"
  }

  null
}

def dotfiles_module_exports [] {
  scope commands
  | where type == custom
  | each {|cmd|
      let module_name = (dotfiles_module_for_command $cmd.name)
      if $module_name == null {
        null
      } else {
        {
          module: $module_name
          kind: "def"
          command: $cmd.name
        }
      }
    }
  | where {|row| $row != null }
  | sort-by module command
}

def dotfiles_shortcuts [] {
  [
    { shortcut: "macos touchid sudo", runs: "macos touchid sudo", module: "touchid-sudo.nu", note: "Enable Touch ID for sudo" }
    { shortcut: "pdf", runs: "pdf", module: "pdf.nu", note: "PDF utilities" }
    { shortcut: "edit", runs: "edit", module: "edit.nu", note: "Edit config files" }
    { shortcut: "zed", runs: "zed sync", module: "zed-sync.nu", note: "Sync Zed settings/extensions" }
    { shortcut: "macos settings", runs: "macos settings sync", module: "macos-settings-sync.nu", note: "Sync macOS settings" }
    { shortcut: "macos icons", runs: "macos icons", module: "app-icons.nu", note: "Apply custom app icons" }
    { shortcut: "op push", runs: "op push", module: "op-push.nu", note: "Push templates to 1Password" }
    { shortcut: "loop", runs: "loop", module: "loop.nu", note: "Keep-awake helper" }
  ]
}

def dotfiles_tokens [context: string] {
  $context
  | str trim
  | split row " "
  | where {|token| $token != "" }
}

def dotfiles_shortcut_completer [_context: string] {
  dotfiles_shortcuts
  | each {|entry|
      let first = ($entry.shortcut | split row " " | first)
      {
        value: $first
        description: $"($entry.note) → ($entry.runs)"
      }
    }
  | uniq-by value
  | sort-by value
}

def dotfiles_edit_subcommands [] {
  dotfiles_module_exports
  | where module == "edit"
  | where command =~ '^edit\s+'
  | get command
  | each {|cmd|
      let sub = ($cmd | split row " " | skip 1 | str join " ")
      {
        value: $sub
        description: $"Use `($cmd)`"
      }
    }
  | where value != ""
  | sort-by value
}

def dotfiles_pdf_subcommands [] {
  dotfiles_module_exports
  | where module == "pdf"
  | where command =~ '^pdf\s+'
  | get command
  | each {|cmd|
      let sub = ($cmd | split row " " | skip 1 | str join " ")
      {
        value: $sub
        description: $"Use `($cmd)`"
      }
    }
  | where value != ""
  | sort-by value
}

def dotfiles_macos_icons_subcommands [] {
  dotfiles_module_exports
  | where module == "app-icons"
  | where command =~ '^macos\s+icons\s+'
  | get command
  | each {|cmd|
      let sub = ($cmd | split row " " | skip 2 | str join " ")
      {
        value: $sub
        description: $"Use `($cmd)`"
      }
    }
  | where value != ""
  | sort-by value
}

def dotfiles_subcommand_completer [context: string] {
  let tokens = (dotfiles_tokens $context)
  let shortcut = ($tokens | get 1? | default "")

  match $shortcut {
    "pdf" => { dotfiles_pdf_subcommands }
    "edit" => { dotfiles_edit_subcommands }
    "macos" => {
      [
        { value: "settings", description: "Use `macos settings sync`" }
        { value: "icons", description: "Use `macos icons ...`" }
        { value: "touchid", description: "Use `macos touchid sudo`" }
      ]
    }
    "op" => {
      [
        { value: "push", description: "Use `op push`" }
      ]
    }
    "zed" => {
      [
        { value: "sync", description: "Use `zed sync`" }
      ]
    }
    _ => { [] }
  }
}

def dotfiles_target_completer [context: string] {
  let tokens = (dotfiles_tokens $context)
  let shortcut = ($tokens | get 1? | default "")
  let sub = ($tokens | get 2? | default "")

  if $shortcut == "macos" and $sub == "icons" {
    return (dotfiles_macos_icons_subcommands)
  }

  if $shortcut == "edit" and $sub == "mise" {
    return [
      { value: "env", description: "Use `edit mise env <env_name>`" }
    ]
  }

  []
}

def dotfiles_usage [] {
  [
    { usage: "dotfiles", description: "Show exported module commands and shortcut mappings" }
    { usage: "dotfiles macos touchid sudo", description: "Insert: macos touchid sudo" }
    { usage: "dotfiles pdf <sub>", description: "Insert: pdf <sub>" }
    { usage: "dotfiles edit <sub>", description: "Insert: edit <sub>" }
    { usage: "dotfiles zed", description: "Insert: zed sync" }
    { usage: "dotfiles macos settings", description: "Insert: macos settings sync" }
    { usage: "dotfiles macos icons <sub>", description: "Insert: macos icons <sub>" }
    { usage: "dotfiles op push", description: "Insert: op push" }
    { usage: "dotfiles loop", description: "Insert: loop" }
  ]
}

def dotfiles_show_overview [] {
  print $"(ansi cyan_bold)Proxy shortcuts(ansi reset)"
  print ((dotfiles_shortcuts | sort-by shortcut) | table)
  print ""
  print $"(ansi cyan_bold)Exported module commands(ansi reset)"
  print ((dotfiles_module_exports | sort-by command) | table)
}

def dotfiles_suggest_command [shortcut: string, sub?: string, target?: string, ...args: string] {
  let pieces = ([$sub, $target] | append $args | where {|v| $v != null })

  match $shortcut {
    "macos" => {
      if ($pieces | length) >= 2 and (($pieces | first) == "touchid") and (($pieces | get 1) == "sudo") {
        "macos touchid sudo"
      } else if ($pieces | is-empty) {
        "macos"
      } else {
        let first = ($pieces | first)
        let tail = ($pieces | skip 1)
        if $first == "settings" {
          "macos settings sync"
        } else {
          ["macos", $first] | append $tail | str join " "
        }
      }
    }
    "pdf" => { if ($pieces | is-empty) { "pdf" } else { ["pdf"] | append $pieces | str join " " } }
    "edit" => { if ($pieces | is-empty) { "edit" } else { ["edit"] | append $pieces | str join " " } }
    "zed" => { if ($pieces | is-empty) { "zed sync" } else { ["zed"] | append $pieces | str join " " } }

    "op" => { if ($pieces | is-empty) { "op" } else { ["op"] | append $pieces | str join " " } }
    "loop" => { "loop" }
    _ => { "" }
  }
}

def dotfiles_replace_or_print [cmd: string] {
  if ($cmd | is-empty) {
    print ((dotfiles_usage) | table)
    return
  }

  if ($nu.is-interactive? | default false) {
    try {
      commandline edit --replace $cmd
    } catch {
      print $cmd
    }
  } else {
    print $cmd
  }
}

# Dotfiles command hub (discoverability only).
#
# - `dotfiles` shows shortcut + exported command tables.
# - `dotfiles ...` inserts the mapped command into the commandline.
#   It does not execute proxied commands.
export def --wrapped main [
  shortcut?: string@dotfiles_shortcut_completer
  sub?: string@dotfiles_subcommand_completer
  target?: string@dotfiles_target_completer
  ...args: string
] {
  if $shortcut == null {
    dotfiles_show_overview
    return
  }

  let cmd = (dotfiles_suggest_command $shortcut $sub $target ...$args)
  dotfiles_replace_or_print $cmd
}
