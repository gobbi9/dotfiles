# Disable the startup banner
$env.config.show_banner = false

# PATH
let toolbox_path  = $"($nu.home-dir)/Library/Application Support/JetBrains/Toolbox/scripts"
let orbstack_path = $"($nu.home-dir)/.orbstack/bin"
let lmstudio_path = $"($nu.home-dir)/.lmstudio/bin"

$env.PATH = ($env.PATH | append "/opt/homebrew/bin")   # Homebrew
$env.PATH = ($env.PATH | append "/opt/homebrew/sbin")  # Homebrew
$env.PATH = ($env.PATH | append "/usr/local/bin")      # Common macOS user binaries
$env.PATH = ($env.PATH | append $orbstack_path)        # OrbStack, just symlinks, not sure if required
$env.PATH = ($env.PATH | append $toolbox_path)         # JetBrains Toolbox
$env.PATH = ($env.PATH | append $lmstudio_path)        # LM Studio CLI (lms)
$env.PATH = ($env.PATH | uniq | sort)                  # deduplicate PATH entries, mise has to be first

# Editors
let zed = "zed --wait"

$env.config.buffer_editor = ($zed | split row " ") # Editor for nushell
$env.EDITOR               =  $zed                  # Editor for command line tools
$env.VISUAL               =  $zed                  # Editor for visual tools
$env.GIT_EDITOR           =  $zed                  # Editor for git

# 1Password SSH socket
$env.SSH_AUTH_SOCK =  $"($nu.home-dir)/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
