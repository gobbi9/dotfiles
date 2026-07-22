# Open the current Git repository's remote URL in the default web browser.

def repository_web_url [remote_url: string] {
  let trimmed_url = ($remote_url | str trim | str replace -r '\.git$' '')

  if $trimmed_url =~ '^https?://' {
    return $trimmed_url
  }

  let ssh_url = (
    $trimmed_url
    | parse -r '^(?:ssh://)?(?:[^@/]+@)?(?<host>[^/:]+)(?::\d+)?[/:](?<path>.+)$'
    | get 0?
  )

  if $ssh_url == null {
    error make --unspanned { msg: $"Unsupported Git remote URL: ($remote_url)" }
  }

  $"https://($ssh_url.host)/($ssh_url.path)"
}

# Open a Git remote's repository page in the default web browser.
export def web [remote: string = "origin"] {
  let remote_url = (^git remote get-url $remote | complete)

  if $remote_url.exit_code != 0 {
    let message = ($remote_url.stderr | str trim)
    error make --unspanned { msg: $"Could not get Git remote '($remote)': ($message)" }
  }

  let web_url = (repository_web_url $remote_url.stdout)
  ^open $web_url
}
