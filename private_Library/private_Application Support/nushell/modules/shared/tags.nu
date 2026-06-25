export def tag_info [msg: string] {
  print $"(ansi cyan_bold)[INFO](ansi reset) ($msg)"
}

export def tag_ok [msg: string] {
  print $"(ansi green_bold)[OK](ansi reset) ($msg)"
}

export def tag_warn [msg: string] {
  print $"(ansi yellow_bold)[WARN](ansi reset) ($msg)"
}

export def tag_error [msg: string] {
  print $"(ansi red_bold)[ERROR](ansi reset) ($msg)"
}

export def tag_dry [msg: string] {
  print $"(ansi magenta_bold)[DRY-RUN](ansi reset) ($msg)"
}
