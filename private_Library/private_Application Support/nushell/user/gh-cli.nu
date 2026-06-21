# GH CLI wrappers
const GH_TOKEN_OWNERS = {
    personal: "op://Personal/gh-cli/token"
    opensockets: "op://Opensockets/gh-cli/token"
}

def gh-token-owner-completions [] {
    $GH_TOKEN_OWNERS | columns
}

def gh-token-options [] {
    gh-token-owner-completions | str join ", "
}

def gh-token-ref-for-owner [owner: string = "personal"] {
    if not ($owner in (gh-token-owner-completions)) {
        error make --unspanned { msg: $"Unknown GitHub token owner '($owner)'. Available options: (gh-token-options)" }
    }

    $GH_TOKEN_OWNERS | get $owner
}

def --wrapped gh-with-owner [owner: string@gh-token-owner-completions = "personal", ...args] {
    let token_ref = gh-token-ref-for-owner $owner
    let gh_token = (^op read --no-newline $token_ref)

    with-env { GH_TOKEN: $gh_token } {
        ^gh ...$args
    }

    ^op signout
}

def --wrapped gh [owner?: string@gh-token-owner-completions, ...args] {
    let owner_name = if $owner == null { null } else { $"($owner)" }

    if $owner_name == null or ($owner_name | str starts-with "-") {
        error make --unspanned { msg: $"Specify a GitHub token owner as the first argument. Available options: (gh-token-options)" }
    }

    gh-with-owner $owner_name ...$args
}
