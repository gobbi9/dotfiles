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
