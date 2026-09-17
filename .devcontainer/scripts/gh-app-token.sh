#!/usr/bin/env bash
# Reads the GitHub App installation token that the PROXY container mints
# and refreshes on its own (see .devcontainer/proxy/gh-app-token-daemon.sh)
# and hands it to `gh` + git. The private signing key never enters this
# container — only the short-lived (~1h) result, read-only. Re-run any
# time you want to pick up a freshly-minted token.
set -euo pipefail

TOKEN_FILE=/gh-token-vol/token

if [ ! -s "$TOKEN_FILE" ]; then
  echo "gh-app-token: no token yet at $TOKEN_FILE (GitHub App not configured in .env, or the proxy hasn't minted one yet) — skipping." >&2
  exit 0
fi

cat "$TOKEN_FILE" | gh auth login --with-token
gh auth setup-git
echo "gh-app-token: installed from the proxy-minted token."
