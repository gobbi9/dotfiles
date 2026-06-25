def parse_quoted [line: string] {
  let with_double_quotes = ($line | parse -r '.*"(?<value>[^"]+)".*')
  if (($with_double_quotes | length) > 0) {
    return ($with_double_quotes | get 0.value)
  }

  let with_single_quotes = ($line | parse -r ".*'(?<value>[^']+)'.*")
  if (($with_single_quotes | length) > 0) {
    return ($with_single_quotes | get 0.value)
  }

  ""
}

def git_root_or_pwd [] {
  let root_result = (^git rev-parse --show-toplevel | complete)
  if $root_result.exit_code == 0 {
    return ($root_result.stdout | str trim)
  }

  pwd
}

def has_gradle_signals [root: string] {
  [
    "settings.gradle.kts"
    "settings.gradle"
    "build.gradle.kts"
    "build.gradle"
    "gradle.properties"
  ] | any {|f| ([$root $f] | path join | path exists) }
}

def find_root_project_name [root: string] {
  for f in ["settings.gradle.kts", "settings.gradle"] {
    let path = ([$root $f] | path join)
    if not ($path | path exists) {
      continue
    }

    let lines = (openn $path | lines)
    let name_lines = ($lines | where {|line| $line =~ '^\s*rootProject\.name\s*='})
    if (($name_lines | length) > 0) {
      let name = (parse_quoted ($name_lines | first))
      if $name != "" {
        return $name
      }
    }
  }

  $root | path basename
}

def find_version_in_build_script [root: string] {
  for f in ["build.gradle.kts", "build.gradle"] {
    let path = ([$root $f] | path join)
    if not ($path | path exists) {
      continue
    }

    let lines = (openn $path | lines)
    let version_lines = ($lines | where {|line| $line =~ '^\s*version\s*='})
    if (($version_lines | length) > 0) {
      let version = (parse_quoted ($version_lines | first))
      if $version != "" {
        return $version
      }
    }
  }

  ""
}

def find_version_in_gradle_properties [root: string] {
  let gradle_props = ([$root "gradle.properties"] | path join)
  if not ($gradle_props | path exists) {
    return ""
  }

  let lines = (openn $gradle_props | lines)
  let version_lines = ($lines | where {|line| $line =~ '^\s*version\s*='})
  if (($version_lines | length) == 0) {
    return ""
  }

  let parsed = (($version_lines | first) | parse -r '^\s*version\s*=\s*(?<version>.+)$')
  if (($parsed | length) == 0) {
    return ""
  }

  ($parsed | get 0.version) | str trim
}

def gradle_root_project_when [] {
  let root = (git_root_or_pwd)
  if (has_gradle_signals $root) {
    exit 0
  }

  exit 1
}

def gradle_root_project_command [] {
  let root = (git_root_or_pwd)
  let name = (find_root_project_name $root)

  mut version = (find_version_in_build_script $root)
  if $version == "" {
    $version = (find_version_in_gradle_properties $root)
  }

  if $version == "" {
    exit 1
  }

  $"󰏖 ($name) v($version)"
}
