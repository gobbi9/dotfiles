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

# restart Nu in-place (replaces current process; avoids nested subshell)
def reload [] {
  exec nu
}

# uuid lowercase without newline
def uuid [] {
  ^uuidgen | str trim | str downcase
}

# ---- External custom user config files ----
source conf/env.nu     # Environment variables
source conf/aliases.nu # Aliases

# ---- External modules ----
use modules/edit.nu *         # `edit` commands for misc config
use modules/gh-cli.nu *       # GitHub CLI wrappers
use modules/overlays.nu *     # Custom overlay management
use modules/app-icons.nu *    # App icon override helpers
use modules/touchid-sudo.nu * # Enable sudo touchID
use modules/pdf.nu *          # Pdf utilities

# ---- Import custom functions for global use ----
use `~/projects/mcp/generate-mcp.nu`
use `~/projects/mcp/mcp-install.nu`
use `~/projects/scans/scans`
