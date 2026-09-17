#!/usr/bin/env bash
# Reads the GitHub App installation token that the PROXY container mints
# and refreshes on its own (see .devcontainer/proxy/gh-app-token-daemon.sh)
# and hands it to `gh` + git. The private signing key never enters this
# container — only the short-lived (~1h) result, read-only.
set -euo pipefail

TOKEN_FILE=/gh-token-vol/token
LAST_SYNCED_MARKER="$HOME/.cache/.gh-app-token-last-mtime"
mkdir -p "$(dirname "$LAST_SYNCED_MARKER")"

sync_once() {
  [ -s "$TOKEN_FILE" ] || return 1
  cat "$TOKEN_FILE" | gh auth login --with-token
}

# git reads this helper's output fresh on every single git operation — no
# caching, so it never goes stale between polls the way a one-time `gh auth
# login` would. --replace-all: this is a multi-valued git config key, so a
# plain `git config --global KEY VALUE` on a repeat run (or one that
# collides with a helper `gh auth setup-git` set previously) just APPENDS
# another entry instead of replacing it — breaking every later git command
# with a "multiple values" error instead of being the idempotent no-op this
# needs to be, since it's called on every invocation of this script.
git config --global --replace-all credential.https://github.com.helper \
  '!f() { echo username=x-access-token; echo "password=$(cat '"$TOKEN_FILE"')"; }; f'

if sync_once; then
  stat -c %Y "$TOKEN_FILE" > "$LAST_SYNCED_MARKER" 2>/dev/null || true
  echo "gh-app-token: installed from the proxy-minted token."
else
  echo "gh-app-token: no token yet at $TOKEN_FILE (GitHub App not configured in .env, or the proxy hasn't minted one yet) — skipping." >&2
fi

# `gh` (as opposed to plain git) caches the token in hosts.yml rather than
# reading it live, so a container left running for hours (across host
# sleep, say) needs this to periodically notice the proxy minted a newer
# token and re-import it — otherwise gh-specific commands (gh pr create,
# gh api, ...) silently keep using an expired token indefinitely between
# container starts, even though `git push` itself would still work fine
# via the credential helper above.
WATCHER_PIDFILE="$HOME/.cache/.gh-app-token-watcher.pid"
if [ -f "$WATCHER_PIDFILE" ] && kill -0 "$(cat "$WATCHER_PIDFILE")" 2>/dev/null; then
  : # already running (e.g. this script was re-run by hand) — don't stack another
else
  # Neither `disown` nor `trap '' HUP` was enough in testing — the watcher
  # still died when the launching exec session closed, which means the
  # container runtime is tearing down the whole process GROUP on exit, not
  # sending a catchable SIGHUP to just this process. `setsid` is the actual
  # fix: it detaches into a brand new session, independent of whatever
  # started it. `export -f` makes sync_once (defined above) visible to that
  # new bash process — a plain `nohup sh -c '...'` wouldn't have it, since
  # it wouldn't inherit this script's function definitions at all.
  export -f sync_once
  export TOKEN_FILE LAST_SYNCED_MARKER
  setsid bash -c '
    echo $$ > "'"$WATCHER_PIDFILE"'"
    while true; do
      sleep 60
      if [ -s "$TOKEN_FILE" ]; then
        mtime=$(stat -c %Y "$TOKEN_FILE" 2>/dev/null || echo 0)
        last=$(cat "$LAST_SYNCED_MARKER" 2>/dev/null || echo 0)
        if [ "$mtime" != "$last" ] && sync_once; then
          echo "$mtime" > "$LAST_SYNCED_MARKER"
        fi
      fi
    done
  ' </dev/null >/tmp/gh-app-token-watch.log 2>&1 &
  disown
fi
