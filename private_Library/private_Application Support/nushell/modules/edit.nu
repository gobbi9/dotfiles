# Open files in Zed, optionally forcing a new window.
export def "zed open" [target: string, --new(-n)] {
  if $new {
    ^zed -n $target
  } else {
    ^zed $target
  }
}

# Completion for mise env config names (config.<env>.toml).
def mise_envs_completions [_context: string] {
  ls -a ($nu.home-dir | path join ".config" "mise")
  | where type == file
  | get name
  | path basename
  | where {|n| $n =~ '^config\..+\.toml$' and $n != 'config.local.toml'}
  | parse 'config.{env}.toml'
  | get env
  | uniq
  | sort
}

# Open Nushell config in Zed.
export def "edit config" [--new(-n)] {
  zed open $nu.config-path --new=$new
}

# Open Nushell login in Zed.
export def "edit login" [--new(-n)] {
  zed open $nu.loginshell-path --new=$new
}

# Open Nushell env in Zed (deprecated).
export def "edit env" [--new(-n)] {
  zed open $nu.env-path --new=$new
}

# Open starship config in Zed.
export def "edit starship" [--new(-n)] {
  zed open ($nu.home-dir | path join ".config" "starship.toml") --new=$new
}

# Open zsh config in Zed.
export def "edit zsh" [--new(-n)] {
  zed open ($nu.home-dir | path join ".zshrc") --new=$new
}

# Edit user mise config.
export def "edit mise" [--new(-n)] {
  zed open ($nu.home-dir | path join ".config" "mise" "config.toml") --new=$new
}

# Edit user miserc.toml.
export def "edit miserc" [--new(-n)] {
  zed open ($nu.home-dir | path join ".config" "mise" "miserc.toml") --new=$new
}

# Edit user mise env config.
export def "edit mise env" [env_name: string@mise_envs_completions, --new(-n)] {
  zed open ($nu.home-dir | path join ".config" "mise" $"config.($env_name).toml") --new=$new
}
