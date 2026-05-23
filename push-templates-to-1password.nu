#!/usr/bin/env nu

def parse-op-ref [ref: string] {
  let parsed = (
    $ref
    | parse -r '^op://(?<vault>[^/]+)/(?<item>[^/]+)/(?<field>.+)$'
  )

  if ($parsed | is-empty) { null } else { $parsed | first }
}

def extract-op-refs [template_path: string] {
  let content = (open --raw $template_path)
  let matches = (
    $content
    | parse -r "(?m)onepasswordRead\\s+(?:\\(\\s*)?[\"'](?<ref>op://[^\"']+)[\"']"
  )

  if ($matches | is-empty) {
    []
  } else {
    $matches | get ref | uniq
  }
}

def source-dir [] {
  let cwd = (pwd)

  try {
    let detected = (^chezmoi source-path | str trim)
    if ($detected | is-empty) { $cwd } else { $detected }
  } catch {
    $cwd
  }
}

def find-field-index [item_json: record, field_name: string] {
  let fields = ($item_json | get fields? | default [])

  let by_id = (
    $fields
    | enumerate
    | where {|r| (($r.item | get id? | default "") == $field_name) }
    | get index
  )

  if not ($by_id | is-empty) {
    return ($by_id | first)
  }

  let by_label = (
    $fields
    | enumerate
    | where {|r| (($r.item | get label? | default "") == $field_name) }
    | get index
  )

  if not ($by_label | is-empty) {
    return ($by_label | first)
  }

  null
}

def file-ref-exists [item_json: record, field_name: string] {
  let files = ($item_json | get files? | default [])

  let by_id = (
    $files
    | where {|f| (($f | get id? | default "") == $field_name) }
  )
  if not ($by_id | is-empty) {
    return true
  }

  let by_name = (
    $files
    | where {|f| (($f | get name? | default "") == $field_name) }
  )

  not ($by_name | is-empty)
}

def escape-assignment-key [s: string] {
  $s
  | str replace --all "\\" "\\\\"
  | str replace --all "." "\\."
  | str replace --all "=" "\\="
}

def update-item-field-via-template [vault: string, item: string, field_name: string, value: string, source_file_path: string] {
  let get_result = (^op item get $item --vault $vault --format json | complete)
  if ($get_result.exit_code != 0) {
    return {
      ok: false,
      reason: "get_failed",
      stderr: ($get_result.stderr | str trim)
    }
  }

  let item_json = (try {
    $get_result.stdout | from json
  } catch {
    return {
      ok: false,
      reason: "json_parse_failed",
      stderr: "Failed parsing `op item get --format json` output"
    }
  })

  let idx = (find-field-index $item_json $field_name)
  if ($idx != null) {
    let updated_fields = (
      ($item_json | get fields)
      | enumerate
      | each {|r|
        if ($r.index == $idx) {
          $r.item | upsert value $value
        } else {
          $r.item
        }
      }
    )

    let updated_item = ($item_json | upsert fields $updated_fields)

    let tmpfile = (^mktemp | str trim)
    ($updated_item | to json) | save -f $tmpfile

    let edit_result = (^op item edit $item --vault $vault --template $tmpfile | complete)
    rm -f $tmpfile

    if ($edit_result.exit_code == 0) {
      return {
        ok: true,
        reason: "ok",
        stderr: ""
      }
    } else {
      return {
        ok: false,
        reason: "edit_failed",
        stderr: ($edit_result.stderr | str trim)
      }
    }
  }

  # If not a standard field, it may be a file attachment referenced as op://.../filename.ext.
  if (file-ref-exists $item_json $field_name) {
    let escaped = (escape-assignment-key $field_name)
    let assignment = $"($escaped)[file]=($source_file_path)"
    let file_edit_result = (^op item edit $item --vault $vault $assignment | complete)

    if ($file_edit_result.exit_code == 0) {
      return {
        ok: true,
        reason: "ok_file",
        stderr: ""
      }
    } else {
      return {
        ok: false,
        reason: "edit_file_failed",
        stderr: ($file_edit_result.stderr | str trim)
      }
    }
  }

  {
    ok: false,
    reason: "field_not_found",
    stderr: $"Field/file not found by id/label/name: ($field_name)"
  }
}

def main [
  --dry-run (-n) # Print intended updates without changing 1Password.
] {
  let src = (source-dir)

  if not ($src | path exists) {
    print $"[ERROR] Source path does not exist: ($src)"
    exit 1
  }

  try {
    ^op --version | ignore
  } catch {
    print "[ERROR] `op` CLI is not available. Install/sign in first."
    exit 1
  }

  let templates = (
    glob ($src | path join "**" "*.tmpl")
    | where {|p| ($p | path type) == "file" }
  )

  mut templates_scanned = 0
  mut templates_with_refs = 0
  mut refs_found = 0
  mut updates_planned = 0
  mut updates_succeeded = 0
  mut updates_failed = 0
  mut missing_targets = 0
  mut invalid_refs = 0

  print $"[INFO] Source dir: ($src)"
  print $"[INFO] Templates found: ($templates | length)"
  print $"[INFO] Mode: (if $dry_run { 'DRY-RUN' } else { 'APPLY' })"
  print ""

  for tmpl in $templates {
    $templates_scanned = ($templates_scanned + 1)

    let refs = (try {
      extract-op-refs $tmpl
    } catch {
      print $"[WARN] Could not parse template: ($tmpl)"
      []
    })

    if ($refs | is-empty) {
      continue
    }

    $templates_with_refs = ($templates_with_refs + 1)
    $refs_found = ($refs_found + ($refs | length))

    let rel = ($tmpl | path relative-to $src)
    let target = (try {
      ^chezmoi target-path $rel | str trim
    } catch {
      print $"[WARN] Could not resolve target path for: ($rel)"
      ""
    })

    if ($target | is-empty) {
      continue
    }

    if not ($target | path exists) {
      $missing_targets = ($missing_targets + 1)
      print $"[WARN] Missing target file: ($target) [source: ($rel)]"
      continue
    }

    let local_content = (open --raw $target)

    print $"[INFO] Template: ($rel)"
    print $"       Target:   ($target)"

    for ref in $refs {
      let parsed = (parse-op-ref $ref)
      if ($parsed == null) {
        $invalid_refs = ($invalid_refs + 1)
        print $"[WARN] Unsupported ref format [expected op://vault/item/field]: ($ref)"
        continue
      }

      let vault = $parsed.vault
      let item = $parsed.item
      let field = $parsed.field

      $updates_planned = ($updates_planned + 1)

      if $dry_run {
        print $"[DRY-RUN] [UPDATE] ($ref) <- ($target)"
        continue
      }

      # Print ref BEFORE op calls, so biometric prompts are unambiguous.
      print $"[UPDATE] ($ref) <- ($target)"

      let update = (update-item-field-via-template $vault $item $field $local_content $target)
      if ($update.ok == true) {
        $updates_succeeded = ($updates_succeeded + 1)
        print $"[OK] Updated existing field for ($ref)"
      } else {
        $updates_failed = ($updates_failed + 1)
        print $"[ERROR] Failed updating ($ref) [reason: ($update.reason)]"
        if (($update.stderr | default "" | str trim | is-empty) == false) {
          print $"        op stderr: ($update.stderr | str trim)"
        }
      }
    }

    print ""
  }

  print "Summary:"
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

  if ($updates_failed > 0) {
    exit 1
  }
}
