# Agent Sandbox Dev Container

A Podman + VS Code dev container for running AI coding agents (Claude Code,
GitHub Copilot, or anything else) with **deny-by-default network egress**:
the workspace container can only reach an explicit domain allowlist, enforced
by a proxy sidecar — not by hoping every tool honors an env var.

## Architecture

- **`workspace`** — where you (and the agent) work. Sits on an `internal`
  Podman network with **no route to the internet at all**.
- **`proxy`** (Squid) — the only container with a route out. Allows
  `CONNECT`/HTTP only to hosts listed in
  [.devcontainer/proxy/allowlist.txt](.devcontainer/proxy/allowlist.txt),
  tunneling HTTPS without decrypting it (no CA cert to install anywhere).

If a tool ignores `HTTP_PROXY`/`HTTPS_PROXY`, or tries a raw socket or DNS
lookup, it simply has nowhere to send packets — it fails closed instead of
silently bypassing the allowlist. That's what makes this agent-agnostic:
nothing here depends on Claude Code, Copilot, or any other tool
cooperating.

## Prerequisites: Podman + VS Code

Docker Desktop is the path VS Code's Dev Containers extension expects by
default; Podman works too, but needs three things set up first. Do them in
this order and verify each one before moving to the next — that way, if
something breaks, you know which layer it's in.

### 1. Install and start Podman itself

- Windows: `winget install RedHat.Podman` (or install **Podman Desktop**,
  which bundles this). Podman on Windows runs containers inside a small
  Linux VM, so after installing, initialize and start it:

  ```bash
  podman machine init
  podman machine start
  ```

  If `podman machine init` complains about WSL2, install it first
  (`wsl --install`, then reboot) and try again.
- macOS: `brew install podman`, then the same `podman machine init` /
  `podman machine start`.
- Linux: install `podman` via your package manager — no VM/machine step
  needed, it uses the host kernel directly.

**Verify:** `podman info` should print engine info with no connection
errors. If this doesn't work, nothing later in this guide will either — fix
it here first.

### 2. Make sure `podman-compose` resolves on PATH

VS Code's Dev Containers extension needs a `docker-compose`-compatible
command on your `PATH` (this repo's devcontainer uses Compose, for the two
services `workspace` + `proxy`).

First check whether Podman already has one wired up:

```bash
podman compose version
```

Recent Podman versions ship a built-in `compose` subcommand that finds (or
offers to auto-download) an external provider — it may just work already,
especially if Docker Desktop happens to also be installed (it'll reuse
Docker's `docker-compose.exe`). If that prints a version, you don't need
Python or `pip install podman-compose` at all.

The catch: VS Code's `dev.containers.dockerComposePath` setting (next step)
needs a single **executable name**, and `podman compose` is two words — it
won't resolve as one. Point it at a tiny wrapper instead of a real
standalone binary. In the same folder as `podman.exe` (already on `PATH` —
check with `Get-Command podman`), create two files, one per shell that
might invoke it:

`podman-compose.cmd` (what VS Code/PowerShell/cmd.exe will actually run):
```bat
@echo off
podman compose %*
```

`podman-compose` (no extension, for Git Bash / MSYS terminals — needs
`chmod +x`):
```bash
#!/bin/sh
exec podman compose "$@"
```

**Verify:** open a *new* terminal (so `PATH` picks up the new files) and
run `podman-compose version` — and, on Windows, also
`podman-compose.cmd version` since that's the literal command VS Code will
invoke. Both should print the same output as step 1's `podman compose
version`.

(No Podman-Desktop-bundled provider and no Docker Desktop either? Install
Python, then `pip install podman-compose` for a real standalone binary
instead of the wrapper above.)

### 3. Point VS Code at Podman instead of Docker

Install the **Dev Containers** extension
(`ms-vscode-remote.remote-containers`) if you haven't already. Then, in VS
Code: `Ctrl+,` to open Settings, search for each of these, and set them —
or edit your `settings.json` directly (Ctrl+Shift+P → "Preferences: Open
User Settings (JSON)") and add:

```json
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.dockerComposePath": "podman-compose"
}
```

Restart VS Code after changing these so the extension picks them up.

### 3.5. Known Podman/netavark bug: provision the network-fix watcher

Podman's `internal: true` networks (what isolates `workspace` from the
internet — see **Architecture**) have a bug: the firewall rule Podman
generates to allow traffic *within* that network only covers *other*
Podman networks, not the network's own subnet. Net effect: `workspace` and
`proxy` silently can't reach each other at all, even though the intended
behavior (`workspace` can't reach the *outside* world directly) works
correctly. This isn't fixable from `docker-compose.yml`/`squid.conf` — it's
a host-level firewall gap.

[devcontainer.json](.devcontainer/devcontainer.json)'s `initializeCommand`
works around it by launching a small watcher, on the host, before every
container start — it waits for Podman to (re)create the broken firewall
chain (which only exists while a container is actually attached to an
internal network) and patches it the moment it appears, then exits. That
watcher script has to live on the Podman machine VM itself (nftables state
is VM-local, not something a repo file can reach into), so it's **not**
part of this repo and needs provisioning once per VM:

```bash
podman machine ssh podman-machine-agentic -- 'cat > /root/.netfix.sh' <<'EOF'
#!/bin/sh
i=0
while [ "$i" -lt 90 ]; do
  if nft list chain ip filter NETAVARK_FORWARD 2>/dev/null | grep -q '10.89.0.0/16 ip daddr 10.89.0.0/16 accept'; then
    exit 0
  fi
  nft add rule ip filter NETAVARK_FORWARD ip saddr 10.89.0.0/16 ip daddr 10.89.0.0/16 accept 2>/dev/null
  i=$((i + 1))
  sleep 1
done
EOF
podman machine ssh podman-machine-agentic -- chmod +x /root/.netfix.sh
```

You only need this once — it's already done on this machine. Re-run it if
the Podman machine VM is ever recreated (`podman machine rm` + `init`), or
if you set this repo up on a different machine. If `podman-machine-agentic`
isn't your VM's name, check `podman machine list` and adjust both here and
in `devcontainer.json`'s `initializeCommand`.

### 4. Create `.env`, then sanity-check the build outside VS Code

Compose reads this file just to parse the file at all (even to run
`config`/`build`), so this has to happen before anything else touches
Compose — including the check right below:

```bash
cp .devcontainer/.env.example .devcontainer/.env
```

It must live next to `docker-compose.yml` (i.e. `.devcontainer/.env`), not
the repo root — Compose's own `${VAR}` substitution only reads `.env` from
its own directory. Leave the values blank for now to try the sandbox
itself first; fill them in later per **Authentication** below when the
agent needs to actually talk to GitHub/Anthropic.

Now build the two containers by hand from a terminal in this project's
root — it isolates "Podman/Compose is broken" from "the VS Code extension
is misconfigured":

```bash
podman-compose -f .devcontainer/docker-compose.yml build
```

This should complete with no errors (it'll take a few minutes the first
time). If it fails here, fix that before opening VS Code at all — the
extension will hit the exact same error, just with a less useful message.

## First-time setup

1. `.env` is already created from step 4 above — go fill in the values you
   need now if you skipped that; see **Authentication** below.
2. In VS Code, open this folder, then Command Palette
   (`Ctrl+Shift+P`) → **Dev Containers: Reopen in Container**. First build
   takes a few minutes (installs Node/Python/`gh`/.NET).
3. In the container terminal, run
   [.devcontainer/scripts/verify-egress.sh](.devcontainer/scripts/verify-egress.sh)
   to confirm the allowlist and network isolation are actually working
   before you trust the sandbox with anything.

### If "Reopen in Container" fails

- **"command not found: podman" / "docker not found"** — step 3's settings
  didn't take. Confirm they're in *User* settings (not a workspace override
  fighting them), and that you restarted VS Code.
- **Hangs or times out on build** — run the step 4 command by hand again;
  Compose build output there is much more readable than VS Code's log
  panel.
- **Hangs after build, while VS Code is "starting"** — it's usually
  downloading the VS Code Server into the container, which goes through the
  proxy. Check `podman-compose -f .devcontainer/docker-compose.yml logs
  proxy` for `TCP_DENIED` lines — Microsoft's CDN hostnames for this do
  drift, see **Extending the allowlist** below.
- **Networking/`internal: true` errors from Podman** — rootless Podman
  needs a reasonably recent version (5.x) for internal Compose networks to
  behave correctly; update Podman if you're on an old release.

## Toolchain versions

Node, Python, and `gh` come from devcontainer features (fixed versions in
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)). The
.NET SDK is different — it's installed in the
[Dockerfile](.devcontainer/Dockerfile) via a `DOTNET_VERSION` build arg so
it's configurable the same way secrets are: set `DOTNET_VERSION` in `.env`
(e.g. `8.0`, `9.0`), or leave it blank for the default (8.0). Rebuild the
container after changing it.

## Authentication

Repo access and AI-model access are handled separately and by design use
**different identities** — see below.

### GitHub (repo, PR, issue access) — dedicated GitHub App

A GitHub App is its own identity (`your-agent[bot]` in commits/PRs/audit
logs), scoped to only the repos and permissions you grant, authenticating
with tokens that expire in ~1 hour rather than a long-lived secret sitting
in the container.

1. GitHub → Settings → Developer settings → **GitHub Apps** → New GitHub
   App. Grant only what's needed (typically Contents, Pull requests, Issues
   — Read & write). Leave webhooks off.
2. Generate a private key (`.pem`) and save it **outside any repo**, e.g.
   `~/.secrets/github-app/agent-key.pem`.
3. Install the App on your account, selecting only the specific repo(s) the
   agent should touch.
4. Fill in `.env`: `GH_APP_ID`, `GH_APP_INSTALLATION_ID`,
   `GH_APP_PRIVATE_KEY_HOST_PATH` (host path to the `.pem`).

[.devcontainer/scripts/gh-app-token.sh](.devcontainer/scripts/gh-app-token.sh)
mints a fresh installation token and hands it to `gh auth login` +
`gh auth setup-git` (so plain `git push`/`pull` use it too). It runs
automatically on every container start; re-run it by hand if a session
outlives the ~1h token.

The private key never gets baked into the image or committed — it's
bind-mounted read-only from the host path you set above.

### Claude Code

Pick one:

- **You have a Claude subscription (Pro/Max)** — leave `ANTHROPIC_API_KEY`
  blank in `.env`. In the container terminal, run `claude` once and follow
  the login prompt (OAuth against your Claude.ai account). The session
  persists in the `claude-config` named volume, so it's one-time per volume,
  not per container rebuild.
- **No subscription, or want a fully separate/headless identity** (e.g.
  reusing this template elsewhere, or unattended runs) — create a dedicated
  Workspace + API key in the Anthropic Console and set
  `ANTHROPIC_API_KEY` in `.env`. This takes priority over a `claude login`
  session if both are present.

### GitHub Copilot

Copilot's AI access is tied to a **Copilot seat on your human GitHub
account** — a GitHub App installation can't hold one, so this part can't be
fully de-identified the way GitHub repo access and Claude Code can be.

- **VS Code extension** (`GitHub.copilot` / `GitHub.copilot-chat` — what
  most people mean by "Copilot"): sign in once via VS Code's Accounts icon
  or the Copilot Chat panel's "Sign in" prompt. Independent of `gh`'s auth
  store, so it never conflicts with the GitHub App token above.
- **`gh copilot` CLI** (optional, terminal suggestions): this *does* share
  `gh`'s auth store with the GitHub App token used for repo actions. If you
  want both, `gh auth login` a second time as yourself and use
  `gh auth switch` to toggle between your personal account (for
  `gh copilot`) and the App token (for scripted repo actions).

## Extending the allowlist

Something failed with a proxy/connection error →
`podman compose -f .devcontainer/docker-compose.yml logs proxy` (from the
host) and look for `TCP_DENIED` lines naming the blocked host. Add it to
[.devcontainer/proxy/allowlist.txt](.devcontainer/proxy/allowlist.txt) and
restart the `proxy` service.

Notes:

- OS package mirrors (`apt-get install` at runtime) are **not** allowlisted
  by default — add `deb.debian.org`/`security.debian.org` if you need them.
  (Build-time `apt-get`, e.g. in a Dockerfile or a devcontainer feature, is
  unaffected — the network restriction only applies to the running
  container.)
- Use HTTPS git remotes (`https://github.com/...`), not SSH — SSH doesn't
  go through an HTTP proxy the way this is set up.
- Microsoft's VS Code Server/Marketplace CDN hostnames drift over time; if
  "Reopen in Container" itself hangs, check the proxy logs before anything
  else.
