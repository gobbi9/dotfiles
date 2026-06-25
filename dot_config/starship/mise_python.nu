def mise_python_raw_version [] {
  let result = (^mise current python | complete)
  if $result.exit_code != 0 {
    return ""
  }

  let parsed = ($result.stdout | parse -r '.*?(?<version>\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.]+)?)')
  if (($parsed | length) == 0) {
    return ""
  }

  $parsed | get 0.version | str trim
}

def mise_python_when [] {
  let version = (mise_python_raw_version)
  if $version == "" {
    exit 1
  }

  exit 0
}

def mise_python_command [] {
  let version = (mise_python_raw_version)
  if $version == "" {
    exit 1
  }

  $" ($version)"
}
