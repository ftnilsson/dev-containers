#!/bin/sh
# Runs inside the PROXY container, not the agent's workspace container —
# that's the whole point. Mints fresh ~1h GitHub App installation tokens
# and writes ONLY the token to a volume the workspace container can read
# but not write; the private signing key itself never enters any container
# the agent has shell access to.
set -u

TOKEN_FILE=/gh-token-vol/token
KEY_FILE="${GH_APP_PRIVATE_KEY_PATH:-/run/secrets/github-app-key.pem}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

mint_once() {
  if [ -z "${GH_APP_ID:-}" ] || [ -z "${GH_APP_INSTALLATION_ID:-}" ] || [ ! -s "$KEY_FILE" ]; then
    return 1
  fi

  now=$(date +%s)
  iat=$((now - 60))
  exp=$((now + 540))   # JWT itself only needs to live long enough for one API call

  header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$GH_APP_ID" | b64url)
  signature=$(printf '%s.%s' "$header" "$payload" \
    | openssl dgst -sha256 -sign "$KEY_FILE" | b64url)
  jwt="${header}.${payload}.${signature}"

  response=$(curl -sS -X POST \
    -H "Authorization: Bearer ${jwt}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${GH_APP_INSTALLATION_ID}/access_tokens")

  token=$(echo "$response" | jq -r '.token // empty')
  [ -n "$token" ] || return 1

  # World-readable (0644), not 0600: this daemon runs as root in the proxy
  # container, but the workspace container's non-root user needs to read
  # it too. Unix perms on top of the read-only mount are belt-and-braces —
  # the real boundary is that workspace has no write access to the mount
  # at all, and no access whatsoever to the signing key that produced this.
  umask 022
  printf '%s' "$token" > "${TOKEN_FILE}.tmp"
  mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"
}

while true; do
  mint_once || echo "gh-app-token-daemon: mint failed or not configured, will retry" >&2
  sleep 2700   # ~45 min — comfortably inside the token's ~1h validity
done
