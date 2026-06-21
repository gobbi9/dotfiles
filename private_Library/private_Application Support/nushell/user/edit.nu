# open files in Zed, optionally forcing a new window
# usage: zed-open <path> [--new(-n)]
def zed-open [target: string, --new(-n)] {
  if $new {
    ^zed -n $target
  } else {
    ^zed $target
  }
}

# open nushell config in Zed
def "edit config" [--new(-n)] {
  zed-open ($nu.config-path) --new=$new
}

# open nushell login in Zed
def "edit login" [--new(-n)] {
  zed-open ($nu.loginshell-path) --new=$new
}

# open nushell env in Zed (deprecated)
def "edit env" [--new(-n)] {
  zed-open ($nu.env-path) --new=$new
}

# open starship config in Zed
def "edit starship" [--new(-n)] {
    zed-open $"(($env.HOME)/.config/starship.toml)" --new=$new
}

# open zsh config in Zed
def "edit zsh" [--new(-n)] {
    zed-open $"(($env.HOME)/.zshrc)" --new=$new
}

# edit user mise config
def "edit mise" [--new(-n)] {
    zed-open $"(($env.HOME)/.config/mise/config.toml)" --new=$new
}

# edit user miserc.toml
def "edit miserc" [--new(-n)] {
    zed-open $"(($env.HOME)/.config/mise/miserc.toml)" --new=$new
}

# completions for mise env config names (config.<env>.toml)
def "--mise envs" [context: string] {
    ls -a ($env.HOME | path join ".config" "mise")
    | where type == file
    | get name
    | path basename
    | where {|n| $n =~ '^config\..+\.toml$' and $n != 'config.local.toml'}
    | parse 'config.{env}.toml'
    | get env
    | uniq
    | sort
}

# edit user mise env config
def "edit mise env" [env_name: string@"--mise envs", --new(-n)] {
    zed-open $"(($env.HOME)/.config/mise/config.($env_name).toml)" --new=$new
}
