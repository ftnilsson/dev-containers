#!/usr/bin/env bash
# Sets up the agent hooks the Agent Grove extension reads status from — what
# its "Agent Grove: Install Agent Hooks" command does, minus the clipboard
# and QuickPick (that command copies hook.mjs and puts a JSON snippet on the
# clipboard for you to merge by hand, so it can't run headlessly).
#
#   1. copies the extension's hook.mjs to ~/.agent-grove/hook.mjs
#   2. MERGES hook entries into ~/.claude/settings.json (existing settings
#      and other hooks are preserved; re-running never duplicates)
#   3. writes ~/.copilot/hooks/agent-grove.json (the extension's own file)
#
# Codex CLI isn't installed in this container, so it's skipped. Run after
# install-bundled-extensions.sh (needs the installed extension to source
# hook.mjs from). Idempotent; never fails the build — always exits 0.
set -u
shopt -s nullglob

src=$(ls -dt "$HOME"/.vscode-server/extensions/ftnilsson.agent-grove-*/dist/hook.mjs 2>/dev/null | head -1)
if [ -z "$src" ]; then
  echo "agent-grove-hooks: WARNING: extension not installed yet — hooks not set up." >&2
  echo "agent-grove-hooks: run install-bundled-extensions.sh, then this script." >&2
  exit 0
fi

hook="$HOME/.agent-grove/hook.mjs"
mkdir -p "$(dirname "$hook")" && cp "$src" "$hook" || { echo "agent-grove-hooks: WARNING: could not copy hook.mjs" >&2; exit 0; }

# --- Claude Code: merge into settings.json ---------------------------------
claude_settings="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$claude_settings")"
[ -s "$claude_settings" ] || echo '{}' > "$claude_settings"

cmd="node \"$hook\" --agent claude"
events='["SessionStart","UserPromptSubmit","PostToolUse","Notification","Stop","SessionEnd"]'
if merged=$(jq --arg cmd "$cmd" --argjson events "$events" '
      .hooks //= {} |
      reduce $events[] as $e (.;
        if ([.hooks[$e][]?.hooks[]?.command] | any(. == $cmd))
        then .
        else .hooks[$e] = ((.hooks[$e] // []) + [{hooks: [{type: "command", command: $cmd}]}])
        end)' "$claude_settings" 2>/dev/null); then
  printf '%s\n' "$merged" > "$claude_settings.tmp" && mv "$claude_settings.tmp" "$claude_settings"
  echo "agent-grove-hooks: Claude Code hooks merged into $claude_settings"
else
  # Don't clobber a file we can't parse (e.g. hand-edited with a typo).
  echo "agent-grove-hooks: WARNING: $claude_settings isn't valid JSON — left untouched, Claude hooks NOT installed." >&2
fi

# --- Copilot CLI: its own file ----------------------------------------------
copilot_file="$HOME/.copilot/hooks/agent-grove.json"
mkdir -p "$(dirname "$copilot_file")"
jq -n --arg hook "$hook" '
  ["sessionStart","userPromptSubmitted","postToolUse","permissionRequest","agentStop","sessionEnd"] as $events |
  {version: 1, hooks: ($events | map(. as $e |
    ("node \"" + $hook + "\" --agent copilot --event " + $e) as $c |
    {key: $e, value: [{type: "command", bash: $c, powershell: $c, timeoutSec: 10}]}) | from_entries)}
' > "$copilot_file.tmp" && mv "$copilot_file.tmp" "$copilot_file" \
  && echo "agent-grove-hooks: Copilot CLI hooks written to $copilot_file" \
  || echo "agent-grove-hooks: WARNING: could not write $copilot_file" >&2

exit 0
