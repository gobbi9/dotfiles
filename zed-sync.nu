#!/usr/bin/env nu

# Sync installed Zed extensions into settings.json -> auto_install_extensions,
# then sync relevant Zed config paths into chezmoi source state.
#
# Default behavior:
# - Detects Zed settings path for current OS
# - Detects installed extensions directory for current OS
# - Writes a sorted auto_install_extensions object with installed extensions set to true
# - Runs `chezmoi add` for:
#   - settings.json
#   - keymap.json (if present)
#   - tasks.json (if present)
#   - snippets/ (if present)
#   - themes/ (if present)
#
# Idempotent behavior:
# - If auto_install_extensions is already up to date, settings.json is not rewritten
# - Re-running is safe
#
# Use --dry-run to preview without writing.

def default_settings_path [] {
  let os_name = ($nu.os-info.name | str downcase)
  let home = $nu.home-dir

  if ($os_name | str contains "windows") {
    let appdata = ($env.APPDATA? | default ($home | path join "AppData" "Roaming"))
    $appdata | path join "Zed" "settings.json"
  } else {
    $home | path join ".config" "zed" "settings.json"
  }
}

def extension_dir_candidates [] {
  let os_name = ($nu.os-info.name | str downcase)
  let home = $nu.home-dir

  if ($os_name | str contains "windows") {
    let localappdata = ($env.LOCALAPPDATA? | default ($home | path join "AppData" "Local"))
    [
      ($localappdata | path join "Zed" "extensions" "installed")
    ]
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

  ls $extensions_dir
  | where type == dir
  | get name
  | each {|name| $name | path basename }
  | sort
}

def build_auto_install_map [ids: list<string>] {
  $ids
  | reduce -f {} {|id, acc| $acc | upsert $id true }
}

def normalize_extension_map [value: any] {
  let as_record = (
    if ($value | describe | str starts-with "record") {
      $value
    } else {
      {}
    }
  )

  $as_record
  | transpose key value
  | sort-by key
}

def load_settings [settings_path: string] {
  if not ($settings_path | path exists) {
    return {}
  }

  let raw = (open --raw $settings_path)

  try {
    $raw | from json
  } catch {
    error make {
      msg: $"Failed to parse settings JSON at: ($settings_path)",
      help: "Ensure the file contains valid JSON (without comments/trailing commas) before running this script."
    }
  }
}

def ensure_parent_dir [path_value: string] {
  let parent = ($path_value | path dirname)
  if not ($parent | path exists) {
    mkdir $parent
  }
}

def ensure_chezmoi_available [] {
  try {
    ^chezmoi --version | ignore
  } catch {
    error make {
      msg: "`chezmoi` command not found",
      help: "Install chezmoi or run with --skip-chezmoi."
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

def run_chezmoi_add [target_path: string] {
  let result = (^chezmoi add $target_path | complete)
  if ($result.exit_code != 0) {
    return {
      ok: false,
      stderr: ($result.stderr | str trim)
    }
  }

  { ok: true, stderr: "" }
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
        print $"[ERROR] Required path missing: ($target_path)"
      } else {
        print $"[INFO] Skipping missing optional path: ($target_name) -> ($target_path)"
      }
      continue
    }

    let add_result = (run_chezmoi_add $target_path)
    if ($add_result.ok == true) {
      print $"[OK] Synced into chezmoi source: ($target_path)"
    } else {
      $failures = ($failures + 1)
      print $"[ERROR] `chezmoi add` failed for: ($target_path)"
      if (($add_result.stderr | is-empty) == false) {
        print $"        ($add_result.stderr)"
      }
    }
  }

  if ($failures > 0) {
    exit 1
  }
}

def main [
  --dry-run (-n) # Preview changes without writing to disk.
  --settings-path (-s): string = "" # Override Zed settings path.
  --extensions-dir (-e): string = "" # Override installed extensions directory.
  --skip-chezmoi # Skip running `chezmoi add`.
] {
  let resolved_settings_path = (
    if ($settings_path | is-empty) {
      default_settings_path
    } else {
      $settings_path
    }
  )

  let resolved_extensions_dir = (
    if ($extensions_dir | is-empty) {
      detect_extension_dir
    } else {
      $extensions_dir
    }
  )

  if ($resolved_extensions_dir | is-empty) {
    print "[ERROR] Could not detect Zed installed extensions directory."
    print "        Pass it explicitly with --extensions-dir."
    exit 1
  }

  if not ($resolved_extensions_dir | path exists) {
    print $"[ERROR] Extensions directory does not exist: ($resolved_extensions_dir)"
    exit 1
  }

  let ids = (collect_installed_extension_ids $resolved_extensions_dir)
  let auto_install = (build_auto_install_map $ids)

  let settings_exists = ($resolved_settings_path | path exists)
  let settings = (load_settings $resolved_settings_path)
  let current_auto_install = ($settings | get auto_install_extensions? | default {})
  let updated_settings = ($settings | upsert auto_install_extensions $auto_install)

  let extension_map_changed = (
    (normalize_extension_map $current_auto_install)
    !=
    (normalize_extension_map $auto_install)
  )

  let should_write_settings = ($extension_map_changed or (not $settings_exists))

  print $"[INFO] Extensions dir: ($resolved_extensions_dir)"
  print $"[INFO] Settings path:  ($resolved_settings_path)"
  print $"[INFO] Found installed extensions: ($ids | length)"

  if ($ids | is-empty) {
    print "[WARN] No installed extensions found; auto_install_extensions will be set to an empty object."
  }

  let targets = (zed_targets $resolved_settings_path)

  if $dry_run {
    print "\n[DRY-RUN] Would set auto_install_extensions to:"
    print ($auto_install | to json --indent 2)

    if $should_write_settings {
      print "[DRY-RUN] Would write settings.json"
    } else {
      print "[DRY-RUN] settings.json already up to date (no write needed)"
    }

    if not $skip_chezmoi {
      print "\n[DRY-RUN] Would run `chezmoi add` for existing Zed targets:"
      for target in $targets {
        if ($target.path | path exists) {
          print $"  - ($target.path)"
        } else if ($target.required == false) {
          print $"  - [skip missing optional] ($target.path)"
        } else {
          print $"  - [error required missing] ($target.path)"
        }
      }
    }

    return
  }

  if $should_write_settings {
    ensure_parent_dir $resolved_settings_path
    ($updated_settings | to json --indent 2) + "\n" | save -f $resolved_settings_path
    print "\n[OK] Updated auto_install_extensions in settings.json"
  } else {
    print "\n[OK] auto_install_extensions already up to date (no file changes)."
  }

  if $skip_chezmoi {
    print "[INFO] Skipping `chezmoi add` (--skip-chezmoi)."
    return
  }

  ensure_chezmoi_available
  sync_targets_into_chezmoi $targets
}
