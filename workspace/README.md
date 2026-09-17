# Workspace

This directory — and only this directory — is what's mounted into the dev
container at `/workspace`. Put the project(s) you want an agent to work on
in here (a fresh clone, a symlink, whatever fits).

Everything else in this repo (`.devcontainer/`, `.env`, `.git`) is
deliberately **not** visible inside the container. An agent running in
there has no read or write access to the sandbox's own proxy allowlist,
compose file, Dockerfile, secrets, or this repo's git history — only to
whatever you put in `workspace/`. See the root [README.md](../README.md)'s
**Isolation boundary** section for why that separation exists.
