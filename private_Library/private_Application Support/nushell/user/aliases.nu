alias maven = mvn

alias c = pbcopy
alias v = pbpaste

# https://www.nushell.sh/book/configuration.html#macos-keeping-usr-bin-open-as-open
alias openn = open
alias open = ^open

alias r = reload

# Has to be a hardcoded alias, because overlay are scoped
# to inside a function if called from a function
# It works best when the overlay file has a module definition
alias o = overlay use --reload overlay.nu
