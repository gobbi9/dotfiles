export-env {
    $env.FZF_DEFAULT_COMMAND = "fd --type file --strip-cwd-prefix --hidden --follow --exclude .git"
    $env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
    $env.FZF_ALT_C_COMMAND = "fd --type directory --strip-cwd-prefix --hidden --follow --exclude .git"

    $env.FZF_DEFAULT_OPTS = [
        "--height=80%"
        "--layout=reverse"
        "--border"
        "--preview='bat --color=always --style=plain --line-range=:300 {}'"
        "--bind=ctrl-/:toggle-preview"
    ] | str join " "
}

def fzf-files [] {
    fd --type file --strip-cwd-prefix --hidden --follow --exclude .git | fzf
}

def --env fzf-cd [] {
    let picked = (fd --type directory --strip-cwd-prefix --hidden --follow --exclude .git | fzf)
    if ($picked | is-not-empty) {
        cd $picked
    }
}
