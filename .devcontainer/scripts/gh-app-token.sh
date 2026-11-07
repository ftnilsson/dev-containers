#!/usr/bin/env bash
# Run by postStartCommand. Points git at the GitHub App token the PROXY
# container mints and refreshes (see .devcontainer/proxy/gh-app-token-daemon.sh).
# The private signing key never enters this container — only the short-lived
# (~1h) token, read-only.
#
# Nothing here caches the token or runs in the background, on purpose: both
# `git` (the credential helper below) and `gh` (the wrapper at
# /usr/local/bin/gh, see gh-wrapper.sh) read /gh-token-vol/token fresh on
# every call, so there is no copy to go stale and no long-lived process to
# die. An earlier design — `gh auth login` plus a background watcher to keep
# its cache fresh — repeatedly ended up with a stale cache and no watcher.
set -euo pipefail

TOKEN_FILE=/gh-token-vol/token

# --replace-all: this is a multi-valued git config key, so a plain
# `git config --global KEY VALUE` on a repeat run just APPENDS another entry
# and breaks every later git command with a "multiple values" error. The
# URL-scoped helper is consulted before the global one VS Code forwards from
# your host, so git authenticates as the App, not your personal account.
git config --global --replace-all credential.https://github.com.helper \
  '!f() { echo username=x-access-token; echo "password=$(cat '"$TOKEN_FILE"')"; }; f'

# Clear any cached App login left in ~/.config/gh by the old design (the
# gh-config volume persists across rebuilds). It's dead weight now — the
# wrapper's GH_TOKEN takes precedence — and once stale makes `gh auth status`
# list a failing account and exit 1, which reads like broken auth. Only
# [bot] accounts: a personal login in the same file is never touched.
if [ -f "$HOME/.config/gh/hosts.yml" ]; then
  for bot in $(grep -oE '[A-Za-z0-9._-]+\[bot\]' "$HOME/.config/gh/hosts.yml" | sort -u); do
    env -u GH_TOKEN -u GITHUB_TOKEN /usr/bin/gh auth logout --hostname github.com --user "$bot" >/dev/null 2>&1 || true
  done
fi

if [ -s "$TOKEN_FILE" ]; then
  echo "gh-app-token: App token available; git and gh read it live."
else
  echo "gh-app-token: no token yet at $TOKEN_FILE (GitHub App not configured in .env, or the proxy hasn't minted one yet)." >&2
fi
