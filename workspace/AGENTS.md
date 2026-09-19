# Sandbox environment

This project runs inside a network-isolated dev container. A few things
that will otherwise look like confusing bugs:

## Network is allowlisted, not open

Only pre-approved domains (GitHub, npm, PyPI, NuGet, Anthropic, Copilot,
VS Code's own infra) are reachable. A blocked request typically times out
or refuses the connection — there's no "blocked by policy" message. If you
hit this, don't try to work around it (alternate registries, raw sockets,
etc.) — tell the user which domain you needed and let them add it.

## You can't see or change this sandbox's own configuration

`.devcontainer/` (the network allowlist, proxy config, secrets) lives
outside this directory tree and isn't mounted here. If asked to fix the
allowlist, adjust proxy settings, or similar, that's not reachable from in
here — say so rather than searching for it.

## Git and GitHub already work — don't set up your own auth

`git push`, `gh pr create`, `gh api`, etc. are pre-authenticated as a
dedicated GitHub App identity. Don't run `gh auth login`, don't configure
different credentials, don't ask for a token. If a `gh`/`git` command fails
with an auth error, say so rather than trying to re-authenticate — it's
likely a transient token refresh, not something fixable from here.

## The GitHub App has limited permissions

It's scoped to specific repos and typically only Contents/Issues/Pull
requests. Repo administration (secrets, workflow files, repo settings)
will likely fail with a permissions error — that's expected, not a bug to
debug around.
