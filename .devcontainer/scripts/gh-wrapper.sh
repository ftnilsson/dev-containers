#!/usr/bin/env bash
# Installed as /usr/local/bin/gh, ahead of the real /usr/bin/gh on PATH.
#
# Reads the GitHub App token the proxy container mints (see
# proxy/gh-app-token-daemon.sh) fresh on EVERY invocation and hands it to gh
# via GH_TOKEN, instead of relying on a cached copy in ~/.config/gh/hosts.yml.
# That cache went stale whenever the background watcher meant to refresh it
# wasn't running, leaving every `gh` call failing with "token is invalid"
# even though the token file itself was valid. Nothing long-lived to die now.
#
# An explicit GH_TOKEN/GITHUB_TOKEN in the environment wins, and with no
# App token available (App not configured yet) gh behaves normally.
token_file=/gh-token-vol/token
if [ -z "${GH_TOKEN:-}" ] && [ -z "${GITHUB_TOKEN:-}" ] && [ -s "$token_file" ]; then
  GH_TOKEN=$(cat "$token_file")
  export GH_TOKEN
fi
exec /usr/bin/gh "$@"
