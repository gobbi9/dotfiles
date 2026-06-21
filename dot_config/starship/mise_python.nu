def mise-python-raw-version [] {
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

def mise-python-when [] {
  let version = (mise-python-raw-version)
  if $version == "" {
    exit 1
  }

  exit 0
}

def mise-python-command [] {
  let version = (mise-python-raw-version)
  if $version == "" {
    exit 1
  }

  $" ($version)"
}
