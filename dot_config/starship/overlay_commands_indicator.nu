def overlay-read-lines [] {
  let module_path = (($env.PWD | default ".") | path join "overlay.nu")
  if not ($module_path | path exists) {
    exit 1
  }

  openn $module_path | lines
}

def overlay-exported-names [src_lines: list<string>] {
  (
    ($src_lines
      | parse -r '^\s*export\s+def(?:\s+--[A-Za-z0-9_-]+)*\s+(?<name>"[^"]+"|[A-Za-z0-9_-]+)'
      | get -o name)
    | append ($src_lines
        | parse -r '^\s*export\s+alias\s+(?<name>[A-Za-z0-9_-]+)\s*=\s*(?<target>.+?)\s*$'
        | get -o name)
    | append ($src_lines
        | parse -r '^\s*export\s+extern\s+(?<name>"[^"]+"|[A-Za-z0-9_-]+)'
        | get -o name)
    | each {|name| $name | str replace -a '"' '' }
    | uniq
  )
}

def overlay-commands-indicator-command [] {
  let src_lines = (overlay-read-lines)
  let exported_names = (overlay-exported-names $src_lines)

  if ($exported_names | is-empty) {
    exit 1
  }

  let total = ($exported_names | length)
  let subs = {
    "0": "₀"
    "1": "₁"
    "2": "₂"
    "3": "₃"
    "4": "₄"
    "5": "₅"
    "6": "₆"
    "7": "₇"
    "8": "₈"
    "9": "₉"
  }

  let subscript_total = (
    $total
    | into string
    | split chars
    | each {|d| $subs | get $d }
    | str join ""
  )

  $"($subscript_total)"
}
