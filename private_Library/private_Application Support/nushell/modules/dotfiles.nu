# Dotfiles command hub for discovery.
#
# Behavior:
# - `dotfiles` returns exported module commands and aliases from `conf/aliases.nu`.
# - Commands are sorted by `command`.
# - Aliases are appended after exported commands.

def dotfiles_module_for_command [name: string] {
  if ($name | str starts-with "edit ") or $name == "zed_open" {
    return "edit"
  }

  if ($name | str starts-with "macos icons ") {
    return "macos-app-icons"
  }

  if ($name | str starts-with "pdf ") {
    return "pdf"
  }

  if $name == "macos touchid sudo" {
    return "macos-touchid-sudo"
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

  if ($name | str starts-with "chezmoi ") {
    return "chezmoi-ext"
  }

  if $name == "dotfiles" {
    return "dotfiles"
  }

  null
}

def dotfiles_first_doc_note [description?: string] {
  if $description == null {
    return ""
  }

  let doc = ($description | str trim)
  if $doc == "" {
    return ""
  }

  let first_line = (
    $doc
    | lines
    | where {|line| ($line | str trim) != "" }
    | first
    | str trim
  )

  let sentence = (
    $first_line
    | parse -r '^(?<sentence>.*?[.!?])(?:\s|$)'
    | get 0?.sentence
    | default ""
    | str trim
  )

  if $sentence == "" { $first_line } else { $sentence }
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
          note: (dotfiles_first_doc_note $cmd.description?)
        }
      }
    }
  | where {|row| $row != null }
  | sort-by command
}

def dotfiles_aliases_file_path [] {
  [$nu.home-dir "Library/Application Support/nushell/conf/aliases.nu"] | path join
}

def dotfiles_alias_rows [] {
  let alias_file = (dotfiles_aliases_file_path)
  if not ($alias_file | path exists) {
    return []
  }

  ^cat $alias_file
  | lines
  | parse -r '^\s*alias\s+(?<name>[A-Za-z0-9_-]+)\s*=\s*(?<target>.+?)\s*$'
  | each {|row|
      {
        module: "aliases"
        kind: "alias"
        command: $row.name
        note: (($row.target | split row "#" | first) | str trim)
      }
    }
  | sort-by command
}

def dotfiles_rows [] {
  let defs = (dotfiles_module_exports)
  let aliases = (dotfiles_alias_rows)

  $defs | append $aliases
}

# Dotfiles command hub (discoverability only).
#
# Returns exported module commands plus aliases from `conf/aliases.nu`.
# Aliases are listed at the end.
export def main [] {
  dotfiles_rows
}
