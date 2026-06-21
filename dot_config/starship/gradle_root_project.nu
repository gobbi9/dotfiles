def parse-quoted [line: string] {
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

def git-root-or-pwd [] {
  let root_result = (^git rev-parse --show-toplevel | complete)
  if $root_result.exit_code == 0 {
    return ($root_result.stdout | str trim)
  }

  pwd
}

def has-gradle-signals [root: string] {
  [
    "settings.gradle.kts"
    "settings.gradle"
    "build.gradle.kts"
    "build.gradle"
    "gradle.properties"
  ] | any {|f| ([$root $f] | path join | path exists) }
}

def find-root-project-name [root: string] {
  for f in ["settings.gradle.kts", "settings.gradle"] {
    let path = ([$root $f] | path join)
    if not ($path | path exists) {
      continue
    }

    let lines = (openn $path | lines)
    let name_lines = ($lines | where {|line| $line =~ '^\s*rootProject\.name\s*='})
    if (($name_lines | length) > 0) {
      let name = (parse-quoted ($name_lines | first))
      if $name != "" {
        return $name
      }
    }
  }

  $root | path basename
}

def find-version-in-build-script [root: string] {
  for f in ["build.gradle.kts", "build.gradle"] {
    let path = ([$root $f] | path join)
    if not ($path | path exists) {
      continue
    }

    let lines = (openn $path | lines)
    let version_lines = ($lines | where {|line| $line =~ '^\s*version\s*='})
    if (($version_lines | length) > 0) {
      let version = (parse-quoted ($version_lines | first))
      if $version != "" {
        return $version
      }
    }
  }

  ""
}

def find-version-in-gradle-properties [root: string] {
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

def gradle-root-project-when [] {
  let root = (git-root-or-pwd)
  if (has-gradle-signals $root) {
    exit 0
  }

  exit 1
}

def gradle-root-project-command [] {
  let root = (git-root-or-pwd)
  let name = (find-root-project-name $root)

  mut version = (find-version-in-build-script $root)
  if $version == "" {
    $version = (find-version-in-gradle-properties $root)
  }

  if $version == "" {
    exit 1
  }

  $"󰏖 ($name) v($version)"
}
