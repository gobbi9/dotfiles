use shared/tags.nu [tag_info tag_ok tag_dry]
use shared/sync-utils.nu [ensure_parent_dir ensure_command_available chezmoi_source_dir run_chezmoi_add run_chezmoi_apply parse_op_ref escape_assignment_key]

const TEXT_REPLACEMENTS_KEY = "NSUserDictionaryReplacementItems"
const TEXT_REPLACEMENTS_OP_REF = "op://Personal/macos-text-replacements/NSUserDictionaryReplacementItems.plist"
const TEXT_REPLACEMENTS_TEMPLATE_REL = "private_Library/Preferences/private_NSUserDictionaryReplacementItems.plist.tmpl"

def ensure_macos [] {
  let os_name = ($nu.os-info.name | str lowercase)
  if not ($os_name | str contains "mac") {
    error make --unspanned {
      msg: "This command only supports macOS"
      help: "Run it on a macOS machine with macOS preference commands available."
    }
  }
}

def keyboard_shortcuts_plist_path [] {
  $nu.home-dir | path join "Library" "Preferences" "com.apple.symbolichotkeys.plist"
}

def text_replacements_key_plist_path [] {
  $nu.home-dir | path join "Library" "Preferences" "NSUserDictionaryReplacementItems.plist"
}

def global_preferences_plist_path [] {
  $nu.home-dir | path join "Library" "Preferences" ".GlobalPreferences.plist"
}

def export_defaults_domain [domain: string] {
  let result = (^defaults export $domain - | complete)
  if ($result.exit_code != 0) {
    let stderr = ($result.stderr | str trim)
    error make --unspanned {
      msg: $"Failed to export defaults domain: ($domain)"
      help: (if ($stderr | is-empty) { "Check macOS defaults configuration and try again." } else { $stderr })
    }
  }

  $result.stdout
}

def write_if_changed [target_path: string, content: string, label: string, dry_run: bool] {
  let target_exists = ($target_path | path exists)
  let current = (if $target_exists { open --raw $target_path } else { "" })
  let changed = ($content != $current)

  if $dry_run {
    if $changed {
      tag_dry $"Would update ($label): ($target_path)"
    } else {
      tag_dry $"($label) already up to date: ($target_path)"
    }
    return $changed
  }

  if $changed {
    ensure_parent_dir $target_path
    $content | save -f $target_path
    tag_ok $"Updated ($label): ($target_path)"
  } else {
    tag_ok $"($label) already up to date: ($target_path)"
  }

  $changed
}

def upload_file_to_1password [op_ref: string, source_file_path: string] {
  let parsed = (parse_op_ref $op_ref)
  if ($parsed == null) {
    return { ok: false, stderr: $"Unsupported 1Password ref [expected op://vault/item/file]: ($op_ref)" }
  }

  let assignment = $"((escape_assignment_key $parsed.field))[file]=($source_file_path)"
  let result = (^op item edit $parsed.item --vault $parsed.vault $assignment | complete)
  if ($result.exit_code == 0) { { ok: true, stderr: "" } } else { { ok: false, stderr: ($result.stderr | str trim) } }
}

def empty_array_plist [] {
  let tmpfile = (^mktemp | str trim)
  ^/usr/libexec/PlistBuddy -c "Clear array" $tmpfile | ignore
  let content = (open --raw $tmpfile)
  rm -f $tmpfile
  $content
}

def extract_text_replacements_key [] {
  ensure_command_available "plutil" "`plutil` ships with macOS; verify your PATH and shell environment."

  let global_plist = (^mktemp | str trim)
  export_defaults_domain "-g" | save -f $global_plist

  let extract_result = (^plutil -extract $TEXT_REPLACEMENTS_KEY xml1 -o - $global_plist | complete)
  rm -f $global_plist

  if ($extract_result.exit_code == 0) {
    return $extract_result.stdout
  }

  let stderr = ($extract_result.stderr | str trim)
  if ($stderr | str contains "Could not extract value") or ($stderr | str contains "No value at that key path") {
    return (empty_array_plist)
  }

  error make --unspanned {
    msg: $"Failed to extract ($TEXT_REPLACEMENTS_KEY) from global preferences"
    help: (if ($stderr | is-empty) { "Check macOS global preferences and try again." } else { $stderr })
  }
}

def reload_keyboard_shortcuts [] {
  # SystemUIServer reads symbolic hotkeys at launch and does not reliably
  # observe a defaults-domain import while it is already running.
  let result = (^killall SystemUIServer | complete)
  if ($result.exit_code == 0) {
    tag_ok "Restarted SystemUIServer to reload keyboard shortcuts"
    return
  }

  let stderr = ($result.stderr | str trim)
  if not ($stderr | str contains "No matching processes") {
    error make --unspanned {
      msg: "Failed to restart SystemUIServer after restoring keyboard shortcuts"
      help: (if ($stderr | is-empty) { "Log out and back in to reload keyboard shortcuts." } else { $stderr })
    }
  }

  tag_info "SystemUIServer was not running; keyboard shortcuts will load when it starts."
}

def import_keyboard_shortcuts [source_plist_path: string, dry_run: bool] {
  ensure_command_available "plutil" "`plutil` ships with macOS; verify your PATH and shell environment."

  if not ($source_plist_path | path exists) {
    error make --unspanned {
      msg: $"Keyboard shortcuts source plist does not exist: ($source_plist_path)"
      help: "Run `chezmoi apply` first so the managed plist is rendered locally."
    }
  }

  let validation = (^plutil -lint $source_plist_path | complete)
  if ($validation.exit_code != 0) {
    let stderr = ($validation.stderr | str trim)
    error make --unspanned {
      msg: $"Failed to parse keyboard shortcuts source plist: ($source_plist_path)"
      help: (if ($stderr | is-empty) { "Validate the keyboard shortcuts plist and try again." } else { $stderr })
    }
  }

  if $dry_run {
    tag_dry $"Would import com.apple.symbolichotkeys from ($source_plist_path)"
    return
  }

  let import_result = (^defaults import com.apple.symbolichotkeys $source_plist_path | complete)
  if ($import_result.exit_code != 0) {
    let stderr = ($import_result.stderr | str trim)
    error make --unspanned {
      msg: $"Failed to import macOS keyboard shortcuts from: ($source_plist_path)"
      help: (if ($stderr | is-empty) { "Check macOS defaults permissions and try again." } else { $stderr })
    }
  }

  tag_ok "Restored macOS keyboard shortcuts: com.apple.symbolichotkeys"
  reload_keyboard_shortcuts
}

def import_text_replacements_key [source_key_plist_path: string, dry_run: bool] {
  ensure_command_available "plutil" "`plutil` ships with macOS; verify your PATH and shell environment."

  if not ($source_key_plist_path | path exists) {
    error make --unspanned {
      msg: $"Text replacements source plist does not exist: ($source_key_plist_path)"
      help: "Run `chezmoi apply` first so the 1Password template renders locally."
    }
  }

  if $dry_run {
    tag_dry $"Would write only ($TEXT_REPLACEMENTS_KEY) into ((global_preferences_plist_path))"
    return
  }

  let source_validation = (^plutil -lint $source_key_plist_path | complete)
  if ($source_validation.exit_code != 0) {
    let stderr = ($source_validation.stderr | str trim)
    error make --unspanned {
      msg: $"Failed to parse text replacements source plist: ($source_key_plist_path)"
      help: (if ($stderr | is-empty) { "Validate the text replacements plist and try again." } else { $stderr })
    }
  }

  # Keep the global domain in its native plist representation: macOS may store
  # dates or data values there, neither of which can be converted to JSON.
  let tmp_global = (^mktemp | str trim)
  export_defaults_domain "-g" | save -f $tmp_global

  let source_xml = (open --raw $source_key_plist_path)
  let update_result = (^plutil -replace $TEXT_REPLACEMENTS_KEY -xml $source_xml $tmp_global | complete)
  if ($update_result.exit_code != 0) {
    let stderr = ($update_result.stderr | str trim)
    rm -f $tmp_global
    error make --unspanned {
      msg: $"Failed to write ($TEXT_REPLACEMENTS_KEY) into exported global preferences"
      help: (if ($stderr | is-empty) { "Validate the text replacements plist and try again." } else { $stderr })
    }
  }

  let import_result = (^defaults import -g $tmp_global | complete)
  rm -f $tmp_global

  if ($import_result.exit_code != 0) {
    let stderr = ($import_result.stderr | str trim)
    error make --unspanned {
      msg: $"Failed to import updated global preferences containing ($TEXT_REPLACEMENTS_KEY)"
      help: (if ($stderr | is-empty) { "Check macOS defaults permissions and try again." } else { $stderr })
    }
  }

  tag_ok $"Restored macOS text replacements key: ($TEXT_REPLACEMENTS_KEY)"
}

def sync_keyboard_shortcuts [plist_path: string, dry_run: bool, skip_chezmoi: bool] {
  tag_info "Setting: macOS keyboard shortcuts"
  tag_info "Domain:  com.apple.symbolichotkeys"
  tag_info $"Plist:   ($plist_path)"

  let exported = (export_defaults_domain "com.apple.symbolichotkeys")
  write_if_changed $plist_path $exported "com.apple.symbolichotkeys plist" $dry_run | ignore

  if $skip_chezmoi {
    tag_info "Skipping `chezmoi add` (--skip-chezmoi)."
    return
  }

  if $dry_run {
    tag_dry $"Would run: chezmoi add ($plist_path)"
    return
  }

  ensure_command_available "chezmoi" "Install chezmoi or run with --skip-chezmoi."
  let add_result = (run_chezmoi_add $plist_path)
  if ($add_result.ok == true) {
    tag_ok $"Synced into chezmoi source: ($plist_path)"
  } else {
    error make --unspanned {
      msg: $"`chezmoi add` failed for: ($plist_path)"
      help: ($add_result.stderr | default "")
    }
  }
}

def text_replacements_template_content [op_ref: string] {
  $"{{ onepasswordRead \"($op_ref)\" }}\n"
}

def ensure_text_replacements_template [op_ref: string, dry_run: bool] {
  let template_path = ((chezmoi_source_dir) | path join $TEXT_REPLACEMENTS_TEMPLATE_REL)
  let content = (text_replacements_template_content $op_ref)
  write_if_changed $template_path $content "text replacements 1Password template" $dry_run | ignore
  $template_path
}

def sync_text_replacements [key_plist_path: string, op_ref: string, dry_run: bool, skip_1password: bool, skip_chezmoi: bool] {
  tag_info "Setting: macOS text replacements"
  tag_info $"Key:     ($TEXT_REPLACEMENTS_KEY)"
  tag_info $"Plist:   ($key_plist_path)"
  tag_info $"1P ref:  ($op_ref)"

  let exported = (extract_text_replacements_key)
  if $skip_chezmoi {
    tag_info "Skipping chezmoi template and state synchronization (--skip-chezmoi)."
  } else {
    ensure_text_replacements_template $op_ref $dry_run | ignore
  }
  write_if_changed $key_plist_path $exported "text replacements key plist" $dry_run | ignore

  if $skip_1password {
    tag_info "Skipping 1Password upload (--skip-1password)."
    return
  }

  if $dry_run {
    tag_dry $"Would upload ($key_plist_path) to ($op_ref)"
    if not $skip_chezmoi {
      tag_dry $"Would run: chezmoi apply --force ($key_plist_path)"
    }
    return
  }

  ensure_command_available "op" "Install 1Password CLI and sign in before syncing text replacements."
  let upload = (upload_file_to_1password $op_ref $key_plist_path)
  if ($upload.ok != true) {
    error make --unspanned {
      msg: $"Failed uploading text replacements key plist to ($op_ref)"
      help: ($upload.stderr | default "")
    }
  }
  tag_ok $"Uploaded text replacements key plist to 1Password: ($op_ref)"

  if $skip_chezmoi {
    return
  }

  ensure_command_available "chezmoi" "Install chezmoi or run with --skip-chezmoi."
  let apply_result = (run_chezmoi_apply $key_plist_path)
  if ($apply_result.ok == true) {
    tag_ok $"Synchronized chezmoi state: ($key_plist_path)"
  } else {
    error make --unspanned {
      msg: $"`chezmoi apply` failed for: ($key_plist_path)"
      help: ($apply_result.stderr | default "")
    }
  }
}

# Sync macOS keyboard shortcuts and text replacements into your dotfiles workflow.
# Optionally uploads text replacements to 1Password and can restore them back to macOS.
export def "macos settings sync" [
  --dry-run (-n) # Preview changes without writing to disk or 1Password.
  --keyboard-shortcuts-plist-path: string = "" # Override keyboard shortcuts plist destination path.
  --plist-path (-p): string = "" # Backward-compatible alias for --keyboard-shortcuts-plist-path.
  --text-replacements-plist-path: string = "" # Override extracted text replacements key plist path.
  --text-replacements-op-ref: string = $TEXT_REPLACEMENTS_OP_REF # 1Password file ref for extracted text replacements plist.
  --restore-keyboard-shortcuts # Import the managed keyboard shortcuts plist through macOS defaults.
  --restore-text-replacements # Write the extracted text replacements plist back into macOS global preferences.
  --skip-keyboard-shortcuts # Do not sync com.apple.symbolichotkeys.
  --skip-text-replacements # Do not sync text replacements.
  --skip-chezmoi # Skip chezmoi source and target-state synchronization.
  --skip-1password # Skip uploading text replacements to 1Password.
] {
  ensure_macos
  ensure_command_available "defaults" "`defaults` ships with macOS; verify your PATH and shell environment."

  let keyboard_path = if not ($keyboard_shortcuts_plist_path | is-empty) {
    $keyboard_shortcuts_plist_path
  } else if not ($plist_path | is-empty) {
    $plist_path
  } else {
    keyboard_shortcuts_plist_path
  }

  let text_path = if ($text_replacements_plist_path | is-empty) {
    text_replacements_key_plist_path
  } else {
    $text_replacements_plist_path
  }

  if $restore_keyboard_shortcuts {
    import_keyboard_shortcuts $keyboard_path $dry_run
    return
  }

  if $restore_text_replacements {
    import_text_replacements_key $text_path $dry_run
    return
  }

  if not $skip_keyboard_shortcuts {
    sync_keyboard_shortcuts $keyboard_path $dry_run $skip_chezmoi
  }

  if not $skip_keyboard_shortcuts and not $skip_text_replacements {
    print ""
  }

  if not $skip_text_replacements {
    sync_text_replacements $text_path $text_replacements_op_ref $dry_run $skip_1password $skip_chezmoi
  }
}
