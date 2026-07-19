use shared/tags.nu [tag_info tag_ok tag_warn tag_error tag_dry]
use shared/sync-utils.nu [chezmoi_source_dir run_chezmoi_apply parse_op_ref escape_assignment_key]

def extract_op_refs [template_path: string] {
  let content = (open --raw $template_path)
  let matches = ($content | parse -r "(?m)onepasswordRead\\s+(?:\\(\\s*)?[\"'](?<ref>op://[^\"']+)[\"']")
  if ($matches | is-empty) { [] } else { $matches | get ref | uniq }
}

def changed_target_paths [source_dir: string] {
  let diff_result = (^chezmoi --source $source_dir diff --no-pager --color=false --use-builtin-diff | complete)
  if ($diff_result.exit_code != 0) {
    error make --unspanned {
      msg: "`chezmoi diff` failed while checking changed targets"
      help: "Run `chezmoi diff` directly to resolve the problem before running `op push`."
    }
  }

  let headers = (
    $diff_result.stdout
    | lines
    | parse -r '^diff --git a/(?<source>.+) b/(?<target>.+)$'
  )
  if ($headers | is-empty) {
    return []
  }

  $headers | get target | each {|target| $nu.home-dir | path join $target } | uniq
}

def find_field_index [item_json: record, field_name: string] {
  let fields = ($item_json | get fields? | default [])

  let by_id = ($fields | enumerate | where {|r| (($r.item | get id? | default "") == $field_name) } | get index)
  if not ($by_id | is-empty) { return ($by_id | first) }

  let by_label = ($fields | enumerate | where {|r| (($r.item | get label? | default "") == $field_name) } | get index)
  if not ($by_label | is-empty) { return ($by_label | first) }

  null
}

def file_ref_exists [item_json: record, field_name: string] {
  let files = ($item_json | get files? | default [])
  let by_id = ($files | where {|f| (($f | get id? | default "") == $field_name) })
  if not ($by_id | is-empty) { return true }

  let by_name = ($files | where {|f| (($f | get name? | default "") == $field_name) })
  not ($by_name | is-empty)
}

def update_field_with_template [item_json: record, field_index: int, value: string, item: string, vault: string] {
  let updated_fields = (
    ($item_json | get fields)
    | enumerate
    | each {|r| if ($r.index == $field_index) { $r.item | upsert value $value } else { $r.item } }
  )

  let updated_item = ($item_json | upsert fields $updated_fields)
  let tmpfile = (^mktemp | str trim)
  ($updated_item | to json) | save -f $tmpfile

  let edit_result = (^op item edit $item --vault $vault --template $tmpfile | complete)
  rm -f $tmpfile

  if ($edit_result.exit_code == 0) {
    { ok: true, reason: "ok", stderr: "" }
  } else {
    { ok: false, reason: "edit_failed", stderr: ($edit_result.stderr | str trim) }
  }
}

def update_file_ref [field_name: string, source_file_path: string, item: string, vault: string] {
  let escaped = (escape_assignment_key $field_name)
  let assignment = $"($escaped)[file]=($source_file_path)"
  let file_edit_result = (^op item edit $item --vault $vault $assignment | complete)

  if ($file_edit_result.exit_code == 0) {
    { ok: true, reason: "ok_file", stderr: "" }
  } else {
    { ok: false, reason: "edit_file_failed", stderr: ($file_edit_result.stderr | str trim) }
  }
}

def update_item_field_via_template [vault: string, item: string, field_name: string, value: string, source_file_path: string] {
  let get_result = (^op item get $item --vault $vault --format json | complete)
  if ($get_result.exit_code != 0) {
    return { ok: false, reason: "get_failed", stderr: ($get_result.stderr | str trim) }
  }

  let item_json = (try {
    $get_result.stdout | from json
  } catch {
    return { ok: false, reason: "json_parse_failed", stderr: "Failed parsing `op item get --format json` output" }
  })

  let idx = (find_field_index $item_json $field_name)
  if ($idx != null) {
    return (update_field_with_template $item_json $idx $value $item $vault)
  }

  if (file_ref_exists $item_json $field_name) {
    return (update_file_ref $field_name $source_file_path $item $vault)
  }

  { ok: false, reason: "field_not_found", stderr: $"Field/file not found by id/label/name: ($field_name)" }
}

# Scan chezmoi templates for `onepasswordRead` refs and push rendered target content to 1Password.
# Supports dry-run mode for previewing planned updates.
export def "op push" [
  --dry-run (-n) # Print intended updates without changing 1Password.
  --all # Update every template instead of only templates with a changed target.
  --source-dir: string = "" # Override chezmoi source directory.
] {
  let src = (chezmoi_source_dir --source_dir $source_dir)

  if not ($src | path exists) {
    error make --unspanned { msg: $"Source path does not exist: ($src)" }
  }

  try {
    ^op --version | ignore
  } catch {
    error make --unspanned { msg: "`op` CLI is not available. Install/sign in first." }
  }

  let templates = (glob ($src | path join "**" "*.tmpl") | where {|p| ($p | path type) == "file" })
  let changed_targets = if $all {
    []
  } else {
    tag_info "Checking changed targets with `chezmoi diff`..."
    changed_target_paths $src
  }

  mut templates_scanned = 0
  mut templates_selected = 0
  mut templates_with_refs = 0
  mut refs_found = 0
  mut updates_planned = 0
  mut updates_succeeded = 0
  mut updates_failed = 0
  mut applies_planned = 0
  mut applies_succeeded = 0
  mut applies_failed = 0
  mut missing_targets = 0
  mut invalid_refs = 0

  tag_info $"Source dir: ($src)"
  tag_info $"Templates found: ($templates | length)"
  tag_info $"Scope: (if $all { 'ALL TEMPLATES' } else { 'CHANGED TARGETS' })"
  tag_info $"Mode: (if $dry_run { 'DRY-RUN' } else { 'APPLY' })"
  print ""

  for tmpl in $templates {
    $templates_scanned = ($templates_scanned + 1)

    let refs = (try { extract_op_refs $tmpl } catch { tag_warn $"Could not parse template: ($tmpl)"; [] })
    if ($refs | is-empty) {
      continue
    }

    $templates_with_refs = ($templates_with_refs + 1)
    $refs_found = ($refs_found + ($refs | length))

    let rel = ($tmpl | path relative-to $src)
    let target = (try { ^chezmoi target-path $rel | str trim } catch { tag_warn $"Could not resolve target path for: ($rel)"; "" })
    if ($target | is-empty) {
      continue
    }

    if not $all and not ($changed_targets | any {|changed_target| $changed_target == $target }) {
      continue
    }
    $templates_selected = ($templates_selected + 1)

    if not ($target | path exists) {
      $missing_targets = ($missing_targets + 1)
      tag_warn $"Missing target file: ($target) [source: ($rel)]"
      continue
    }

    let local_content = (open --raw $target)

    tag_info $"Template: ($rel)"
    print $"       (ansi cyan)Target:(ansi reset)   ($target)"

    mut template_updates_planned = 0
    mut template_updates_succeeded = 0

    for ref in $refs {
      let parsed = (parse_op_ref $ref)
      if ($parsed == null) {
        $invalid_refs = ($invalid_refs + 1)
        tag_warn $"Unsupported ref format [expected op://vault/item/field]: ($ref)"
        continue
      }

      let vault = $parsed.vault
      let item = $parsed.item
      let field = $parsed.field

      $updates_planned = ($updates_planned + 1)
      $template_updates_planned = ($template_updates_planned + 1)

      if $dry_run {
        tag_dry $"[UPDATE] ($ref) <- ($target)"
        continue
      }

      tag_info $"[UPDATE] ($ref) <- ($target)"

      let update = (update_item_field_via_template $vault $item $field $local_content $target)
      if ($update.ok == true) {
        $updates_succeeded = ($updates_succeeded + 1)
        $template_updates_succeeded = ($template_updates_succeeded + 1)
        tag_ok $"Updated existing field for ($ref)"
      } else {
        $updates_failed = ($updates_failed + 1)
        tag_error $"Failed updating ($ref) [reason: ($update.reason)]"
        if (($update.stderr | default "" | str trim | is-empty) == false) {
          print $"        (ansi red)op stderr:(ansi reset) ($update.stderr | str trim)"
        }
      }
    }

    let should_apply = if $dry_run {
      $template_updates_planned > 0
    } else {
      $template_updates_succeeded > 0
    }

    if $should_apply {
      $applies_planned = ($applies_planned + 1)

      if $dry_run {
        tag_dry $"[APPLY] chezmoi apply --force ($target)"
      } else {
        tag_info $"[APPLY] chezmoi apply --force ($target)"
        let apply_result = (run_chezmoi_apply $target)
        if ($apply_result.ok == true) {
          $applies_succeeded = ($applies_succeeded + 1)
          tag_ok $"Synchronized chezmoi state: ($target)"
        } else {
          $applies_failed = ($applies_failed + 1)
          tag_error $"`chezmoi apply` failed for: ($target)"
          if (($apply_result.stderr | default "" | str trim | is-empty) == false) {
            print $"        (ansi red)chezmoi stderr:(ansi reset) ($apply_result.stderr | str trim)"
          }
        }
      }
    }

    print ""
  }

  let changed_target_count = ($changed_targets | length)
  let changed_target_summary = if $all {
    "Not checked (--all)"
  } else {
    $"($changed_target_count)"
  }
  let update_results = if $dry_run {
    $"($updates_planned) planned"
  } else {
    $"($updates_planned) planned, ($updates_succeeded) succeeded, ($updates_failed) failed"
  }
  let apply_results = if $dry_run {
    $"($applies_planned) planned"
  } else {
    $"($applies_planned) planned, ($applies_succeeded) succeeded, ($applies_failed) failed"
  }
  let summary = [
    { metric: "Templates scanned", value: $"($templates_scanned)" }
    { metric: "Templates with 1Password refs", value: $"($templates_with_refs)" }
    { metric: "Templates selected", value: $"($templates_selected)" }
    { metric: "Changed targets", value: $changed_target_summary }
    { metric: "onepasswordRead refs", value: $"($refs_found)" }
    { metric: "1Password updates", value: $update_results }
    { metric: "chezmoi applies", value: $apply_results }
    { metric: "Missing target files", value: $"($missing_targets)" }
    { metric: "Invalid refs", value: $"($invalid_refs)" }
  ]

  print $"(ansi cyan_bold)Summary:(ansi reset)"
  $summary | table --index false
}
