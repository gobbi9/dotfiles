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

# Restart Nu in-place (replaces current process; avoids nested subshell)
def reload [] {
  exec nu
}

# Generate an UUID lowercase without newline
def uuid [] {
  ^uuidgen | str trim | str downcase
}

# External modules
use modules/edit.nu *                # `edit` commands for misc config
use modules/gh-cli.nu *              # GitHub CLI wrappers
use modules/overlays.nu *            # Custom overlay management
use modules/macos-app-icons.nu *     # App icon override helpers
use modules/macos-touchid-sudo.nu *  # Enable sudo touchID
use modules/pdf.nu *                 # Pdf utilities
use modules/macos-settings-sync.nu * # macOS settings sync helpers
use modules/op-push.nu *             # Push onepasswordRead template targets into 1Password
use modules/zed-sync.nu *            # Sync installed Zed extensions and Zed config
use modules/loop.nu *                # Keep-awake loop helper
use modules/chezmoi-ext.nu *         # Chezmoi helper commands
use modules/dotfiles.nu *            # Dotfiles command hub / command discovery

# External custom user config files
source conf/env.nu                   # Environment variables
source conf/aliases.nu               # Aliases, set after modules they can target module commands

# Import custom functions for global use
use `~/projects/mcp/mcp.nu` *        # Local MCP infrastructure: `mcp install` and `mcp generate`
use `~/projects/scans/scans`         # Pdf splitting and tagging
