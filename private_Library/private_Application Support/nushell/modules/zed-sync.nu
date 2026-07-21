use shared/tags.nu [tag_info tag_ok tag_warn tag_dry tag_error]
use shared/sync-utils.nu [ensure_parent_dir ensure_command_available run_chezmoi_add]

def default_settings_path [] {
  let os_name = ($nu.os-info.name | str lowercase)
  let home = $nu.home-dir

  if ($os_name | str contains "windows") {
    let appdata = ($env.APPDATA? | default ($home | path join "AppData" "Roaming"))
    $appdata | path join "Zed" "settings.json"
  } else {
    $home | path join ".config" "zed" "settings.json"
  }
}

def extension_dir_candidates [] {
  let os_name = ($nu.os-info.name | str lowercase)
  let home = $nu.home-dir

  if ($os_name | str contains "windows") {
    let localappdata = ($env.LOCALAPPDATA? | default ($home | path join "AppData" "Local"))
    [($localappdata | path join "Zed" "extensions" "installed")]
  } else if ($os_name | str contains "mac") {
    [
      ($home | path join "Library" "Application Support" "Zed" "extensions" "installed")
      ($home | path join ".local" "share" "zed" "extensions" "installed")
    ]
  } else {
    [
      ($home | path join ".local" "share" "zed" "extensions" "installed")
      ($home | path join "Library" "Application Support" "Zed" "extensions" "installed")
    ]
  }
}

def detect_extension_dir [] {
  for candidate in (extension_dir_candidates) {
    if ($candidate | path exists) {
      return $candidate
    }
  }

  ""
}

def collect_installed_extension_ids [extensions_dir: string] {
  if not ($extensions_dir | path exists) {
    return []
  }

  ls $extensions_dir | where type == dir | get name | each {|name| $name | path basename } | sort
}

def build_auto_install_map [ids: list<string>] {
  $ids | reduce -f {} {|id, acc| $acc | upsert $id true }
}

def normalize_extension_map [value: any] {
  let as_record = if ($value | describe | str starts-with "record") { $value } else { {} }
  $as_record | transpose key value | sort-by key
}

def load_settings [settings_path: string] {
  if not ($settings_path | path exists) {
    return {}
  }

  let raw = (openn --raw $settings_path)
  try {
    $raw | from json
  } catch {
    error make --unspanned {
      msg: $"Failed to parse settings JSON at: ($settings_path)"
      help: "Ensure the file contains valid JSON (without comments/trailing commas) before running this command."
    }
  }
}

def zed_targets [settings_path: string] {
  let zed_dir = ($settings_path | path dirname)
  [
    { path: $settings_path, required: true, name: "settings.json" }
    { path: ($zed_dir | path join "keymap.json"), required: false, name: "keymap.json" }
    { path: ($zed_dir | path join "tasks.json"), required: false, name: "tasks.json" }
    { path: ($zed_dir | path join "snippets"), required: false, name: "snippets/" }
    { path: ($zed_dir | path join "themes"), required: false, name: "themes/" }
  ]
}

def sync_targets_into_chezmoi [targets: list<any>] {
  mut failures = 0

  for target in $targets {
    let target_path = $target.path
    let target_name = $target.name
    let required = $target.required

    if not ($target_path | path exists) {
      if $required {
        $failures = ($failures + 1)
        tag_error $"Required path missing: ($target_path)"
      } else {
        tag_info $"Skipping missing optional path: ($target_name) -> ($target_path)"
      }
      continue
    }

    let add_result = (run_chezmoi_add $target_path)
    if ($add_result.ok == true) {
      tag_ok $"Synced into chezmoi source: ($target_path)"
    } else {
      $failures = ($failures + 1)
      tag_error $"`chezmoi add` failed for: ($target_path)"
      if (($add_result.stderr | is-empty) == false) {
        print $"        (ansi red)($add_result.stderr)(ansi reset)"
      }
    }
  }

  if ($failures > 0) {
    error make --unspanned { msg: $"Failed syncing ($failures) Zed paths into chezmoi" }
  }
}

# Sync installed Zed extensions into `settings.json` as `auto_install_extensions`.
# Optionally adds Zed config paths to chezmoi source state.
export def "zed sync" [
  --dry-run (-n) # Preview changes without writing to disk.
  --settings-path (-s): string = "" # Override Zed settings path.
  --extensions-dir (-e): string = "" # Override installed extensions directory.
  --skip-chezmoi # Skip running `chezmoi add`.
] {
  let resolved_settings_path = if ($settings_path | is-empty) { default_settings_path } else { $settings_path }
  let resolved_extensions_dir = if ($extensions_dir | is-empty) { detect_extension_dir } else { $extensions_dir }

  if ($resolved_extensions_dir | is-empty) {
    error make --unspanned {
      msg: "Could not detect Zed installed extensions directory."
      help: "Pass it explicitly with --extensions-dir."
    }
  }

  if not ($resolved_extensions_dir | path exists) {
    error make --unspanned { msg: $"Extensions directory does not exist: ($resolved_extensions_dir)" }
  }

  let ids = (collect_installed_extension_ids $resolved_extensions_dir)
  let auto_install = (build_auto_install_map $ids)

  let settings_exists = ($resolved_settings_path | path exists)
  let settings = (load_settings $resolved_settings_path)
  let current_auto_install = ($settings | get auto_install_extensions? | default {})
  let updated_settings = ($settings | upsert auto_install_extensions $auto_install)

  let extension_map_changed = ((normalize_extension_map $current_auto_install) != (normalize_extension_map $auto_install))
  let should_write_settings = ($extension_map_changed or (not $settings_exists))

  tag_info $"Extensions dir: ($resolved_extensions_dir)"
  tag_info $"Settings path:  ($resolved_settings_path)"
  tag_info $"Found installed extensions: ($ids | length)"

  if ($ids | is-empty) {
    tag_warn "No installed extensions found; auto_install_extensions will be set to an empty object."
  }

  let targets = (zed_targets $resolved_settings_path)

  if $dry_run {
    print ""
    tag_dry "Would set auto_install_extensions to:"
    print ($auto_install | to json --indent 2)

    if $should_write_settings {
      tag_dry "Would write settings.json"
    } else {
      tag_dry "settings.json already up to date (no write needed)"
    }

    if not $skip_chezmoi {
      print ""
      tag_dry "Would run `chezmoi add` for existing Zed targets:"
      for target in $targets {
        if ($target.path | path exists) {
          print $"  (ansi magenta)- (ansi reset)($target.path)"
        } else if ($target.required == false) {
          print $"  (ansi yellow)- [skip missing optional] (ansi reset)($target.path)"
        } else {
          print $"  (ansi red)- [error required missing] (ansi reset)($target.path)"
        }
      }
    }

    return
  }

  if $should_write_settings {
    ensure_parent_dir $resolved_settings_path
    ($updated_settings | to json --indent 2) + "\n" | save -f $resolved_settings_path
    print ""
    tag_ok "Updated auto_install_extensions in settings.json"
  } else {
    print ""
    tag_ok "auto_install_extensions already up to date (no file changes)."
  }

  if $skip_chezmoi {
    tag_info "Skipping `chezmoi add` (--skip-chezmoi)."
    return
  }

  ensure_command_available "chezmoi" "Install chezmoi or run with --skip-chezmoi."
  sync_targets_into_chezmoi $targets
}
