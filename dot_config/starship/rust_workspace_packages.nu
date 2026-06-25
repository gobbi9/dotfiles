def rust_workspace_packages_when [] {
  if ((which cargo | length) > 0) {
    let cargo_locate = (^cargo locate-project --workspace --message-format plain | complete)
    if $cargo_locate.exit_code == 0 {
      exit 0
    }
  }

  if ((which mise | length) > 0) {
    let mise_locate = (^mise exec -- cargo locate-project --workspace --message-format plain | complete)
    if $mise_locate.exit_code == 0 {
      exit 0
    }
  }

  exit 1
}

def cargo_metadata_result [] {
  if ((which cargo | length) > 0) {
    return (^cargo metadata --no-deps --format-version 1 | complete)
  }

  { exit_code: 1, stdout: "", stderr: "" }
}

def rust_metadata_json [] {
  let cargo_result = (cargo_metadata_result)
  if $cargo_result.exit_code == 0 {
    return $cargo_result.stdout
  }

  if ((which mise | length) == 0) {
    exit 1
  }

  let mise_result = (^mise exec -- cargo metadata --no-deps --format-version 1 | complete)
  if $mise_result.exit_code != 0 {
    exit 1
  }

  $mise_result.stdout
}

def workspace_packages [metadata] {
  let members = ($metadata.workspace_members | default [])
  if (($members | length) == 0) {
    return []
  }

  (
    $members
    | each {|id|
        $metadata.packages
        | where id == $id
        | first
      }
    | sort-by name
  )
}

def group_packages_by_version [packages: list<any>] {
  $packages
  | reduce --fold [] {|pkg, acc|
      if (($acc | length) == 0) {
        [{ version: $pkg.version, names: [$pkg.name] }]
      } else {
        let last = ($acc | last)
        if $last.version == $pkg.version {
          let n = ($acc | length)
          let head = if $n > 1 { $acc | first ($n - 1) } else { [] }
          $head | append { version: $last.version, names: ($last.names | append $pkg.name) }
        } else {
          $acc | append { version: $pkg.version, names: [$pkg.name] }
        }
      }
    }
}

def rust_workspace_packages_command [] {
  let metadata_json = (rust_metadata_json)
  let metadata = (try { $metadata_json | from json } catch { null })
  if $metadata == null {
    exit 1
  }

  let packages = (workspace_packages $metadata)
  if (($packages | length) == 0) {
    exit 1
  }

  let groups = (group_packages_by_version $packages)
  let rendered = (
    $groups
    | each {|g| $"󰏗 ($g.names | str join ' ') v($g.version)" }
    | str join " "
  )

  $"($rendered)"
}
