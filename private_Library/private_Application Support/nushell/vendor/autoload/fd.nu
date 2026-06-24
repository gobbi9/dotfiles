export-env {
    let ls_dark = "fi=0:di=94:ln=96:ex=92:or=91:mi=91"
    let ls_light = "fi=0:di=34:ln=36:ex=32:or=31:mi=31"

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

    $env.LS_COLORS = if ($bg_index != null and $bg_index < 8) {
        $ls_dark
    } else if ($bg_index != null and $bg_index >= 8) {
        $ls_light
    } else {
        # fallback
        $ls_dark
    }

    $env.FD_OPTIONS = "--hidden --follow --exclude .git --color=auto"
}
