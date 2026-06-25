use shared/tags.nu [tag_info tag_ok tag_warn tag_error tag_dry]
use shared/sync-utils.nu [chezmoi_source_dir parse_op_ref escape_assignment_key]

def extract_op_refs [template_path: string] {
  let content = (openn --raw $template_path)
  let matches = ($content | parse -r "(?m)onepasswordRead\\s+(?:\\(\\s*)?[\"'](?<ref>op://[^\"']+)[\"']")
  if ($matches | is-empty) { [] } else { $matches | get ref | uniq }
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
export def main [
  --dry-run (-n) # Print intended updates without changing 1Password.
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

  mut templates_scanned = 0
  mut templates_with_refs = 0
  mut refs_found = 0
  mut updates_planned = 0
  mut updates_succeeded = 0
  mut updates_failed = 0
  mut missing_targets = 0
  mut invalid_refs = 0

  tag_info $"Source dir: ($src)"
  tag_info $"Templates found: ($templates | length)"
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

    if not ($target | path exists) {
      $missing_targets = ($missing_targets + 1)
      tag_warn $"Missing target file: ($target) [source: ($rel)]"
      continue
    }

    let local_content = (openn --raw $target)

    tag_info $"Template: ($rel)"
    print $"       (ansi cyan)Target:(ansi reset)   ($target)"

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

      if $dry_run {
        tag_dry $"[UPDATE] ($ref) <- ($target)"
        continue
      }

      tag_info $"[UPDATE] ($ref) <- ($target)"

      let update = (update_item_field_via_template $vault $item $field $local_content $target)
      if ($update.ok == true) {
        $updates_succeeded = ($updates_succeeded + 1)
        tag_ok $"Updated existing field for ($ref)"
      } else {
        $updates_failed = ($updates_failed + 1)
        tag_error $"Failed updating ($ref) [reason: ($update.reason)]"
        if (($update.stderr | default "" | str trim | is-empty) == false) {
          print $"        (ansi red)op stderr:(ansi reset) ($update.stderr | str trim)"
        }
      }
    }

    print ""
  }

  print $"(ansi cyan_bold)Summary:(ansi reset)"
  print $"  Templates scanned:        ($templates_scanned)"
  print $"  Templates with refs:      ($templates_with_refs)"
  print $"  onepasswordRead refs:     ($refs_found)"
  print $"  Updates planned:          ($updates_planned)"
  if not $dry_run {
    print $"  Updates succeeded:        ($updates_succeeded)"
    print $"  Updates failed:           ($updates_failed)"
  }
  print $"  Missing target files:     ($missing_targets)"
  print $"  Invalid ref format count: ($invalid_refs)"
}
