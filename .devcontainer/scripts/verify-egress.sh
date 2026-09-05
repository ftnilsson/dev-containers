#!/usr/bin/env bash
# Run this INSIDE the workspace container after it starts.
set -uo pipefail

echo "== Allowed domain (api.anthropic.com) should succeed =="
if curl -sS -m 8 -o /dev/null -w "HTTP %{http_code}\n" https://api.anthropic.com; then
  :
else
  echo "FAILED — check proxy container logs and allowlist.txt"
fi

echo
echo "== Disallowed domain (example.com) should FAIL =="
if curl -sS -m 5 https://example.com >/dev/null 2>&1; then
  echo "WARNING: example.com was reachable — deny-by-default is NOT working"
else
  echo "OK: blocked as expected"
fi

echo
echo "== Direct egress bypassing the proxy should also FAIL =="
if curl -sS -m 5 --noproxy '*' https://example.com >/dev/null 2>&1; then
  echo "WARNING: direct (non-proxied) egress succeeded — network isolation is NOT working"
else
  echo "OK: no direct route out, as expected"
fi
