#!/usr/bin/env bash
# Mints a short-lived (~1h) GitHub App installation access token and hands
# it to `gh` + git, so the agent authenticates as the dedicated App — never
# as your personal GitHub account. Re-run any time the token has expired.
set -euo pipefail

: "${GH_APP_ID:?Set GH_APP_ID in .env}"
: "${GH_APP_INSTALLATION_ID:?Set GH_APP_INSTALLATION_ID in .env}"
: "${GH_APP_PRIVATE_KEY_PATH:?Set GH_APP_PRIVATE_KEY_PATH (mounted key file)}"

# -s (not just -f): the default mount is an empty placeholder file when
# GH_APP_PRIVATE_KEY_HOST_PATH isn't set yet, so "exists" alone isn't enough.
if [ ! -s "$GH_APP_PRIVATE_KEY_PATH" ]; then
  echo "gh-app-token: no private key configured (GH_APP_PRIVATE_KEY_HOST_PATH unset in .env) — skipping." >&2
  exit 0
fi

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
iat=$((now - 60))
exp=$((now + 540))   # JWT itself only needs to live long enough for one API call

header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$GH_APP_ID" | b64url)
signature=$(printf '%s.%s' "$header" "$payload" \
  | openssl dgst -sha256 -sign "$GH_APP_PRIVATE_KEY_PATH" | b64url)
jwt="${header}.${payload}.${signature}"

response=$(curl -sS -X POST \
  -H "Authorization: Bearer ${jwt}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${GH_APP_INSTALLATION_ID}/access_tokens")

token=$(echo "$response" | jq -r '.token // empty')

if [ -z "$token" ]; then
  echo "gh-app-token: failed to mint installation token:" >&2
  echo "$response" >&2
  exit 1
fi

echo "$token" | gh auth login --with-token
gh auth setup-git
echo "gh-app-token: installed, valid ~1h. Re-run this script when it expires."
