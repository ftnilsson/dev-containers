#!/usr/bin/env bash
# Installs the .vsix extensions bundled into this image (/opt/vsix, see the
# Dockerfile) into the VS Code server inside the container — no Marketplace
# or GitHub access needed, so it works behind the deny-by-default proxy.
#
# Called from post-create.sh; also safe to re-run by hand (idempotent) if
# the extension is missing after a build, e.g. in case the VS Code server
# wasn't ready yet at create time. Reload the window afterwards.
#
# Never fails the container build: always exits 0, with a loud message.
set -u

shopt -s nullglob
vsix_files=(/opt/vsix/*.vsix)
if [ "${#vsix_files[@]}" -eq 0 ]; then
  echo "bundled-extensions: nothing to install in /opt/vsix"
  exit 0
fi

# Newest server install wins if several VS Code versions have left one
# behind. Lives under the vscode user's home, so this must run as that user.
cli=$(ls -dt "$HOME"/.vscode-server/bin/*/bin/code-server 2>/dev/null | head -1)
if [ -z "$cli" ]; then
  echo "bundled-extensions: WARNING: VS Code server CLI not found under ~/.vscode-server — not installed." >&2
  echo "bundled-extensions: once VS Code has connected, run: install-bundled-extensions.sh" >&2
  exit 0
fi

for vsix in "${vsix_files[@]}"; do
  if "$cli" --install-extension "$vsix"; then
    echo "bundled-extensions: installed $(basename "$vsix")"
  else
    echo "bundled-extensions: WARNING: failed to install $(basename "$vsix")" >&2
  fi
done
exit 0
