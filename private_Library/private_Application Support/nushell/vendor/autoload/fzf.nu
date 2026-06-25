export-env {
    $env.FZF_DEFAULT_COMMAND = "fd --type file --strip-cwd-prefix --hidden --follow --exclude .git"
    $env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
    $env.FZF_ALT_C_COMMAND = "fd --type directory --strip-cwd-prefix --hidden --follow --exclude .git"

    let fzf_dark = "bg+:-1,bg:-1,spinner:108,hl:110,fg:253,header:110,info:108,pointer:168,marker:168,fg+:254,prompt:109,hl+:110"
    let fzf_light = "bg+:-1,bg:-1,spinner:25,hl:24,fg:16,header:24,info:25,pointer:124,marker:124,fg+:16,prompt:25,hl+:24"

    let bg_index = (try {
        let raw = ($env.COLORFGBG? | default "" | str trim)
        if $raw == "" {
            null
        } else {
            $raw | split row ";" | last | str trim | into int
        }
    } catch {
        null
    })

    let fzf_palette = if ($bg_index != null and $bg_index < 8) {
        $fzf_dark
    } else if ($bg_index != null and $bg_index >= 8) {
        $fzf_light
    } else {
        # fallback
        $fzf_dark
    }

    let bat_dark_theme = "Catppuccin Mocha"
    let bat_light_theme = "Coldark-Cold"
    let bat_theme = if ($bg_index != null and $bg_index < 8) {
        $bat_dark_theme
    } else if ($bg_index != null and $bg_index >= 8) {
        $bat_light_theme
    } else {
        # fallback
        $bat_dark_theme
    }

    let preview_cmd = ("bat --color=always --style=plain --theme='" + $bat_theme + "' --line-range=:300 {}")

    $env.FZF_DEFAULT_OPTS = [
        "--height=80%"
        "--layout=reverse"
        "--border"
        $"--color=($fzf_palette)"
        $"--preview='($preview_cmd)'"
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
