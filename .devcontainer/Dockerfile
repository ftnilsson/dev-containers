# Base dev image. devcontainer "features" (node/python/gh) layer on top of
# this at build time via the Dev Containers CLI — that build step has normal
# internet access; only the *running* container is egress-restricted.
FROM mcr.microsoft.com/devcontainers/base:debian

# jq: handy for general use inside the sandbox.
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*

# Sandbox tooling scripts, baked into the image rather than read from
# /workspace — /workspace is intentionally just the workspace/ subdirectory
# (see docker-compose.yml), not this whole repo, so .devcontainer/ (these
# scripts' source location on the host) isn't reachable at runtime.
COPY scripts/gh-app-token.sh scripts/verify-egress.sh scripts/post-create.sh scripts/install-bundled-extensions.sh scripts/install-agent-grove-hooks.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/gh-app-token.sh /usr/local/bin/verify-egress.sh /usr/local/bin/post-create.sh /usr/local/bin/install-bundled-extensions.sh /usr/local/bin/install-agent-grove-hooks.sh

# `gh` wrapper that reads the live App token on every call (see the script).
# Sits ahead of the real /usr/bin/gh (installed later by the github-cli
# devcontainer feature) on PATH; the wrapper calls /usr/bin/gh by full path.
COPY scripts/gh-wrapper.sh /usr/local/bin/gh
RUN chmod +x /usr/local/bin/gh

# VS Code extensions bundled with the sandbox (vendored in the repo rather
# than pulled from GitHub/Marketplace at runtime, which the allowlist would
# block anyway). The build fails if a file doesn't match its pinned
# checksum in extensions/SHA256SUMS. Installed into VS Code by post-create.sh.
COPY extensions/ /opt/vsix/
RUN cd /opt/vsix && sha256sum -c SHA256SUMS && rm SHA256SUMS

# .NET SDK — version set via DOTNET_VERSION in .env (build-time arg, so it
# comes from the same file as everything else). Installed with Microsoft's
# official script rather than a devcontainer feature so it's configurable
# from .env instead of a hardcoded value in this file.
ARG DOTNET_VERSION=8.0
RUN case "${DOTNET_VERSION}" in \
      *.*) CHANNEL="${DOTNET_VERSION}" ;; \
      *) CHANNEL="${DOTNET_VERSION}.0" ;; \
    esac \
 && curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
 && bash /tmp/dotnet-install.sh --channel "${CHANNEL}" --install-dir /usr/share/dotnet \
 && rm /tmp/dotnet-install.sh \
 && ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet
ENV DOTNET_ROOT=/usr/share/dotnet \
    PATH="${PATH}:/usr/share/dotnet" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1
