def kotlin_version_from_catalog [catalog_path: string] {
  if (not ($catalog_path | path exists)) {
    return ""
  }

  let catalog = (try { openn $catalog_path } catch { null })
  if $catalog == null {
    return ""
  }

  let versions = ($catalog.versions? | default {})
  if (($versions | columns) | any {|c| $c == "kotlinVersion"}) {
    return ($versions.kotlinVersion | into string)
  }

  if (($versions | columns) | any {|c| $c == "kotlin"}) {
    return ($versions.kotlin | into string)
  }

  let plugins = ($catalog.plugins? | default {})
  for key in ($plugins | columns) {
    let plugin = ($plugins | get $key)
    let plugin_id = ($plugin.id? | default "" | into string)
    if not ($plugin_id | str starts-with "org.jetbrains.kotlin") {
      continue
    }

    let direct = ($plugin.version? | default "")
    if $direct != "" {
      return ($direct | into string)
    }

    let ref_key = ($plugin.version.ref? | default "")
    if $ref_key != "" {
      let ref_version = ($versions | get -o $ref_key)
      if $ref_version != null {
        return ($ref_version | into string)
      }
    }
  }

  ""
}

def kotlin_version_from_build_script [path: string] {
  if (not ($path | path exists)) {
    return ""
  }

  let lines = (openn $path | lines)
  let candidates = ($lines | where {|line|
    ($line =~ 'kotlin\("[^"]+"\)\s+version\s+"[^"]+"')
    or ($line =~ 'id\("org\.jetbrains\.kotlin[^"]*"\)\s+version\s+"[^"]+"')
    or ($line =~ 'id\s+"org\.jetbrains\.kotlin[^"]*"\s+version\s+"[^"]+"')
  })

  if (($candidates | length) == 0) {
    return ""
  }

  let parsed = (($candidates | first) | parse -r '.*version\s+"(?<value>[^"]+)".*')
  if (($parsed | length) == 0) {
    return ""
  }

  $parsed | get 0.value
}

def catalog_path_from_settings [settings_path: string] {
  if not ($settings_path | path exists) {
    return ""
  }

  let matches = (
    openn $settings_path
    | lines
    | where {|line| $line =~ "from\\(files\\([\"'][^\"']+[\"']\\)\\)"}
  )

  if (($matches | length) == 0) {
    return ""
  }

  let parsed = (($matches | first) | parse -r ".*from\\(files\\([\"'](?<path>[^\"']+)[\"']\\)\\).*")
  if (($parsed | length) == 0) {
    return ""
  }

  $parsed | get 0.path
}

def discover_catalog_path [] {
  for f in ["settings.gradle.kts", "settings.gradle"] {
    let found = (catalog_path_from_settings $f)
    if $found != "" {
      return $found
    }
  }

  ""
}

def kotlin_version_from_catalog_candidates [catalog: string] {
  for c in [$catalog, "gradle/libs.versions.toml", "gradle/libs.toml"] {
    if $c == "" {
      continue
    }

    let found = (kotlin_version_from_catalog $c)
    if $found != "" {
      return $found
    }
  }

  ""
}

def kotlin_gradle_command [] {
  let catalog = (discover_catalog_path)
  mut version = (kotlin_version_from_catalog_candidates $catalog)

  if $version == "" {
    $version = (kotlin_version_from_build_script "build.gradle.kts")
  }

  if $version == "" {
    $version = (kotlin_version_from_build_script "build.gradle")
  }

  if $version == "" {
    exit 1
  }

  $"󱈙 v($version)"
}
