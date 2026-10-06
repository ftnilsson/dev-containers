#!/usr/bin/env bash
# Runs once at container create (devcontainer.json's postCreateCommand).
#
# Replaces a one-line `a && b && c || true` chain that silently produced
# nothing when `npm install` fired before the proxy path was ready — the
# `|| true` swallowed the failure with no trace, leaving `claude` and
# `copilot` missing with no hint why. This retries, and says so loudly if it
# still can't install.
#
# Deliberately exits 0 even on failure: devcontainer lifecycle commands run
# in order and a failing one stops the rest, which would also skip
# postStartCommand (GitHub App auth) — a worse outcome than a missing CLI
# you can install by hand with the command printed below.
set -u

# Named volumes are created root-owned on both Podman and Docker, but the
# container runs as the non-root vscode user — without this, `claude login`
# and `gh auth login` fail with "permission denied" on these directories.
sudo chown -R vscode:vscode /home/vscode/.claude /home/vscode/.config/gh \
  || echo "post-create: WARNING: chown of config volumes failed" >&2

install-bundled-extensions.sh
install-agent-grove-hooks.sh

CLIS="@anthropic-ai/claude-code @github/copilot"
ATTEMPTS="${POST_CREATE_ATTEMPTS:-6}"
DELAY="${POST_CREATE_RETRY_DELAY:-10}"

# npm exiting 0 is NOT proof these installed: each CLI ships its real binary
# as a platform-specific *optional* dependency, and when the registry fetch
# for that fails transiently (the proxy returned 503s at container start)
# npm silently skips it and still exits 0 — leaving launchers that print
# "native binary not installed". So success means both CLIs actually run;
# a plain re-run of the install then fetches whatever was skipped.
clis_work() {
  hash -r
  claude --version >/dev/null 2>&1 && copilot --version >/dev/null 2>&1
}

for attempt in $(seq 1 "$ATTEMPTS"); do
  # shellcheck disable=SC2086
  npm install -g $CLIS
  if clis_work; then
    echo "post-create: agent CLIs installed and working."
    exit 0
  fi
  echo "post-create: agent CLIs not working yet (attempt $attempt/$ATTEMPTS) — the proxy path may not be ready yet; retrying in ${DELAY}s" >&2
  sleep "$DELAY"
done

echo "post-create: FAILED to install the agent CLIs after $ATTEMPTS attempts." >&2
echo "post-create: check 'podman logs <proxy container>' for denials, then run by hand:" >&2
echo "post-create:   npm install -g $CLIS" >&2
exit 0
