alias maven = mvn
alias     r = reload
alias     g = git
alias     c = pbcopy
alias     v = pbpaste
alias     d = dotfiles
alias openn = open # https://www.nushell.sh/book/configuration.html#macos-keeping-usr-bin-open-as-open
alias  open = ^open
alias    hl = rg --passthru --color=always -F

# Has to be a hardcoded alias, because overlays are scoped
# to the shell or functions they are called from.
# `overlay.nu` could be called anything.
alias     o = overlay use --reload overlay.nu
