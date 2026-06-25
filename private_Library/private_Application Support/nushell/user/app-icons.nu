let app_icons_root_dir = {||
  $nu.home-dir | path join ".config" "app-icons"
}

let app_icons_require_ok = {|result: record, label: string|
  let exit_code = ($result.exit_code? | default 1)

  if $exit_code != 0 {
    let stderr_text = ($result.stderr? | default "" | str trim)
    let stdout_text = ($result.stdout? | default "" | str trim)
    let detail = (if ($stderr_text | is-empty) { $stdout_text } else { $stderr_text })

    if ($detail | is-empty) {
      error make --unspanned { msg: $"($label) failed with exit code ($exit_code)." }
    } else {
      error make --unspanned { msg: $"($label) failed with exit code ($exit_code): ($detail)" }
    }
  }
}

let app_icons_icon_entries = {||
  let icon_dir = (do $app_icons_root_dir)

  if not ($icon_dir | path exists) {
    error make --unspanned { msg: $"Icon directory not found: ($icon_dir)" }
  }

  let entries = (
    ls $icon_dir
    | where type == file
    | where name =~ '(?i)\.(png|icns)$'
    | each {|item|
        let parsed = ($item.name | path parse)
        let ext = ($parsed.extension | default "" | str downcase)

        {
          app_name: $parsed.stem
          icon_path: $item.name
          icon_format: $ext
          priority: (if $ext == "png" { 0 } else { 1 })
        }
      }
    | sort-by app_name priority
  )

  $entries
  | uniq-by app_name
  | select app_name icon_path icon_format
  | sort-by app_name
}

let app_icons_source_for_app = {|app_name: string|
  let icon_dir = (do $app_icons_root_dir)
  let png_path = ($icon_dir | path join $"($app_name).png")
  let icns_path = ($icon_dir | path join $"($app_name).icns")

  if ($png_path | path exists) {
    { app_name: $app_name, icon_path: $png_path, icon_format: "png" }
  } else if ($icns_path | path exists) {
    { app_name: $app_name, icon_path: $icns_path, icon_format: "icns" }
  } else {
    error make --unspanned { msg: $"Icon file not found for app '($app_name)'. Expected one of: ($png_path), ($icns_path)" }
  }
}

let app_icons_resolve_app = {|app_name: string|
  let candidates = [
    $"/Applications/($app_name).app"
    ($nu.home-dir | path join "Applications" $"($app_name).app")
  ]

  let app_path = (
    $candidates
    | where {|path| $path | path exists }
    | first
  )

  if ($app_path | is-empty) {
    error make --unspanned { msg: $"App bundle not found for '($app_name)'. Tried: ($candidates | str join ', ')" }
  }

  $app_path
}

let app_icons_prepare_finder_source = {|icon_path: string|
  let ext = (($icon_path | path parse | get extension | default "" | str downcase))

  if ($ext != "png") and ($ext != "icns") {
    error make --unspanned { msg: $"Unsupported icon format: ($icon_path). Use .png or .icns" }
  }

  { source_icon: $icon_path, cleanup_dir: null, source_format: $ext }
}

let app_icons_set_finder_icon = {|app_bundle: string, icon_path: string|
  let swift_script = ($nu.config-path | path dirname | path join "user" "app-icons-set-icon.swift")

  if not ($swift_script | path exists) {
    error make --unspanned { msg: $"Swift helper not found: ($swift_script)" }
  }

  let swift_result = (^swift $swift_script $app_bundle $icon_path | complete)
  do $app_icons_require_ok $swift_result "set custom app icon"

  let touch_result = (^touch $app_bundle | complete)
  do $app_icons_require_ok $touch_result "touch app bundle"
}

let app_icons_cleanup = {|cleanup_dir: string|
  if ($cleanup_dir | path exists) {
    ^rm -rf $cleanup_dir
  }
}

# List available icon mappings from ~/.config/app-icons.
#
# Supported source formats:
#   - <AppName>.png (preferred)
#   - <AppName>.icns
# If both exist, PNG is preferred.
def "app-icons list" [] {
  do $app_icons_icon_entries
}

# Completion for `app-icons apply <app_name>`.
def "app-icons --apply-completer" [_context: string] {
  try {
    do $app_icons_icon_entries
    | each {|entry|
        {
          value: $entry.app_name
          description: $entry.icon_path
        }
      }
  } catch {
    []
  }
}

# Apply custom app icon(s) from ~/.config/app-icons using Finder custom icon metadata
# (equivalent to Get Info drag-and-drop behavior).
#
# Examples:
#   app-icons apply Notion
#   app-icons apply Notion --dry-run
#   app-icons apply
def "app-icons apply" [
  app_name?: string@"app-icons --apply-completer" # Optional app name. If omitted, applies all available icons.
  --dry-run(-n) # Show what would be changed without applying icon metadata.
] {

  let icons = (
    if $app_name == null {
      do $app_icons_icon_entries
    } else {
      [ (do $app_icons_source_for_app $app_name) ]
    }
  )

  let results = (
    $icons
    | each {|entry|
        try {
          let target_app_name = $entry.app_name
          let app_bundle = (do $app_icons_resolve_app $target_app_name)
          let effective_source = (
            if $dry_run {
              { source_icon: $entry.icon_path, cleanup_dir: null, source_format: $entry.icon_format }
            } else {
              do $app_icons_prepare_finder_source $entry.icon_path
            }
          )

          let cleanup_dir = $effective_source.cleanup_dir

          if not $dry_run {
            try {
              do $app_icons_set_finder_icon $app_bundle $effective_source.source_icon
            } catch {|set_err|
              if $cleanup_dir != null {
                do $app_icons_cleanup $cleanup_dir
              }

              error make --unspanned { msg: ($set_err.msg? | default ($set_err | to json)) }
            }
          }

          if $cleanup_dir != null {
            do $app_icons_cleanup $cleanup_dir
          }

          {
            app_name: $target_app_name
            app_bundle: $app_bundle
            source_icon: $entry.icon_path
            source_format: $entry.icon_format
            apply_mode: "finder-custom-icon"
            status: (if $dry_run { "dry-run" } else { "updated" })
          }
        } catch {|err|
          {
            app_name: ($entry.app_name? | default null)
            app_bundle: null
            source_icon: ($entry.icon_path? | default null)
            source_format: ($entry.icon_format? | default null)
            apply_mode: "finder-custom-icon"
            status: "failed"
            error: ($err.msg? | default ($err | to json))
          }
        }
      }
    | collect
  )

  print ($results | table)

  if not $dry_run {
    print $"(ansi yellow)Note:(ansi reset) For icon changes to take effect, close running apps, remove them from Dock, then reopen and re-add to Dock."
  }
}
