def non-empty-lines [content: string] {
  $content | lines | where {|line| $line != ""}
}

def head-tags [] {
  let tags = (^git tag --points-at HEAD --sort=-creatordate)
  non-empty-lines $tags | str join ","
}

def start-ref [head_tags: string] {
  if ($head_tags == "") {
    return "HEAD"
  }

  let head_prev = (^git rev-parse --verify HEAD^ | complete)
  if $head_prev.exit_code == 0 {
    return ($head_prev.stdout | str trim)
  }

  ""
}

def previous-tags [start_ref: string] {
  if ($start_ref == "") {
    return ""
  }

  let nearest_tag_result = (^git describe --tags --abbrev=0 --first-parent $start_ref | complete)
  if $nearest_tag_result.exit_code != 0 {
    return ""
  }

  let nearest_tag = ($nearest_tag_result.stdout | str trim)
  if $nearest_tag == "" {
    return ""
  }

  let commit_result = (^git rev-list -n 1 $nearest_tag | complete)
  if $commit_result.exit_code != 0 {
    return ""
  }

  let tag_commit = ($commit_result.stdout | str trim)
  if $tag_commit == "" {
    return ""
  }

  let tags = (^git tag --points-at $tag_commit --sort=-creatordate)
  non-empty-lines $tags | str join ","
}

def git-tags-when [] {
  let git_repo = (^git rev-parse --is-inside-work-tree | complete)
  if $git_repo.exit_code == 0 {
    exit 0
  }

  exit 1
}

def git-tags-command [] {
  let head_tags = (head-tags)
  let start_ref_value = (start-ref $head_tags)
  let prev_tags = (previous-tags $start_ref_value)

  mut out = ""
  if ($prev_tags != "") {
    $out = $"󰋚 ($prev_tags)"
  }

  if ($head_tags != "") {
    if ($out != "") {
      $out = $"($out)  ($head_tags)"
    } else {
      $out = $" ($head_tags)"
    }
  }

  if ($out == "") {
    $out = "󱈠·"
  }

  $out
}
