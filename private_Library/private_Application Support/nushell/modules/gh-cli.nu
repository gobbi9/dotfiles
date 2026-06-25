# GH CLI wrappers
const GH_TOKEN_OWNERS = {
  personal: "op://Personal/gh-cli/token"
  opensockets: "op://Opensockets/gh-cli/token"
}

def gh_token_owner_completions [] {
  $GH_TOKEN_OWNERS | columns
}

def gh_token_options [] {
  gh_token_owner_completions | str join ", "
}

def gh_token_ref_for_owner [owner: string = "personal"] {
  if not ($owner in (gh_token_owner_completions)) {
    error make --unspanned { msg: $"Unknown GitHub token owner '($owner)'. Available options: (gh_token_options)" }
  }

  $GH_TOKEN_OWNERS | get $owner
}

def gh_with_owner [owner: string@gh_token_owner_completions = "personal", ...args] {
  let token_ref = (gh_token_ref_for_owner $owner)
  let gh_token = (^op read --no-newline $token_ref)

  with-env { GH_TOKEN: $gh_token } {
    ^gh ...$args
  }

  ^op signout
}

# Run GitHub CLI with a 1Password-backed token selected by owner.
# Requires token owner as first arg (`personal` or `opensockets`).
export def --wrapped gh [owner?: string@gh_token_owner_completions, ...args] {
  let owner_name = if $owner == null { null } else { $"($owner)" }

  if $owner_name == null or ($owner_name | str starts-with "-") {
    error make --unspanned { msg: $"Specify a GitHub token owner as the first argument. Available options: (gh_token_options)" }
  }

  gh_with_owner $owner_name ...$args
}
