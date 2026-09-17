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
COPY scripts/gh-app-token.sh scripts/verify-egress.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/gh-app-token.sh /usr/local/bin/verify-egress.sh

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
