export-env {
    $env.BAT_CONFIG_PATH = $"($nu.home-dir)/Library/Application Support/nushell/vendor/autoload/bat.conf"
    # Use bat as MANPAGER
    $env.MANPAGER = "sh -c 'col -bx | bat -l man -p --paging=always'"
}
