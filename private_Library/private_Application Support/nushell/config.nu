# config.nu
#
# Installed by:
# version = "0.112.2"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# Homebrew
$env.PATH = (
  $env.PATH | prepend "/opt/homebrew/bin" | prepend "/opt/homebrew/sbin"
)

# Common macOS user binaries
$env.PATH = (
  $env.PATH |append "/usr/local/bin"
)

# OrbStack, just symlinks, not sure if required
$env.PATH = (
    $env.PATH | append `~/.orbstack/bin`
)

# JetBrains Toolbox
$env.PATH = (
    $env.PATH | append `~/Library/Application Support/JetBrains/Toolbox/scripts`
)

# Disable the startup banner
$env.config.show_banner = false

# Editor for nu
$env.config.buffer_editor = ["zed", "--wait"]

# Editors for external tools like git
$env.EDITOR = "zed --wait"
$env.VISUAL = "zed --wait"
$env.GIT_EDITOR = "zed --wait"

# 1Password SSH socket
$env.SSH_AUTH_SOCK =  $"($nu.home-dir)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Added by LM Studio CLI (lms)
$env.PATH = ($env.PATH | append ($nu.home-dir | path join '.lmstudio' 'bin'))

# aliases
alias maven = mvn
alias c = pbcopy
alias v = pbpaste
# https://www.nushell.sh/book/configuration.html#macos-keeping-usr-bin-open-as-open
alias openn = open
alias open = ^open

# open files in Zed, optionally forcing a new window
# usage: zed-open <path> [--new(-n)]
def zed-open [target: string, --new(-n)] {
  if $new {
    ^zed -n $target
  } else {
    ^zed $target
  }
}

# compress a .pdf using ghostscript: pdf compres input output [quality]
def "pdf compress" [
  input: string
  output: string
  quality: string = "screen"
] {
  ^gs -q -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dSAFER $"(-dPDFSETTINGS=/($quality))" -dCompatibilityLevel=1.4 $"(-sOutputFile=($output))" $input
}

# compress, auto-rotate and deskew a .pdf file using ocrmypdf: "pdf optimize" file (in-place)
def "pdf optimize" [file: string] {
  ^ocrmypdf -l 'deu+por' --rotate-pages --deskew --optimize 3 --clean --clean-final --unpaper-args '--layout single --no-blackfilter --no-grayfilter' --tesseract-timeout 0 $file $file
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

# restart Nu in-place (replaces current process; avoids nested subshell)
def reload [] {
  exec nu
}

# run closures in sequence (bash-like && chaining for externals)
def then [...steps: closure] {
  for step in $steps {
    do $step
  }
}

# uuid lowercase without newline
def uuid [] {
  ^uuidgen | str trim | str downcase
}

# ffmpeg x265: output next to input as "<stem>-x265.mp4"
def x265 [input: string] {
  let p = ($input | path parse)
  let out = ($p.parent | path join $"($p.stem)-x265.mp4")
  ^ffmpeg -i $input -c:v libx265 -crf 26 -preset fast -c:a aac -b:a 320k $out
}

# enable sudo touchID, this setting is removed after every MacOS update
def enable-touchid-sudo [] {
    let sudo_pam = "/etc/pam.d/sudo"
    let touchid_line = "auth       sufficient     pam_tid.so"

    let contents = (sudo cat $sudo_pam)

    if ($contents | str contains "pam_tid.so") {
        print "✅ Touch ID for sudo is already enabled."
        return
    }

    print "🔧 Enabling Touch ID for sudo..."

    # Create backup
    sudo cp $sudo_pam $"($sudo_pam).backup"

    # Create updated content
    let new_contents = ($touchid_line + "\n" + $contents)

    # Write atomically through temp file
    let tmp = (mktemp)

    $new_contents | save -f $tmp

    sudo mv $tmp $sudo_pam

    print "✅ Touch ID enabled for sudo."
    print $"📦 Backup saved to ($sudo_pam).backup"
}

# import mcp-install function
use `~/projects/mcp/generate-mcp.nu`
use `~/projects/mcp/mcp-install.nu`

# GH CLI wrapper
def --wrapped gh [...args] {
    let gh_token = (^op read --no-newline "op://Personal/gh-cli/token")
    with-env { GH_TOKEN: $gh_token } {
        ^gh ...$args
    }
}

# import scans function
use `~/projects/scans/scans`
