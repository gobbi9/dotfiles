export def ensure_parent_dir [path_value: string] {
  let parent = ($path_value | path dirname)
  if not ($parent | path exists) {
    mkdir $parent
  }
}

export def ensure_command_available [command_name: string, help_text: string] {
  try {
    ^which $command_name | ignore
  } catch {
    error make --unspanned { msg: $"`($command_name)` command not found", help: $help_text }
  }
}

export def chezmoi_source_dir [
  --source_dir(-s): string = ""
  --help: string = "Pass --source-dir explicitly if needed."
] {
  if not ($source_dir | is-empty) {
    return $source_dir
  }

  let detected = (try { ^chezmoi source-path | str trim } catch { "" })
  if ($detected | is-empty) {
    error make --unspanned { msg: "Could not resolve chezmoi source-path", help: $help }
  }

  $detected
}

export def run_chezmoi_add [target_path: string] {
  let result = (^chezmoi add $target_path | complete)
  if ($result.exit_code != 0) {
    return { ok: false, stderr: ($result.stderr | str trim) }
  }

  { ok: true, stderr: "" }
}

export def run_chezmoi_apply [target_path: string] {
  let result = (^chezmoi apply --force $target_path | complete)
  if ($result.exit_code != 0) {
    return { ok: false, stderr: ($result.stderr | str trim) }
  }

  { ok: true, stderr: "" }
}

export def parse_op_ref [ref: string] {
  let parsed = ($ref | parse -r '^op://(?<vault>[^/]+)/(?<item>[^/]+)/(?<field>.+)$')
  if ($parsed | is-empty) { null } else { $parsed | first }
}

export def escape_assignment_key [s: string] {
  $s | str replace --all "\\" "\\\\" | str replace --all "." "\\." | str replace --all "=" "\\="
}
