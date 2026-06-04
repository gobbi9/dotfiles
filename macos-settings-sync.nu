#!/usr/bin/env nu

# Sync selected macOS settings into chezmoi/1Password.
#
# - Keyboard shortcuts: exports com.apple.symbolichotkeys and runs `chezmoi add`.
# - Text replacements: exports/imports only the NSUserDictionaryReplacementItems
#   key from the global preferences domain. The extracted key plist is stored in
#   1Password and rendered locally through a chezmoi `onepasswordRead` template.

const TEXT_REPLACEMENTS_KEY = "NSUserDictionaryReplacementItems"
const TEXT_REPLACEMENTS_OP_REF = "op://Personal/macos-text-replacements/NSUserDictionaryReplacementItems.plist"
const TEXT_REPLACEMENTS_TEMPLATE_REL = "private_Library/Preferences/private_NSUserDictionaryReplacementItems.plist.tmpl"


def ensure-macos [] {
  let os_name = ($nu.os-info.name | str downcase)
  if not ($os_name | str contains "mac") {
    error make {
      msg: "This script only supports macOS"
      help: "Run it on a macOS machine with macOS preference commands available."
    }
  }
}

def keyboard-shortcuts-plist-path [] {
  $nu.home-dir | path join "Library" "Preferences" "com.apple.symbolichotkeys.plist"
}

def text-replacements-key-plist-path [] {
  $nu.home-dir | path join "Library" "Preferences" "NSUserDictionaryReplacementItems.plist"
}

def global-preferences-plist-path [] {
  $nu.home-dir | path join "Library" "Preferences" ".GlobalPreferences.plist"
}

def source-dir [] {
  let detected = (try { ^chezmoi source-path | str trim } catch { "" })
  if ($detected | is-empty) { pwd } else { $detected }
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
    error make { msg: $"`($command_name)` command not found", help: $help_text }
  }
}

def ensure-chezmoi-available [] {
  ensure-command-available "chezmoi" "Install chezmoi or run with --skip-chezmoi."
}

def ensure-op-available [] {
  ensure-command-available "op" "Install 1Password CLI and sign in before syncing text replacements."
}

def ensure-plutil-available [] {
  ensure-command-available "plutil" "`plutil` ships with macOS; verify your PATH and shell environment."
}

def export-defaults-domain [domain: string] {
  let result = (^defaults export $domain - | complete)
  if ($result.exit_code != 0) {
    let stderr = ($result.stderr | str trim)
    error make {
      msg: $"Failed to export defaults domain: ($domain)"
      help: (if ($stderr | is-empty) { "Check macOS defaults configuration and try again." } else { $stderr })
    }
  }

  $result.stdout
}

def write-if-changed [target_path: string, content: string, label: string, dry_run: bool] {
  let target_exists = ($target_path | path exists)
  let current = (if $target_exists { open --raw $target_path } else { "" })
  let changed = ($content != $current)

  if $dry_run {
    if $changed { print $"[DRY-RUN] Would update ($label): ($target_path)" } else { print $"[DRY-RUN] ($label) already up to date: ($target_path)" }
    return $changed
  }

  if $changed {
    ensure-parent-dir $target_path
    $content | save -f $target_path
    print $"[OK] Updated ($label): ($target_path)"
  } else {
    print $"[OK] ($label) already up to date: ($target_path)"
  }

  $changed
}

def run-chezmoi-add [target_path: string] {
  let result = (^chezmoi add $target_path | complete)
  if ($result.exit_code != 0) {
    return { ok: false, stderr: ($result.stderr | str trim) }
  }

  { ok: true, stderr: "" }
}

def parse-op-ref [ref: string] {
  let parsed = ($ref | parse -r '^op://(?<vault>[^/]+)/(?<item>[^/]+)/(?<field>.+)$')
  if ($parsed | is-empty) { null } else { $parsed | first }
}

def escape-assignment-key [s: string] {
  $s | str replace --all "\\" "\\\\" | str replace --all "." "\\." | str replace --all "=" "\\="
}

def upload-file-to-1password [op_ref: string, source_file_path: string] {
  let parsed = (parse-op-ref $op_ref)
  if ($parsed == null) {
    return { ok: false, stderr: $"Unsupported 1Password ref [expected op://vault/item/file]: ($op_ref)" }
  }

  let assignment = $"((escape-assignment-key $parsed.field))[file]=($source_file_path)"
  let result = (^op item edit $parsed.item --vault $parsed.vault $assignment | complete)
  if ($result.exit_code == 0) { { ok: true, stderr: "" } } else { { ok: false, stderr: ($result.stderr | str trim) } }
}

def empty-array-plist [] {
  let tmpfile = (^mktemp | str trim)
  ^/usr/libexec/PlistBuddy -c "Clear array" $tmpfile | ignore
  let content = (open --raw $tmpfile)
  rm -f $tmpfile
  $content
}

def extract-text-replacements-key [] {
  ensure-plutil-available

  let global_plist = (^mktemp | str trim)
  export-defaults-domain "-g" | save -f $global_plist

  let extract_result = (^plutil -extract $TEXT_REPLACEMENTS_KEY xml1 -o - $global_plist | complete)
  rm -f $global_plist

  if ($extract_result.exit_code == 0) {
    return $extract_result.stdout
  }

  let stderr = ($extract_result.stderr | str trim)
  if ($stderr | str contains "Could not extract value") or ($stderr | str contains "No value at that key path") {
    return (empty-array-plist)
  }

  error make {
    msg: $"Failed to extract ($TEXT_REPLACEMENTS_KEY) from global preferences"
    help: (if ($stderr | is-empty) { "Check macOS global preferences and try again." } else { $stderr })
  }
}

def import-text-replacements-key [source_key_plist_path: string, dry_run: bool] {
  ensure-plutil-available

  if not ($source_key_plist_path | path exists) {
    error make {
      msg: $"Text replacements source plist does not exist: ($source_key_plist_path)"
      help: "Run `chezmoi apply` first so the 1Password template renders locally."
    }
  }

  if $dry_run {
    print $"[DRY-RUN] Would write only ($TEXT_REPLACEMENTS_KEY) into ((global-preferences-plist-path))"
    return
  }

  let tmp_global = (^mktemp | str trim)
  let tmp_json = (^mktemp | str trim)
  export-defaults-domain "-g" | save -f $tmp_global

  let key_json_result = (^plutil -convert json -o - $source_key_plist_path | complete)
  if ($key_json_result.exit_code != 0) {
    let stderr = ($key_json_result.stderr | str trim)
    rm -f $tmp_global $tmp_json
    error make {
      msg: $"Failed to parse text replacements source plist: ($source_key_plist_path)"
      help: (if ($stderr | is-empty) { "Validate the text replacements plist and try again." } else { $stderr })
    }
  }

  let global_json_result = (^plutil -convert json -o - $tmp_global | complete)
  if ($global_json_result.exit_code != 0) {
    let stderr = ($global_json_result.stderr | str trim)
    rm -f $tmp_global $tmp_json
    error make {
      msg: "Failed to convert current global preferences to JSON"
      help: (if ($stderr | is-empty) { "Check macOS global preferences and try again." } else { $stderr })
    }
  }

  let key_value = ($key_json_result.stdout | from json)
  let global_value = ($global_json_result.stdout | from json)
  ($global_value | upsert $TEXT_REPLACEMENTS_KEY $key_value | to json) | save -f $tmp_json

  let convert_result = (^plutil -convert xml1 -o $tmp_global $tmp_json | complete)
  if ($convert_result.exit_code != 0) {
    let stderr = ($convert_result.stderr | str trim)
    rm -f $tmp_global $tmp_json
    error make {
      msg: "Failed to convert updated global preferences to plist"
      help: (if ($stderr | is-empty) { "Validate generated global preferences JSON and try again." } else { $stderr })
    }
  }

  let import_result = (^defaults import -g $tmp_global | complete)
  rm -f $tmp_global $tmp_json

  if ($import_result.exit_code != 0) {
    let stderr = ($import_result.stderr | str trim)
    error make {
      msg: $"Failed to import updated global preferences containing ($TEXT_REPLACEMENTS_KEY)"
      help: (if ($stderr | is-empty) { "Check macOS defaults permissions and try again." } else { $stderr })
    }
  }

  print $"[OK] Restored macOS text replacements key: ($TEXT_REPLACEMENTS_KEY)"
}

def sync-keyboard-shortcuts [plist_path: string, dry_run: bool, skip_chezmoi: bool] {
  print "[INFO] Setting: macOS keyboard shortcuts"
  print "[INFO] Domain:  com.apple.symbolichotkeys"
  print $"[INFO] Plist:   ($plist_path)"

  let exported = (export-defaults-domain "com.apple.symbolichotkeys")
  write-if-changed $plist_path $exported "com.apple.symbolichotkeys plist" $dry_run | ignore

  if $skip_chezmoi {
    print "[INFO] Skipping `chezmoi add` (--skip-chezmoi)."
    return
  }

  if $dry_run {
    print $"[DRY-RUN] Would run: chezmoi add ($plist_path)"
    return
  }

  ensure-chezmoi-available
  let add_result = (run-chezmoi-add $plist_path)
  if ($add_result.ok == true) { print $"[OK] Synced into chezmoi source: ($plist_path)" } else {
    print $"[ERROR] `chezmoi add` failed for: ($plist_path)"
    if (($add_result.stderr | is-empty) == false) { print $"        ($add_result.stderr)" }
    exit 1
  }
}

def text-replacements-template-content [op_ref: string] {
  $"{{ onepasswordRead \"($op_ref)\" }}\n"
}

def ensure-text-replacements-template [op_ref: string, dry_run: bool] {
  let template_path = ((source-dir) | path join $TEXT_REPLACEMENTS_TEMPLATE_REL)
  let content = (text-replacements-template-content $op_ref)
  write-if-changed $template_path $content "text replacements 1Password template" $dry_run | ignore
  $template_path
}

def sync-text-replacements [key_plist_path: string, op_ref: string, dry_run: bool, skip_1password: bool] {
  print "[INFO] Setting: macOS text replacements"
  print $"[INFO] Key:     ($TEXT_REPLACEMENTS_KEY)"
  print $"[INFO] Plist:   ($key_plist_path)"
  print $"[INFO] 1P ref:  ($op_ref)"

  let exported = (extract-text-replacements-key)
  ensure-text-replacements-template $op_ref $dry_run | ignore
  write-if-changed $key_plist_path $exported "text replacements key plist" $dry_run | ignore

  if $skip_1password {
    print "[INFO] Skipping 1Password upload (--skip-1password)."
    return
  }

  if $dry_run {
    print $"[DRY-RUN] Would upload ($key_plist_path) to ($op_ref)"
    return
  }

  ensure-op-available
  let upload = (upload-file-to-1password $op_ref $key_plist_path)
  if ($upload.ok == true) { print $"[OK] Uploaded text replacements key plist to 1Password: ($op_ref)" } else {
    print $"[ERROR] Failed uploading text replacements key plist to 1Password: ($op_ref)"
    if (($upload.stderr | is-empty) == false) { print $"        ($upload.stderr)" }
    exit 1
  }
}

def main [
  --dry-run (-n) # Preview changes without writing to disk or 1Password.
  --keyboard-shortcuts-plist-path: string = "" # Override keyboard shortcuts plist destination path.
  --plist-path (-p): string = "" # Backward-compatible alias for --keyboard-shortcuts-plist-path.
  --text-replacements-plist-path: string = "" # Override extracted text replacements key plist path.
  --text-replacements-op-ref: string = $TEXT_REPLACEMENTS_OP_REF # 1Password file ref for extracted text replacements plist.
  --restore-text-replacements # Write the extracted text replacements plist back into macOS global preferences.
  --skip-keyboard-shortcuts # Do not sync com.apple.symbolichotkeys.
  --skip-text-replacements # Do not sync text replacements.
  --skip-chezmoi # Skip `chezmoi add` for non-sensitive files.
  --skip-1password # Skip uploading text replacements to 1Password.
] {
  ensure-macos
  ensure-command-available "defaults" "`defaults` ships with macOS; verify your PATH and shell environment."

  let keyboard_path = if not ($keyboard_shortcuts_plist_path | is-empty) { $keyboard_shortcuts_plist_path } else if not ($plist_path | is-empty) { $plist_path } else { keyboard-shortcuts-plist-path }
  let text_path = if ($text_replacements_plist_path | is-empty) { text-replacements-key-plist-path } else { $text_replacements_plist_path }

  if $restore_text_replacements {
    import-text-replacements-key $text_path $dry_run
    return
  }

  if not $skip_keyboard_shortcuts {
    sync-keyboard-shortcuts $keyboard_path $dry_run $skip_chezmoi
  }

  if not $skip_keyboard_shortcuts and not $skip_text_replacements {
    print ""
  }

  if not $skip_text_replacements {
    sync-text-replacements $text_path $text_replacements_op_ref $dry_run $skip_1password
  }
}
