#!/usr/bin/env nu

# Sync macOS keyboard shortcuts (com.apple.symbolichotkeys) into chezmoi source state.
#
# Default behavior:
# - Ensures host OS is macOS
# - Exports current domain via `defaults export com.apple.symbolichotkeys -`
# - Writes plist to ~/Library/Preferences/com.apple.symbolichotkeys.plist
# - Runs `chezmoi add` for that plist
#
# Idempotent behavior:
# - If exported plist content is unchanged, file is not rewritten
# - Re-running is safe
#
# Use --dry-run to preview without writing.

def ensure-macos [] {
  let os_name = ($nu.os-info.name | str downcase)
  if not ($os_name | str contains "mac") {
    error make {
      msg: "This script only supports macOS"
      help: "Run it on a macOS machine with the `defaults` command available."
    }
  }
}

def default-plist-path [] {
  $nu.home-dir | path join "Library" "Preferences" "com.apple.symbolichotkeys.plist"
}

def ensure-parent-dir [path_value: string] {
  let parent = ($path_value | path dirname)
  if not ($parent | path exists) {
    mkdir $parent
  }
}

def ensure-command-available [command_name: string, help_text: string] {
  try {
    ^which $command_name | ignore
  } catch {
    error make {
      msg: $"`($command_name)` command not found"
      help: $help_text
    }
  }
}

def ensure-chezmoi-available [] {
  ensure-command-available "chezmoi" "Install chezmoi or run with --skip-chezmoi."
}

def export-symbolic-hotkeys [] {
  let result = (^defaults export com.apple.symbolichotkeys - | complete)

  if ($result.exit_code != 0) {
    let stderr = ($result.stderr | str trim)
    error make {
      msg: "Failed to export com.apple.symbolichotkeys"
      help: (
        if ($stderr | is-empty) {
          "Check macOS defaults configuration and try again."
        } else {
          $stderr
        }
      )
    }
  }

  $result.stdout
}

def run-chezmoi-add [target_path: string] {
  let result = (^chezmoi add $target_path | complete)
  if ($result.exit_code != 0) {
    return {
      ok: false,
      stderr: ($result.stderr | str trim)
    }
  }

  { ok: true, stderr: "" }
}

def main [
  --dry-run (-n) # Preview changes without writing to disk.
  --plist-path (-p): string = "" # Override plist destination path.
  --skip-chezmoi # Skip running `chezmoi add`.
] {
  ensure-macos
  ensure-command-available "defaults" "`defaults` ships with macOS; verify your PATH and shell environment."

  let resolved_plist_path = (
    if ($plist_path | is-empty) {
      default-plist-path
    } else {
      $plist_path
    }
  )

  let exported = (export-symbolic-hotkeys)
  let target_exists = ($resolved_plist_path | path exists)
  let current = (if $target_exists { open --raw $resolved_plist_path } else { "" })
  let changed = ($exported != $current)

  print $"[INFO] Domain:     com.apple.symbolichotkeys"
  print $"[INFO] Plist path: ($resolved_plist_path)"

  if $dry_run {
    if $changed {
      print "[DRY-RUN] Would update plist file from current exported defaults domain."
    } else {
      print "[DRY-RUN] Plist already up to date (no write needed)."
    }

    if not $skip_chezmoi {
      print $"[DRY-RUN] Would run: chezmoi add ($resolved_plist_path)"
    }

    return
  }

  if $changed {
    ensure-parent-dir $resolved_plist_path
    $exported | save -f $resolved_plist_path
    print "[OK] Updated com.apple.symbolichotkeys plist"
  } else {
    print "[OK] com.apple.symbolichotkeys plist already up to date (no file changes)."
  }

  if $skip_chezmoi {
    print "[INFO] Skipping `chezmoi add` (--skip-chezmoi)."
    return
  }

  ensure-chezmoi-available
  let add_result = (run-chezmoi-add $resolved_plist_path)

  if ($add_result.ok == true) {
    print $"[OK] Synced into chezmoi source: ($resolved_plist_path)"
  } else {
    print $"[ERROR] `chezmoi add` failed for: ($resolved_plist_path)"
    if (($add_result.stderr | is-empty) == false) {
      print $"        ($add_result.stderr)"
    }
    exit 1
  }
}
