# Dotfiles command hub for discovery.
#
# Behavior:
# - `dotfiles` returns top-level config commands, exported module commands, and aliases from `conf/aliases.nu`.
# - Commands are sorted by `command`.
# - Aliases are appended after definitions.

def dotfiles_modules_dirs [] {
  let default_modules_dir = ([$nu.default-config-dir "modules"] | path join)
  let loaded_modules_dir = (
    scope modules
    | where name == "dotfiles"
    | get 0?.file
    | if $in == null { null } else { $in | path dirname }
  )

  [$default_modules_dir $loaded_modules_dir]
  | where {|dir| $dir != null }
  | uniq
}


def dotfiles_aliases_file_path [] {
  [$nu.default-config-dir "conf" "aliases.nu"] | path join
}


def dotfiles_config_command_names [] {
  if not ($nu.config-path | path exists) {
    return []
  }

  open --raw $nu.config-path
  | lines
  | parse -r '^\s*def\s+(?:--env\s+)?(?<name>[^\s\[]+)'
  | get name
}


def dotfiles_command_module_rows [] {
  let modules_dirs = (dotfiles_modules_dirs)

  scope modules
  | where file != null
  | where {|mod| ($mod.file | str ends-with ".nu") and ($modules_dirs | any {|dir| $mod.file | str starts-with $dir }) }
  | each {|mod|
      let module_name = (
        $mod.file
        | path basename
        | str replace --regex '\.nu$' ''
      )

      $mod.commands
      | each {|cmd|
          {
            command: $cmd.name
            module: $module_name
          }
        }
    }
  | flatten
}


def dotfiles_module_for_command [name: string, command_modules: list<record<command: string, module: string>>] {
  $command_modules
  | where command == $name
  | get 0?.module
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
  let command_modules = (dotfiles_command_module_rows)

  scope commands
  | where type == custom
  | where {|cmd| not ($cmd.name =~ '_') }
  | each {|cmd|
      let module_name = (dotfiles_module_for_command $cmd.name $command_modules)
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

def dotfiles_config_exports [] {
  let config_command_names = (dotfiles_config_command_names)

  scope commands
  | where type == custom
  | where {|cmd| $config_command_names | any {|name| $name == $cmd.name } }
  | where {|cmd| not ($cmd.name =~ '_') }
  | each {|cmd|
      {
        module: "config"
        kind: "def"
        command: $cmd.name
        note: (dotfiles_first_doc_note $cmd.description?)
      }
    }
}


def dotfiles_alias_rows [] {
  let alias_file = (dotfiles_aliases_file_path)
  if not ($alias_file | path exists) {
    return []
  }

  ^cat $alias_file
  | lines
  | parse -r '^\s*alias\s+(?<name>[^\s=]+)\s*=\s*(?<target>.+?)\s*$'
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
  let defs = (
    (dotfiles_config_exports)
    | append (dotfiles_module_exports)
    | sort-by command
  )
  let aliases = (dotfiles_alias_rows)

  $defs | append $aliases
}

# Dotfiles command hub (discoverability only).
#
# Returns top-level config commands, exported module commands, and aliases from `conf/aliases.nu`.
# Aliases are listed at the end.
export def main [] {
  dotfiles_rows
}
